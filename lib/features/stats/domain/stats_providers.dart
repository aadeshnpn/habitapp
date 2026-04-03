import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/domain/habit_providers.dart';
import '../../streaks/data/streak_model.dart';
import 'stats_service.dart';

// ---------------------------------------------------------------------------
// Service provider
// ---------------------------------------------------------------------------

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService(
    ref.watch(checkInRepositoryProvider),
    ref.watch(streakDaoProvider),
  );
});

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

final overallCompletionRateProvider = FutureProvider<double>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  return ref.watch(statsServiceProvider).overallCompletionRate(habits);
});

final longestActiveStreakProvider = FutureProvider<StreakData?>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  return ref.watch(statsServiceProvider).longestActiveStreak(habits);
});

final insightCardsProvider = FutureProvider<List<InsightCard>>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  return ref.watch(statsServiceProvider).generateInsights(habits);
});

/// Per-habit 30-day completion rate.
final habitCompletionRateProvider =
    FutureProvider.family<double, String>((ref, habitId) async {
  return ref
      .watch(statsServiceProvider)
      .habitCompletionRate(habitId, days: 30);
});

/// Day-of-week breakdown for a specific habit.
final dayOfWeekBreakdownProvider =
    FutureProvider.family<Map<int, double>, String>((ref, habitId) async {
  return ref.watch(statsServiceProvider).dayOfWeekBreakdown(habitId);
});
