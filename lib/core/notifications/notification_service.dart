import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Abstract interface for scheduling notifications.
/// Extracted so [NotificationScheduler] can be tested without real platform
/// calls — pass a fake implementation in tests.
abstract class NotificationServiceBase {
  Future<void> scheduleHabitReminder({
    required int index,
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  });

  Future<void> scheduleStreakAtRiskAlert({
    required int index,
    required String habitId,
    required String habitName,
    required int streak,
  });

  Future<void> scheduleStreakRepairReminder({
    required int index,
    required String habitId,
    required String habitName,
    required int lostStreak,
  });

  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  });

  Future<void> cancelHabitNotifications(int index);
  Future<void> cancelNotification(int id);

  /// Schedule all time-slot notifications for a single interval reminder
  /// within its active window.  Up to 20 slots per reminder.
  Future<void> scheduleIntervalReminder({
    required int reminderIndex,
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots, // list of "HH:MM" strings
  });

  Future<void> cancelIntervalReminder(int reminderIndex);

  /// Show a snooze notification [snoozeMinutes] from now.
  Future<void> scheduleSnooze({
    required int originalNotifId,
    required String habitId,
    required String habitName,
    required String habitIcon,
    int snoozeMinutes = 30,
  });
}

class NotificationService extends NotificationServiceBase {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'habit_tracker_main';
  static const _channelName = 'Habit Tracker';
  static const _channelDesc = 'Habit reminders and streak alerts';

  // Notification ID ranges (avoids collisions):
  // Daily reminders:     1000 + index
  // Streak at-risk:      2000 + index
  // Streak repair:       3000 + index
  // Milestone celebrate: 4000 + index
  // Interval reminders:  5000 + (reminderIndex * 20) + slotIndex
  // Snooze:              9000 + (original id % 1000)

  static const _intervalChannelId = 'interval_reminders';
  static const _intervalChannelName = 'Interval Reminders';
  static const _intervalChannelDesc = 'Hydration, medication, movement reminders';
  static const _maxSlotsPerReminder = 20;

  static void Function(String habitId)? onNotificationTap;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    // Set the local timezone so scheduled times match the device's clock.
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
    } catch (_) {
      // Fallback if system timezone location cannot be resolved
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createChannel();
    await _createIntervalChannel();
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ---------------------------------------------------------------------------
  // Schedule: daily reminder
  // ---------------------------------------------------------------------------

  /// Schedule a daily repeating notification at the given [time].
  /// [index] is the habit's position in the list and determines the notification ID.
  /// [habitId] is stored as payload for deep-linking on tap.
  @override
  Future<void> scheduleHabitReminder({
    required int index,
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  }) async {
    if (kIsWeb) return;
    final notifId = 1000 + index;

    // Cancel existing reminder before rescheduling.
    await _plugin.cancel(notifId);

    final messages = [
      '$habitIcon Time for your $habitName habit!',
      '$habitIcon Don\'t forget: $habitName today.',
      'Your daily $habitName is waiting for you. $habitIcon',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate = _nextInstanceOfTime(time, alreadyCompletedToday: alreadyCompletedToday);

    // exactAllowWhileIdle: fires reliably when screen is off and supports
    // repeating schedules with matchDateTimeComponents.
    await _plugin.zonedSchedule(
      notifId,
      'Habit Reminder',
      body,
      scheduledDate,
      _notifDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: habitId,
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule: streak at-risk (10 pm tonight)
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleStreakAtRiskAlert({
    required int index,
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
    if (kIsWeb) return;
    final notifId = 2000 + index;
    await _plugin.cancel(notifId);

    final messages = [
      '🔥 $streak-day streak at risk! Complete $habitName before midnight.',
      '⚡ Don\'t lose your $streak-day $habitName streak!',
      '⏰ Last chance for $habitName — streak at $streak days.',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate = _todayAt(hour: 22, minute: 0);

    // Only schedule if 10 pm is still in the future.
    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        notifId,
        'Streak at Risk',
        body,
        scheduledDate,
        _notifDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: habitId,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Schedule: streak repair reminder (9 am tomorrow)
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleStreakRepairReminder({
    required int index,
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {
    if (kIsWeb) return;
    final notifId = 3000 + index;
    await _plugin.cancel(notifId);

    final messages = [
      '💪 Missed $habitName yesterday. Use a freeze token to save your $lostStreak-day streak?',
      '🔧 Streak repair available for $habitName ($lostStreak days).',
      'Your $habitName streak ($lostStreak days) can still be saved — tap to repair.',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate = _tomorrowAt(hour: 9, minute: 0);

    await _plugin.zonedSchedule(
      notifId,
      'Streak Repair Available',
      body,
      scheduledDate,
      _notifDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: habitId,
    );
  }

  // ---------------------------------------------------------------------------
  // Show immediately: milestone celebration
  // ---------------------------------------------------------------------------

  @override
  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  }) async {
    if (kIsWeb) return;
    final messages = [
      '🎉 $streak-day streak on $habitName! You\'re incredible!',
      '🏆 $streak days of $habitName — new personal best!',
      '🔥 $streak days strong on $habitName. Keep it up!',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    // Use a unique ID in the milestone range, derived from streak+name hash.
    final notifId = 4000 + (streak ^ habitName.hashCode).abs() % 1000;

    await _plugin.show(
      notifId,
      'Milestone Reached!',
      body,
      _notifDetails(),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule: interval reminders (multiple slots per day)
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleIntervalReminder({
    required int reminderIndex,
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  }) async {
    if (kIsWeb) return;

    // Cancel all existing slots for this reminder first.
    await cancelIntervalReminder(reminderIndex);

    final limitedSlots =
        slots.take(_maxSlotsPerReminder).toList();

    for (var i = 0; i < limitedSlots.length; i++) {
      final slotStr = limitedSlots[i];
      final tod = _parseTimeOfDay(slotStr);
      if (tod == null) continue;

      final notifId = 5000 + (reminderIndex * _maxSlotsPerReminder) + i;

      final messages = [
        '$reminderIcon Time for $reminderName!',
        '$reminderIcon Don\'t forget your $reminderName.',
        '$reminderName reminder $reminderIcon',
      ];
      final body = messages[math.Random().nextInt(messages.length)];

      final scheduled = _nextInstanceOfTime(tod);

      await _plugin.zonedSchedule(
        notifId,
        reminderName,
        body,
        scheduled,
        _intervalNotifDetails(notifId: notifId, payload: reminderId),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminderId,
      );
    }
  }

  @override
  Future<void> cancelIntervalReminder(int reminderIndex) async {
    if (kIsWeb) return;
    final futures = List.generate(
      _maxSlotsPerReminder,
      (i) => _plugin.cancel(5000 + (reminderIndex * _maxSlotsPerReminder) + i),
    );
    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Snooze: reschedule a single notification N minutes from now
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleSnooze({
    required int originalNotifId,
    required String habitId,
    required String habitName,
    required String habitIcon,
    int snoozeMinutes = 30,
  }) async {
    if (kIsWeb) return;

    final snoozeId = 9000 + (originalNotifId % 1000);
    await _plugin.cancel(snoozeId);

    final snoozeTime =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeMinutes));

    await _plugin.zonedSchedule(
      snoozeId,
      'Snoozed: $habitName',
      '$habitIcon Reminder — snoozed for $snoozeMinutes minutes.',
      snoozeTime,
      _notifDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: habitId,
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel helpers
  // ---------------------------------------------------------------------------

  @override
  Future<void> cancelHabitNotifications(int index) async {
    if (kIsWeb) return;
    await Future.wait([
      _plugin.cancel(1000 + index),
      _plugin.cancel(2000 + index),
      _plugin.cancel(3000 + index),
    ]);
  }

  @override
  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _createIntervalChannel() async {
    const channel = AndroidNotificationChannel(
      _intervalChannelId,
      _intervalChannelName,
      description: _intervalChannelDesc,
      importance: Importance.defaultImportance,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  NotificationDetails _notifDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'snooze',
            'Snooze 30 min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  NotificationDetails _intervalNotifDetails({
    required int notifId,
    required String payload,
  }) {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _intervalChannelId,
        _intervalChannelName,
        channelDescription: _intervalChannelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
        actions: [
          AndroidNotificationAction(
            'snooze',
            'Snooze 30 min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'done',
            'Log it ✓',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      ),
    );
  }

  /// Returns a [tz.TZDateTime] for the next occurrence of [time] (today if
  /// still in the future, tomorrow otherwise). If [alreadyCompletedToday] is true,
  /// it will schedule for tomorrow even if the time hasn't passed today.
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time, {bool alreadyCompletedToday = false}) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now) || alreadyCompletedToday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Returns a [tz.TZDateTime] for today at [hour]:[minute].
  tz.TZDateTime _todayAt({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  }

  /// Returns a [tz.TZDateTime] for tomorrow at [hour]:[minute].
  tz.TZDateTime _tomorrowAt({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(
        tz.local, now.year, now.month, now.day + 1, hour, minute);
  }

  // Parse "HH:MM" helper — also used by interval scheduler
  static TimeOfDay? _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      // Handle snooze action
      if (response.actionId == 'snooze') {
        scheduleSnooze(
          originalNotifId: response.id ?? 0,
          habitId: payload,
          habitName: 'Reminder',
          habitIcon: '⏰',
        );
        return;
      }
      onNotificationTap?.call(payload);
    }
  }
}
