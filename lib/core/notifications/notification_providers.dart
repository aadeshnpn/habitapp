import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/habits/domain/habit_providers.dart';
import '../../features/checkin/domain/checkin_service.dart';
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

/// Schedules all habit notifications whenever the active habits list changes.
/// Watch this provider from the home screen to keep notifications in sync.
final scheduleNotificationsProvider = FutureProvider.autoDispose<void>((ref) async {
  if (kIsWeb) return;

  final habits = await ref.watch(activeHabitsProvider.future);
  final streakDao = ref.watch(streakDaoProvider);
  final checkInRepo = ref.watch(checkInRepositoryProvider);
  final scheduler = ref.watch(notificationSchedulerProvider);

  final streaks = await streakDao.getAll();
  final completedToday = <String>{};
  for (final h in habits) {
    if (await checkInRepo.isCompletedToday(h.id)) {
      completedToday.add(h.id);
    }
  }

  await scheduler.refreshAll(habits, streaks, completedToday);
});
