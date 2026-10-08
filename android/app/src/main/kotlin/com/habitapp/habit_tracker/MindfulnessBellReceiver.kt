package com.habitapp.habit_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Fires when a scheduled mindfulness alarm is due — starts media playback. */
class MindfulnessBellReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != ACTION_FIRE) return
        val soundId = intent.getStringExtra(EXTRA_SOUND_ID) ?: "bowl"
        Log.i(TAG, "alarm fired sound=$soundId slot=${intent.getIntExtra(EXTRA_SLOT, -1)}")
        // goAsync gives us a bit more time to start the FGS on slower devices.
        val pending = goAsync()
        try {
            MindfulnessBellService.start(context, soundId, preview = false)
        } finally {
            pending.finish()
        }
    }

    companion object {
        private const val TAG = "MindfulnessBell"
        const val ACTION_FIRE = "com.habitapp.habit_tracker.MINDFULNESS_BELL_FIRE"
        const val EXTRA_SOUND_ID = "sound_id"
        const val EXTRA_SLOT = "slot"
    }
}
