import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/schedule.dart';
import '../services/ringer_service.dart';
import '../services/scheduler_service.dart';

const _uuid = Uuid();

/// Exposes the open Hive box of schedules.
final scheduleBoxProvider = Provider<Box<Schedule>>((ref) {
  return Hive.box<Schedule>(kScheduleBoxName);
});

final settingsBoxProvider = Provider<Box<AppSettings>>((ref) {
  return Hive.box<AppSettings>(kSettingsBoxName);
});

/// All schedules, sorted by start time. Rebuilds whenever the Hive box
/// changes (add/edit/delete/duplicate).
final schedulesProvider =
    StreamProvider.autoDispose<List<Schedule>>((ref) async* {
  final box = ref.watch(scheduleBoxProvider);
  yield _sorted(box.values.toList());
  yield* box.watch().asyncMap((_) => Future.value(_sorted(box.values.toList())));
});

List<Schedule> _sorted(List<Schedule> list) {
  list.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  return list;
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
  (ref) => SettingsNotifier(ref.watch(settingsBoxProvider)),
);

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Box<AppSettings> _box;
  SettingsNotifier(this._box) : super(_box.get(kSettingsKey) ?? AppSettings()) {
    if (_box.get(kSettingsKey) == null) _box.put(kSettingsKey, state);
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    final updated = updater(state);
    state = updated;
    await _box.put(kSettingsKey, updated);
  }
}

/// CRUD operations for schedules. Every mutation also re-syncs native
/// alarms so the UI and the background scheduler never drift apart.
class ScheduleController extends StateNotifier<void> {
  final Box<Schedule> box;
  ScheduleController(this.box) : super(null);

  Future<void> add({
    required String name,
    required int startMinutes,
    required int endMinutes,
    required List<int> activeDays,
    SilenceMode mode = SilenceMode.vibrate,
    RestoreBehavior restoreBehavior = RestoreBehavior.previousMode,
  }) async {
    final schedule = Schedule(
      id: _uuid.v4(),
      name: name,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      activeDays: activeDays,
      mode: mode,
      restoreBehavior: restoreBehavior,
    );
    await box.put(schedule.id, schedule);
    await SchedulerService.scheduleForSchedule(schedule);
  }

  Future<void> update(Schedule schedule) async {
    await box.put(schedule.id, schedule);
    await SchedulerService.cancelForSchedule(schedule.id);
    if (schedule.enabled) {
      await SchedulerService.scheduleForSchedule(schedule);
    }
  }

  Future<void> delete(String id) async {
    await SchedulerService.cancelForSchedule(id);
    await box.delete(id);
  }

  Future<void> duplicate(Schedule schedule) async {
    final copy = schedule.copyWith(
      id: _uuid.v4(),
      name: '${schedule.name} (copy)',
      savedRingerMode: null,
    );
    await box.put(copy.id, copy);
    if (copy.enabled) {
      await SchedulerService.scheduleForSchedule(copy);
    }
  }

  Future<void> toggleEnabled(String id) async {
    final schedule = box.get(id);
    if (schedule == null) return;
    schedule.enabled = !schedule.enabled;
    await schedule.save();
    if (schedule.enabled) {
      await SchedulerService.scheduleForSchedule(schedule);
    } else {
      await SchedulerService.cancelForSchedule(id);
    }
  }
}

final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, void>(
  (ref) => ScheduleController(ref.watch(scheduleBoxProvider)),
);

/// Live current ringer mode, polled for the Home screen status card.
final currentRingerModeProvider = StreamProvider.autoDispose<RingerMode>((ref) async* {
  while (true) {
    yield await RingerService.getCurrentRingerMode();
    await Future.delayed(const Duration(seconds: 5));
  }
});

/// Master automation on/off switch (separate from individual schedule
/// toggles — this is the big Home-screen kill switch).
final automationEnabledProvider = Provider<bool>((ref) {
  return ref.watch(settingsProvider).automationEnabled;
});
