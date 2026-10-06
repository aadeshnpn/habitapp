// Notification system tests.
//
// These tests cover the pure scheduling LOGIC in [NotificationScheduler]
// without touching the Android platform.  A [_FakeNotificationService]
// records every call made so the tests can assert on what was scheduled or
// cancelled and with which arguments.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:habit_tracker/core/notifications/notification_ids.dart';
import 'package:habit_tracker/core/notifications/notification_scheduler.dart';
import 'package:habit_tracker/core/notifications/notification_service.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/mindfulness_bell/domain/mindfulness_bell_config.dart';
import 'package:habit_tracker/features/reminders/data/interval_reminder_model.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';

// ---------------------------------------------------------------------------
// Fake notification service — records calls, no platform interaction
// ---------------------------------------------------------------------------

class _FakeNotificationService implements NotificationServiceBase {
  final List<Map<String, dynamic>> scheduledReminders = [];
  final List<Map<String, dynamic>> scheduledAtRiskAlerts = [];
  final List<Map<String, dynamic>> scheduledRepairReminders = [];
  final List<Map<String, dynamic>> milestoneCelebrations = [];
  final List<Map<String, dynamic>> scheduledIntervals = [];
  final List<Map<String, dynamic>> scheduledMindfulness = [];
  final List<int> cancelledIds = [];
  final List<String> cancelledIntervalReminderIds = [];
  int cancelMindfulnessCount = 0;

  void reset() {
    scheduledReminders.clear();
    scheduledAtRiskAlerts.clear();
    scheduledRepairReminders.clear();
    milestoneCelebrations.clear();
    scheduledIntervals.clear();
    scheduledMindfulness.clear();
    cancelledIds.clear();
    cancelledIntervalReminderIds.clear();
    cancelMindfulnessCount = 0;
  }

  @override
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  }) async {
    scheduledReminders.add({
      'habitId': habitId,
      'habitName': habitName,
      'habitIcon': habitIcon,
      'time': time,
      'alreadyCompletedToday': alreadyCompletedToday,
    });
  }

  @override
  Future<void> scheduleStreakAtRiskAlert({
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
    scheduledAtRiskAlerts.add({
      'habitId': habitId,
      'habitName': habitName,
      'streak': streak,
    });
  }

  @override
  Future<void> scheduleStreakRepairReminder({
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {
    scheduledRepairReminders.add({
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
  Future<void> cancelHabitNotifications(String habitId) async {
    cancelledIds.addAll([
      NotificationIds.daily(habitId),
      NotificationIds.atRisk(habitId),
      NotificationIds.repair(habitId),
    ]);
  }

  @override
  Future<void> cancelNotification(int id) async {
    cancelledIds.add(id);
  }

  @override
  Future<void> scheduleIntervalReminder({
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  }) async {
    scheduledIntervals.add({
      'reminderId': reminderId,
      'reminderName': reminderName,
      'reminderIcon': reminderIcon,
      'slots': slots,
    });
  }

  @override
  Future<void> cancelIntervalReminder(String reminderId) async {
    cancelledIntervalReminderIds.add(reminderId);
  }

  @override
  Future<void> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  }) async {
    scheduledMindfulness.add({
      'soundId': soundId,
      'whenList': whenList,
    });
  }

  @override
  Future<void> cancelMindfulnessBells() async {
    cancelMindfulnessCount++;
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

IntervalReminder _makeInterval({
  String id = 'r1',
  bool isActive = true,
}) =>
    IntervalReminder(
      id: id,
      name: 'Water',
      icon: '💧',
      color: 0xFF0277BD,
      category: ReminderCategory.hydration,
      intervalMinutes: 120,
      windowStart: '09:00',
      windowEnd: '17:00',
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
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
      'notif_intervals': true,
    });
  });

  group('parseTimeOfDay', () {
    test('parses "09:00" → hour 9, minute 0', () {
      final tod = NotificationScheduler.parseTimeOfDay('09:00');
      expect(tod, isNotNull);
      expect(tod!.hour, 9);
      expect(tod.minute, 0);
    });

    test('returns null for invalid input', () {
      expect(NotificationScheduler.parseTimeOfDay('0900'), isNull);
      expect(NotificationScheduler.parseTimeOfDay('25:00'), isNull);
      expect(NotificationScheduler.parseTimeOfDay(''), isNull);
    });
  });

  group('NotificationIds', () {
    test('stable slot is deterministic and in range', () {
      final slot = NotificationIds.stableSlot('h1');
      expect(slot, NotificationIds.stableSlot('h1'));
      expect(slot, inInclusiveRange(0, 899));
    });

    test('daily / at-risk / repair ranges do not collide', () {
      const id = 'habit-abc';
      final daily = NotificationIds.daily(id);
      final atRisk = NotificationIds.atRisk(id);
      final repair = NotificationIds.repair(id);
      expect(daily, inInclusiveRange(1000, 1899));
      expect(atRisk, inInclusiveRange(2000, 2899));
      expect(repair, inInclusiveRange(3000, 3899));
      expect({daily, atRisk, repair}.length, 3);
    });

    test('interval slot IDs stay in 5000–5899', () {
      final id = NotificationIds.intervalSlot('reminder-1', 0);
      expect(id, inInclusiveRange(5000, 5899));
      expect(
        NotificationIds.intervalSlot('reminder-1', 19) -
            NotificationIds.intervalSlot('reminder-1', 0),
        19,
      );
    });

    test('mindfulness IDs stay in 6000–6047', () {
      expect(NotificationIds.mindfulness(0), 6000);
      expect(NotificationIds.mindfulness(47), 6047);
    });

    test('same habitId always maps to same daily ID', () {
      expect(NotificationIds.daily('h2'), NotificationIds.daily('h2'));
      expect(NotificationIds.daily('h2'), isNot(NotificationIds.daily('h3')));
    });
  });

  group('onCheckInCompleted', () {
    test('cancels daily and at-risk using stable habitId IDs', () async {
      await scheduler.onCheckInCompleted(
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 4),
      );

      expect(fake.cancelledIds, contains(NotificationIds.daily('h1')));
      expect(fake.cancelledIds, contains(NotificationIds.atRisk('h1')));
    });

    test('sends milestone celebration at 7-day streak', () async {
      await scheduler.onCheckInCompleted(
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 7),
      );

      expect(fake.milestoneCelebrations.length, 1);
      expect(fake.milestoneCelebrations.first['streak'], 7);
    });

    test('does NOT send milestone when notif_milestone pref is false',
        () async {
      SharedPreferences.setMockInitialValues({'notif_milestone': false});

      await scheduler.onCheckInCompleted(
        habitId: 'h1',
        habitName: 'Running',
        habitIcon: '🏃',
        updatedStreak: _makeStreak(current: 7),
      );

      expect(fake.milestoneCelebrations, isEmpty);
    });
  });

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
      final habit = _makeHabit();
      final streak = _makeStreak();

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledReminders, isEmpty);
      expect(fake.cancelledIds, contains(NotificationIds.daily('h1')));
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
      expect(fake.cancelledIds, contains(NotificationIds.daily('h1')));
    });

    test('schedules at-risk alert when streak is atRisk and pref on',
        () async {
      final habit = _makeHabit();
      final streak = _makeStreak(state: StreakState.atRisk, current: 5);

      await scheduler.refreshAll([habit], [streak], <String>{});

      expect(fake.scheduledAtRiskAlerts.length, 1);
      expect(fake.scheduledAtRiskAlerts.first['habitId'], 'h1');
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
      expect(fake.scheduledRepairReminders.first['lostStreak'], 7);
    });

    test('uses stable IDs independent of list order', () async {
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

      expect(
        fake.scheduledReminders.any((r) => r['habitId'] == 'h2'),
        isTrue,
      );
      expect(
        fake.scheduledAtRiskAlerts.any((r) => r['habitId'] == 'h2'),
        isTrue,
      );
      expect(fake.cancelledIds, contains(NotificationIds.atRisk('h0')));
      expect(fake.cancelledIds, contains(NotificationIds.atRisk('h1')));
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

  group('refreshIntervalReminders', () {
    test('schedules active reminders when intervals pref is on', () async {
      final reminder = _makeInterval();
      await scheduler.refreshIntervalReminders([reminder]);

      expect(fake.scheduledIntervals.length, 1);
      expect(fake.scheduledIntervals.first['reminderId'], 'r1');
      expect(
        (fake.scheduledIntervals.first['slots'] as List).isNotEmpty,
        isTrue,
      );
    });

    test('cancels inactive reminders', () async {
      final reminder = _makeInterval(isActive: false);
      await scheduler.refreshIntervalReminders([reminder]);

      expect(fake.scheduledIntervals, isEmpty);
      expect(fake.cancelledIntervalReminderIds, contains('r1'));
    });

    test('cancels all when notif_intervals pref is false', () async {
      SharedPreferences.setMockInitialValues({'notif_intervals': false});
      final reminder = _makeInterval();
      await scheduler.refreshIntervalReminders([reminder]);

      expect(fake.scheduledIntervals, isEmpty);
      expect(fake.cancelledIntervalReminderIds, contains('r1'));
    });
  });

  group('refreshMindfulnessBell', () {
    setUp(() {
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('UTC'));
    });

    test('cancels when disabled', () async {
      await scheduler.refreshMindfulnessBell(
        MindfulnessBellConfig.defaults.copyWith(enabled: false),
      );
      expect(fake.cancelMindfulnessCount, 1);
      expect(fake.scheduledMindfulness, isEmpty);
    });

    test('schedules one-shots when enabled', () async {
      await scheduler.refreshMindfulnessBell(
        const MindfulnessBellConfig(
          enabled: true,
          startHour: 0,
          startMinute: 0,
          endHour: 23,
          endMinute: 59,
          intervalMinutes: 60,
          soundId: 'chime',
        ),
      );
      expect(fake.scheduledMindfulness.length, 1);
      expect(fake.scheduledMindfulness.first['soundId'], 'chime');
      expect(
        (fake.scheduledMindfulness.first['whenList'] as List).isNotEmpty,
        isTrue,
      );
    });
  });
}
