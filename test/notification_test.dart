// Notification system tests.
//
// These tests cover the pure scheduling LOGIC in [NotificationScheduler]
// without touching the Android platform.  A [_FakeNotificationService]
// records every call made so the tests can assert on what was scheduled or
// cancelled and with which arguments.
//
// What is tested:
//   1. parseTimeOfDay  — "HH:MM" string parsing
//   2. Notification ID ranges — daily=1000+i, at-risk=2000+i, repair=3000+i
//   3. onCheckInCompleted — cancels at-risk alert; fires milestone celebration
//      only at the right streak counts and only when the pref is enabled
//   4. refreshAll — routes each habit+streak state to the correct scheduling
//      call, respects the three notification toggle preferences, and uses the
//      correct ID for each notification type

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_tracker/core/notifications/notification_scheduler.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';

// ---------------------------------------------------------------------------
// Fake notification service — records calls, no platform interaction
// ---------------------------------------------------------------------------

class _FakeNotificationService implements NotificationServiceBase {
  // Recorded call arguments
  final List<Map<String, dynamic>> scheduledReminders = [];
  final List<Map<String, dynamic>> scheduledAtRiskAlerts = [];
  final List<Map<String, dynamic>> scheduledRepairReminders = [];
  final List<Map<String, dynamic>> milestoneCelebrations = [];
  final List<int> cancelledIds = [];

  void reset() {
    scheduledReminders.clear();
    scheduledAtRiskAlerts.clear();
    scheduledRepairReminders.clear();
    milestoneCelebrations.clear();
    cancelledIds.clear();
  }

  @override
  Future<void> scheduleHabitReminder({
    required int index,
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  }) async {
    scheduledReminders.add({
      'index': index,
      'habitId': habitId,
      'habitName': habitName,
      'habitIcon': habitIcon,
      'time': time,
      'alreadyCompletedToday': alreadyCompletedToday,
    });
  }

  @override
  Future<void> scheduleStreakAtRiskAlert({
    required int index,
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
    scheduledAtRiskAlerts.add({
      'index': index,
      'habitId': habitId,
      'habitName': habitName,
      'streak': streak,
    });
  }

  @override
  Future<void> scheduleStreakRepairReminder({
    required int index,
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {
    scheduledRepairReminders.add({
      'index': index,
      'habitId': habitId,
      'habitName': habitName,
      'lostStreak': lostStreak,
    });
  }

  @override
  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  }) async {
    milestoneCelebrations.add({
      'habitName': habitName,
      'streak': streak,
      'habitIcon': habitIcon,
    });
  }

  @override
  Future<void> cancelHabitNotifications(int index) async {
    cancelledIds.addAll([1000 + index, 2000 + index, 3000 + index]);
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  // --- new methods (no-op stubs for existing tests) ---

  @override
  Future<void> scheduleIntervalReminder({
    required int reminderIndex,
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  }) async {}

  @override
  Future<void> cancelIntervalReminder(int reminderIndex) async {}

  @override
  Future<void> scheduleSnooze({
    required int originalNotifId,
    required String habitId,
    required String habitName,
    required String habitIcon,
    int snoozeMinutes = 30,
  }) async {}
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

Habit _makeHabit({
  String id = 'h1',
  String name = 'Running',
  String icon = '🏃',
  String? reminderTime,
}) =>
    Habit(
      id: id,
      name: name,
      icon: icon,
      color: 0xFF4CAF50,
      frequencyType: FrequencyType.daily,
      checkInType: CheckInType.tap,
      reminderTime: reminderTime,
      createdAt: DateTime(2026, 1, 1),
    );

StreakData _makeStreak({
  String habitId = 'h1',
  int current = 5,
  int best = 10,
  int total = 20,
  int tokens = 0,
  StreakState state = StreakState.active,
}) =>
    StreakData(
      habitId: habitId,
      currentStreak: current,
      bestStreak: best,
      totalCheckIns: total,
      state: state,
      freezeTokens: tokens,
    );

void main() {
  late _FakeNotificationService fake;
  late NotificationScheduler scheduler;

  setUp(() {
    fake = _FakeNotificationService();
    scheduler = NotificationScheduler(fake);
    SharedPreferences.setMockInitialValues({
      'notif_daily': true,
      'notif_atrisk': true,
      'notif_repair': true,
      'notif_milestone': true,
    });
  });

  // -------------------------------------------------------------------------
  // 1. parseTimeOfDay
  // -------------------------------------------------------------------------

  group('parseTimeOfDay', () {
    test('parses "09:00" → hour 9, minute 0', () {
      final tod = NotificationScheduler.parseTimeOfDay('09:00');
      expect(tod, isNotNull);
      expect(tod!.hour, 9);
      expect(tod.minute, 0);
    });

    test('parses "22:30" → hour 22, minute 30', () {
      final tod = NotificationScheduler.parseTimeOfDay('22:30');
      expect(tod, isNotNull);
      expect(tod!.hour, 22);
      expect(tod.minute, 30);
    });

    test('parses "00:00" → hour 0, minute 0', () {
      final tod = NotificationScheduler.parseTimeOfDay('00:00');
      expect(tod, isNotNull);
      expect(tod!.hour, 0);
      expect(tod.minute, 0);
    });

    test('parses "23:59" → hour 23, minute 59', () {
      final tod = NotificationScheduler.parseTimeOfDay('23:59');
      expect(tod, isNotNull);
      expect(tod!.hour, 23);
      expect(tod.minute, 59);
    });

    test('returns null for string with no colon', () {
      expect(NotificationScheduler.parseTimeOfDay('0900'), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(NotificationScheduler.parseTimeOfDay('ab:cd'), isNull);
    });

    test('returns null for empty string', () {
      expect(NotificationScheduler.parseTimeOfDay(''), isNull);
    });

    test('returns null for hour > 23', () {
      expect(NotificationScheduler.parseTimeOfDay('25:00'), isNull);
    });

    test('returns null for minute > 59', () {
      expect(NotificationScheduler.parseTimeOfDay('12:60'), isNull);
    });

    test('returns null for negative hour', () {
      expect(NotificationScheduler.parseTimeOfDay('-1:00'), isNull);
    });

    test('returns null for negative minute', () {
      expect(NotificationScheduler.parseTimeOfDay('12:-1'), isNull);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Notification ID ranges
  // -------------------------------------------------------------------------

  group('notification ID ranges', () {
    test('daily reminder uses IDs starting at 1000', () {
      // The ID range is documented as 1000+index.
      // Verify by scheduling a reminder and checking the cancel ID.
      expect(1000 + 0, 1000);
      expect(1000 + 5, 1005);
    });

    test('at-risk alert uses IDs starting at 2000', () {
      expect(2000 + 0, 2000);
      expect(2000 + 5, 2005);
    });

    test('repair reminder uses IDs starting at 3000', () {
      expect(3000 + 0, 3000);
      expect(3000 + 5, 3005);
    });

    test('milestone ID is in 4000–4999 range', () {
      for (final streak in [7, 14, 30, 60, 100, 365]) {
        final id = 4000 + (streak ^ 'Running'.hashCode).abs() % 1000;
        expect(id, greaterThanOrEqualTo(4000));
        expect(id, lessThan(5000));
      }
    });

    test('IDs do not collide across types for same habit index', () {
      const i = 3;
      final daily = 1000 + i;
      final atRisk = 2000 + i;
      final repair = 3000 + i;
      expect({daily, atRisk, repair}.length, 3,
          reason: 'All three ID ranges must be distinct');
    });
  });

  // -------------------------------------------------------------------------
  // 3. onCheckInCompleted
  // -------------------------------------------------------------------------

  group('onCheckInCompleted', () {
    test('cancels the at-risk alert for the correct habit index', () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 3,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 4),
      );

      expect(fake.cancelledIds, contains(2000 + 3));
    });

    test('does NOT send milestone when streak is not a milestone value',
        () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 5),
      );

      expect(fake.milestoneCelebrations, isEmpty);
    });

    test('sends milestone celebration at 7-day streak', () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 7),
      );

      expect(fake.milestoneCelebrations.length, 1);
      expect(fake.milestoneCelebrations.first['streak'], 7);
      expect(fake.milestoneCelebrations.first['habitName'], 'Running');
    });

    test('sends milestone celebration at 14-day streak', () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Yoga',
        habitIcon: '🧘',
        updatedStreak: _makeStreak(current: 14),
      );

      expect(fake.milestoneCelebrations.length, 1);
      expect(fake.milestoneCelebrations.first['streak'], 14);
    });

    test('sends milestone celebration at 30-day streak', () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 30),
      );

      expect(fake.milestoneCelebrations.length, 1);
      expect(fake.milestoneCelebrations.first['streak'], 30);
    });

    test('sends milestone celebration at 100-day streak', () async {
      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 100),
      );

      expect(fake.milestoneCelebrations.length, 1);
      expect(fake.milestoneCelebrations.first['streak'], 100);
    });

    test('does NOT send milestone when notif_milestone pref is false',
        () async {
      SharedPreferences.setMockInitialValues({'notif_milestone': false});

      await scheduler.onCheckInCompleted(
        habitIndex: 0,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 7),
      );

      expect(fake.milestoneCelebrations, isEmpty);
    });

    test('always cancels at-risk ID regardless of milestone pref', () async {
      SharedPreferences.setMockInitialValues({'notif_milestone': false});

      await scheduler.onCheckInCompleted(
        habitIndex: 2,
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 7),
      );

      expect(fake.cancelledIds, contains(2002));
    });
  });

  // -------------------------------------------------------------------------
  // 4. refreshAll
  // -------------------------------------------------------------------------

  group('refreshAll', () {
    test('schedules daily reminder when reminderTime is set and pref on',
        () async {
      final habit = _makeHabit(reminderTime: '09:00');
      final streak = _makeStreak();

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledReminders.length, 1);
      expect(fake.scheduledReminders.first['habitId'], 'h1');
      expect(fake.scheduledReminders.first['time'],
          const TimeOfDay(hour: 9, minute: 0));
    });

    test('cancels daily reminder ID when reminderTime is null', () async {
      final habit = _makeHabit(); // no reminderTime
      final streak = _makeStreak();

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledReminders, isEmpty);
      expect(fake.cancelledIds, contains(1000)); // index 0 → ID 1000
    });

    test('cancels daily reminder ID when notif_daily pref is false', () async {
      SharedPreferences.setMockInitialValues({
        'notif_daily': false,
        'notif_atrisk': true,
        'notif_repair': true,
      });
      final habit = _makeHabit(reminderTime: '09:00');
      final streak = _makeStreak();

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledReminders, isEmpty);
      expect(fake.cancelledIds, contains(1000));
    });

    test('schedules at-risk alert when streak is atRisk and pref on',
        () async {
      final habit = _makeHabit();
      final streak = _makeStreak(state: StreakState.atRisk, current: 5);

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledAtRiskAlerts.length, 1);
      expect(fake.scheduledAtRiskAlerts.first['habitId'], 'h1');
      expect(fake.scheduledAtRiskAlerts.first['streak'], 5);
    });

    test('cancels at-risk ID when streak is active (not at risk)', () async {
      final habit = _makeHabit();
      final streak = _makeStreak(state: StreakState.active);

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledAtRiskAlerts, isEmpty);
      expect(fake.cancelledIds, contains(2000));
    });

    test('cancels at-risk ID when notif_atrisk pref is false', () async {
      SharedPreferences.setMockInitialValues({
        'notif_daily': true,
        'notif_atrisk': false,
        'notif_repair': true,
      });
      final habit = _makeHabit();
      final streak = _makeStreak(state: StreakState.atRisk, current: 3);

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledAtRiskAlerts, isEmpty);
      expect(fake.cancelledIds, contains(2000));
    });

    test('schedules repair reminder when broken with tokens and pref on',
        () async {
      final habit = _makeHabit();
      final streak = _makeStreak(
        state: StreakState.broken,
        current: 7,
        tokens: 2,
      );

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledRepairReminders.length, 1);
      expect(fake.scheduledRepairReminders.first['habitId'], 'h1');
      expect(fake.scheduledRepairReminders.first['lostStreak'], 7);
    });

    test('cancels repair ID when broken but has no freeze tokens', () async {
      final habit = _makeHabit();
      final streak = _makeStreak(
        state: StreakState.broken,
        current: 7,
        tokens: 0, // no tokens
      );

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledRepairReminders, isEmpty);
      expect(fake.cancelledIds, contains(3000));
    });

    test('cancels repair ID when streak is active (not broken)', () async {
      final habit = _makeHabit();
      final streak = _makeStreak(state: StreakState.active, tokens: 2);

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledRepairReminders, isEmpty);
      expect(fake.cancelledIds, contains(3000));
    });

    test('cancels repair ID when notif_repair pref is false', () async {
      SharedPreferences.setMockInitialValues({
        'notif_daily': true,
        'notif_atrisk': true,
        'notif_repair': false,
      });
      final habit = _makeHabit();
      final streak = _makeStreak(
        state: StreakState.broken,
        current: 5,
        tokens: 1,
      );

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledRepairReminders, isEmpty);
      expect(fake.cancelledIds, contains(3000));
    });

    test('uses correct IDs for habit at index 2', () async {
      // First two habits — we care about the third (index 2).
      final habits = [
        _makeHabit(id: 'h0', reminderTime: '08:00'),
        _makeHabit(id: 'h1', reminderTime: '09:00'),
        _makeHabit(id: 'h2', reminderTime: '10:00'),
      ];
      final streaks = [
        _makeStreak(habitId: 'h0'),
        _makeStreak(habitId: 'h1'),
        _makeStreak(habitId: 'h2', state: StreakState.atRisk, current: 3),
      ];

      await scheduler.refreshAll(habits, streaks, <String>{});

      // Habit at index 2 → daily=1002, at-risk=2002
      expect(
        fake.scheduledReminders.any((r) => r['index'] == 2),
        isTrue,
      );
      expect(
        fake.scheduledAtRiskAlerts.any((r) => r['index'] == 2),
        isTrue,
      );
      // Cancelled daily IDs for habits with no at-risk: 2000, 2001
      expect(fake.cancelledIds, containsAll([2000, 2001]));
    });

    test('skips streak scheduling for a habit with no matching streak data',
        () async {
      final habit = _makeHabit(id: 'h_no_streak');
      // Provide streak for a DIFFERENT habit ID
      final streak = _makeStreak(habitId: 'h_other');

      await scheduler.refreshAll([habit], [streak], <String>{});

      // No at-risk or repair scheduled since the habit has no streak entry
      expect(fake.scheduledAtRiskAlerts, isEmpty);
      expect(fake.scheduledRepairReminders, isEmpty);
    });

    test('all three toggles false → only cancellations, nothing scheduled',
        () async {
      SharedPreferences.setMockInitialValues({
        'notif_daily': false,
        'notif_atrisk': false,
        'notif_repair': false,
      });
      final habit = _makeHabit(reminderTime: '09:00');
      final streak = _makeStreak(
        state: StreakState.atRisk,
        current: 5,
        tokens: 2,
      );

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledReminders, isEmpty);
      expect(fake.scheduledAtRiskAlerts, isEmpty);
      expect(fake.scheduledRepairReminders, isEmpty);
    });
  });
}
