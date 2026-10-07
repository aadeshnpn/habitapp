import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';
import 'package:habit_tracker/features/streaks/domain/streak_calculator.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns a [DateTime] for the given day offset relative to a fixed
  /// reference date (2024-01-15 = Monday, weekday 1).
  DateTime day(int offset, {int hour = 10}) {
    final base = DateTime(2024, 1, 15, hour); // Monday
    return base.add(Duration(days: offset));
  }

  StreakData initial() => StreakData.initial('habit-1');

  // ---------------------------------------------------------------------------
  // 1. Initial state
  // ---------------------------------------------------------------------------

  group('initial streak', () {
    test('is 0 with state active', () {
      final data = initial();
      expect(data.currentStreak, 0);
      expect(data.bestStreak, 0);
      expect(data.totalCheckIns, 0);
      expect(data.state, StreakState.active);
      expect(data.lastCheckIn, isNull);
      expect(data.freezeTokens, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. First check-in
  // ---------------------------------------------------------------------------

  group('first check-in', () {
    test('sets streak to 1', () {
      final result = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(result.currentStreak, 1);
      expect(result.bestStreak, 1);
      expect(result.totalCheckIns, 1);
      expect(result.state, StreakState.active);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Consecutive daily check-ins
  // ---------------------------------------------------------------------------

  group('consecutive daily check-ins', () {
    test('increment streak each day', () {
      var data = initial();

      for (int i = 0; i < 5; i++) {
        data = StreakCalculator.recordCheckIn(
          current: data,
          checkInTime: day(i),
          frequencyType: FrequencyType.daily,
          daysOfWeek: [],
        );
      }

      expect(data.currentStreak, 5);
      expect(data.bestStreak, 5);
      expect(data.totalCheckIns, 5);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Same-day idempotency
  // ---------------------------------------------------------------------------

  group('same-day second check-in', () {
    test('does not double-increment streak', () {
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0, hour: 9),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      // Second check-in on the same day.
      final again = StreakCalculator.recordCheckIn(
        current: data,
        checkInTime: day(0, hour: 20),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(again.currentStreak, 1);
      expect(again.totalCheckIns, 1); // still 1 — no double count
      expect(again.state, StreakState.active);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. Missing 1 day → atRisk
  // ---------------------------------------------------------------------------

  group('missing one day', () {
    test('transitions active → atRisk past grace hour', () {
      // Check in on day 0.
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      // Evaluate on day 1, past 21:00, without a new check-in.
      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(1, hour: 22), // 22:00 on day+1
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(evaluated.state, StreakState.atRisk);
      expect(evaluated.currentStreak, 1); // streak preserved during grace
    });

    test('stays active before grace hour', () {
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(1, hour: 10), // 10:00 — well before grace hour
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(evaluated.state, StreakState.active);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. Missing 2 days → broken, streak resets to 0
  // ---------------------------------------------------------------------------

  group('missing two days', () {
    test('transitions to broken and resets streak to 0', () {
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );
      // Simulate a 3-day streak first.
      data = StreakCalculator.recordCheckIn(
        current: data,
        checkInTime: day(1),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );
      data = StreakCalculator.recordCheckIn(
        current: data,
        checkInTime: day(2),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      // Evaluate 2 days later — fully missed.
      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(4, hour: 10),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(evaluated.state, StreakState.broken);
      expect(evaluated.currentStreak, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 7. Best streak preserved after break
  // ---------------------------------------------------------------------------

  group('best streak', () {
    test('is preserved after the streak breaks', () {
      var data = initial();

      // Build a 5-day streak.
      for (int i = 0; i < 5; i++) {
        data = StreakCalculator.recordCheckIn(
          current: data,
          checkInTime: day(i),
          frequencyType: FrequencyType.daily,
          daysOfWeek: [],
        );
      }
      expect(data.bestStreak, 5);

      // Break the streak.
      final broken = StreakCalculator.evaluateState(
        current: data,
        now: day(7, hour: 10), // 2 days later
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(broken.state, StreakState.broken);
      expect(broken.currentStreak, 0);
      expect(broken.bestStreak, 5); // best preserved
    });
  });

  // ---------------------------------------------------------------------------
  // 8. Repair with token
  // ---------------------------------------------------------------------------

  group('repairStreak', () {
    test('restores streak, consumes one token, sets state to active', () {
      // Start with a broken streak that has tokens.
      final broken = StreakData(
        habitId: 'habit-1',
        currentStreak: 0,
        bestStreak: 7,
        totalCheckIns: 7,
        state: StreakState.broken,
        lastCheckIn: day(-3),
        freezeTokens: 2,
      );

      final repaired = StreakCalculator.repairStreak(
        current: broken,
        now: day(0),
      );

      expect(repaired, isNotNull);
      expect(repaired!.state, StreakState.active);
      expect(repaired.freezeTokens, 1); // consumed one
      expect(repaired.lastCheckIn, isNotNull);
    });

    test('also repairs atRisk streaks', () {
      final atRisk = StreakData(
        habitId: 'habit-1',
        currentStreak: 5,
        bestStreak: 5,
        totalCheckIns: 5,
        state: StreakState.atRisk,
        lastCheckIn: day(-1),
        freezeTokens: 1,
      );

      final repaired = StreakCalculator.repairStreak(
        current: atRisk,
        now: day(0),
      );

      expect(repaired, isNotNull);
      expect(repaired!.state, StreakState.active);
      expect(repaired.freezeTokens, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. Repair with 0 tokens → null
  // ---------------------------------------------------------------------------

  group('repairStreak with no tokens', () {
    test('returns null', () {
      final broken = StreakData(
        habitId: 'habit-1',
        currentStreak: 0,
        bestStreak: 10,
        totalCheckIns: 10,
        state: StreakState.broken,
        lastCheckIn: day(-3),
        freezeTokens: 0, // no tokens
      );

      final result = StreakCalculator.repairStreak(
        current: broken,
        now: day(0),
      );

      expect(result, isNull);
    });

    test('returns null when streak is already active', () {
      final active = StreakData(
        habitId: 'habit-1',
        currentStreak: 5,
        bestStreak: 5,
        totalCheckIns: 5,
        state: StreakState.active,
        lastCheckIn: day(0),
        freezeTokens: 3,
      );

      final result = StreakCalculator.repairStreak(
        current: active,
        now: day(0),
      );

      expect(result, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // 10. Token earned at 7-day milestone
  // ---------------------------------------------------------------------------

  group('checkMilestoneTokenEarn', () {
    test('awards token at 7-day streak', () {
      final data = StreakData(
        habitId: 'habit-1',
        currentStreak: 7,
        bestStreak: 7,
        totalCheckIns: 7,
        state: StreakState.active,
        lastCheckIn: day(6),
        freezeTokens: 0,
      );

      final result = StreakCalculator.checkMilestoneTokenEarn(data);

      expect(result.freezeTokens, 1);
    });

    // ---------------------------------------------------------------------------
    // 11. Token earned at 30-day milestone
    // ---------------------------------------------------------------------------

    test('awards token at 30-day streak', () {
      final data = StreakData(
        habitId: 'habit-1',
        currentStreak: 30,
        bestStreak: 30,
        totalCheckIns: 30,
        state: StreakState.active,
        lastCheckIn: day(29),
        freezeTokens: 1,
      );

      final result = StreakCalculator.checkMilestoneTokenEarn(data);

      expect(result.freezeTokens, 2);
    });

    test('awards token at 60-day streak', () {
      final data = StreakData(
        habitId: 'habit-1',
        currentStreak: 60,
        bestStreak: 60,
        totalCheckIns: 60,
        state: StreakState.active,
        lastCheckIn: day(59),
        freezeTokens: 2,
      );

      final result = StreakCalculator.checkMilestoneTokenEarn(data);

      expect(result.freezeTokens, 3);
    });

    test('does not award token for non-milestone streaks', () {
      final data = StreakData(
        habitId: 'habit-1',
        currentStreak: 10,
        bestStreak: 10,
        totalCheckIns: 10,
        state: StreakState.active,
        lastCheckIn: day(9),
        freezeTokens: 0,
      );

      final result = StreakCalculator.checkMilestoneTokenEarn(data);

      expect(result.freezeTokens, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 12. Token cap — never exceeds 3
  // ---------------------------------------------------------------------------

  group('token cap', () {
    test('never exceeds 3 tokens even at milestone', () {
      final data = StreakData(
        habitId: 'habit-1',
        currentStreak: 7,
        bestStreak: 7,
        totalCheckIns: 7,
        state: StreakState.active,
        lastCheckIn: day(6),
        freezeTokens: 3, // already at cap
      );

      final result = StreakCalculator.checkMilestoneTokenEarn(data);

      expect(result.freezeTokens, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // 13. Milestone tier detection
  // ---------------------------------------------------------------------------

  group('getMilestoneTier', () {
    test('returns correct tier for 7 days', () {
      expect(StreakCalculator.getMilestoneTier(7), MilestoneTier.week);
    });

    test('returns correct tier for 30 days', () {
      expect(StreakCalculator.getMilestoneTier(30), MilestoneTier.month);
    });

    test('returns correct tier for 100 days', () {
      expect(StreakCalculator.getMilestoneTier(100), MilestoneTier.century);
    });

    test('returns null for non-milestone streak', () {
      expect(StreakCalculator.getMilestoneTier(5), isNull);
      expect(StreakCalculator.getMilestoneTier(15), isNull);
      expect(StreakCalculator.getMilestoneTier(99), isNull);
    });

    test('returns correct tier for 14, 60, 365 days', () {
      expect(StreakCalculator.getMilestoneTier(14), MilestoneTier.twoWeeks);
      expect(StreakCalculator.getMilestoneTier(60), MilestoneTier.twoMonths);
      expect(StreakCalculator.getMilestoneTier(365), MilestoneTier.year);
    });
  });

  // ---------------------------------------------------------------------------
  // 14. isNewPersonalBest
  // ---------------------------------------------------------------------------

  group('isNewPersonalBest', () {
    test('returns true when current streak exceeds previous best', () {
      final before = StreakData(
        habitId: 'habit-1',
        currentStreak: 9,
        bestStreak: 9,
        totalCheckIns: 9,
        state: StreakState.active,
        lastCheckIn: day(8),
        freezeTokens: 0,
      );

      final after = StreakCalculator.recordCheckIn(
        current: before,
        checkInTime: day(9),
        frequencyType: FrequencyType.daily,
        daysOfWeek: [],
      );

      expect(StreakCalculator.isNewPersonalBest(before, after), isTrue);
    });

    test('returns false when current streak does not exceed previous best', () {
      final before = StreakData(
        habitId: 'habit-1',
        currentStreak: 3,
        bestStreak: 10,
        totalCheckIns: 13,
        state: StreakState.active,
        lastCheckIn: day(0),
        freezeTokens: 0,
      );

      final after = before.copyWith(currentStreak: 4);

      expect(StreakCalculator.isNewPersonalBest(before, after), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // 15. daysOfWeek habit: skip non-scheduled days in evaluation
  // ---------------------------------------------------------------------------

  group('daysOfWeek habit', () {
    // Reference: day(0) = Monday (weekday 1).
    // Schedule: Monday + Wednesday + Friday = weekdays [1, 3, 5].
    const schedule = [1, 3, 5];

    test('does not break streak when evaluated on a non-scheduled day', () {
      // Check in on Monday (day 0).
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0), // Monday
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      // Evaluate on Tuesday (day 1) — not a scheduled day, no issue.
      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(1, hour: 22), // Tuesday evening
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      expect(evaluated.state, StreakState.active);
      expect(evaluated.currentStreak, 1);
    });

    test('marks atRisk on scheduled day past grace hour', () {
      // Check in on Monday (day 0).
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0), // Monday
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      // Wednesday is day 2 from our Monday base (weekday 3).
      // Evaluate on Wednesday evening without a check-in.
      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(2, hour: 22), // Wednesday 22:00
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      expect(evaluated.state, StreakState.atRisk);
    });

    test('continues streak when consecutive scheduled days are checked in', () {
      var data = initial();

      // Check in Mon (day 0), Wed (day 2), Fri (day 4).
      for (final offset in [0, 2, 4]) {
        data = StreakCalculator.recordCheckIn(
          current: data,
          checkInTime: day(offset),
          frequencyType: FrequencyType.daysOfWeek,
          daysOfWeek: schedule,
        );
      }

      expect(data.currentStreak, 3);
      expect(data.state, StreakState.active);
    });

    test('breaks streak when a scheduled day is fully missed', () {
      // Check in on Monday (day 0).
      var data = StreakCalculator.recordCheckIn(
        current: initial(),
        checkInTime: day(0), // Monday
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      // Evaluate on Friday (day 4) — Wednesday was missed entirely.
      final evaluated = StreakCalculator.evaluateState(
        current: data,
        now: day(4, hour: 22), // Friday evening
        frequencyType: FrequencyType.daysOfWeek,
        daysOfWeek: schedule,
      );

      // Wednesday was missed, Friday is now also at-risk or broken.
      expect(
        evaluated.state,
        anyOf(StreakState.atRisk, StreakState.broken),
      );
    });
  });
}
