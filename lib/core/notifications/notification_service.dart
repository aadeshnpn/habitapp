import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import 'notification_ids.dart';
import 'notification_time.dart';

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

  Future<void> scheduleIntervalReminder({
    required String reminderId,
    required String reminderName,
    required String reminderIcon,
    required List<String> slots,
  });

  Future<void> cancelIntervalReminder(String reminderId);

  /// Returns how many mindfulness one-shots were successfully scheduled.
  Future<int> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  });

  Future<void> cancelMindfulnessBells();

  Future<void> previewMindfulnessBell(String soundId);

  /// Debug-only: schedule one mindfulness-channel notification soon.
  Future<void> scheduleMindfulnessTest({
    required String soundId,
    int minutesFromNow = 1,
  });

  Future<void> scheduleSnooze({
    required int originalNotifId,
    required String habitId,
    required String habitName,
    required String habitIcon,
    int snoozeMinutes = 30,
  });

  /// Fire an immediate test notification (verifies permission + channel).
  Future<void> showTestNotification();

  /// Schedule a one-shot test notification [minutesFromNow] minutes ahead.
  Future<void> scheduleTestNotification({int minutesFromNow = 1});

  /// Number of pending OS notifications, or -1 if unavailable.
  Future<int> pendingNotificationCount();

  Future<bool> canScheduleExactNotifications();
}

class NotificationService extends NotificationServiceBase {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'habit_tracker_main_v2';
  static const _channelName = 'Habit Tracker';
  static const _channelDesc = 'Habit reminders and streak alerts';

  static const _intervalChannelId = 'interval_reminders_v2';
  static const _intervalChannelName = 'Interval Reminders';
  static const _intervalChannelDesc = 'Hydration, medication, movement reminders';

  /// Channel prefix — bump when sound assets / URI wiring change. Android will
  /// not update an existing channel's sound; a new id forces recreation.
  static const _mindfulnessChannelPrefix = 'mindfulness_bell_v4_';

  static const mindfulnessSoundIds = [
    'bowl',
    'chime',
    'soft_bell',
    'wood',
    'gong',
  ];

  static const _legacyMindfulnessChannelPrefixes = [
    'mindfulness_bell_',
    'mindfulness_bell_v2_',
    'mindfulness_bell_v3_',
  ];

  static const _channelSetup = MethodChannel('habitapp/notif_channels');

  static const _testNotifId = 9998;
  static const _testScheduleId = 9997;
  static const _mindfulnessTestId = 9996;

  static void Function(String habitId)? onNotificationTap;

  bool _exactAlarmsAllowed = false;
  String _timezoneName = 'UTC';

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
    await ensureMindfulnessChannels();
    await _refreshExactAlarmCapability();
    debugPrint(
      'NotificationService ready tz=$_timezoneName exact=$_exactAlarmsAllowed',
    );
  }

  /// Creates / refreshes mindfulness channels with correct sound URIs.
  /// Safe to call multiple times (e.g. after the Activity MethodChannel is ready).
  Future<void> ensureMindfulnessChannels() => _createMindfulnessChannels();

  Future<void> _configureLocalTimezone() async {
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz));
      _timezoneName = localTz;
      debugPrint('Timezone set to $localTz');
      return;
    } catch (e) {
      debugPrint('IANA timezone resolve failed: $e');
    }

    // Fall back to a fixed offset matching the device clock so wall times
    // (from TimeOfDay pickers) stay correct even without an IANA name.
    final location =
        NotificationTime.fixedOffsetLocation(DateTime.now().timeZoneOffset);
    tz.setLocalLocation(location);
    _timezoneName = location.name;
    debugPrint('Using fixed-offset timezone fallback: $_timezoneName');
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final notifGranted = await requestNotificationPermissionOnly();
    await requestExactAlarmsPermissionOnly();
    return notifGranted;
  }

  /// POST_NOTIFICATIONS only — never opens the Alarms settings screen.
  Future<bool> requestNotificationPermissionOnly() async {
    if (kIsWeb) return false;
    try {
      final granted =
          await _androidPlugin?.requestNotificationsPermission() ?? false;
      debugPrint('Notification permission=$granted');
      return granted;
    } catch (e) {
      debugPrint('requestNotificationsPermission error: $e');
      return false;
    }
  }

  /// Opens system Alarms & reminders settings when needed. Safe to call from
  /// an explicit settings button — not from schedule/test paths.
  Future<bool> requestExactAlarmsPermissionOnly() async {
    if (kIsWeb) return false;
    try {
      await _androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      // Pixel may throw if the toggle is unavailable/locked.
      debugPrint('requestExactAlarmsPermission error: $e');
    }
    await _refreshExactAlarmCapability();
    debugPrint('Exact alarms allowed=$_exactAlarmsAllowed');
    return _exactAlarmsAllowed;
  }

  @override
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
      // Do NOT assume true when null — wrong assumption causes
      // PlatformException(exact_alarms_not_permitted).
      _exactAlarmsAllowed = allowed == true;
    } catch (e) {
      debugPrint('canScheduleExactNotifications error: $e');
      _exactAlarmsAllowed = false;
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

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
    final scheduledDate = NotificationTime.nextInstanceOfTime(
      time: time,
      now: tz.TZDateTime.now(tz.local),
      alreadyCompletedToday: alreadyCompletedToday,
    );

    await _safeZonedSchedule(
      id: notifId,
      title: 'Habit Reminder',
      body: body,
      when: scheduledDate,
      details: _notifDetails(),
      payload: habitId,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

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
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      22,
      0,
    );

    if (scheduledDate.isAfter(now)) {
      await _safeZonedSchedule(
        id: notifId,
        title: 'Streak at Risk',
        body: body,
        when: scheduledDate,
        details: _notifDetails(),
        payload: habitId,
      );
    }
  }

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
    final now = tz.TZDateTime.now(tz.local);
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      9,
      0,
    );

    await _safeZonedSchedule(
      id: notifId,
      title: 'Streak Repair Available',
      body: body,
      when: scheduledDate,
      details: _notifDetails(),
      payload: habitId,
    );
  }

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
    await _plugin.show(notifId, 'Milestone Reached!', body, _notifDetails());
  }

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
    final now = tz.TZDateTime.now(tz.local);

    for (var i = 0; i < limitedSlots.length; i++) {
      final tod = _parseTimeOfDay(limitedSlots[i]);
      if (tod == null) continue;

      final notifId = NotificationIds.intervalSlot(reminderId, i);
      final messages = [
        '$reminderIcon Time for $reminderName!',
        '$reminderIcon Don\'t forget your $reminderName.',
        '$reminderName reminder $reminderIcon',
      ];
      final body = messages[math.Random().nextInt(messages.length)];
      final scheduled = NotificationTime.nextInstanceOfTime(
        time: tod,
        now: now,
      );

      await _safeZonedSchedule(
        id: notifId,
        title: reminderName,
        body: body,
        when: scheduled,
        details: _intervalNotifDetails(),
        payload: reminderId,
        matchDateTimeComponents: DateTimeComponents.time,
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

  @override
  Future<int> scheduleMindfulnessBells({
    required String soundId,
    required List<tz.TZDateTime> whenList,
  }) async {
    if (kIsWeb) return 0;
    await requestNotificationPermissionOnly();
    await cancelMindfulnessBells();

    final sound = _normalizeSoundId(soundId);
    final limited = whenList.take(NotificationIds.maxMindfulnessSlots).toList();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = 0;

    for (var i = 0; i < limited.length; i++) {
      final when = limited[i];
      if (!when.isAfter(now)) continue;
      // Jittered bells do not need alarmClock — prefer inexact so Pixel can
      // accept dozens of slots without exact-alarm quota pressure.
      final ok = await _safeZonedSchedule(
        id: NotificationIds.mindfulness(i),
        title: 'Mindfulness',
        body: 'Take a breath',
        when: when,
        details: _mindfulnessNotifDetails(sound),
        payload: 'mindfulness',
        preferInexact: true,
      );
      if (ok) scheduled++;
    }
    debugPrint(
      'Mindfulness scheduled=$scheduled/${limited.length} '
      'sound=$sound tz=$_timezoneName exact=$_exactAlarmsAllowed',
    );
    return scheduled;
  }

  @override
  Future<void> cancelMindfulnessBells() async {
    if (kIsWeb) return;
    final futures = List.generate(
      NotificationIds.maxMindfulnessSlots,
      (i) => _plugin.cancel(NotificationIds.mindfulness(i)),
    );
    await Future.wait([
      ...futures,
      _plugin.cancel(_mindfulnessTestId),
    ]);
  }

  @override
  Future<void> previewMindfulnessBell(String soundId) async {
    if (kIsWeb) return;
    await requestNotificationPermissionOnly();
    final sound = _normalizeSoundId(soundId);
    await _plugin.show(
      6999,
      'Mindfulness',
      'Take a breath',
      _mindfulnessNotifDetails(sound),
    );
  }

  @override
  Future<void> scheduleMindfulnessTest({
    required String soundId,
    int minutesFromNow = 1,
  }) async {
    if (kIsWeb || kReleaseMode) return;
    await requestNotificationPermissionOnly();
    try {
      await _plugin.cancel(_mindfulnessTestId);
    } catch (_) {}
    final sound = _normalizeSoundId(soundId);
    final when = tz.TZDateTime.now(tz.local).add(
      Duration(minutes: minutesFromNow),
    );
    final ok = await _safeZonedSchedule(
      id: _mindfulnessTestId,
      title: 'Mindfulness test',
      body: 'Bell sound "$sound" — scheduled ${minutesFromNow}m ahead.',
      when: when,
      details: _mindfulnessNotifDetails(sound),
      payload: 'mindfulness',
      preferInexact: true,
    );
    if (!ok) {
      throw StateError(
        'Could not schedule mindfulness test. Check notification permission '
        'and Alarms & reminders, then try again.',
      );
    }
  }

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

    await _safeZonedSchedule(
      id: snoozeId,
      title: 'Snoozed: $habitName',
      body: '$habitIcon Reminder — snoozed for $snoozeMinutes minutes.',
      when: snoozeTime,
      details: _notifDetails(),
      payload: habitId,
    );
  }

  @override
  Future<void> showTestNotification() async {
    if (kIsWeb || kReleaseMode) return;
    await requestNotificationPermissionOnly();
    await _plugin.show(
      _testNotifId,
      'Test notification',
      'If you see this, notification permission and channels work.',
      _notifDetails(),
    );
  }

  @override
  Future<void> scheduleTestNotification({int minutesFromNow = 1}) async {
    if (kIsWeb || kReleaseMode) return;
    // Do NOT open exact-alarm settings here — that caused a large
    // PlatformException / settings jump on Pixel when tapping Schedule test.
    await requestNotificationPermissionOnly();
    try {
      await _plugin.cancel(_testScheduleId);
    } catch (e) {
      debugPrint('cancel test schedule id failed: $e');
    }
    final when = tz.TZDateTime.now(tz.local).add(
      Duration(minutes: minutesFromNow),
    );
    final ok = await _safeZonedSchedule(
      id: _testScheduleId,
      title: 'Scheduled test',
      body:
          'This was scheduled $minutesFromNow min ahead (tz=$_timezoneName, exact=$_exactAlarmsAllowed).',
      when: when,
      details: _notifDetails(),
      payload: 'test',
    );
    if (!ok) {
      throw StateError(
        'Could not schedule the test notification. '
        'Open “Alarms & reminders permission” in Settings, enable it, then try again.',
      );
    }
  }

  @override
  Future<int> pendingNotificationCount() async {
    if (kIsWeb) return -1;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return -1;
    }
  }

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
  // Safe schedule with mode fallbacks
  // ---------------------------------------------------------------------------

  /// Returns true if a schedule mode succeeded.
  Future<bool> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required NotificationDetails details,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
    bool preferInexact = false,
  }) async {
    await _refreshExactAlarmCapability();

    if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
      debugPrint('Skip schedule id=$id — time is not in the future: $when');
      return false;
    }

    // Always end with inexact so Pixel devices without exact-alarm grant still
    // get a schedule instead of PlatformException(exact_alarms_not_permitted).
    // Mindfulness uses preferInexact — ±10m jitter does not need alarmClock.
    final modes = <AndroidScheduleMode>[
      if (!preferInexact && _exactAlarmsAllowed)
        AndroidScheduleMode.alarmClock,
      if (!preferInexact && _exactAlarmsAllowed)
        AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
      AndroidScheduleMode.inexact,
    ];

    Object? lastError;
    for (final mode in modes) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: matchDateTimeComponents,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        debugPrint(
          'Scheduled id=$id mode=$mode when=$when tz=$_timezoneName',
        );
        return true;
      } catch (e, st) {
        lastError = e;
        final msg = e.toString();
        if (msg.contains('exact_alarms_not_permitted')) {
          _exactAlarmsAllowed = false;
        }
        debugPrint('Schedule id=$id failed mode=$mode: $e\n$st');
      }
    }
    debugPrint('All schedule modes failed for id=$id: $lastError');
    return false;
  }

  // ---------------------------------------------------------------------------
  // Channels / details
  // ---------------------------------------------------------------------------

  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _createIntervalChannel() async {
    const channel = AndroidNotificationChannel(
      _intervalChannelId,
      _intervalChannelName,
      description: _intervalChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _androidPlugin?.createNotificationChannel(channel);
  }

  Future<void> _createMindfulnessChannels() async {
    // Native setup only: Pixel/Android 8+ often stays silent when the channel
    // sound URI is the name-based form (`.../raw/bowl`). Native code uses the
    // numeric resource-id form (`android.resource://pkg/<id>`).
    // Do NOT fall back to flutter_local_notifications channel creation — that
    // would permanently register a silent/broken channel for this id.
    try {
      final created = await _channelSetup.invokeMethod<int>(
        'setupMindfulnessChannels',
        {
          'sounds': mindfulnessSoundIds,
          'prefix': _mindfulnessChannelPrefix,
          'legacyPrefixes': _legacyMindfulnessChannelPrefixes,
        },
      );
      debugPrint('Mindfulness channels created via native=$created');
    } catch (e) {
      debugPrint('Native mindfulness channel setup failed: $e');
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
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
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
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.reminder,
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
    final channelId = '$_mindfulnessChannelPrefix$soundId';
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Mindfulness Bell (${_soundLabel(soundId)})',
        channelDescription: 'Mindfulness bell sound and vibration',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        sound: RawResourceAndroidNotificationSound(soundId),
        enableVibration: true,
        autoCancel: true,
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.notification,
      ),
    );
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
    if (payload == 'mindfulness' || payload == 'test') return;
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
