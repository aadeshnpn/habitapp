import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
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

  static void Function(String habitId)? onNotificationTap;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createChannel();
  }

  Future<bool> requestPermission() async {
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
  Future<void> scheduleHabitReminder({
    required int index,
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
  }) async {
    final notifId = 1000 + index;

    // Cancel existing reminder before rescheduling.
    await _plugin.cancel(notifId);

    final messages = [
      '$habitIcon Time for your $habitName habit!',
      '$habitIcon Don\'t forget: $habitName today.',
      'Your daily $habitName is waiting for you. $habitIcon',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate = _nextInstanceOfTime(time);

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

  Future<void> scheduleStreakAtRiskAlert({
    required int index,
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
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

  Future<void> scheduleStreakRepairReminder({
    required int index,
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {
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

  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  }) async {
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
  // Cancel helpers
  // ---------------------------------------------------------------------------

  Future<void> cancelHabitNotifications(int index) async {
    await Future.wait([
      _plugin.cancel(1000 + index),
      _plugin.cancel(2000 + index),
      _plugin.cancel(3000 + index),
    ]);
  }

  Future<void> cancelNotification(int id) async {
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

  NotificationDetails _notifDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
  }

  /// Returns a [tz.TZDateTime] for the next occurrence of [time] (today if
  /// still in the future, tomorrow otherwise).
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduled.isBefore(now)) {
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

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationTap?.call(payload);
    }
  }
}
