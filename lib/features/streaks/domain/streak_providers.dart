import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/domain/habit_providers.dart';
import '../data/streak_model.dart';
import 'streak_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

/// Provides the [StreakService], wired to the [StreakDao] from
/// [streakDaoProvider] defined in habit_providers.dart.
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService(ref.watch(streakDaoProvider));
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Provides [StreakData] for a specific habit (by [habitId]).
final streakDataProvider =
    FutureProvider.family<StreakData, String>((ref, habitId) {
  return ref.watch(streakServiceProvider).getStreakData(habitId);
});

/// Provides a list of habit IDs whose streaks are currently [StreakState.atRisk].
///
/// Useful for scheduling "at-risk" notifications or surfacing warnings in the
/// UI without loading full habit objects.
final atRiskHabitsProvider = FutureProvider<List<String>>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);

  // Re-evaluate all streaks against the current time.
  final streakService = ref.watch(streakServiceProvider);
  final streakList = await streakService.evaluateAllStreaks(habits);

  return streakList
      .where((s) => s.state == StreakState.atRisk)
      .map((s) => s.habitId)
      .toList();
});
