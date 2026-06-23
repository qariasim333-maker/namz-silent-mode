package com.namazsilent.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import be.tramckrijte.workmanager.WorkmanagerPlugin

/**
 * Fires on BOOT_COMPLETED (and a few related actions) and asks the
 * Dart-side WorkManager task ("rescheduleAllAlarms") to re-read all
 * schedules from Hive and re-register native AlarmManager alarms.
 *
 * The actual rescheduling logic lives in Dart (Hive schedule data +
 * prayer-time calculation), so this receiver's only job is to reliably
 * kick that process off as early as possible after boot, timezone
 * change, or app update.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED -> {
                WorkmanagerPlugin.enqueueOneOffTask(
                    context,
                    "reschedule-all-alarms",
                    "rescheduleAllAlarms"
                )
            }
        }
    }
}
