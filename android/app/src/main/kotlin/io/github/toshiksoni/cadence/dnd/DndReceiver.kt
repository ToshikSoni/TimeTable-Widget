package io.github.toshiksoni.cadence.dnd

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Fires at each Do Not Disturb boundary, and re-arms after reboots and updates. */
class DndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        DndScheduler.apply(context)
    }

    companion object {
        const val ACTION_TICK = "io.github.toshiksoni.cadence.dnd.TICK"
    }
}
