import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../shared/widgets/app_nav_bar.dart';
import '../data/interval_reminder_model.dart';
import '../domain/interval_reminder_providers.dart';
import '../domain/interval_reminder_repository.dart';
import 'add_interval_reminder_sheet.dart';
import 'interval_reminder_log_sheet.dart';
import 'widgets/interval_reminder_card.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(activeIntervalRemindersProvider);
    final summaryAsync = ref.watch(reminderTodaySummaryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interval Reminders'),
        centerTitle: false,
        actions: [
          // Summary badge
          summaryAsync.when(
            data: (s) {
              if (s.total == 0) return const SizedBox.shrink();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s.done}/${s.total} done',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_interval_reminder',
        onPressed: () async {
          final created = await AddIntervalReminderSheet.show(context);
          if (created == true) {
            ref.invalidate(activeIntervalRemindersProvider);
            ref.invalidate(reminderTodaySummaryProvider);
            ref.invalidate(scheduleNotificationsProvider);
          }
        },
        icon: const Icon(Icons.alarm_add_outlined),
        label: const Text('Add Reminder'),
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 1),
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return _EmptyState(
              onAdd: () async {
                final created = await AddIntervalReminderSheet.show(context);
                if (created == true) {
                  ref.invalidate(activeIntervalRemindersProvider);
                  ref.invalidate(reminderTodaySummaryProvider);
                  ref.invalidate(scheduleNotificationsProvider);
                }
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(activeIntervalRemindersProvider);
              ref.invalidate(reminderTodaySummaryProvider);
              ref.invalidate(scheduleNotificationsProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Top summary card
                SliverToBoxAdapter(
                  child: summaryAsync.when(
                    data: (s) => s.total > 0
                        ? _SummaryCard(done: s.done, total: s.total)
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
                // Reminder list
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final reminder = reminders[index];
                      return Dismissible(
                        key: ValueKey(reminder.id),
                        direction: DismissDirection.endToStart,
                        background: _DeleteBackground(),
                        confirmDismiss: (_) async =>
                            _confirmDelete(context, reminder.name),
                        onDismissed: (_) async {
                          final repo =
                              ref.read(intervalReminderRepositoryProvider);
                          await repo.deleteReminder(reminder.id);
                          await NotificationService.instance
                              .cancelIntervalReminder(reminder.id);
                          ref.invalidate(activeIntervalRemindersProvider);
                          ref.invalidate(reminderTodaySummaryProvider);
                          ref.invalidate(scheduleNotificationsProvider);
                        },
                        child: IntervalReminderCard(
                          reminder: reminder,
                          onLogTap: () async {
                            final logged =
                                await IntervalReminderLogSheet.show(
                              context,
                              reminder: reminder,
                            );
                            if (logged == true) {
                              ref.invalidate(reminderTodaySummaryProvider);
                            }
                          },
                          onTap: () async {
                            // Long-press / tap → edit sheet
                            final updated =
                                await AddIntervalReminderSheet.show(
                              context,
                              existing: reminder,
                            );
                            if (updated == true) {
                              ref.invalidate(activeIntervalRemindersProvider);
                              ref.invalidate(reminderTodaySummaryProvider);
                              ref.invalidate(scheduleNotificationsProvider);
                            }
                          },
                        ),
                      );
                    },
                    childCount: reminders.length,
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: 100)), // FAB padding
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder'),
        content: Text('Remove "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary card
// ---------------------------------------------------------------------------

class _SummaryCard extends StatelessWidget {
  final int done;
  final int total;

  const _SummaryCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = total > 0 ? done / total : 0.0;
    final allDone = done >= total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
              : [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? '🎉 All done today!' : 'Today\'s Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: allDone
                        ? Colors.white
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$done of $total reminders completed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: (allDone
                            ? Colors.white
                            : theme.colorScheme.onPrimaryContainer)
                        .withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      allDone ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            allDone ? '✅' : '⏰',
            style: const TextStyle(fontSize: 36),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: const Text('⏰', style: TextStyle(fontSize: 72)),
            ),
            const SizedBox(height: 24),
            Text(
              'No Interval Reminders',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Set up recurring reminders for water, medication, movement, or nutrition — and track them through the day.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: const [
                _PresetChip(emoji: '💧', label: 'Water'),
                _PresetChip(emoji: '💊', label: 'Meds'),
                _PresetChip(emoji: '🚶', label: 'Steps'),
                _PresetChip(emoji: '🍎', label: 'Food'),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('Add First Reminder'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _PresetChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text('$emoji $label',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe-to-delete background
// ---------------------------------------------------------------------------

class _DeleteBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer),
    );
  }
}
