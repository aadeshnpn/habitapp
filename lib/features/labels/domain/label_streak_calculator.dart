import '../../streaks/data/streak_model.dart';
import '../data/label_model.dart';

/// Pure business logic for label streak state transitions.
///
/// No Flutter, no DB, no async — every method is a pure function that takes
/// value objects and returns a new [LabelStreak].
///
/// OR logic: if any member habit with this label was completed on a given day,
/// that day counts toward the label streak.
class LabelStreakCalculator {
  const LabelStreakCalculator._();

  /// Called when any member habit is checked in.
  /// [today] = date-only (no time) of the check-in.
  /// OR logic: if any habit with this label was done today, the label streak lives.
  static LabelStreak recordActivity({
    required LabelStreak current,
    required DateTime today,
  }) {
    final lastDay = current.lastActiveDay != null
        ? _dateOnly(current.lastActiveDay!)
        : null;
    final todayDate = _dateOnly(today);

    // Already counted today — idempotent
    if (lastDay == todayDate) return current;

    // Did the previous active day keep the streak alive?
    final continuous = lastDay != null &&
        todayDate.difference(lastDay).inDays == 1;

    final newStreak = continuous ? current.currentStreak + 1 : 1;
    final newBest =
        newStreak > current.bestStreak ? newStreak : current.bestStreak;

    return current.copyWith(
      currentStreak: newStreak,
      bestStreak: newBest,
      totalDays: current.totalDays + 1,
      state: StreakState.active,
      lastActiveDay: todayDate,
    );
  }

  /// Call on app open to mark labels at-risk or broken.
  static LabelStreak evaluateState({
    required LabelStreak current,
    required DateTime now,
  }) {
    if (current.lastActiveDay == null) return current;
    final lastDay = _dateOnly(current.lastActiveDay!);
    final today = _dateOnly(now);
    final gap = today.difference(lastDay).inDays;

    if (gap == 0) return current.copyWith(state: StreakState.active);
    if (gap == 1) return current.copyWith(state: StreakState.atRisk);
    // Gap >= 2: broken, reset streak
    return current.copyWith(
      state: StreakState.broken,
      currentStreak: 0,
    );
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
