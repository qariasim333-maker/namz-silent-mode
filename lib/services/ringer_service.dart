import 'package:flutter/services.dart';

/// Mirrors Android's AudioManager ringer modes:
/// 0 = SILENT, 1 = VIBRATE, 2 = NORMAL
enum RingerMode { silent, vibrate, normal }

/// Thin wrapper around a MethodChannel implemented natively in
/// android/app/.../RingerModeHandler.kt. Flutter has no built-in API to
/// change ringer mode or DND state, so this must go through native code.
class RingerService {
  static const _channel = MethodChannel('namaz_silent_mode/ringer');

  /// Returns true if the app has Notification Policy Access permission,
  /// which is required to change ringer mode to SILENT or to toggle DND
  /// on Android 7.0+.
  static Future<bool> hasNotificationPolicyAccess() async {
    return await _channel.invokeMethod<bool>('hasDndAccess') ?? false;
  }

  /// Opens the system settings screen where the user can grant
  /// Notification Policy Access (DND access) to this app.
  static Future<void> openNotificationPolicySettings() async {
    await _channel.invokeMethod('openDndSettings');
  }

  /// Returns true if the app can schedule exact alarms (Android 12+).
  static Future<bool> canScheduleExactAlarms() async {
    return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
        false;
  }

  static Future<void> openExactAlarmSettings() async {
    await _channel.invokeMethod('openExactAlarmSettings');
  }

  /// Reads the device's current ringer mode (0=silent,1=vibrate,2=normal).
  static Future<RingerMode> getCurrentRingerMode() async {
    final mode = await _channel.invokeMethod<int>('getRingerMode') ?? 2;
    return RingerMode.values[mode];
  }

  /// Switches the device ringer mode. For [RingerMode.silent] and DND,
  /// notification policy access must already be granted, or this is a
  /// no-op on the native side.
  static Future<void> setRingerMode(RingerMode mode) async {
    await _channel.invokeMethod('setRingerMode', {'mode': mode.index});
  }

  /// Enables Do Not Disturb (priority-only or total-silence interruption
  /// filter, depending on native implementation).
  static Future<void> enableDnd() async {
    await _channel.invokeMethod('enableDnd');
  }

  /// Disables Do Not Disturb, returning the interruption filter to
  /// "allow all".
  static Future<void> disableDnd() async {
    await _channel.invokeMethod('disableDnd');
  }

  /// Returns a snapshot int that encodes the full current state
  /// (ringer mode + DND filter) so it can be restored later. Stored
  /// as the schedule's savedRingerMode.
  static Future<int> captureCurrentState() async {
    return await _channel.invokeMethod<int>('captureState') ?? 2;
  }

  /// Restores a previously captured state from [captureCurrentState].
  static Future<void> restoreState(int state) async {
    await _channel.invokeMethod('restoreState', {'state': state});
  }
}
