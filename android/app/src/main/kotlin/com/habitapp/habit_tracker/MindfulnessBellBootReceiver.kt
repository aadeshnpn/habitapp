package com.habitapp.habit_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-arms mindfulness media alarms after reboot / app update. */
class MindfulnessBellBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            MindfulnessBellScheduler.rescheduleFromPrefs(context)
        }
    }
}
