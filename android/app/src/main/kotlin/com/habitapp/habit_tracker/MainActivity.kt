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
        // Debug APKs only — release builds must not expose the notif_test bridge.
        if (!isDebuggable) return

        pendingNotifTest = intent?.getStringExtra(EXTRA_NOTIF_TEST)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
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
        private const val CHANNEL = "habitapp/notif_test"
        const val EXTRA_NOTIF_TEST = "notif_test"
    }
}
