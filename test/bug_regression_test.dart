// Regression tests for two bugs fixed in the labels/stats area:
//
//  1. Duplicate Dismissible keys on the stats screen when multiple habits share
//     the same "best day of week" insight title.
//     Fix: _keyFor now includes the subtitle so each habit produces a unique key.
//
//  2. Flutter '_dependents.isEmpty: is not true' assertion on the labels tab
//     when toggling isAtRisk with 2+ member habits.
//     Fix: CalendarHeatmap and chips sections are wrapped in KeyedSubtree so
//     Flutter matches them by key when the at-risk block shifts column positions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/habits/domain/habit_providers.dart';
import 'package:habit_tracker/features/labels/data/label_model.dart';
import 'package:habit_tracker/features/labels/domain/label_providers.dart';
import 'package:habit_tracker/features/labels/presentation/widgets/label_card.dart';
import 'package:habit_tracker/features/stats/domain/stats_service.dart';
import 'package:habit_tracker/features/streaks/data/streak_model.dart';

// ---------------------------------------------------------------------------
// Shared test fixtures
// ---------------------------------------------------------------------------

final _testLabel = HabitLabel(
  id: 'l1',
  name: 'Fitness',
  emoji: '💪',
  color: 0xFF4CAF50,
  createdAt: DateTime(2026, 1, 1),
);

Habit _makeHabit(String id, String name) => Habit(
      id: id,
      name: name,
      icon: '🏃',
      color: 0xFF4CAF50,
      frequencyType: FrequencyType.daily,
      checkInType: CheckInType.tap,
      createdAt: DateTime(2026, 1, 1),
    );

LabelStreak _makeStreak({StreakState state = StreakState.active}) => LabelStreak(
      labelId: 'l1',
      currentStreak: 5,
      bestStreak: 10,
      totalDays: 20,
      state: state,
      lastActiveDay: DateTime(2026, 4, 1),
    );

// Replicates the private _keyFor logic from stats_screen.dart.
String _keyFor(InsightCard card) =>
    '${card.type.name}|${card.title}|${card.subtitle}';

// ---------------------------------------------------------------------------
// Bug 1 — Duplicate insight-card keys
// ---------------------------------------------------------------------------

void main() {
  group('InsightCard key uniqueness (stats screen)', () {
    test(
        'two bestDayOfWeek cards with same title but different habits '
        'produce unique keys via subtitle', () {
      const cardA = InsightCard(
        emoji: '📅',
        title: 'Your best day is Tuesday',
        subtitle: 'Habit A: 80% completion on Tuesdays',
        type: InsightType.bestDayOfWeek,
      );
      const cardB = InsightCard(
        emoji: '📅',
        title: 'Your best day is Tuesday',
        subtitle: 'Habit B: 75% completion on Tuesdays',
        type: InsightType.bestDayOfWeek,
      );

      expect(_keyFor(cardA), isNot(equals(_keyFor(cardB))));
    });

    test(
        'two neverMissedDay cards for the same day but different habits '
        'produce unique keys', () {
      const cardA = InsightCard(
        emoji: '🌟',
        title: "You've never missed a Monday",
        subtitle: 'Habit A has a perfect Monday record!',
        type: InsightType.neverMissedDay,
      );
      const cardB = InsightCard(
        emoji: '🌟',
        title: "You've never missed a Monday",
        subtitle: 'Habit B has a perfect Monday record!',
        type: InsightType.neverMissedDay,
      );

      expect(_keyFor(cardA), isNot(equals(_keyFor(cardB))));
    });

    test(
        'two consistencyStreak cards with same milestone but different habits '
        'produce unique keys', () {
      const cardA = InsightCard(
        emoji: '🎉',
        title: '5 more to reach 50 completions!',
        subtitle: 'Running is at 45 — almost there!',
        type: InsightType.consistencyStreak,
      );
      const cardB = InsightCard(
        emoji: '🎉',
        title: '5 more to reach 50 completions!',
        subtitle: 'Yoga is at 45 — almost there!',
        type: InsightType.consistencyStreak,
      );

      expect(_keyFor(cardA), isNot(equals(_keyFor(cardB))));
    });

    test('cards with the same type produce different keys when types differ', () {
      const cardA = InsightCard(
        emoji: '🔥',
        title: 'Keep going',
        subtitle: 'You are almost there!',
        type: InsightType.nearPersonalBest,
      );
      const cardB = InsightCard(
        emoji: '🎉',
        title: 'Keep going',
        subtitle: 'You are almost there!',
        type: InsightType.consistencyStreak,
      );

      expect(_keyFor(cardA), isNot(equals(_keyFor(cardB))));
    });

    test('identical cards produce the same key (dismissed together)', () {
      const card = InsightCard(
        emoji: '📅',
        title: 'Your best day is Tuesday',
        subtitle: 'Habit A: 80% completion on Tuesdays',
        type: InsightType.bestDayOfWeek,
      );

      expect(_keyFor(card), equals(_keyFor(card)));
    });

    test(
        'key list built from two habits that share the same best day '
        'contains no duplicates', () {
      final cards = [
        const InsightCard(
          emoji: '📅',
          title: 'Your best day is Tuesday',
          subtitle: 'Running: 80% completion on Tuesdays',
          type: InsightType.bestDayOfWeek,
        ),
        const InsightCard(
          emoji: '📅',
          title: 'Your best day is Tuesday',
          subtitle: 'Yoga: 70% completion on Tuesdays',
          type: InsightType.bestDayOfWeek,
        ),
      ];

      final keys = cards.map(_keyFor).toList();
      expect(
        keys.toSet().length,
        equals(keys.length),
        reason: 'Duplicate keys found: $keys',
      );
    });
  });

  // -------------------------------------------------------------------------
  // Bug 2 — LabelCard _dependents.isEmpty assertion
  // -------------------------------------------------------------------------

  group('LabelCard with multiple member habits (labels tab)', () {
    // Builds a LabelCard inside a minimal scaffold using static provider
    // overrides. Sufficient for rendering tests that don't need state mutation.
    Widget _buildCard({
      required List<String> habitIds,
      required List<Habit> habits,
      required LabelStreak streak,
    }) {
      return ProviderScope(
        overrides: [
          labelStreakProvider('l1').overrideWith((_) async => streak),
          labelCompletionMapProvider('l1')
              .overrideWith((_) async => <DateTime, bool>{}),
          labelHabitIdsProvider('l1').overrideWith((_) async => habitIds),
          activeHabitsProvider.overrideWith((_) async => habits),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: LabelCard(label: _testLabel, onTap: () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with zero member habits without error', (tester) async {
      await tester.pumpWidget(
        _buildCard(habitIds: [], habits: [], streak: _makeStreak()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('renders with one member habit without error', (tester) async {
      final h1 = _makeHabit('h1', 'Running');
      await tester.pumpWidget(
        _buildCard(habitIds: ['h1'], habits: [h1], streak: _makeStreak()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('renders with two member habits without error', (tester) async {
      final h1 = _makeHabit('h1', 'Running');
      final h2 = _makeHabit('h2', 'Yoga');
      await tester.pumpWidget(
        _buildCard(
          habitIds: ['h1', 'h2'],
          habits: [h1, h2],
          streak: _makeStreak(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fitness'), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });

    testWidgets('renders with three member habits without error', (tester) async {
      final h1 = _makeHabit('h1', 'Running');
      final h2 = _makeHabit('h2', 'Yoga');
      final h3 = _makeHabit('h3', 'Cycling');
      await tester.pumpWidget(
        _buildCard(
          habitIds: ['h1', 'h2', 'h3'],
          habits: [h1, h2, h3],
          streak: _makeStreak(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Chip), findsNWidgets(3));
    });

    testWidgets(
        'heatmap and chips sections carry stable KeyedSubtree keys',
        (tester) async {
      final h1 = _makeHabit('h1', 'Running');
      final h2 = _makeHabit('h2', 'Yoga');
      await tester.pumpWidget(
        _buildCard(
          habitIds: ['h1', 'h2'],
          habits: [h1, h2],
          streak: _makeStreak(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('label_card_heatmap')),
        findsOneWidget,
        reason: 'CalendarHeatmap section must be wrapped in KeyedSubtree',
      );
      expect(
        find.byKey(const ValueKey('label_card_chips')),
        findsOneWidget,
        reason: 'Chips section must be wrapped in KeyedSubtree',
      );
    });

    testWidgets(
        'toggling isAtRisk with two habits does not throw '
        '_dependents.isEmpty assertion', (tester) async {
      // This test directly exercises the bug scenario:
      //   isAtRisk: false → true inserts two widgets before the heatmap,
      //   shifting unkeyed column children and causing CalendarHeatmap's
      //   _ScrollableScope to be deactivated while dependents still exist.
      //
      // The fix (KeyedSubtree) preserves element identity so Flutter never
      // deactivates an InheritedElement with non-empty _dependents.

      final h1 = _makeHabit('h1', 'Running');
      final h2 = _makeHabit('h2', 'Yoga');

      final streakState = StateProvider<LabelStreak>(
        (_) => _makeStreak(state: StreakState.active),
      );

      final container = ProviderContainer(overrides: [
        labelStreakProvider('l1').overrideWith(
          (ref) async => ref.watch(streakState),
        ),
        labelCompletionMapProvider('l1')
            .overrideWith((_) async => <DateTime, bool>{}),
        labelHabitIdsProvider('l1').overrideWith((_) async => ['h1', 'h2']),
        activeHabitsProvider.overrideWith((_) async => [h1, h2]),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: LabelCard(label: _testLabel, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Confirm initial state: chips visible, no at-risk banner.
      expect(find.byType(Chip), findsNWidgets(2));
      expect(find.text('Streak at risk!'), findsNothing);
      expect(find.byKey(const ValueKey('label_card_heatmap')), findsOneWidget);
      expect(find.byKey(const ValueKey('label_card_chips')), findsOneWidget);

      // Trigger the bug scenario: change streak to atRisk.
      // This inserts the at-risk block (SizedBox + Container) into the Column
      // before the heatmap and chips, shifting their positions by +2.
      container.read(streakState.notifier).state =
          _makeStreak(state: StreakState.atRisk);
      await tester.pumpAndSettle();

      // At-risk banner appears and keyed sections survive with same identity.
      expect(find.text('Streak at risk!'), findsOneWidget);
      expect(find.byKey(const ValueKey('label_card_heatmap')), findsOneWidget);
      expect(find.byKey(const ValueKey('label_card_chips')), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));

      // Toggle back to active — at-risk block removed, positions shift back.
      container.read(streakState.notifier).state =
          _makeStreak(state: StreakState.active);
      await tester.pumpAndSettle();

      expect(find.text('Streak at risk!'), findsNothing);
      expect(find.byKey(const ValueKey('label_card_heatmap')), findsOneWidget);
      expect(find.byKey(const ValueKey('label_card_chips')), findsOneWidget);
      expect(find.byType(Chip), findsNWidgets(2));
    });
  });
}
