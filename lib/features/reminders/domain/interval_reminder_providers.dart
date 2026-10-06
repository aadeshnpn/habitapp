import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../../features/streaks/data/streak_dao.dart';
import '../data/interval_reminder_dao.dart';
import '../data/interval_reminder_model.dart';
import 'interval_reminder_repository.dart';

// ---------------------------------------------------------------------------
// Infrastructure providers
// ---------------------------------------------------------------------------

final intervalReminderDaoProvider = Provider<IntervalReminderDao>((ref) {
  return IntervalReminderDao(DatabaseService.instance);
});

final intervalReminderRepositoryProvider =
    Provider<IntervalReminderRepository>((ref) {
  return IntervalReminderRepository(
    ref.read(intervalReminderDaoProvider),
    StreakDao(DatabaseService.instance),
  );
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// All active interval reminders.
final activeIntervalRemindersProvider =
    FutureProvider<List<IntervalReminder>>((ref) async {
  final repo = ref.read(intervalReminderRepositoryProvider);
  return repo.getActiveReminders();
});

/// Today's logged count for a specific reminder.
final todayProgressProvider =
    FutureProvider.family<int, String>((ref, reminderId) async {
  final repo = ref.read(intervalReminderRepositoryProvider);
  return repo.getTodayProgress(reminderId);
});

/// All today's check-ins for a specific reminder.
final todayCheckInsProvider =
    FutureProvider.family<List<IntervalCheckIn>, String>(
        (ref, reminderId) async {
  final repo = ref.read(intervalReminderRepositoryProvider);
  return repo.getTodayCheckIns(reminderId);
});

/// Streak data (current + best) for a specific reminder.
final reminderStreakProvider =
    FutureProvider.family<int, String>((ref, reminderId) async {
  final repo = ref.read(intervalReminderRepositoryProvider);
  final streak = await repo.getStreak(reminderId);
  return streak?.currentStreak ?? 0;
});

/// Summary: how many reminders have met today's goal.
final reminderTodaySummaryProvider =
    FutureProvider<({int total, int done})>((ref) async {
  final reminders =
      await ref.watch(activeIntervalRemindersProvider.future);
  int done = 0;
  final repo = ref.read(intervalReminderRepositoryProvider);

  await Future.wait(reminders.map((r) async {
    final count = await repo.getTodayProgress(r.id);
    final target = r.targetCount > 0 ? r.targetCount : r.dailySlotCount;
    if (count >= target) done++;
  }));

  return (total: reminders.length, done: done);
});
