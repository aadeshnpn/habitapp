import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

/// Pure helpers for notification wall-clock math (unit-testable).
class NotificationTime {
  NotificationTime._();

  /// Next occurrence of [time] in [location] at or after [now].
  /// If [alreadyCompletedToday] is true, always use tomorrow.
  static tz.TZDateTime nextInstanceOfTime({
    required TimeOfDay time,
    required tz.TZDateTime now,
    bool alreadyCompletedToday = false,
  }) {
    var scheduled = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now) || alreadyCompletedToday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Build a fixed-offset [tz.Location] matching the device's current UTC offset.
  /// Used when the IANA timezone name cannot be resolved.
  static tz.Location fixedOffsetLocation(Duration offset) {
    final ms = offset.inMilliseconds;
    final sign = ms >= 0 ? '+' : '-';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    final name = 'UTC$sign$hours:$minutes';
    return tz.Location(
      name,
      const [0],
      const [0],
      [tz.TimeZone(ms, isDst: false, abbreviation: name)],
    );
  }

  /// Whether [scheduled] is a valid future fire time relative to [now].
  static bool isFutureSchedule(tz.TZDateTime scheduled, tz.TZDateTime now) {
    return scheduled.isAfter(now);
  }
}
