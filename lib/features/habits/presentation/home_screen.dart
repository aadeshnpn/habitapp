import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../checkin/domain/checkin_repository.dart';
import '../../../streaks/domain/streak_providers.dart';
import '../data/habit_model.dart';
import '../domain/habit_providers.dart';
import '../domain/layout_preference_provider.dart';
import 'layouts/card_list_layout.dart';
import 'layouts/icon_grid_layout.dart';
import 'layouts/rings_layout.dart';
import 'widgets/checkin_bottom_sheet.dart';
import 'widgets/layout_toggle_button.dart';

// ---------------------------------------------------------------------------
// Derived providers for today's completions and streak counts
// ---------------------------------------------------------------------------

/// Set of habit IDs completed today.
final completedTodayProvider = FutureProvider<Set<String>>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  final repo = ref.read(checkInRepositoryProvider);

  final results = await Future.wait(
    habits.map((h) async {
      final done = await repo.isCompletedToday(h.id);
      return done ? h.id : null;
    }),
  );

  return results.whereType<String>().toSet();
});

/// Map of habitId → current streak count.
final streakCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final habits = await ref.watch(activeHabitsProvider.future);
  final Map<String, int> counts = {};

  await Future.wait(
    habits.map((h) async {
      final data = await ref.watch(streakDataProvider(h.id).future);
      counts[h.id] = data.currentStreak;
    }),
  );

  return counts;
});

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _todayTitle() {
    return DateFormat('EEEE, MMM d').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final layoutAsync = ref.watch(layoutPreferenceProvider);
    final completedAsync = ref.watch(completedTodayProvider);
    final streaksAsync = ref.watch(streakCountsProvider);
    final atRiskAsync = ref.watch(atRiskHabitsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_todayTitle()),
        actions: [
          // Stats chip showing "X/Y done"
          habitsAsync.when(
            data: (habits) => completedAsync.when(
              data: (completed) {
                final total = habits.length;
                final done = completed.length;
                if (total == 0) return const SizedBox.shrink();
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$done/$total done',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const LayoutToggleButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: habitsAsync.when(
        data: (habits) {
          final completed = completedAsync.valueOrNull ?? {};
          final streaks = streaksAsync.valueOrNull ?? {};
          final atRisk = Set<String>.from(atRiskAsync.valueOrNull ?? []);

          // All done state
          if (habits.isNotEmpty && completed.length >= habits.length) {
            return _AllDoneState(
              onAddMore: () => context.go('/habit/add'),
            );
          }

          // Choose layout
          final layout = layoutAsync.valueOrNull ?? HomeLayout.cardList;

          void handleComplete(String habitId) async {
            final habit = habits.firstWhere((h) => h.id == habitId);
            if (habit.checkInType == CheckInType.tap) {
              // Direct tap check-in
              final repo = ref.read(checkInRepositoryProvider);
              await repo.recordCheckIn(habitId);
              ref.invalidate(completedTodayProvider);
              ref.invalidate(streakCountsProvider);
              ref.invalidate(atRiskHabitsProvider);
              ref.invalidate(streakDataProvider(habitId));
            } else {
              // Show bottom sheet for note/quantity
              if (context.mounted) {
                await CheckInBottomSheet.show(
                  context,
                  habitId: habitId,
                  habitName: habit.name,
                  checkInType: habit.checkInType,
                  quantityUnit: habit.quantityUnit,
                );
                ref.invalidate(completedTodayProvider);
                ref.invalidate(streakCountsProvider);
                ref.invalidate(atRiskHabitsProvider);
                ref.invalidate(streakDataProvider(habitId));
              }
            }
          }

          void handleTap(String habitId) {
            context.go('/habit/$habitId');
          }

          switch (layout) {
            case HomeLayout.cardList:
              return CardListLayout(
                habits: habits,
                completedToday: completed,
                streakCounts: streaks,
                atRiskHabits: atRisk,
                onComplete: handleComplete,
                onTap: handleTap,
              );
            case HomeLayout.iconGrid:
              return IconGridLayout(
                habits: habits,
                completedToday: completed,
                streakCounts: streaks,
                atRiskHabits: atRisk,
                onComplete: handleComplete,
                onTap: handleTap,
              );
            case HomeLayout.rings:
              return RingsLayout(
                habits: habits,
                completedToday: completed,
                streakCounts: streaks,
                atRiskHabits: atRisk,
                onComplete: handleComplete,
                onTap: handleTap,
              );
          }
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/habit/add'),
        tooltip: 'Add habit',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        onDestinationSelected: (i) {
          if (i == 1) context.go('/stats');
          if (i == 2) context.go('/settings');
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// All-done state
// ---------------------------------------------------------------------------

class _AllDoneState extends StatelessWidget {
  final VoidCallback onAddMore;

  const _AllDoneState({required this.onAddMore});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryGlow = theme.colorScheme.primary.withOpacity(0.10);

    return Container(
      color: primaryGlow,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated trophy emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: const Text('🏆', style: TextStyle(fontSize: 80)),
              ),
              const SizedBox(height: 24),
              Text(
                'All done for today! 🎉',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Your streaks are safe. See you tomorrow.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: onAddMore,
                icon: const Icon(Icons.add),
                label: const Text('Add another habit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
