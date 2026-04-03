import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/habits/domain/habit_providers.dart';
import '../../../../shared/widgets/calendar_heatmap.dart';
import '../../../../shared/widgets/streak_counter.dart';
import '../../data/label_model.dart';
import '../../domain/label_providers.dart';

class LabelCard extends ConsumerWidget {
  final HabitLabel label;
  final VoidCallback onTap;

  const LabelCard({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final labelColor = Color(label.color);
    final streakAsync = ref.watch(labelStreakProvider(label.id));
    final completionAsync = ref.watch(labelCompletionMapProvider(label.id));
    final habitIdsAsync = ref.watch(labelHabitIdsProvider(label.id));
    final allHabitsAsync = ref.watch(activeHabitsProvider);

    final streak = streakAsync.valueOrNull;
    final isAtRisk = streak?.state.name == 'atRisk';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAtRisk
                ? Colors.amber
                : theme.colorScheme.outline.withOpacity(0.15),
            width: isAtRisk ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: emoji + name + streak
              Row(
                children: [
                  Text(label.emoji,
                      style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (streak != null && streak.bestStreak > 0)
                          Text(
                            'Best: ${streak.bestStreak} days',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (streak != null)
                    StreakCounter(
                      count: streak.currentStreak,
                      color: labelColor,
                      fontSize: 20,
                    ),
                ],
              ),

              // At-risk indicator
              if (isAtRisk) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.amber),
                      SizedBox(width: 4),
                      Text(
                        'Streak at risk!',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Mini heatmap (last 30 days)
              completionAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (completionMap) => CalendarHeatmap(
                  completionMap: completionMap,
                  accentColor: labelColor,
                  days: 30,
                ),
              ),

              // Member habit chips
              habitIdsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (habitIds) {
                  if (habitIds.isEmpty) return const SizedBox.shrink();
                  final habits = allHabitsAsync.valueOrNull ?? [];
                  final memberHabits = habits
                      .where((h) => habitIds.contains(h.id))
                      .toList();

                  if (memberHabits.isEmpty) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: memberHabits.map((h) {
                          return Chip(
                            label: Text(
                              '${h.icon} ${h.name}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 0),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
