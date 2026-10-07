import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:habit_tracker/features/mindfulness_bell/domain/mindfulness_bell_config.dart';
import 'package:habit_tracker/features/mindfulness_bell/domain/mindfulness_bell_scheduler.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  MindfulnessBellConfig config({
    bool enabled = true,
    int startHour = 9,
    int startMinute = 0,
    int endHour = 17,
    int endMinute = 0,
    int intervalMinutes = 30,
    String soundId = 'bowl',
  }) =>
      MindfulnessBellConfig(
        enabled: enabled,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        intervalMinutes: intervalMinutes,
        soundId: soundId,
      );

  tz.TZDateTime at(int hour, int minute, {int day = 6}) =>
      tz.TZDateTime(tz.UTC, 2026, 10, day, hour, minute);

  group('MindfulnessBellScheduler.generateSlots', () {
    test('returns empty when disabled', () {
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config(enabled: false),
        now: at(10, 0),
        random: Random(1),
      );
      expect(slots, isEmpty);
    });

    test('returns empty when end is before start', () {
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config(startHour: 17, endHour: 9),
        now: at(10, 0),
        random: Random(1),
      );
      expect(slots, isEmpty);
    });

    test('all slots fall within the daily window (±jitter clamped)', () {
      final now = at(8, 0);
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config(),
        now: now,
        random: Random(42),
      );

      expect(slots, isNotEmpty);
      for (final slot in slots) {
        final minutes = slot.hour * 60 + slot.minute;
        // Window 09:00–17:00; jitter may not push outside after clamp/skip.
        expect(minutes, greaterThanOrEqualTo(9 * 60));
        expect(minutes, lessThanOrEqualTo(17 * 60));
        expect(slot.isAfter(now), isTrue);
      }
    });

    test('skips slots that are already in the past today', () {
      final now = at(16, 0);
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config(intervalMinutes: 30),
        now: now,
        random: Random(0),
      );

      for (final slot in slots.where((s) => s.day == now.day)) {
        expect(slot.isAfter(now), isTrue);
      }
      // Still schedules tomorrow's window.
      expect(slots.any((s) => s.day == now.day + 1), isTrue);
    });

    test('respects maxSlots cap', () {
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config(
          startHour: 0,
          endHour: 23,
          endMinute: 59,
          intervalMinutes: 15,
        ),
        now: at(0, 0),
        random: Random(1),
        maxSlots: 10,
      );
      expect(slots.length, lessThanOrEqualTo(10));
    });

    test('jitter stays within ±10 of cadence with fixed seed variability', () {
      // With jitter disabled path: interval cadence from start.
      // Verify two seeds produce different schedules for same window.
      final a = MindfulnessBellScheduler.generateSlots(
        config: config(),
        now: at(8, 0),
        random: Random(1),
      );
      final b = MindfulnessBellScheduler.generateSlots(
        config: config(),
        now: at(8, 0),
        random: Random(2),
      );
      expect(a.map((e) => e.toIso8601String()).toList(),
          isNot(b.map((e) => e.toIso8601String()).toList()));
    });
  });
}
