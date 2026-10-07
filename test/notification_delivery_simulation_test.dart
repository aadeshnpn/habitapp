/// Simulated notification delivery tests.
///
/// These do not need a real Android device. They verify the scheduling math
/// and scheduler wiring that historically caused "no notifications" on Pixel:
/// wrong timezone wall-clock, past fire times, and disabled toggles.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:habit_tracker/core/notifications/notification_ids.dart';
import 'package:habit_tracker/core/notifications/notification_scheduler.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/core/notifications/notification_time.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/mindfulness_bell/domain/mindfulness_bell_config.dart';
import 'package:habit_tracker/features/mindfulness_bell/domain/mindfulness_bell_scheduler.dart';
import 'package:habit_tracker/features/reminders/data/interval_reminder_model.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';

class _RecordingService implements NotificationServiceBase {
  final scheduled = <Map<String, dynamic>>[];
  final cancelled = <int>[];
  int testShows = 0;
  int testSchedules = 0;

  @override
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  }) async {
    final when = NotificationTime.nextInstanceOfTime(
      time: time,
      now: tz.TZDateTime.now(tz.local),
      alreadyCompletedToday: alreadyCompletedToday,
    );
    scheduled.add({
      'type': 'daily',
      'habitId': habitId,
      'time': time,
      'when': when,
      'id': NotificationIds.daily(habitId),
    });
  }

  @override
  Future<void> scheduleStreakAtRiskAlert({
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
    scheduled.add({'type': 'atrisk', 'habitId': habitId, 'streak': streak});
  }

  @override
  Future<void> scheduleStreakRepairReminder({
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {}

  @override
  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  }) async {}

  @override
  Future<void> cancelHabitNotifications(String habitId) async {
    cancelled.addAll([
      NotificationIds.daily(habitId),
      NotificationIds.atRisk(habitId),
      NotificationIds.repair(habitId),
    ]);
  }

  @override
  Future<void> cancelNotification(int id) async => cancelled.add(id);

  @override
  Future<void> scheduleIntervalReminder({
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  }) async {
    scheduled.add({
      'type': 'interval',
      'reminderId': reminderId,
      'slots': slots,
      'count': slots.length,
    });
  }

  @override
  Future<void> cancelIntervalReminder(String reminderId) async {}

  @override
  Future<void> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  }) async {
    scheduled.add({
      'type': 'mindfulness',
      'soundId': soundId,
      'whenList': whenList,
    });
  }

  @override
  Future<void> cancelMindfulnessBells() async {
    scheduled.add({'type': 'mindfulness_cancel'});
  }

  @override
  Future<void> previewMindfulnessBell(String soundId) async {}

  @override
  Future<void> scheduleSnooze({
    required int originalNotifId,
    required String habitId,
    required String habitName,
    required String habitIcon,
    int snoozeMinutes = 30,
  }) async {}

  @override
  Future<void> showTestNotification() async => testShows++;

  @override
  Future<void> scheduleTestNotification({int minutesFromNow = 1}) async =>
      testSchedules++;

  @override
  Future<int> pendingNotificationCount() async => scheduled.length;

  @override
  Future<bool> canScheduleExactNotifications() async => true;
}

Habit _habit({
  String id = 'h1',
  String? reminderTime = '09:00',
}) =>
    Habit(
      id: id,
      name: 'Run',
      icon: '🏃',
      color: 0xFF4CAF50,
      frequencyType: FrequencyType.daily,
      checkInType: CheckInType.tap,
      reminderTime: reminderTime,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('NotificationTime simulation', () {
    test('fixed offset location matches device wall clock hours', () {
      // Simulate MDT (UTC-6).
      final loc = NotificationTime.fixedOffsetLocation(
        const Duration(hours: -6),
      );
      tz.setLocalLocation(loc);

      final now = tz.TZDateTime(loc, 2026, 10, 6, 8, 0); // 8:00 local
      final next = NotificationTime.nextInstanceOfTime(
        time: const TimeOfDay(hour: 9, minute: 0),
        now: now,
      );

      expect(next.hour, 9);
      expect(next.minute, 0);
      expect(next.day, 6);
      expect(next.isAfter(now), isTrue);
      // Instant should be 9:00 MDT == 15:00 UTC
      expect(next.toUtc().hour, 15);
    });

    test('UTC fallback bug: wall hour must NOT be treated as UTC hour', () {
      // This is the bug users hit when tz.local stayed UTC on a US phone.
      final mdt = NotificationTime.fixedOffsetLocation(
        const Duration(hours: -6),
      );
      final nowMdt = tz.TZDateTime(mdt, 2026, 10, 6, 8, 30);
      final correct = NotificationTime.nextInstanceOfTime(
        time: const TimeOfDay(hour: 9, minute: 0),
        now: nowMdt,
      );

      tz.setLocalLocation(tz.UTC);
      final nowUtc = tz.TZDateTime.utc(2026, 10, 6, 14, 30); // 8:30 MDT
      final wrongUtcWall = NotificationTime.nextInstanceOfTime(
        time: const TimeOfDay(hour: 9, minute: 0),
        now: nowUtc,
      );

      // Correct local schedule is 15:00 UTC; naive UTC wall is 09:00 UTC.
      expect(correct.toUtc().hour, 15);
      expect(wrongUtcWall.toUtc().hour, 9);
      expect(correct.toUtc(), isNot(wrongUtcWall.toUtc()));
    });

    test('past time today rolls to tomorrow', () {
      final loc = tz.getLocation('UTC');
      final now = tz.TZDateTime(loc, 2026, 10, 6, 18, 0);
      final next = NotificationTime.nextInstanceOfTime(
        time: const TimeOfDay(hour: 9, minute: 0),
        now: now,
      );
      expect(next.day, 7);
      expect(next.hour, 9);
    });

    test('alreadyCompletedToday forces tomorrow even if time is future', () {
      final loc = tz.getLocation('UTC');
      final now = tz.TZDateTime(loc, 2026, 10, 6, 8, 0);
      final next = NotificationTime.nextInstanceOfTime(
        time: const TimeOfDay(hour: 9, minute: 0),
        now: now,
        alreadyCompletedToday: true,
      );
      expect(next.day, 7);
    });

    test('isFutureSchedule rejects past times', () {
      final loc = tz.getLocation('UTC');
      final now = tz.TZDateTime(loc, 2026, 10, 6, 12, 0);
      final past = now.subtract(const Duration(minutes: 1));
      expect(NotificationTime.isFutureSchedule(past, now), isFalse);
      expect(
        NotificationTime.isFutureSchedule(
          now.add(const Duration(minutes: 1)),
          now,
        ),
        isTrue,
      );
    });
  });

  group('end-to-end scheduler simulation', () {
    late _RecordingService fake;
    late NotificationScheduler scheduler;

    setUp(() {
      fake = _RecordingService();
      scheduler = NotificationScheduler(fake);
      SharedPreferences.setMockInitialValues({
        'notif_daily': true,
        'notif_atrisk': true,
        'notif_repair': true,
        'notif_intervals': true,
      });
      tz.setLocalLocation(
        NotificationTime.fixedOffsetLocation(const Duration(hours: -6)),
      );
    });

    test('refreshAll schedules future daily reminder for habit with time',
        () async {
      await scheduler.refreshAll(
        [_habit(reminderTime: '09:00')],
        [StreakData(habitId: 'h1', currentStreak: 1, bestStreak: 1, totalCheckIns: 1)],
        {},
      );

      final daily = fake.scheduled.where((e) => e['type'] == 'daily').toList();
      expect(daily, hasLength(1));
      final when = daily.first['when'] as tz.TZDateTime;
      expect(when.isAfter(tz.TZDateTime.now(tz.local)), isTrue);
      expect(when.hour, 9);
    });

    test('completed today pushes daily reminder to tomorrow', () async {
      final now = tz.TZDateTime.now(tz.local);
      // Pick a time 2 hours ahead so without completion it would be today.
      final futureHour = (now.hour + 2) % 24;
      final timeStr =
          '${futureHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      await scheduler.refreshAll(
        [_habit(reminderTime: timeStr)],
        [],
        {'h1'}, // completed today
      );

      final when = fake.scheduled.firstWhere((e) => e['type'] == 'daily')['when']
          as tz.TZDateTime;
      // Must not be "today" if the chosen hour is still ahead today —
      // alreadyCompletedToday forces +1 day.
      final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
      expect(when.isAfter(today.add(const Duration(days: 1)).subtract(
            const Duration(seconds: 1),
          )),
          isTrue);
    });

    test('interval reminders are scheduled (not dead-code skipped)', () async {
      final reminder = IntervalReminder(
        id: 'r1',
        name: 'Water',
        icon: '💧',
        color: 0xFF0277BD,
        category: ReminderCategory.hydration,
        intervalMinutes: 120,
        windowStart: '08:00',
        windowEnd: '20:00',
        createdAt: DateTime(2026, 1, 1),
      );

      await scheduler.refreshIntervalReminders([reminder]);

      final interval =
          fake.scheduled.where((e) => e['type'] == 'interval').toList();
      expect(interval, hasLength(1));
      expect((interval.first['slots'] as List).length, greaterThan(1));
    });

    test('mindfulness enabled produces future one-shots', () async {
      final config = MindfulnessBellConfig(
        enabled: true,
        startHour: 0,
        startMinute: 0,
        endHour: 23,
        endMinute: 59,
        intervalMinutes: 60,
        soundId: 'bowl',
      );
      final slots = MindfulnessBellScheduler.generateSlots(
        config: config,
        now: tz.TZDateTime.now(tz.local),
      );
      expect(slots, isNotEmpty);
      for (final s in slots) {
        expect(s.isAfter(tz.TZDateTime.now(tz.local).subtract(
              const Duration(seconds: 1),
            )),
            isTrue);
      }

      await scheduler.refreshMindfulnessBell(config);
      final mind =
          fake.scheduled.where((e) => e['type'] == 'mindfulness').toList();
      expect(mind, hasLength(1));
      expect((mind.first['whenList'] as List).isNotEmpty, isTrue);
    });

    test('mindfulness disabled cancels instead of scheduling', () async {
      await scheduler.refreshMindfulnessBell(
        MindfulnessBellConfig.defaults.copyWith(enabled: false),
      );
      expect(
        fake.scheduled.any((e) => e['type'] == 'mindfulness_cancel'),
        isTrue,
      );
      expect(
        fake.scheduled.any((e) => e['type'] == 'mindfulness'),
        isFalse,
      );
    });

    test('stable IDs stay consistent across reorder', () async {
      final idA = NotificationIds.daily('habit-a');
      final idB = NotificationIds.daily('habit-b');
      expect(idA, NotificationIds.daily('habit-a'));
      expect(idA, isNot(idB));
      expect(idA, inInclusiveRange(1000, 1899));
    });
  });
}
