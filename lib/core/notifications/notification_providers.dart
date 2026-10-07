import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/checkin/domain/checkin_service.dart';
import '../../features/habits/domain/habit_providers.dart';
import '../../features/mindfulness_bell/domain/mindfulness_bell_store.dart';
import '../../features/reminders/domain/interval_reminder_providers.dart';
import 'notification_scheduler.dart';
import 'notification_service.dart';

/// Provides the singleton [NotificationService].
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService.instance;
});

/// Provides [NotificationScheduler] wired to the [NotificationService].
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return NotificationScheduler(ref.watch(notificationServiceProvider));
});

/// Schedules habit, interval, and mindfulness notifications.
/// Keep-alive so schedules persist even when leaving Home.
final scheduleNotificationsProvider = FutureProvider<void>((ref) async {
  if (kIsWeb) return;

  // Keep this provider alive for the app lifetime.
  ref.keepAlive();

  try {
    final habits = await ref.watch(activeHabitsProvider.future);
    final streakDao = ref.watch(streakDaoProvider);
    final checkInRepo = ref.watch(checkInRepositoryProvider);
    final scheduler = ref.watch(notificationSchedulerProvider);
    final reminders = await ref.watch(activeIntervalRemindersProvider.future);
    final mindfulnessConfig = await MindfulnessBellStore().load();

    final streaks = await streakDao.getAll();
    final completedToday = <String>{};
    for (final h in habits) {
      if (await checkInRepo.isCompletedToday(h.id)) {
        completedToday.add(h.id);
      }
    }

    await scheduler.refreshAll(habits, streaks, completedToday);
    await scheduler.refreshIntervalReminders(reminders);
    await scheduler.refreshMindfulnessBell(mindfulnessConfig);
  } catch (e, st) {
    debugPrint('Notification schedule failed: $e\n$st');
  }
});
