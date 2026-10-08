package com.habitapp.habit_tracker

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray

/**
 * Schedules mindfulness bells via [AlarmManager]. Playback is media-stream based
 * (not notification sound) so bells still ring in vibrate/silent mode.
 */
object MindfulnessBellScheduler {
    private const val TAG = "MindfulnessBell"
    private const val PREFS = "mindfulness_bell_alarms"
    private const val KEY_SOUND = "sound_id"
    private const val KEY_TIMES = "times_ms"
    private const val MAX_ALARMS = 48
    private const val REQUEST_BASE = 71000

    fun schedule(
        context: Context,
        soundId: String,
        timesMs: List<Long>,
    ): Int {
        cancel(context)

        val now = System.currentTimeMillis()
        val future =
            timesMs
                .filter { it > now + 1_000L }
                .distinct()
                .sorted()
                .take(MAX_ALARMS)

        Log.i(TAG, "schedule sound=$soundId incoming=${timesMs.size} future=${future.size}")

        if (future.isEmpty()) {
            clearPrefs(context)
            return 0
        }

        savePrefs(context, soundId, future)

        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return 0
        var scheduled = 0
        for ((index, whenMs) in future.withIndex()) {
            val pi = pendingIntent(context, index, soundId)
            val showPi = showPendingIntent(context)
            try {
                // setAlarmClock is the most reliable wake path on Pixel and is
                // an allowed exemption for starting a media FGS from background.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(whenMs, showPi),
                        pi,
                    )
                } else {
                    alarmManager.setExact(AlarmManager.RTC_WAKEUP, whenMs, pi)
                }
                scheduled++
            } catch (e: SecurityException) {
                Log.w(TAG, "setAlarmClock denied, falling back", e)
                try {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        whenMs,
                        pi,
                    )
                    scheduled++
                } catch (e2: Exception) {
                    Log.e(TAG, "fallback schedule failed index=$index", e2)
                }
            } catch (e: Exception) {
                Log.e(TAG, "schedule failed index=$index", e)
            }
        }
        Log.i(TAG, "scheduled=$scheduled alarms")
        return scheduled
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        for (index in 0 until MAX_ALARMS) {
            alarmManager.cancel(pendingIntent(context, index, "bowl"))
        }
        clearPrefs(context)
        Log.i(TAG, "cancelled all mindfulness alarms")
    }

    fun rescheduleFromPrefs(context: Context): Int {
        val sound = loadSound(context)
        val times = loadTimes(context)
        if (times.isEmpty()) return 0
        return schedule(context, sound, times)
    }

    fun preview(context: Context, soundId: String) {
        Log.i(TAG, "preview sound=$soundId")
        MindfulnessBellService.start(context, soundId, preview = true)
    }

    private fun pendingIntent(
        context: Context,
        index: Int,
        soundId: String,
    ): PendingIntent {
        val intent =
            Intent(context, MindfulnessBellReceiver::class.java).apply {
                action = MindfulnessBellReceiver.ACTION_FIRE
                putExtra(MindfulnessBellReceiver.EXTRA_SOUND_ID, soundId)
                putExtra(MindfulnessBellReceiver.EXTRA_SLOT, index)
            }
        val flags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_BASE + index,
            intent,
            flags,
        )
    }

    private fun showPendingIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent(context, MainActivity::class.java)
        val flags =
            PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_IMMUTABLE
                } else {
                    0
                }
        return PendingIntent.getActivity(context, 70999, launch, flags)
    }

    private fun savePrefs(context: Context, soundId: String, timesMs: List<Long>) {
        val arr = JSONArray()
        timesMs.forEach { arr.put(it) }
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SOUND, soundId)
            .putString(KEY_TIMES, arr.toString())
            .apply()
    }

    private fun clearPrefs(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun loadSound(context: Context): String =
        context
            .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SOUND, "bowl") ?: "bowl"

    private fun loadTimes(context: Context): List<Long> {
        val raw =
            context
                .getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_TIMES, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            buildList {
                for (i in 0 until arr.length()) add(arr.getLong(i))
            }
        } catch (_: Exception) {
            emptyList()
        }
    }
}
