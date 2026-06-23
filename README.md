# Namaz Silent Mode

Automatically switches an Android phone to Vibrate / Silent / Do Not Disturb
during prayer times and restores the previous sound profile afterward.

## Stack

- **Flutter** (Android-first; iOS not targeted)
- **State management:** Riverpod (`flutter_riverpod`)
- **Local storage:** Hive (`schedules` box + `settings` box)
- **Background scheduling:** `android_alarm_manager_plus` (exact alarms) +
  `workmanager` (periodic safety-net + boot-recovery task)
- **Native channel:** `lib/services/ringer_service.dart` ↔
  `android/.../RingerModeHandler.kt` — Flutter has no built-in API to
  change ringer mode or toggle DND, so this is implemented as a native
  `MethodChannel`.
- **Prayer times:** `adhan` package (offline astronomical calculation,
  10 calculation methods) + `geolocator` for device location.

## Architecture (Clean Architecture layering)

```
lib/
  models/        # Hive entities: Schedule, AppSettings
  services/      # Platform/data layer: RingerService, SchedulerService,
                  # PrayerTimeService (no UI/state knowledge)
  providers/      # Riverpod providers/controllers (app state layer)
  screens/        # UI layer (Home, Schedule list, Add/Edit, Settings,
                  # Permissions)
  utils/          # Pure helper functions (next-schedule countdown calc)

android/app/src/main/kotlin/.../
  MainActivity.kt          # Registers the platform channel
  RingerModeHandler.kt     # Native ringer mode / DND / capture-restore logic
  BootReceiver.kt          # Re-triggers rescheduling after reboot/timezone change
```

## How scheduling works

1. Each `Schedule` has a start/end time (minutes-since-midnight) and a set
   of active weekdays.
2. `SchedulerService.scheduleForSchedule()` registers two **exact**
   `AndroidAlarmManager` one-shot alarms per schedule: one to "activate"
   (capture current ringer state, then switch mode) and one to "restore".
3. Alarms run a top-level Dart callback (`alarmCallbackDispatcher`) in a
   background isolate, which re-opens Hive, performs the action, and
   shows a local notification.
4. A `workmanager` **periodic task** (every 6 hours) re-reads all
   schedules and re-registers any missing alarms — a safety net against
   OEM battery-optimization killing exact alarms.

## Edge cases handled

| Case | Handling |
|---|---|
| Device reboot | `BootReceiver` (BOOT_COMPLETED) re-triggers the WorkManager `rescheduleAllAlarms` task, which re-reads Hive and re-registers every alarm. `android_alarm_manager_plus` alarms are also created with `rescheduleOnReboot: true`. |
| Timezone / DST change | `BootReceiver` also listens for `ACTION_TIMEZONE_CHANGED` / `ACTION_TIME_CHANGED` and reschedules, since minute-of-day alarms must be recalculated against the new local time. |
| App update | `ACTION_MY_PACKAGE_REPLACED` triggers the same reschedule path. |
| Overlapping schedules | Each schedule independently captures its own "previous state" snapshot at activation time; restoration uses that schedule's own snapshot, so nested/overlapping windows won't clobber each other's restore target (the innermost schedule's restore wins for its own window). |
| Permission revocation | `PermissionsScreen` polls live permission status and lets the user re-grant; `RingerModeHandler.applyRingerMode` silently degrades SILENT→VIBRATE if DND access is missing, instead of crashing. |
| Battery optimization killing alarms | 6-hourly WorkManager safety net + recommend user disable battery optimization for the app (can be added as an additional permission card). |

## Required permissions (declared in `AndroidManifest.xml`)

- `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` — precise prayer-time firing
- `ACCESS_NOTIFICATION_POLICY` — change ringer mode to Silent / toggle DND
- `RECEIVE_BOOT_COMPLETED` — reschedule after reboot
- `POST_NOTIFICATIONS` — activation/restoration notifications
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` — optional, only for
  automatic Prayer Time Mode

The in-app **Permissions** screen explains each one in plain language and
deep-links straight to the relevant system settings screen.

## Setup

```bash
flutter pub get
flutter packages pub run build_runner build   # generates schedule.g.dart, app_settings.g.dart
flutter run
```

## Known gaps to finish before a store release

- Generate Hive `.g.dart` adapter files via `build_runner` (not checked in
  here since they're generated code).
- Add app icon assets under `android/app/src/main/res/mipmap-*`.
- Wire up a "Disable battery optimization" permission card using
  `Permission.ignoreBatteryOptimizations` from `permission_handler`.
- Add unit tests for `computeNextSchedule` and the minute-of-day
  next-occurrence logic in `SchedulerService`.
- Add `flutter_local_notifications` Android 13+ runtime notification
  permission flow (already requested via `permission_handler` in the
  Permissions screen, but double check ordering on first launch).
