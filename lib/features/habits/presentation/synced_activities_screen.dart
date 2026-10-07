import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_nav_bar.dart';
import '../domain/synced_activities_provider.dart';
import '../domain/garmin_ai_sync_service.dart';
import '../domain/habit_providers.dart';
import 'widgets/garmin_sync_sheet.dart';

class SyncedActivitiesScreen extends ConsumerStatefulWidget {
  const SyncedActivitiesScreen({super.key});

  @override
  ConsumerState<SyncedActivitiesScreen> createState() => _SyncedActivitiesScreenState();
}

class _SyncedActivitiesScreenState extends ConsumerState<SyncedActivitiesScreen> {
  bool _isSyncing = false;

  Future<void> _triggerSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final aiResult = await ref.read(triggerGarminAiSyncProvider.future);

      ref.invalidate(syncedActivitiesProvider);
      ref.invalidate(activeHabitsProvider);

      if (mounted) {
        final totalAuto = aiResult.matchedHabitNames.length;
        if (totalAuto > 0) {
          final names = aiResult.matchedHabitNames.join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync complete! Auto-logged: $names 🤖🎉'),
              backgroundColor: Colors.green[700],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sync complete. No new activities to map.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync notice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Widget _buildConfidenceBadge(String confidence, ThemeData theme) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (confidence.toLowerCase()) {
      case 'direct':
        bg = Colors.blue.withOpacity(0.15);
        fg = Colors.blue[800]!;
        label = 'Direct Metric';
        icon = Icons.gps_fixed;
      case 'high':
        bg = Colors.green.withOpacity(0.15);
        fg = Colors.green[800]!;
        label = 'AI High Match';
        icon = Icons.auto_awesome;
      case 'medium':
        bg = Colors.amber.withOpacity(0.15);
        fg = Colors.amber[900]!;
        label = 'AI Match';
        icon = Icons.psychology;
      case 'low':
      default:
        bg = Colors.orange.withOpacity(0.15);
        fg = Colors.orange[900]!;
        label = 'AI Low Match';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final syncedAsync = ref.watch(syncedActivitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Synced Activities'),
        actions: [
          IconButton(
            tooltip: 'Sync Settings / Setup',
            icon: const Icon(Icons.tune_outlined),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const GarminSyncSheet(),
              );
            },
          ),
          IconButton(
            tooltip: 'Trigger Sync Now',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: _triggerSync,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _triggerSync,
        child: syncedAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.sync_outlined,
                          size: 36,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Synced Activities Yet',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Activities from Garmin, Google Fit, or Apple Health will automatically be classified and mapped to your habits here.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _triggerSync,
                        icon: const Icon(Icons.sync),
                        label: const Text('Run Health Sync Now'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final timeFmt = DateFormat('MMM d, yyyy • h:mm a');

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final habitColor = Color(item.habitColor);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: item.habitId.isNotEmpty
                        ? () => context.push('/habit/${item.habitId}')
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Activity Title + Confidence Chip
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: habitColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  item.habitIcon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.activityTitle,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Mapped to ${item.habitName}',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: habitColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              _buildConfidenceBadge(item.confidence, theme),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Details / Note
                          if (item.note.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item.note,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Timestamp
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                timeFmt.format(item.processedAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'View Habit',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.chevron_right, size: 14, color: theme.colorScheme.primary),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading sync log: $err')),
        ),
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 2),
    );
  }
}
