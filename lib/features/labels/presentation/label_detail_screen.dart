import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/calendar_heatmap.dart';
import '../../../shared/widgets/streak_counter.dart';
import '../../habits/domain/habit_providers.dart';
import '../data/label_model.dart';
import '../domain/label_providers.dart';

class LabelDetailScreen extends ConsumerWidget {
  final String labelId;

  const LabelDetailScreen({super.key, required this.labelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(allLabelsProvider);
    final streakAsync = ref.watch(labelStreakProvider(labelId));
    final completionAsync = ref.watch(labelCompletionMapProvider(labelId));
    final habitIdsAsync = ref.watch(labelHabitIdsProvider(labelId));
    final allHabitsAsync = ref.watch(activeHabitsProvider);
    final theme = Theme.of(context);

    final label = labelsAsync.valueOrNull
        ?.firstWhereOrNull((l) => l.id == labelId);

    if (label == null && labelsAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (label == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Label not found')),
      );
    }

    final labelColor = Color(label.color);
    final streak = streakAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(label.name),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(labelStreakProvider(labelId));
          ref.invalidate(labelCompletionMapProvider(labelId));
          ref.invalidate(labelHabitIdsProvider(labelId));
        },
        child: CustomScrollView(
          slivers: [
            // Stats row
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _StatsRow(
                  streak: streak,
                  labelColor: labelColor,
                  theme: theme,
                ),
              ),
            ),

            // Heatmap
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Text(
                  'Activity (last 90 days)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: completionAsync.when(
                  loading: () => const SizedBox(
                    height: 80,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, _) => Text('Error: $e'),
                  data: (map) => CalendarHeatmap(
                    completionMap: map,
                    accentColor: labelColor,
                    days: 90,
                  ),
                ),
              ),
            ),

            // Member habits section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Row(
                  children: [
                    Text(
                      'Member Habits',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: labelColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'OR logic',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: labelColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            habitIdsAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
              data: (habitIds) {
                final habits = allHabitsAsync.valueOrNull ?? [];
                final memberHabits =
                    habits.where((h) => habitIds.contains(h.id)).toList();

                if (memberHabits.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No habits assigned yet. Edit a habit to add this label.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _MemberHabitTile(
                      habit: memberHabits[i],
                      labelColor: labelColor,
                    ),
                    childCount: memberHabits.length,
                  ),
                );
              },
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stats Row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final LabelStreak? streak;
  final Color labelColor;
  final ThemeData theme;

  const _StatsRow({
    required this.streak,
    required this.labelColor,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final current = streak?.currentStreak ?? 0;
    final best = streak?.bestStreak ?? 0;
    final total = streak?.totalDays ?? 0;
    final rate = (total > 0 && streak?.lastActiveDay != null)
        ? _computeRate(streak!)
        : 0.0;

    return Row(
      children: [
        _StatCard(
          label: 'Current',
          value: '$current',
          icon: '🔥',
          color: current > 0 ? labelColor : theme.colorScheme.outline,
          theme: theme,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Best',
          value: '$best',
          icon: '⭐',
          color: best > 0 ? labelColor : theme.colorScheme.outline,
          theme: theme,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Total days',
          value: '$total',
          icon: '📅',
          color: theme.colorScheme.primary,
          theme: theme,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Rate',
          value: '${rate.toStringAsFixed(0)}%',
          icon: '📊',
          color: theme.colorScheme.primary,
          theme: theme,
        ),
      ],
    );
  }

  double _computeRate(LabelStreak streak) {
    if (streak.lastActiveDay == null) return 0;
    final daysSinceCreation =
        DateTime.now().difference(streak.lastActiveDay!).inDays + 1;
    if (daysSinceCreation <= 0) return 0;
    return (streak.totalDays / daysSinceCreation * 100).clamp(0, 100);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String icon;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member Habit Tile
// ---------------------------------------------------------------------------

class _MemberHabitTile extends StatelessWidget {
  final dynamic habit; // Habit type from habit_model.dart
  final Color labelColor;

  const _MemberHabitTile({required this.habit, required this.labelColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(habit.color as int).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          habit.icon as String,
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        habit.name as String,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        (habit.frequencyType?.name ?? 'daily') == 'daily'
            ? 'Every day'
            : 'Custom schedule',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Null-safe firstWhereOrNull extension
// ---------------------------------------------------------------------------

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
