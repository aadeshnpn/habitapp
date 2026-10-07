import 'dart:math';

import 'package:timezone/timezone.dart' as tz;

import 'mindfulness_bell_config.dart';

/// Pure Dart generator for jittered mindfulness bell fire times.
class MindfulnessBellScheduler {
  MindfulnessBellScheduler._();

  /// Generate remaining one-shot fire times for today (and tomorrow's window
  /// if still enabled), each offset from the cadence by ±[MindfulnessBellConfig.jitterMinutes].
  static List<tz.TZDateTime> generateSlots({
    required MindfulnessBellConfig config,
    required tz.TZDateTime now,
    Random? random,
    int maxSlots = 48,
  }) {
    if (!config.enabled) return const [];

    final startMinutes = config.startHour * 60 + config.startMinute;
    final endMinutes = config.endHour * 60 + config.endMinute;
    if (endMinutes <= startMinutes) return const [];
    if (config.intervalMinutes <= 0) return const [];

    final rng = random ?? Random();
    final slots = <tz.TZDateTime>[];

    // Schedule remaining times for today, then the full tomorrow window so
    // bells keep working overnight without requiring the app to reopen.
    for (final dayOffset in [0, 1]) {
      final day = now.add(Duration(days: dayOffset));
      final windowStart = tz.TZDateTime(
        now.location,
        day.year,
        day.month,
        day.day,
        config.startHour,
        config.startMinute,
      );
      final windowEnd = tz.TZDateTime(
        now.location,
        day.year,
        day.month,
        day.day,
        config.endHour,
        config.endMinute,
      );

      var cursor = windowStart;
      while (!cursor.isAfter(windowEnd) && slots.length < maxSlots) {
        final jitter =
            rng.nextInt(MindfulnessBellConfig.jitterMinutes * 2 + 1) -
                MindfulnessBellConfig.jitterMinutes;
        var fireAt = cursor.add(Duration(minutes: jitter));

        if (fireAt.isBefore(windowStart)) fireAt = windowStart;
        if (fireAt.isAfter(windowEnd)) {
          // Skip this cadence tick if jitter pushed past the window.
          cursor = cursor.add(Duration(minutes: config.intervalMinutes));
          continue;
        }

        if (fireAt.isAfter(now)) {
          slots.add(fireAt);
        }

        cursor = cursor.add(Duration(minutes: config.intervalMinutes));
      }
    }

    slots.sort();
    return slots.take(maxSlots).toList();
  }
}
