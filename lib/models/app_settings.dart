import 'package:hive/hive.dart';
import 'schedule.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 3)
enum CalculationMethodOption {
  @HiveField(0)
  muslimWorldLeague,
  @HiveField(1)
  egyptian,
  @HiveField(2)
  karachi,
  @HiveField(3)
  ummAlQura,
  @HiveField(4)
  dubai,
  @HiveField(5)
  moonsightingCommittee,
  @HiveField(6)
  northAmerica,
  @HiveField(7)
  kuwait,
  @HiveField(8)
  qatar,
  @HiveField(9)
  singapore,
}

@HiveType(typeId: 4)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool automationEnabled;

  @HiveField(1)
  bool prayerTimeModeEnabled;

  @HiveField(2)
  CalculationMethodOption calculationMethod;

  /// Prayer duration in minutes (15, 20, 30, or custom)
  @HiveField(3)
  int prayerDurationMinutes;

  @HiveField(4)
  SilenceMode defaultMode;

  @HiveField(5)
  RestoreBehavior restoreBehavior;

  @HiveField(6)
  double? lastLatitude;

  @HiveField(7)
  double? lastLongitude;

  @HiveField(8)
  bool notifyOnActivate;

  @HiveField(9)
  bool notifyOnRestore;

  AppSettings({
    this.automationEnabled = true,
    this.prayerTimeModeEnabled = false,
    this.calculationMethod = CalculationMethodOption.muslimWorldLeague,
    this.prayerDurationMinutes = 20,
    this.defaultMode = SilenceMode.vibrate,
    this.restoreBehavior = RestoreBehavior.previousMode,
    this.lastLatitude,
    this.lastLongitude,
    this.notifyOnActivate = true,
    this.notifyOnRestore = true,
  });
}
