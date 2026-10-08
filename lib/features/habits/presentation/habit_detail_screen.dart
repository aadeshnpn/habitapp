import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/habit_model.dart';
import '../domain/habit_providers.dart';
import '../../checkin/data/checkin_model.dart';
import '../../streaks/data/streak_model.dart';

import '../../../shared/widgets/calendar_heatmap.dart';
import '../../../shared/widgets/freeze_token_display.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  Habit? _habit;
  StreakData? _streak;
  List<CheckIn> _recentCheckIns = [];
  Map<DateTime, bool> _completionMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habitRepo = ref.read(habitRepositoryProvider);
    final checkInRepo = ref.read(checkInRepositoryProvider);

    final habit = await habitRepo.getHabitById(widget.habitId);
    if (!mounted) return;
    if (habit == null) {
      setState(() => _loading = false);
      return;
    }

    final streakDao = ref.read(streakDaoProvider);
    final streak =
        await streakDao.getForHabit(widget.habitId) ?? StreakData.initial(widget.habitId);

    final allCheckIns = await checkInRepo.getHistory(widget.habitId, days: 90);
    final completionMap =
        await checkInRepo.getCompletionMap(widget.habitId, days: 90);

    if (!mounted) return;
    setState(() {
      _habit = habit;
      _streak = streak;
      _recentCheckIns = allCheckIns
          .sorted((a, b) => b.timestamp.compareTo(a.timestamp))
          .take(10)
          .toList();
      _completionMap = completionMap;
      _loading = false;
    });
  }

  Future<void> _archiveHabit() async {
    final habit = _habit;
    if (habit == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Archive "${habit.name}"?'),
        content: const Text('Your history will be preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final habitRepo = ref.read(habitRepositoryProvider);
      await habitRepo.archiveHabit(widget.habitId);
      ref.invalidate(activeHabitsProvider);
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    }
  }

  double _compute30DayRate() {
    if (_completionMap.isEmpty) return 0;
    final now = DateTime.now();
    int completed = 0;
    int total = 0;
    for (int i = 0; i < 30; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      total++;
      if (_completionMap[d] == true) completed++;
    }
    return total == 0 ? 0 : (completed / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_habit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit Detail')),
        body: const Center(child: Text('Habit not found.')),
      );
    }

    final habit = _habit!;
    final streak = _streak ?? StreakData.initial(widget.habitId);
    final accentColor = Color(habit.color);
    final rate = _compute30DayRate();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _HabitSliverAppBar(
            habit: habit,
            accentColor: accentColor,
            onEdit: () async {
              await context.pushNamed(
                'editHabit',
                pathParameters: {'id': habit.id},
              );
              if (mounted) await _load();
            },
            onArchive: _archiveHabit,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (habit.description != null &&
                    habit.description!.trim().isNotEmpty) ...[
                  Text(
                    habit.description!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Stats row
                _StatsRow(
                  currentStreak: streak.currentStreak,
                  bestStreak: streak.bestStreak,
                  totalCompletions: streak.totalCheckIns,
                  thirtyDayRate: rate,
                  accentColor: accentColor,
                ),
                const SizedBox(height: 20),

                // Freeze tokens
                Row(
                  children: [
                    Text(
                      'Streak freeze tokens',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FreezeTokenDisplay(tokenCount: streak.freezeTokens),
                  ],
                ),
                const SizedBox(height: 20),

                // Calendar heatmap
                Text(
                  '90-day history',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: CalendarHeatmap(
                    completionMap: _completionMap,
                    accentColor: accentColor,
                    days: 90,
                  ),
                ),
                const SizedBox(height: 20),

                // Recent check-ins
                Text(
                  'Recent check-ins',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (_recentCheckIns.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No check-ins yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentCheckIns.map(
                    (ci) => _CheckInTile(
                      checkIn: ci,
                      checkInType: habit.checkInType,
                      quantityUnit: habit.quantityUnit,
                      accentColor: accentColor,
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sliver AppBar
// ---------------------------------------------------------------------------

class _HabitSliverAppBar extends StatelessWidget {
  final Habit habit;
  final Color accentColor;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  const _HabitSliverAppBar({
    required this.habit,
    required this.accentColor,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back',
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(habit.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                habit.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.25),
                theme.colorScheme.surface,
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit habit',
          onPressed: onEdit,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'archive',
              child: Row(
                children: [
                  Icon(Icons.archive_outlined, size: 18),
                  SizedBox(width: 10),
                  Text('Archive'),
                ],
              ),
            ),
          ],
          onSelected: (v) {
            if (v == 'archive') onArchive();
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats row
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;
  final int totalCompletions;
  final double thirtyDayRate;
  final Color accentColor;

  const _StatsRow({
    required this.currentStreak,
    required this.bestStreak,
    required this.totalCompletions,
    required this.thirtyDayRate,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Current streak',
          value: '$currentStreak',
          unit: 'days',
          icon: '🔥',
          accentColor: accentColor,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Best streak',
          value: '$bestStreak',
          unit: 'days',
          icon: '🏆',
          accentColor: accentColor,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Total',
          value: '$totalCompletions',
          unit: 'done',
          icon: '✅',
          accentColor: accentColor,
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: '30-day rate',
          value: '${thirtyDayRate.toStringAsFixed(0)}%',
          unit: '',
          icon: '📊',
          accentColor: accentColor,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final String icon;
  final Color accentColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: accentColor,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                unit,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 9,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Check-in tile
// ---------------------------------------------------------------------------

class _CheckInTile extends StatelessWidget {
  final CheckIn checkIn;
  final CheckInType checkInType;
  final String? quantityUnit;
  final Color accentColor;

  static final _dateFmt = DateFormat('MMM d, yyyy');
  static final _timeFmt = DateFormat('HH:mm');

  const _CheckInTile({
    required this.checkIn,
    required this.checkInType,
    required this.quantityUnit,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String? subtitle;
    final noteText = checkIn.note;
    if (checkInType == CheckInType.quantity && checkIn.quantity != null) {
      final unit = quantityUnit ?? '';
      final qty = checkIn.quantity!;
      final qtyStr = qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty.toStringAsFixed(1);
      final qtyText = '$qtyStr $unit'.trim();
      if (noteText != null && noteText.isNotEmpty) {
        subtitle = '$qtyText • $noteText';
      } else {
        subtitle = qtyText;
      }
    } else if (noteText != null && noteText.isNotEmpty) {
      subtitle = noteText;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: accentColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _dateFmt.format(checkIn.timestamp),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Text(
            _timeFmt.format(checkIn.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extension helpers
// ---------------------------------------------------------------------------

extension _SortedList<T> on List<T> {
  List<T> sorted(int Function(T a, T b) compare) {
    final copy = List<T>.from(this);
    copy.sort(compare);
    return copy;
  }
}
