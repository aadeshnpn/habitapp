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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Stats'),
        centerTitle: false,
        elevation: 0,
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 3),
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
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
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
// Insights section — first 3 visible, rest behind "Show more"
// ---------------------------------------------------------------------------

const _kInsightsPreviewCount = 3;

class _InsightsSection extends ConsumerStatefulWidget {
  const _InsightsSection();

  @override
  ConsumerState<_InsightsSection> createState() => _InsightsSectionState();
}

class _InsightsSectionState extends ConsumerState<_InsightsSection> {
  bool _expanded = false;
  final Set<String> _dismissedKeys = {};

  static String _keyFor(InsightCard card) =>
      '${card.type.name}|${card.title}|${card.subtitle}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insightsAsync = ref.watch(insightCardsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Insights',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            insightsAsync.when(
              data: (insights) {
                final remaining = insights
                    .where((c) => !_dismissedKeys.contains(_keyFor(c)))
                    .toList();
                if (remaining.length <= _kInsightsPreviewCount) {
                  return const SizedBox.shrink();
                }
                return _SectionPill(
                  label: _expanded
                      ? 'Show less'
                      : '+${remaining.length - _kInsightsPreviewCount} more',
                  onTap: () => setState(() => _expanded = !_expanded),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        insightsAsync.when(
          data: (allInsights) {
            final insights = allInsights
                .where((c) => !_dismissedKeys.contains(_keyFor(c)))
                .toList();

            if (insights.isEmpty) return _InsightsEmptyState();

            // Always the first N cards — never overlaps with the overflow block.
            final visible = insights.length > _kInsightsPreviewCount
                ? insights.sublist(0, _kInsightsPreviewCount)
                : insights;

            Widget dismissible(InsightCard card) => Dismissible(
                  key: ValueKey(_keyFor(card)),
                  direction: DismissDirection.startToEnd,
                  onDismissed: (_) =>
                      setState(() => _dismissedKeys.add(_keyFor(card))),
                  background: _DismissBackground(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InsightCardWidget(card: card),
                  ),
                );

            return Column(
              children: [
                // Always-visible cards
                ...visible.map(dismissible),
                // Animated overflow cards
                if (insights.length > _kInsightsPreviewCount)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Column(
                            children: insights
                                .sublist(_kInsightsPreviewCount)
                                .map(dismissible)
                                .toList(),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                // Collapse button shown at bottom when fully expanded
                if (_expanded && insights.length > _kInsightsPreviewCount)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _ShowLessButton(
                      onTap: () => setState(() => _expanded = false),
                    ),
                  ),
              ],
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habit breakdown section — each card individually expandable
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
        // Section header with habit count badge
        Row(
          children: [
            Text(
              'Habit Breakdown',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            habitsAsync.when(
              data: (habits) => habits.isEmpty
                  ? const SizedBox.shrink()
                  : _CountBadge(count: habits.length),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Tap a habit to see detailed stats',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HabitBreakdownCard(habit: habit),
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

class _HabitBreakdownCard extends ConsumerStatefulWidget {
  final Habit habit;

  const _HabitBreakdownCard({required this.habit});

  @override
  ConsumerState<_HabitBreakdownCard> createState() =>
      _HabitBreakdownCardState();
}

class _HabitBreakdownCardState extends ConsumerState<_HabitBreakdownCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rateAsync = ref.watch(habitCompletionRateProvider(widget.habit.id));
    final dowAsync = ref.watch(dayOfWeekBreakdownProvider(widget.habit.id));
    final habitColor = Color(widget.habit.color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Compact header row (always visible) ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: habitColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        widget.habit.icon,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(
                    child: Text(
                      widget.habit.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Completion % pill
                  rateAsync.when(
                    data: (rate) => _RatePill(rate: rate, color: habitColor),
                    loading: () => const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(width: 4),
                  // Expand / collapse chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // Navigate to detail (separate from expand tap)
                  IconButton(
                    icon: Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'View habit details',
                    onPressed: () => context.push('/habit/${widget.habit.id}'),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

          // ── Expandable detail area ──
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? _HabitDetail(
                    rateAsync: rateAsync,
                    dowAsync: dowAsync,
                    habitColor: habitColor,
                    isDark: isDark,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// The detail content shown when a habit card is expanded.
class _HabitDetail extends StatelessWidget {
  final AsyncValue<double> rateAsync;
  final AsyncValue<Map<int, double>> dowAsync;
  final Color habitColor;
  final bool isDark;

  const _HabitDetail({
    required this.rateAsync,
    required this.dowAsync,
    required this.habitColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.12),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar with label
          Row(
            children: [
              Text(
                'Completion',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              rateAsync.when(
                data: (rate) => Text(
                  '${(rate * 100).round()}% this month',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: habitColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          rateAsync.when(
            data: (rate) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 7,
                backgroundColor: isDark
                    ? Colors.white12
                    : Colors.black.withOpacity(0.07),
                valueColor: AlwaysStoppedAnimation<Color>(habitColor),
              ),
            ),
            loading: () => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: null,
                minHeight: 7,
                backgroundColor: isDark
                    ? Colors.white12
                    : Colors.black.withOpacity(0.07),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          // Day-of-week label
          Text(
            'Best days of the week',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          dowAsync.when(
            data: (breakdown) =>
                _DayOfWeekChart(breakdown: breakdown, color: habitColor),
            loading: () => const SizedBox(height: 40),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

/// Rounded pill showing completion rate.
class _RatePill extends StatelessWidget {
  final double rate;
  final Color color;

  const _RatePill({required this.rate, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${(rate * 100).round()}%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Red background revealed when swiping an insight card to dismiss it.
class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(
        Icons.delete_outline_rounded,
        color: theme.colorScheme.onErrorContainer,
        size: 22,
      ),
    );
  }
}

/// Rounded pill used in section headers (e.g. "+4 more").
class _SectionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SectionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// "Show less" text button shown at the bottom of expanded insights.
class _ShowLessButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShowLessButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 16),
        label: const Text('Show less'),
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          textStyle: theme.textTheme.labelSmall,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
    );
  }
}

/// Small count badge shown next to "Habit Breakdown" heading.
class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
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
        final weekday = i + 1;
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
