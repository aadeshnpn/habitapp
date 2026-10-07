import '../../habits/data/habit_model.dart';
import '../data/streak_dao.dart';
import '../data/streak_model.dart';
import 'streak_calculator.dart';

/// Orchestrates [StreakCalculator] with [StreakDao] persistence.
class StreakService {
  final StreakDao _streakDao;

  const StreakService(this._streakDao);

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Called immediately after a check-in is persisted.
  ///
  /// Loads existing streak (or creates an initial one), records the check-in,
  /// checks for milestone token awards, persists, and returns the result.
  Future<StreakData> onCheckIn({
    required String habitId,
    required DateTime checkInTime,
    required FrequencyType frequencyType,
    required List<int> daysOfWeek,
  }) async {
    final current =
        await _streakDao.getForHabit(habitId) ?? StreakData.initial(habitId);

    var updated = StreakCalculator.recordCheckIn(
      current: current,
      checkInTime: checkInTime,
      frequencyType: frequencyType,
      daysOfWeek: daysOfWeek,
    );

    updated = StreakCalculator.checkMilestoneTokenEarn(updated);

    await _streakDao.upsert(updated);
    return updated;
  }

  /// Re-evaluates streak state for all [habits] and persists any changes.
  ///
  /// Call this on app open or when a daily background timer fires.
  Future<List<StreakData>> evaluateAllStreaks(List<Habit> habits) async {
    final now = DateTime.now();
    final results = <StreakData>[];

    for (final habit in habits) {
      final current = await _streakDao.getForHabit(habit.id) ??
          StreakData.initial(habit.id);

      final evaluated = StreakCalculator.evaluateState(
        current: current,
        now: now,
        frequencyType: habit.frequencyType,
        daysOfWeek: habit.daysOfWeek,
      );

      if (evaluated != current) {
        await _streakDao.upsert(evaluated);
      }

      results.add(evaluated);
    }

    return results;
  }

  /// Attempts to repair the streak for [habitId] using a freeze token.
  ///
  /// Returns the updated [StreakData] on success, or null if the repair
  /// was not possible (no tokens, or streak already active).
  Future<StreakData?> repairStreak(String habitId) async {
    final current = await _streakDao.getForHabit(habitId);
    if (current == null) return null;

    final repaired = StreakCalculator.repairStreak(
      current: current,
      now: DateTime.now(),
    );

    if (repaired == null) return null;

    await _streakDao.upsert(repaired);
    return repaired;
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Returns streak data for [habitId], creating an initial record if absent.
  Future<StreakData> getStreakData(String habitId) async {
    return await _streakDao.getForHabit(habitId) ?? StreakData.initial(habitId);
  }
}
