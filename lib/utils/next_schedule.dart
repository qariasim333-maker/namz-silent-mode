import '../models/schedule.dart';

class NextScheduleInfo {
  final Schedule schedule;
  final DateTime startsAt;
  final Duration remaining;
  final bool isCurrentlyActive;
  final DateTime? endsAt;

  NextScheduleInfo({
    required this.schedule,
    required this.startsAt,
    required this.remaining,
    required this.isCurrentlyActive,
    this.endsAt,
  });
}

/// Determines the currently-active schedule (if any) or the next
/// upcoming one, along with a countdown — used on the Home screen.
NextScheduleInfo? computeNextSchedule(List<Schedule> schedules) {
  final enabled = schedules.where((s) => s.enabled).toList();
  if (enabled.isEmpty) return null;

  final now = DateTime.now();
  final nowMinutes = now.hour * 60 + now.minute;

  // 1. Check if any schedule is currently active (today).
  for (final s in enabled) {
    if (s.activeDays.contains(now.weekday) &&
        nowMinutes >= s.startMinutes &&
        nowMinutes < s.endMinutes) {
      final endsAt = DateTime(now.year, now.month, now.day)
          .add(Duration(minutes: s.endMinutes));
      return NextScheduleInfo(
        schedule: s,
        startsAt: DateTime(now.year, now.month, now.day)
            .add(Duration(minutes: s.startMinutes)),
        remaining: endsAt.difference(now),
        isCurrentlyActive: true,
        endsAt: endsAt,
      );
    }
  }

  // 2. Otherwise find the soonest upcoming start across the next 8 days.
  DateTime? bestStart;
  Schedule? bestSchedule;
  for (final s in enabled) {
    for (int offset = 0; offset < 8; offset++) {
      final day = now.add(Duration(days: offset));
      if (s.activeDays.isNotEmpty && !s.activeDays.contains(day.weekday)) {
        continue;
      }
      final candidate = DateTime(day.year, day.month, day.day)
          .add(Duration(minutes: s.startMinutes));
      if (candidate.isAfter(now)) {
        if (bestStart == null || candidate.isBefore(bestStart)) {
          bestStart = candidate;
          bestSchedule = s;
        }
        break;
      }
    }
  }

  if (bestStart == null || bestSchedule == null) return null;
  return NextScheduleInfo(
    schedule: bestSchedule,
    startsAt: bestStart,
    remaining: bestStart.difference(now),
    isCurrentlyActive: false,
  );
}
