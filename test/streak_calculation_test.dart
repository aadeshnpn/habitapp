import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';
import 'package:habit_tracker/features/checkin/domain/checkin_repository.dart';
import 'package:habit_tracker/features/checkin/data/checkin_dao.dart';
import 'package:habit_tracker/features/streaks/data/streak_dao.dart';
import 'package:habit_tracker/core/database/database_service.dart';

// ---------------------------------------------------------------------------
// Pure streak-calculation helpers (extracted from CheckInRepository for
// testability without a real database).
// ---------------------------------------------------------------------------

/// Mirrors CheckInRepository._applyCheckIn so we can unit-test it without
/// any database dependencies.
StreakData applyCheckIn(StreakData existing, DateTime timestamp) {
  final newTotal = existing.totalCheckIns + 1;
  final now = DateTime(timestamp.year, timestamp.month, timestamp.day);
  final last = existing.lastCheckIn != null
      ? DateTime(
          existing.lastCheckIn!.year,
          existing.lastCheckIn!.month,
          existing.lastCheckIn!.day,
        )
      : null;

  int newCurrent = existing.currentStreak;
  if (last == null) {
    newCurrent = 1;
  } else {
    final diff = now.difference(last).inDays;
    if (diff == 1) {
      newCurrent = existing.currentStreak + 1;
    } else if (diff == 0) {
      newCurrent = existing.currentStreak;
    } else {
      newCurrent = 1;
    }
  }

  final newBest =
      newCurrent > existing.bestStreak ? newCurrent : existing.bestStreak;

  return existing.copyWith(
    currentStreak: newCurrent,
    bestStreak: newBest,
    totalCheckIns: newTotal,
    state: StreakState.active,
    lastCheckIn: timestamp,
  );
}

/// Compute the streak state as at [today] given the last check-in date.
/// This mirrors the logic that EPIC 8 will own, kept minimal here.
StreakData computeState(StreakData data, DateTime today) {
  if (data.lastCheckIn == null) return data;

  final lastDay = DateTime(
    data.lastCheckIn!.year,
    data.lastCheckIn!.month,
    data.lastCheckIn!.day,
  );
  final todayDay = DateTime(today.year, today.month, today.day);
  final gap = todayDay.difference(lastDay).inDays;

  if (gap <= 1) return data.copyWith(state: StreakState.active);
  if (gap == 2) return data.copyWith(state: StreakState.atRisk);
  // gap >= 3: broken, streak resets to 0
  return data.copyWith(state: StreakState.broken, currentStreak: 0);
}

void main() {
  group('StreakData model', () {
    test('new habit starts with streak 0', () {
      const streak = StreakData(habitId: 'h1');

      expect(streak.currentStreak, 0);
      expect(streak.bestStreak, 0);
      expect(streak.totalCheckIns, 0);
      expect(streak.state, StreakState.active);
      expect(streak.lastCheckIn, isNull);
      expect(streak.freezeTokens, 0);
    });
  });

  group('applyCheckIn', () {
    final baseDate = DateTime(2026, 4, 1, 9, 0);

    test('first check-in increments streak to 1', () {
      const initial = StreakData(habitId: 'h1');
      final result = applyCheckIn(initial, baseDate);

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.totalCheckIns, 1);
      expect(result.state, StreakState.active);
      expect(result.lastCheckIn, baseDate);
    });

    test('consecutive daily check-ins increment streak', () {
      const initial = StreakData(habitId: 'h1');
      final day1 = applyCheckIn(initial, baseDate);
      final day2 = applyCheckIn(day1, baseDate.add(const Duration(days: 1)));
      final day3 = applyCheckIn(day2, baseDate.add(const Duration(days: 2)));

      expect(day3.currentStreak, 3);
      expect(day3.bestStreak, 3);
      expect(day3.totalCheckIns, 3);
    });

    test('best streak is preserved when current streak drops', () {
      const initial = StreakData(habitId: 'h1');
      // Build a streak of 3.
      var streak = applyCheckIn(initial, baseDate);
      streak = applyCheckIn(streak, baseDate.add(const Duration(days: 1)));
      streak = applyCheckIn(streak, baseDate.add(const Duration(days: 2)));
      expect(streak.bestStreak, 3);

      // Skip two days, then check in again — streak resets but best stays.
      final afterGap =
          applyCheckIn(streak, baseDate.add(const Duration(days: 5)));
      expect(afterGap.currentStreak, 1);
      expect(afterGap.bestStreak, 3);
    });

    test('same-day second check-in does not change streak count', () {
      const initial = StreakData(habitId: 'h1');
      final first = applyCheckIn(initial, baseDate);
      final second = applyCheckIn(
          first, baseDate.add(const Duration(hours: 3))); // same calendar day

      expect(second.currentStreak, 1);
      expect(second.totalCheckIns, 2);
    });
  });

  group('computeState', () {
    final baseDate = DateTime(2026, 4, 1, 9, 0);

    test('missing one day (gap=1) keeps state active', () {
      const initial = StreakData(habitId: 'h1', currentStreak: 5);
      final withLastCheckIn = initial.copyWith(lastCheckIn: baseDate);
      // today is 1 day after last check-in
      final today = baseDate.add(const Duration(days: 1));
      final result = computeState(withLastCheckIn, today);

      expect(result.state, StreakState.active);
      expect(result.currentStreak, 5);
    });

    test('missing two days (gap=2) sets state to atRisk', () {
      const initial = StreakData(habitId: 'h1', currentStreak: 5);
      final withLastCheckIn = initial.copyWith(lastCheckIn: baseDate);
      // today is 2 days after last check-in
      final today = baseDate.add(const Duration(days: 2));
      final result = computeState(withLastCheckIn, today);

      expect(result.state, StreakState.atRisk);
      expect(result.currentStreak, 5); // streak not yet cleared
    });

    test('missing three or more days sets state to broken and resets streak', () {
      const initial = StreakData(habitId: 'h1', currentStreak: 5);
      final withLastCheckIn = initial.copyWith(lastCheckIn: baseDate);
      // today is 3 days after last check-in
      final today = baseDate.add(const Duration(days: 3));
      final result = computeState(withLastCheckIn, today);

      expect(result.state, StreakState.broken);
      expect(result.currentStreak, 0);
    });

    test('no check-in ever returns data unchanged', () {
      const initial = StreakData(habitId: 'h1');
      final result = computeState(initial, DateTime.now());

      expect(result.state, StreakState.active);
      expect(result.currentStreak, 0);
    });
  });

  group('StreakData serialization', () {
    test('toMap / fromMap round-trip', () {
      final original = StreakData(
        habitId: 'habit-123',
        currentStreak: 7,
        bestStreak: 14,
        totalCheckIns: 42,
        state: StreakState.atRisk,
        lastCheckIn: DateTime(2026, 3, 30, 12, 0),
        freezeTokens: 2,
      );

      final map = original.toMap();
      final restored = StreakData.fromMap(map);

      expect(restored, original);
    });

    test('fromMap handles null lastCheckIn', () {
      final map = {
        'habit_id': 'h1',
        'current_streak': 0,
        'best_streak': 0,
        'total_check_ins': 0,
        'state': 'active',
        'last_check_in': null,
        'freeze_tokens': 0,
      };
      final streak = StreakData.fromMap(map);
      expect(streak.lastCheckIn, isNull);
    });
  });
}
