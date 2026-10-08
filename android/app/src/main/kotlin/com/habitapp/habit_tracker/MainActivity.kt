package com.habitapp.habit_tracker

import android.content.Intent
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingNotifTest: String? = null

    private val isDebuggable: Boolean
        get() = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Mindfulness bell: media-stream playback + AlarmManager scheduling.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_MINDFULNESS,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "schedule" -> {
                    try {
                        val soundId = call.argument<String>("soundId") ?: "bowl"
                        @Suppress("UNCHECKED_CAST")
                        val times =
                            (call.argument<List<Number>>("timesMs") ?: emptyList())
                                .map { it.toLong() }
                        val count =
                            MindfulnessBellScheduler.schedule(
                                applicationContext,
                                soundId,
                                times,
                            )
                        result.success(count)
                    } catch (e: Exception) {
                        result.error("mindfulness_schedule_failed", e.message, null)
                    }
                }
                "cancel" -> {
                    try {
                        MindfulnessBellScheduler.cancel(applicationContext)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("mindfulness_cancel_failed", e.message, null)
                    }
                }
                "preview" -> {
                    try {
                        val soundId = call.argument<String>("soundId") ?: "bowl"
                        MindfulnessBellScheduler.preview(applicationContext, soundId)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("mindfulness_preview_failed", e.message, null)
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

    companion object {
        private const val CHANNEL_MINDFULNESS = "habitapp/mindfulness_bell"
        private const val CHANNEL_TEST = "habitapp/notif_test"
        const val EXTRA_NOTIF_TEST = "notif_test"
    }
}
