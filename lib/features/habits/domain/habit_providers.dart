import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../checkin/data/checkin_dao.dart';
import '../../checkin/domain/checkin_repository.dart';
import '../../checkin/domain/checkin_service.dart';
import '../../streaks/data/streak_dao.dart';
import '../../streaks/domain/streak_providers.dart';
import '../data/habit_dao.dart';
import '../data/habit_model.dart';
import 'habit_repository.dart';

// ---------------------------------------------------------------------------
// Core / infrastructure providers
// ---------------------------------------------------------------------------

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService.instance,
);

// ---------------------------------------------------------------------------
// DAO providers
// ---------------------------------------------------------------------------

final habitDaoProvider = Provider<HabitDao>((ref) {
  return HabitDao(ref.watch(databaseServiceProvider));
});

final checkInDaoProvider = Provider<CheckInDao>((ref) {
  return CheckInDao(ref.watch(databaseServiceProvider));
});

final streakDaoProvider = Provider<StreakDao>((ref) {
  return StreakDao(ref.watch(databaseServiceProvider));
});

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return HabitRepository(
    ref.watch(habitDaoProvider),
    ref.watch(streakDaoProvider),
  );
});

final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepository(
    ref.watch(checkInDaoProvider),
    ref.watch(streakDaoProvider),
  );
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

final activeHabitsProvider = FutureProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).getActiveHabits();
});

final archivedHabitsProvider = FutureProvider<List<Habit>>((ref) {
  return ref.watch(habitRepositoryProvider).getArchivedHabits();
});

// ---------------------------------------------------------------------------
// CheckInService provider
// ---------------------------------------------------------------------------

final checkInServiceProvider = Provider<CheckInService>((ref) {
  return CheckInService(
    ref.watch(checkInRepositoryProvider),
    ref.watch(streakServiceProvider),
    ref.watch(notificationSchedulerProvider),
  );
});
