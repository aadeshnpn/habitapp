import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'notification_ids.dart';

/// Abstract interface for scheduling notifications.
/// Extracted so [NotificationScheduler] can be tested without real platform
/// calls — pass a fake implementation in tests.
abstract class NotificationServiceBase {
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  });

  Future<void> scheduleStreakAtRiskAlert({
    required String habitId,
    required String habitName,
    required int streak,
  });

  Future<void> scheduleStreakRepairReminder({
    required String habitId,
    required String habitName,
    required int lostStreak,
  });

  Future<void> sendMilestoneCelebration({
    required String habitName,
    required int streak,
    required String habitIcon,
  });

  Future<void> cancelHabitNotifications(String habitId);
  Future<void> cancelNotification(int id);

  /// Schedule all time-slot notifications for a single interval reminder
  /// within its active window.  Up to 20 slots per reminder.
  Future<void> scheduleIntervalReminder({
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots, // list of "HH:MM" strings
  });

  Future<void> cancelIntervalReminder(String reminderId);

  /// Schedule one-shot mindfulness bells at [whenList] using [soundId].
  Future<void> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  });

  Future<void> cancelMindfulnessBells();

  /// Fire an immediate mindfulness preview (sound + vibrate).
  Future<void> previewMindfulnessBell(String soundId);

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

  static const _intervalChannelId = 'interval_reminders';
  static const _intervalChannelName = 'Interval Reminders';
  static const _intervalChannelDesc = 'Hydration, medication, movement reminders';

  static const mindfulnessSoundIds = [
    'bowl',
    'chime',
    'soft_bell',
    'wood',
    'gong',
  ];

  static void Function(String habitId)? onNotificationTap;

  bool _exactAlarmsAllowed = true;

  // ---------------------------------------------------------------------------
  // Init
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    await _createChannel();
    await _createIntervalChannel();
    await _createMindfulnessChannels();
    await _refreshExactAlarmCapability();
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
      return;
    } catch (e) {
      debugPrint('Timezone resolve failed: $e');
    }
    debugPrint('Using UTC timezone fallback for notification schedules');
    tz.setLocalLocation(tz.UTC);
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final android = _androidPlugin;
    final notifGranted =
        await android?.requestNotificationsPermission() ?? false;
    await android?.requestExactAlarmsPermission();
    await _refreshExactAlarmCapability();
    return notifGranted;
  }

  Future<bool> canScheduleExactNotifications() async {
    if (kIsWeb) return false;
    await _refreshExactAlarmCapability();
    return _exactAlarmsAllowed;
  }

  Future<void> _refreshExactAlarmCapability() async {
    if (kIsWeb) {
      _exactAlarmsAllowed = false;
      return;
    }
    try {
      final allowed = await _androidPlugin?.canScheduleExactNotifications();
      // null (older API) → assume exact is available.
      _exactAlarmsAllowed = allowed ?? true;
    } catch (_) {
      _exactAlarmsAllowed = true;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  AndroidScheduleMode get _scheduleMode => _exactAlarmsAllowed
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  // ---------------------------------------------------------------------------
  // Schedule: daily reminder
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String habitName,
    required String habitIcon,
    required TimeOfDay time,
    bool alreadyCompletedToday = false,
  }) async {
    if (kIsWeb) return;
    final notifId = NotificationIds.daily(habitId);

    await _plugin.cancel(notifId);

    final messages = [
      '$habitIcon Time for your $habitName habit!',
      '$habitIcon Don\'t forget: $habitName today.',
      'Your daily $habitName is waiting for you. $habitIcon',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate =
        _nextInstanceOfTime(time, alreadyCompletedToday: alreadyCompletedToday);

    await _plugin.zonedSchedule(
      notifId,
      'Habit Reminder',
      body,
      scheduledDate,
      _notifDetails(),
      androidScheduleMode: _scheduleMode,
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
    required String habitId,
    required String habitName,
    required int streak,
  }) async {
    if (kIsWeb) return;
    final notifId = NotificationIds.atRisk(habitId);
    await _plugin.cancel(notifId);

    final messages = [
      '🔥 $streak-day streak at risk! Complete $habitName before midnight.',
      '⚡ Don\'t lose your $streak-day $habitName streak!',
      '⏰ Last chance for $habitName — streak at $streak days.',
    ];
    final body = messages[math.Random().nextInt(messages.length)];

    final scheduledDate = _todayAt(hour: 22, minute: 0);

    if (scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.zonedSchedule(
        notifId,
        'Streak at Risk',
        body,
        scheduledDate,
        _notifDetails(),
        androidScheduleMode: _scheduleMode,
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
    required String habitId,
    required String habitName,
    required int lostStreak,
  }) async {
    if (kIsWeb) return;
    final notifId = NotificationIds.repair(habitId);
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
      androidScheduleMode: _scheduleMode,
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

    final notifId = NotificationIds.milestone(habitName, streak);

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
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  }) async {
    if (kIsWeb) return;

    await cancelIntervalReminder(reminderId);

    final limitedSlots =
        slots.take(NotificationIds.maxSlotsPerReminder).toList();

    for (var i = 0; i < limitedSlots.length; i++) {
      final slotStr = limitedSlots[i];
      final tod = _parseTimeOfDay(slotStr);
      if (tod == null) continue;

      final notifId = NotificationIds.intervalSlot(reminderId, i);

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
        _intervalNotifDetails(),
        androidScheduleMode: _scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminderId,
      );
    }
  }

  @override
  Future<void> cancelIntervalReminder(String reminderId) async {
    if (kIsWeb) return;
    final futures = List.generate(
      NotificationIds.maxSlotsPerReminder,
      (i) => _plugin.cancel(NotificationIds.intervalSlot(reminderId, i)),
    );
    await Future.wait(futures);
  }

  // ---------------------------------------------------------------------------
  // Mindfulness bell
  // ---------------------------------------------------------------------------

  @override
  Future<void> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  }) async {
    if (kIsWeb) return;
    await cancelMindfulnessBells();

    final sound = _normalizeSoundId(soundId);
    final limited = whenList.take(NotificationIds.maxMindfulnessSlots).toList();
    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < limited.length; i++) {
      final when = limited[i];
      if (!when.isAfter(now)) continue;
      final notifId = NotificationIds.mindfulness(i);
      await _plugin.zonedSchedule(
        notifId,
        'Mindfulness',
        '',
        when,
        _mindfulnessNotifDetails(sound),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'mindfulness',
      );
    }
  }

  @override
  Future<void> cancelMindfulnessBells() async {
    if (kIsWeb) return;
    final futures = List.generate(
      NotificationIds.maxMindfulnessSlots,
      (i) => _plugin.cancel(NotificationIds.mindfulness(i)),
    );
    await Future.wait(futures);
  }

  @override
  Future<void> previewMindfulnessBell(String soundId) async {
    if (kIsWeb) return;
    final sound = _normalizeSoundId(soundId);
    await _plugin.show(
      6999,
      'Mindfulness',
      '',
      _mindfulnessNotifDetails(sound),
    );
  }

  // ---------------------------------------------------------------------------
  // Snooze
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

    final snoozeId = NotificationIds.snooze(originalNotifId);
    await _plugin.cancel(snoozeId);

    final snoozeTime =
        tz.TZDateTime.now(tz.local).add(Duration(minutes: snoozeMinutes));

    await _plugin.zonedSchedule(
      snoozeId,
      'Snoozed: $habitName',
      '$habitIcon Reminder — snoozed for $snoozeMinutes minutes.',
      snoozeTime,
      _notifDetails(),
      androidScheduleMode: _scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: habitId,
    );
  }

  // ---------------------------------------------------------------------------
  // Cancel helpers
  // ---------------------------------------------------------------------------

  @override
  Future<void> cancelHabitNotifications(String habitId) async {
    if (kIsWeb) return;
    await Future.wait([
      _plugin.cancel(NotificationIds.daily(habitId)),
      _plugin.cancel(NotificationIds.atRisk(habitId)),
      _plugin.cancel(NotificationIds.repair(habitId)),
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
    await _androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _createIntervalChannel() async {
    const channel = AndroidNotificationChannel(
      _intervalChannelId,
      _intervalChannelName,
      description: _intervalChannelDesc,
      importance: Importance.defaultImportance,
    );
    await _androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _createMindfulnessChannels() async {
    for (final sound in mindfulnessSoundIds) {
      final channel = AndroidNotificationChannel(
        'mindfulness_bell_$sound',
        'Mindfulness Bell (${_soundLabel(sound)})',
        description: 'Mindfulness bell sound and vibration',
        importance: Importance.high,
        playSound: true,
        sound: RawResourceAndroidNotificationSound(sound),
        enableVibration: true,
      );
      await _androidPlugin?.createNotificationChannel(channel);
    }
  }

  static String _soundLabel(String soundId) {
    switch (soundId) {
      case 'bowl':
        return 'Bowl';
      case 'chime':
        return 'Chime';
      case 'soft_bell':
        return 'Soft Bell';
      case 'wood':
        return 'Wood';
      case 'gong':
        return 'Gong';
      default:
        return soundId;
    }
  }

  static String _normalizeSoundId(String soundId) {
    if (mindfulnessSoundIds.contains(soundId)) return soundId;
    return 'bowl';
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

  NotificationDetails _intervalNotifDetails() {
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

  NotificationDetails _mindfulnessNotifDetails(String soundId) {
    final channelId = 'mindfulness_bell_$soundId';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Mindfulness Bell (${_soundLabel(soundId)})',
        channelDescription: 'Mindfulness bell sound and vibration',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundId),
        enableVibration: true,
        autoCancel: true,
        category: AndroidNotificationCategory.reminder,
        // Sound/vibrate only — no actions.
      ),
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time,
      {bool alreadyCompletedToday = false}) {
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

  tz.TZDateTime _todayAt({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
  }

  tz.TZDateTime _tomorrowAt({required int hour, required int minute}) {
    final now = tz.TZDateTime.now(tz.local);
    return tz.TZDateTime(
        tz.local, now.year, now.month, now.day + 1, hour, minute);
  }

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
    if (payload == null || payload.isEmpty) return;
    if (payload == 'mindfulness') return;
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
