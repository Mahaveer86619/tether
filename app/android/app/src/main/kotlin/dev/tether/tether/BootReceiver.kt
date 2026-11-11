package dev.tether.tether

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Starts the notification service again after the phone restarts, if it was on. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED && NotifyPrefs.of(context).getBoolean("enabled", false)) {
            NotifyPrefs.start(context)
        }
    }
}
