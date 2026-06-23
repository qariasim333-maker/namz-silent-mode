import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/app_settings.dart';
import 'models/schedule.dart';
import 'screens/home_screen.dart';
import 'services/scheduler_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(ScheduleAdapter());
  Hive.registerAdapter(SilenceModeAdapter());
  Hive.registerAdapter(RestoreBehaviorAdapter());
  Hive.registerAdapter(CalculationMethodOptionAdapter());
  Hive.registerAdapter(AppSettingsAdapter());

  final scheduleBox = await Hive.openBox<Schedule>(kScheduleBoxName);
  await Hive.openBox<AppSettings>(kSettingsBoxName);

  await SchedulerService.init();

  // Seed the five standard prayer schedules on first launch only.
  if (scheduleBox.isEmpty) {
    await _seedDefaultSchedules(scheduleBox);
  }

  await SchedulerService.rescheduleAll();

  runApp(const ProviderScope(child: NamazSilentModeApp()));
}

Future<void> _seedDefaultSchedules(Box<Schedule> box) async {
  final defaults = [
    Schedule(id: 'fajr', name: 'Fajr', startMinutes: 5 * 60, endMinutes: 5 * 60 + 30, activeDays: const [1, 2, 3, 4, 5, 6, 7]),
    Schedule(id: 'dhuhr', name: 'Dhuhr', startMinutes: 13 * 60 + 15, endMinutes: 13 * 60 + 45, activeDays: const [1, 2, 3, 4, 5, 6, 7]),
    Schedule(id: 'asr', name: 'Asr', startMinutes: 16 * 60 + 45, endMinutes: 17 * 60 + 15, activeDays: const [1, 2, 3, 4, 5, 6, 7]),
    Schedule(id: 'maghrib', name: 'Maghrib', startMinutes: 19 * 60, endMinutes: 19 * 60 + 20, activeDays: const [1, 2, 3, 4, 5, 6, 7]),
    Schedule(id: 'isha', name: 'Isha', startMinutes: 20 * 60 + 30, endMinutes: 21 * 60, activeDays: const [1, 2, 3, 4, 5, 6, 7]),
  ];
  for (final s in defaults) {
    await box.put(s.id, s);
  }
}

class NamazSilentModeApp extends StatelessWidget {
  const NamazSilentModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seed = const Color(0xFF1B5E20); // deep green, mosque-inspired
    return MaterialApp(
      title: 'Namaz Silent Mode',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
      ),
      home: const HomeScreen(),
    );
  }
}
