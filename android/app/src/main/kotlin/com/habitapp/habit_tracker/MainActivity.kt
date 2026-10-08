package com.habitapp.habit_tracker

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingNotifTest: String? = null

    private val isDebuggable: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Always available — creates mindfulness channels with resource-ID sound
        // URIs (name-based URIs often play silently on Pixel / Android 8+).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_SETUP,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setupMindfulnessChannels" -> {
                    try {
                        @Suppress("UNCHECKED_CAST")
                        val sounds =
                            call.argument<List<String>>("sounds") ?: emptyList()
                        val prefix =
                            call.argument<String>("prefix")
                                ?: "mindfulness_bell_v4_"
                        @Suppress("UNCHECKED_CAST")
                        val legacyPrefixes =
                            call.argument<List<String>>("legacyPrefixes")
                                ?: emptyList()
                        val created =
                            setupMindfulnessChannels(sounds, prefix, legacyPrefixes)
                        result.success(created)
                    } catch (e: Exception) {
                        result.error("channel_setup_failed", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Debug APKs only — release builds must not expose the notif_test bridge.
        if (!isDebuggable) return

        pendingNotifTest = intent?.getStringExtra(EXTRA_NOTIF_TEST)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_TEST,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    val value = pendingNotifTest
                    pendingNotifTest = null
                    result.success(value)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isDebuggable) {
            pendingNotifTest = intent.getStringExtra(EXTRA_NOTIF_TEST)
        }
    }

    /**
     * Creates mindfulness channels using numeric resource-ID sound URIs.
     * Returns the number of channels created/updated.
     */
    private fun setupMindfulnessChannels(
        sounds: List<String>,
        prefix: String,
        legacyPrefixes: List<String>,
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return 0

        val manager = getSystemService(NotificationManager::class.java) ?: return 0

        // Drop stale channels so users are not stuck with silent/broken ones.
        for (legacy in legacyPrefixes) {
            for (sound in sounds) {
                manager.deleteNotificationChannel(legacy + sound)
            }
        }

        val audioAttributes =
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

        var created = 0
        for (sound in sounds) {
            val resId = resources.getIdentifier(sound, "raw", packageName)
            if (resId == 0) continue

            // Numeric ID form — required for reliable custom sounds on many devices.
            val soundUri =
                Uri.parse("android.resource://$packageName/$resId")
            val channelId = prefix + sound
            val label =
                sound.replace('_', ' ').replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase() else it.toString()
                }

            val channel =
                NotificationChannel(
                    channelId,
                    "Mindfulness Bell ($label)",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Mindfulness bell sound and vibration"
                    setSound(soundUri, audioAttributes)
                    enableVibration(true)
                    setShowBadge(false)
                }
            manager.createNotificationChannel(channel)
            created++
        }
        return created
    }

    companion object {
        private const val CHANNEL_SETUP = "habitapp/notif_channels"
        private const val CHANNEL_TEST = "habitapp/notif_test"
        const val EXTRA_NOTIF_TEST = "notif_test"
    }
}
