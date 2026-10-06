import '../../habits/data/habit_model.dart';
import '../data/streak_model.dart';

/// Milestone tiers that can be reached by building a streak.
enum MilestoneTier { week, twoWeeks, month, twoMonths, century, year }

/// Pure business logic for streak state transitions.
///
/// No Flutter, no DB, no async — every method is a pure function that takes
/// value objects and returns a new [StreakData].
class StreakCalculator {
  const StreakCalculator._();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Record a new check-in and return updated [StreakData].
  ///
  /// Rules:
  ///  - If the habit was already checked in today, do not double-increment.
  ///  - If the check-in is on a non-scheduled day for [daysOfWeek] habits,
  ///    it is still accepted (the user may do bonus check-ins).
  ///  - A check-in always moves [state] to [StreakState.active].
  static StreakData recordCheckIn({
    required StreakData current,
    required DateTime checkInTime,
    required FrequencyType frequencyType,
    required List<int> daysOfWeek,
  }) {
    final today = _dateOnly(checkInTime);
    final lastDay =
        current.lastCheckIn != null ? _dateOnly(current.lastCheckIn!) : null;

    // Already checked in today — idempotent, just ensure state is active.
    if (lastDay != null && lastDay == today) {
      return current.copyWith(state: StreakState.active);
    }

    // Determine whether the streak should continue or restart.
    final newStreak = _shouldContinueStreak(
      lastCheckInDay: lastDay,
      today: today,
      frequencyType: frequencyType,
      daysOfWeek: daysOfWeek,
    )
        ? current.currentStreak + 1
        : 1;

    final newBest =
        newStreak > current.bestStreak ? newStreak : current.bestStreak;

    return current.copyWith(
      currentStreak: newStreak,
      bestStreak: newBest,
      totalCheckIns: current.totalCheckIns + 1,
      state: StreakState.active,
      lastCheckIn: checkInTime,
    );
  }

  /// Evaluate whether the streak should transition state based on elapsed time.
  ///
  /// Call this on app open or a daily timer.
  ///
  /// State machine:
  ///   active  → atRisk  : last check-in was yesterday (daily) or the most
  ///                        recent scheduled day (daysOfWeek) and today/that
  ///                        day has no check-in yet, AND it's past the grace
  ///                        hour (21:00 by default).
  ///   active  → broken  : last check-in was 2+ days ago (daily) or a
  ///                        scheduled day was fully missed.
  ///   atRisk  → broken  : another full day passes with no check-in.
  ///   broken  → (no change via evaluate; use repairStreak to fix).
  ///   active  → (no change if checked in today).
  static StreakData evaluateState({
    required StreakData current,
    required DateTime now,
    required FrequencyType frequencyType,
    required List<int> daysOfWeek,
    int atRiskHour = 21,
  }) {
    // A broken streak stays broken until repaired or a new check-in.
    if (current.state == StreakState.broken) return current;

    // No check-in ever — nothing to evaluate.
    if (current.lastCheckIn == null) return current;

    final today = _dateOnly(now);
    final lastDay = _dateOnly(current.lastCheckIn!);

    if (frequencyType == FrequencyType.daily) {
      return _evaluateDaily(
        current: current,
        today: today,
        lastDay: lastDay,
        now: now,
        atRiskHour: atRiskHour,
      );
    } else {
      // daysOfWeek (and timesPerWeek falls back to daysOfWeek logic if
      // daysOfWeek is non-empty; otherwise treated as daily).
      if (daysOfWeek.isEmpty) {
        return _evaluateDaily(
          current: current,
          today: today,
          lastDay: lastDay,
          now: now,
          atRiskHour: atRiskHour,
        );
      }
      return _evaluateDaysOfWeek(
        current: current,
        today: today,
        lastDay: lastDay,
        now: now,
        daysOfWeek: daysOfWeek,
        atRiskHour: atRiskHour,
      );
    }
  }

  /// Consume one freeze token to repair a broken or atRisk streak.
  ///
  /// Returns null if:
  ///  - No tokens available.
  ///  - Streak is already active and not in need of repair.
  ///
  /// After repair:
  ///  - [state] = active
  ///  - [freezeTokens] decremented by 1
  ///  - [lastCheckIn] set to yesterday (so the next real check-in continues
  ///    the streak correctly)
  static StreakData? repairStreak({
    required StreakData current,
    required DateTime now,
  }) {
    if (current.freezeTokens <= 0) return null;
    if (current.state == StreakState.active) return null;

    final yesterday = _dateOnly(now).subtract(const Duration(days: 1));
    // Restore lastCheckIn to yesterday at noon so subsequent evaluations
    // treat the streak as intact.
    final repairedLastCheckIn = DateTime(
      yesterday.year,
      yesterday.month,
      yesterday.day,
      12,
    );

    return current.copyWith(
      state: StreakState.active,
      freezeTokens: current.freezeTokens - 1,
      lastCheckIn: repairedLastCheckIn,
    );
  }

  /// Award freeze tokens at the 7 / 30 / 60 day milestones.
  ///
  /// Tokens are non-cumulative (earned once each at these thresholds) and
  /// capped at 3.  Because we don't track which milestones were already
  /// awarded, this method is idempotent when called every check-in — it only
  /// increments the token count when the streak is **exactly** at a milestone
  /// value, ensuring a single award per milestone crossing.
  static StreakData checkMilestoneTokenEarn(StreakData data) {
    const milestones = {7, 30, 60};
    if (!milestones.contains(data.currentStreak)) return data;
    if (data.freezeTokens >= 3) return data;

    return data.copyWith(freezeTokens: data.freezeTokens + 1);
  }

  /// Returns true if [after.currentStreak] exceeds [before.bestStreak].
  static bool isNewPersonalBest(StreakData before, StreakData after) {
    return after.currentStreak > before.bestStreak;
  }

  /// Maps a streak count to a [MilestoneTier], or null if not a milestone.
  static MilestoneTier? getMilestoneTier(int streak) {
    return switch (streak) {
      7 => MilestoneTier.week,
      14 => MilestoneTier.twoWeeks,
      30 => MilestoneTier.month,
      60 => MilestoneTier.twoMonths,
      100 => MilestoneTier.century,
      365 => MilestoneTier.year,
      _ => null,
    };
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Returns the date portion of [dt] (time zeroed out) in local time.
  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Whether a new check-in on [today] should continue an existing streak,
  /// given the last check-in was on [lastCheckInDay].
  static bool _shouldContinueStreak({
    required DateTime? lastCheckInDay,
    required DateTime today,
    required FrequencyType frequencyType,
    required List<int> daysOfWeek,
  }) {
    if (lastCheckInDay == null) return false; // first ever check-in

    if (frequencyType == FrequencyType.daily) {
      // Streak continues only if last check-in was yesterday.
      final yesterday = today.subtract(const Duration(days: 1));
      return lastCheckInDay == yesterday;
    }

    // daysOfWeek: the streak continues as long as there was no fully-missed
    // scheduled day between [lastCheckInDay] and [today].
    if (daysOfWeek.isEmpty) {
      // Treat as daily when no days configured.
      final yesterday = today.subtract(const Duration(days: 1));
      return lastCheckInDay == yesterday;
    }

    return !_hasMissedScheduledDay(
      from: lastCheckInDay,
      to: today,
      daysOfWeek: daysOfWeek,
    );
  }

  /// Returns true if any scheduled day between [from] (exclusive) and [to]
  /// (exclusive) was missed.
  static bool _hasMissedScheduledDay({
    required DateTime from,
    required DateTime to,
    required List<int> daysOfWeek,
  }) {
    DateTime cursor = from.add(const Duration(days: 1));
    while (cursor.isBefore(to)) {
      if (daysOfWeek.contains(cursor.weekday)) return true;
      cursor = cursor.add(const Duration(days: 1));
    }
    return false;
  }

  static StreakData _evaluateDaily({
    required StreakData current,
    required DateTime today,
    required DateTime lastDay,
    required DateTime now,
    required int atRiskHour,
  }) {
    final daysDiff = today.difference(lastDay).inDays;

    // Guard against device clock going backward (daysDiff < 0).
    if (daysDiff < 0) return current;

    if (daysDiff == 0) {
      // Checked in today — streak is fine.
      return current.copyWith(state: StreakState.active);
    }

    if (daysDiff == 1) {
      // Haven't checked in today yet.
      if (now.hour >= atRiskHour) {
        // Past the grace hour — mark at-risk.
        return current.copyWith(state: StreakState.atRisk);
      }
      // Still within the day — streak is active.
      return current;
    }

    // 2+ days without check-in → broken.
    return current.copyWith(
      state: StreakState.broken,
      currentStreak: 0,
    );
  }

  static StreakData _evaluateDaysOfWeek({
    required StreakData current,
    required DateTime today,
    required DateTime lastDay,
    required DateTime now,
    required List<int> daysOfWeek,
    required int atRiskHour,
  }) {
    // Find the most recent scheduled day up to and including today.
    final mostRecentScheduled = _mostRecentScheduledDay(today, daysOfWeek);

    if (mostRecentScheduled == null) {
      // No scheduled days in the past — nothing to evaluate.
      return current;
    }

    // If the last check-in covers the most recent scheduled day, all is fine.
    if (!lastDay.isBefore(mostRecentScheduled)) {
      return current.copyWith(state: StreakState.active);
    }

    // The most recent scheduled day was missed (or we're still on it).
    if (mostRecentScheduled == today) {
      // Today is a scheduled day and hasn't been checked in yet.
      if (now.hour >= atRiskHour) {
        return current.copyWith(state: StreakState.atRisk);
      }
      // Still early — check if there's an older missed day.
      final previousScheduled =
          _mostRecentScheduledDay(today.subtract(const Duration(days: 1)), daysOfWeek);
      if (previousScheduled != null && lastDay.isBefore(previousScheduled)) {
        // An earlier scheduled day was also missed → broken.
        return current.copyWith(
          state: StreakState.broken,
          currentStreak: 0,
        );
      }
      return current;
    }

    // The most recent scheduled day is in the past and was missed.
    if (current.state == StreakState.atRisk) {
      // Already in grace period and another day passed — broken.
      return current.copyWith(
        state: StreakState.broken,
        currentStreak: 0,
      );
    }

    // Transition to atRisk (grace period).
    return current.copyWith(state: StreakState.atRisk);
  }

  /// Returns the most recent scheduled day (weekday in [daysOfWeek]) on or
  /// before [reference], or null if none found within 7 days.
  static DateTime? _mostRecentScheduledDay(
    DateTime reference,
    List<int> daysOfWeek,
  ) {
    for (int i = 0; i < 7; i++) {
      final candidate = reference.subtract(Duration(days: i));
      if (daysOfWeek.contains(candidate.weekday)) return candidate;
    }
    return null;
  }
}
