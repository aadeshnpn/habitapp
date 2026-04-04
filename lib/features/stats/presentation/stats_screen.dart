import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_nav_bar.dart';
import '../../habits/data/habit_model.dart';
import '../../habits/domain/habit_providers.dart';
import '../domain/stats_providers.dart';
import '../domain/stats_service.dart';

// ---------------------------------------------------------------------------
// StatsScreen — top-level entry point
// ---------------------------------------------------------------------------

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Stats'),
        centerTitle: false,
        elevation: 0,
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 1),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(overallCompletionRateProvider);
          ref.invalidate(longestActiveStreakProvider);
          ref.invalidate(insightCardsProvider);
          ref.invalidate(activeHabitsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const [
            _SummarySection(),
            SizedBox(height: 28),
            _InsightsSection(),
            SizedBox(height: 28),
            _HabitBreakdownSection(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary cards row
// ---------------------------------------------------------------------------

class _SummarySection extends ConsumerWidget {
  const _SummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overallAsync = ref.watch(overallCompletionRateProvider);
    final streakAsync = ref.watch(longestActiveStreakProvider);
    final habitsAsync = ref.watch(activeHabitsProvider);

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Overall completion rate
          overallAsync.when(
            data: (rate) => _SummaryCard(
              accentColor: AppColors.greenPrimary,
              icon: Icons.check_circle_outline_rounded,
              value: '${(rate * 100).round()}%',
              label: 'This month',
            ),
            loading: () => const _SummaryCardSkeleton(),
            error: (_, __) => const _SummaryCard(
              accentColor: AppColors.greenPrimary,
              icon: Icons.check_circle_outline_rounded,
              value: '--',
              label: 'This month',
            ),
          ),
          const SizedBox(width: 12),
          // Best current streak
          streakAsync.when(
            data: (streak) => _SummaryCard(
              accentColor: AppColors.orangePrimary,
              icon: Icons.local_fire_department_rounded,
              value: streak != null ? '${streak.currentStreak}' : '0',
              label: 'Best streak',
            ),
            loading: () => const _SummaryCardSkeleton(),
            error: (_, __) => const _SummaryCard(
              accentColor: AppColors.orangePrimary,
              icon: Icons.local_fire_department_rounded,
              value: '--',
              label: 'Best streak',
            ),
          ),
          const SizedBox(width: 12),
          // Total active habits
          habitsAsync.when(
            data: (habits) => _SummaryCard(
              accentColor: AppColors.purplePrimary,
              icon: Icons.list_alt_rounded,
              value: '${habits.length}',
              label: 'Active habits',
            ),
            loading: () => const _SummaryCardSkeleton(),
            error: (_, __) => const _SummaryCard(
              accentColor: AppColors.purplePrimary,
              icon: Icons.list_alt_rounded,
              value: '--',
              label: 'Active habits',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String value;
  final String label;

  const _SummaryCard({
    required this.accentColor,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          top: BorderSide(color: accentColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: accentColor, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 130,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ---------------------------------------------------------------------------
// Insights section
// ---------------------------------------------------------------------------

class _InsightsSection extends ConsumerWidget {
  const _InsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(insightCardsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        insightsAsync.when(
          data: (insights) {
            if (insights.isEmpty) {
              return _InsightsEmptyState();
            }
            return Column(
              children: insights
                  .map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InsightCardWidget(card: card),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            'Could not load insights.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.errorColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _InsightsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark
            : AppColors.greenSurface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            'Complete habits for 7+ days to unlock insights',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCardWidget extends StatelessWidget {
  final InsightCard card;

  const _InsightCardWidget({required this.card});

  Color _backgroundForType(BuildContext context, InsightType type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (type) {
      case InsightType.neverMissedDay:
        return isDark
            ? AppColors.greenPrimary.withOpacity(0.15)
            : AppColors.greenSurface;
      case InsightType.nearPersonalBest:
        return isDark
            ? AppColors.orangePrimary.withOpacity(0.15)
            : AppColors.orangeSurface;
      case InsightType.bestDayOfWeek:
        return isDark
            ? AppColors.purplePrimary.withOpacity(0.15)
            : AppColors.purpleSurface;
      case InsightType.currentChampion:
        return isDark
            ? AppColors.orangePrimary.withOpacity(0.15)
            : AppColors.orangeSurface;
      case InsightType.consistencyStreak:
        return isDark
            ? AppColors.greenPrimary.withOpacity(0.15)
            : AppColors.greenSurface;
    }
  }

  Color _circleColorForType(InsightType type) {
    switch (type) {
      case InsightType.neverMissedDay:
        return AppColors.greenPrimary;
      case InsightType.nearPersonalBest:
        return AppColors.orangePrimary;
      case InsightType.bestDayOfWeek:
        return AppColors.purplePrimary;
      case InsightType.currentChampion:
        return AppColors.orangeStreak;
      case InsightType.consistencyStreak:
        return AppColors.greenStreak;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = _backgroundForType(context, card.type);
    final circleColor = _circleColorForType(card.type);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: circleColor.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              card.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
        title: Text(
          card.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            card.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habit breakdown section
// ---------------------------------------------------------------------------

class _HabitBreakdownSection extends ConsumerWidget {
  const _HabitBreakdownSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(activeHabitsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Habit Breakdown',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        habitsAsync.when(
          data: (habits) {
            if (habits.isEmpty) {
              return Text(
                'No active habits yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              );
            }
            return Column(
              children: habits
                  .map((habit) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HabitBreakdownRow(habit: habit),
                      ))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Text(
            'Could not load habits.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.errorColor),
          ),
        ),
      ],
    );
  }
}

class _HabitBreakdownRow extends ConsumerWidget {
  final Habit habit;

  const _HabitBreakdownRow({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rateAsync = ref.watch(habitCompletionRateProvider(habit.id));
    final dowAsync = ref.watch(dayOfWeekBreakdownProvider(habit.id));

    final habitColor = Color(habit.color);

    return GestureDetector(
      onTap: () => context.push('/habit/${habit.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + name + completion label
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: habitColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      habit.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                rateAsync.when(
                  data: (rate) => Text(
                    '${(rate * 100).round()}% this month',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: habitColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  loading: () => const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            rateAsync.when(
              data: (rate) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.black.withOpacity(0.07),
                  valueColor: AlwaysStoppedAnimation<Color>(habitColor),
                ),
              ),
              loading: () => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: null,
                  minHeight: 6,
                  backgroundColor:
                      isDark ? Colors.white12 : Colors.black.withOpacity(0.07),
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            // Day-of-week mini chart
            dowAsync.when(
              data: (breakdown) =>
                  _DayOfWeekChart(breakdown: breakdown, color: habitColor),
              loading: () => const SizedBox(height: 32),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day-of-week mini bar chart
// ---------------------------------------------------------------------------

class _DayOfWeekChart extends StatelessWidget {
  final Map<int, double> breakdown;
  final Color color;

  const _DayOfWeekChart({required this.breakdown, required this.color});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barBg =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final weekday = i + 1; // 1=Mon … 7=Sun
        final rate = breakdown[weekday] ?? 0.0;
        return Column(
          children: [
            SizedBox(
              height: 32,
              width: 18,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: rate.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: rate > 0 ? color : barBg,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _labels[i],
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }),
    );
  }
}
