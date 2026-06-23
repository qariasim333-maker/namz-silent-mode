package com.namazsilent.app

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Handles all native ringer-mode / Do Not Disturb operations.
 *
 * Encoding used for "captureState" / "restoreState":
 *   bits 0-1  -> AudioManager ringer mode (0=silent,1=vibrate,2=normal)
 *   bits 2-4  -> NotificationManager interruption filter (0..4)
 */
class RingerModeHandler(private val context: Context) : MethodCallHandler {

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val notificationManager: NotificationManager
        get() = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "hasDndAccess" -> result.success(notificationManager.isNotificationPolicyAccessGranted)

            "openDndSettings" -> {
                val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
                result.success(null)
            }

            "canScheduleExactAlarms" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val am = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                    result.success(am.canScheduleExactAlarms())
                } else {
                    result.success(true)
                }
            }

            "openExactAlarmSettings" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    intent.data = Uri.parse("package:${context.packageName}")
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    context.startActivity(intent)
                }
                result.success(null)
            }

            "getRingerMode" -> result.success(audioManager.ringerMode)

            "setRingerMode" -> {
                val mode = call.argument<Int>("mode") ?: 2
                applyRingerMode(mode)
                result.success(null)
            }

            "enableDnd" -> {
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_PRIORITY
                    )
                    result.success(true)
                } else {
                    result.success(false)
                }
            }

            "disableDnd" -> {
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(
                        NotificationManager.INTERRUPTION_FILTER_ALL
                    )
                }
                result.success(null)
            }

            "captureState" -> {
                val ringer = audioManager.ringerMode
                val filter = notificationManager.currentInterruptionFilter
                val encoded = (ringer and 0x3) or ((filter and 0x7) shl 2)
                result.success(encoded)
            }

            "restoreState" -> {
                val encoded = call.argument<Int>("state") ?: 2
                val ringer = encoded and 0x3
                val filter = (encoded shr 2) and 0x7
                applyRingerMode(ringer)
                if (notificationManager.isNotificationPolicyAccessGranted) {
                    notificationManager.setInterruptionFilter(filter)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun applyRingerMode(mode: Int) {
        // SILENT mode requires DND access on Android 7+, otherwise the
        // system silently ignores the call. We guard anyway to avoid a
        // SecurityException.
        if (mode == AudioManager.RINGER_MODE_SILENT &&
            !notificationManager.isNotificationPolicyAccessGranted
        ) {
            // Fall back to vibrate if we don't have permission to go silent.
            audioManager.ringerMode = AudioManager.RINGER_MODE_VIBRATE
            return
        }
        audioManager.ringerMode = mode
    }

    companion object {
        const val CHANNEL_NAME = "namaz_silent_mode/ringer"
    }
}
