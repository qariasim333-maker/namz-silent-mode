import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../models/app_settings.dart';
import '../models/schedule.dart';
import 'ringer_service.dart';

const String kScheduleBoxName = 'schedules';
const String kSettingsBoxName = 'settings';
const String kSettingsKey = 'app_settings';
const String kRescheduleTask = 'rescheduleAllAlarms';

/// Each schedule gets two alarm IDs derived from a hash of its id:
/// one for "activate" (start) and one for "restore" (end).
int _activateAlarmId(String scheduleId) => scheduleId.hashCode & 0x7fffffff;
int _restoreAlarmId(String scheduleId) =>
    (scheduleId.hashCode ^ 0x5bd1e995) & 0x7fffffff;

/// Top-level entry point required by android_alarm_manager_plus.
/// Runs in a background isolate, so it must open Hive itself.
@pragma('vm:entry-point')
void alarmCallbackDispatcher(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBindingHelper.ensureInitialized();
  await Hive.initFlutter();
  _registerAdapters();

  final scheduleId = params['scheduleId'] as String;
  final action = params['action'] as String; // 'activate' or 'restore'

  final box = await Hive.openBox<Schedule>(kScheduleBoxName);
  final schedule = box.values.firstWhere(
    (s) => s.id == scheduleId,
    orElse: () => Schedule(
      id: scheduleId,
      name: 'unknown',
      startMinutes: 0,
      endMinutes: 0,
      activeDays: [],
    ),
  );

  if (action == 'activate') {
    await _activate(schedule, box);
  } else {
    await _restore(schedule, box);
  }
}

Future<void> _activate(Schedule schedule, Box<Schedule> box) async {
  if (!schedule.enabled) return;
  if (!schedule.activeDays.contains(DateTime.now().weekday)) return;

  final captured = await RingerService.captureCurrentState();
  schedule.savedRingerMode = captured;
  await schedule.save();

  switch (schedule.mode) {
    case SilenceMode.vibrate:
      await RingerService.setRingerMode(RingerMode.vibrate);
      break;
    case SilenceMode.silent:
      await RingerService.setRingerMode(RingerMode.silent);
      break;
    case SilenceMode.dnd:
      await RingerService.enableDnd();
      break;
  }

  await NotificationHelper.show(
    title: 'Silent Mode Activated',
    body: '${schedule.name} — phone switched to ${schedule.mode.name}.',
    id: schedule.id.hashCode,
  );
}

Future<void> _restore(Schedule schedule, Box<Schedule> box) async {
  final settingsBox = await Hive.openBox<AppSettings>(kSettingsBoxName);
  final settings = settingsBox.get(kSettingsKey) ?? AppSettings();

  if (schedule.restoreBehavior == RestoreBehavior.alwaysNormal ||
      settings.restoreBehavior == RestoreBehavior.alwaysNormal) {
    await RingerService.disableDnd();
    await RingerService.setRingerMode(RingerMode.normal);
  } else if (schedule.savedRingerMode != null) {
    await RingerService.restoreState(schedule.savedRingerMode!);
  } else {
    await RingerService.disableDnd();
    await RingerService.setRingerMode(RingerMode.normal);
  }

  await NotificationHelper.show(
    title: 'Silent Mode Restored',
    body: '${schedule.name} ended — previous sound profile restored.',
    id: schedule.id.hashCode + 1,
  );
}

void _registerAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ScheduleAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SilenceModeAdapter());
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(RestoreBehaviorAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(CalculationMethodOptionAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(AppSettingsAdapter());
}

/// WorkManager headless callback dispatcher. Handles the
/// boot/timezone-change "reschedule everything" task, plus acts as a
/// secondary safety net for activate/restore in case an exact alarm
/// was dropped by the OS (e.g. aggressive battery optimization).
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Hive.initFlutter();
    _registerAdapters();

    if (task == kRescheduleTask) {
      await SchedulerService.rescheduleAll();
    }
    return Future.value(true);
  });
}

class SchedulerService {
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();
    await Workmanager().initialize(
      workManagerCallbackDispatcher,
      isInDebugMode: false,
    );
  }

  /// Cancels and re-registers exact alarms for every enabled schedule.
  /// Called on: app start, schedule create/edit/delete, boot, timezone
  /// change, and as a periodic safety net.
  static Future<void> rescheduleAll() async {
    final box = await Hive.openBox<Schedule>(kScheduleBoxName);
    for (final schedule in box.values) {
      await cancelForSchedule(schedule.id);
      if (schedule.enabled) {
        await scheduleForSchedule(schedule);
      }
    }

    // Periodic safety-net task in case exact alarms get dropped.
    await Workmanager().registerPeriodicTask(
      'safety-net-reschedule',
      kRescheduleTask,
      frequency: const Duration(hours: 6),
    );
  }

  static Future<void> scheduleForSchedule(Schedule schedule) async {
    final now = DateTime.now();
    final nextStart = _nextOccurrence(schedule.startMinutes, schedule.activeDays, now);
    final nextEnd = _nextOccurrence(schedule.endMinutes, schedule.activeDays, now);

    await AndroidAlarmManager.oneShotAt(
      nextStart,
      _activateAlarmId(schedule.id),
      alarmCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {'scheduleId': schedule.id, 'action': 'activate'},
    );

    await AndroidAlarmManager.oneShotAt(
      nextEnd,
      _restoreAlarmId(schedule.id),
      alarmCallbackDispatcher,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
      params: {'scheduleId': schedule.id, 'action': 'restore'},
    );
  }

  static Future<void> cancelForSchedule(String scheduleId) async {
    await AndroidAlarmManager.cancel(_activateAlarmId(scheduleId));
    await AndroidAlarmManager.cancel(_restoreAlarmId(scheduleId));
  }

  /// Finds the next DateTime (today or a future day) matching one of the
  /// schedule's active weekdays at the given minute-of-day.
  static DateTime _nextOccurrence(
    int minuteOfDay,
    List<int> activeDays,
    DateTime from,
  ) {
    for (int offset = 0; offset < 8; offset++) {
      final candidateDate = from.add(Duration(days: offset));
      if (!activeDays.contains(candidateDate.weekday) && activeDays.isNotEmpty) {
        continue;
      }
      final candidate = DateTime(
        candidateDate.year,
        candidateDate.month,
        candidateDate.day,
      ).add(Duration(minutes: minuteOfDay));
      if (candidate.isAfter(from)) return candidate;
    }
    // Fallback: same time tomorrow.
    return from.add(const Duration(days: 1));
  }
}

/// Minimal stand-in so the background isolate entry point compiles
/// without pulling in a full WidgetsFlutterBinding dependency chain.
class WidgetsFlutterBindingHelper {
  static void ensureInitialized() {
    DartPluginRegistrant.ensureInitialized();
  }
}

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    _initialized = true;
  }

  static Future<void> show({
    required String title,
    required String body,
    required int id,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      'silent_mode_channel',
      'Silent Mode Updates',
      channelDescription: 'Notifies when silent mode is activated or restored',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }
}
