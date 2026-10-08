package com.habitapp.habit_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Plays the mindfulness bell on the **media** stream (works in silent/vibrate)
 * and shows a silent status notification that auto-dismisses after 10 seconds.
 */
class MindfulnessBellService : Service() {
    private var player: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())
    private var dismissPosted = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val soundId = intent?.getStringExtra(EXTRA_SOUND_ID) ?: "bowl"
        Log.i(TAG, "onStartCommand sound=$soundId")

        try {
            ensureChannel()
            val notification = buildNotification()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            Log.e(TAG, "startForeground failed", e)
            // Still try to play even if notification setup fails.
        }

        acquireWakeLock()
        scheduleAutoDismiss()
        playSound(soundId)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        abandonAudioFocus()
        releasePlayer()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun scheduleAutoDismiss() {
        if (dismissPosted) return
        dismissPosted = true
        // Keep the silent status chip for 10s, then tear down the FGS properly.
        // NotificationManager.cancel() alone does NOT remove a foreground notification.
        handler.postDelayed({ finishAndRemoveNotification() }, AUTO_DISMISS_MS)
    }

    private fun playSound(soundId: String) {
        releasePlayer()
        val resId = resources.getIdentifier(soundId, "raw", packageName)
        if (resId == 0) {
            Log.e(TAG, "Missing raw resource for soundId=$soundId")
            return
        }

        try {
            val audioManager = getSystemService(AudioManager::class.java)
            val attrs =
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && audioManager != null) {
                val req =
                    AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                        .setAudioAttributes(attrs)
                        .setOnAudioFocusChangeListener { }
                        .build()
                focusRequest = req
                val focus = audioManager.requestAudioFocus(req)
                Log.i(TAG, "audioFocus=$focus")
            }

            // MediaPlayer.create uses the app resources and is more reliable than
            // manually setting a resource URI on some Pixel builds.
            val created = MediaPlayer.create(this, resId)
            if (created == null) {
                Log.e(TAG, "MediaPlayer.create returned null for resId=$resId")
                return
            }
            player =
                created.apply {
                    setAudioAttributes(attrs)
                    isLooping = false
                    setOnCompletionListener {
                        Log.i(TAG, "playback complete")
                        // Keep the status notification until the 10s timer; only
                        // release the player here.
                        releasePlayer()
                        abandonAudioFocus()
                    }
                    setOnErrorListener { _, what, extra ->
                        Log.e(TAG, "MediaPlayer error what=$what extra=$extra")
                        releasePlayer()
                        true
                    }
                    // create() already prepared
                    start()
                    Log.i(TAG, "playback started durationMs=${duration}")
                }
        } catch (e: Exception) {
            Log.e(TAG, "playSound failed", e)
            releasePlayer()
        }
    }

    private fun finishAndRemoveNotification() {
        Log.i(TAG, "auto-dismiss — stopping foreground service")
        releasePlayer()
        abandonAudioFocus()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "stopForeground failed", e)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(NOTIFICATION_ID)
        releaseWakeLock()
        stopSelf()
    }

    private fun releasePlayer() {
        try {
            player?.setOnCompletionListener(null)
            player?.setOnErrorListener(null)
            if (player?.isPlaying == true) player?.stop()
            player?.release()
        } catch (_: Exception) {
        }
        player = null
    }

    private fun abandonAudioFocus() {
        try {
            val am = getSystemService(AudioManager::class.java) ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focusRequest?.let { am.abandonAudioFocusRequest(it) }
            }
        } catch (_: Exception) {
        }
        focusRequest = null
    }

    private fun acquireWakeLock() {
        try {
            val pm = getSystemService(PowerManager::class.java) ?: return
            wakeLock =
                pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "habitapp:mindfulness_bell",
                ).also {
                    it.setReferenceCounted(false)
                    it.acquire(AUTO_DISMISS_MS + 2_000L)
                }
        } catch (e: Exception) {
            Log.e(TAG, "wakeLock failed", e)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        // Drop older channel variants that may have been created with sound.
        nm.deleteNotificationChannel("mindfulness_bell_media_v1")
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                "Mindfulness Bell",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description =
                    "Silent status while the mindfulness bell plays on media volume"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        nm.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val launch =
            packageManager.getLaunchIntentForPackage(packageName)?.let { launchIntent ->
                val flags =
                    PendingIntent.FLAG_UPDATE_CURRENT or
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_IMMUTABLE
                        } else {
                            0
                        }
                PendingIntent.getActivity(this, 0, launchIntent, flags)
            }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Mindfulness")
            .setContentText("Take a breath")
            .setSmallIcon(R.drawable.ic_stat_mindfulness)
            .setContentIntent(launch)
            .setOngoing(true) // FGS status; removed explicitly after 10s
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .build()
    }

    companion object {
        private const val TAG = "MindfulnessBell"
        const val CHANNEL_ID = "mindfulness_bell_media_v2"
        const val NOTIFICATION_ID = 6998
        const val EXTRA_SOUND_ID = "sound_id"
        private const val AUTO_DISMISS_MS = 10_000L

        fun start(context: Context, soundId: String, preview: Boolean) {
            Log.i(TAG, "start requested sound=$soundId preview=$preview")
            val intent =
                Intent(context, MindfulnessBellService::class.java).apply {
                    putExtra(EXTRA_SOUND_ID, soundId)
                    putExtra("preview", preview)
                }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "startForegroundService failed", e)
            }
        }
    }
}
