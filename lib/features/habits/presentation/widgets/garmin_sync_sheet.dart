import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/health/garmin_activity_fetcher.dart';
import '../../../../core/health/health_service.dart';
import '../../domain/garmin_ai_sync_service.dart';
import '../../domain/habit_providers.dart';
import '../../data/habit_model.dart';


class ProcessedLogItem {
  final String activityId;
  final String habitId;
  final String activityTitle;
  final String confidence;
  final String note;
  final DateTime processedAt;

  ProcessedLogItem({
    required this.activityId,
    required this.habitId,
    required this.activityTitle,
    required this.confidence,
    required this.note,
    required this.processedAt,
  });
}

class GarminSyncSheet extends ConsumerStatefulWidget {
  const GarminSyncSheet({super.key});

  @override
  ConsumerState<GarminSyncSheet> createState() => _GarminSyncSheetState();
}

class _GarminSyncSheetState extends ConsumerState<GarminSyncSheet> {
  bool _isSyncing = false;
  bool _isRequestingPermission = false;
  List<GarminWorkout> _recentWorkouts = [];
  List<ProcessedLogItem> _processedLogs = [];
  bool _isLoadingData = true;
  int _selectedDaysBack = 7;

  @override
  void initState() {
    super.initState();
    _loadSyncData();
  }

  Future<void> _loadSyncData() async {
    setState(() => _isLoadingData = true);
    try {
      final fetcher = ref.read(garminActivityFetcherProvider);
      final workouts = await fetcher.fetchRecentWorkouts(daysBack: _selectedDaysBack);

      final db = await DatabaseService.instance.database;
      final rows = await db.query('processed_activities', orderBy: 'processed_at DESC', limit: 20);

      final logs = rows.map((r) {
        return ProcessedLogItem(
          activityId: r['activity_id'] as String? ?? '',
          habitId: r['habit_id'] as String? ?? '',
          activityTitle: r['activity_title'] as String? ?? 'Garmin Activity',
          confidence: r['confidence'] as String? ?? 'high',
          note: r['note'] as String? ?? '',
          processedAt: DateTime.tryParse(r['processed_at'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _recentWorkouts = workouts;
          _processedLogs = logs;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }


  Future<void> _requestHealthPermissions() async {
    setState(() => _isRequestingPermission = true);
    try {
      final healthService = ref.read(healthServiceProvider);
      final granted = await healthService.requestPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(granted
                ? 'Health & Google Fit permissions requested successfully!'
                : 'Permission request completed. Make sure Health Connect / Google Fit permissions are enabled in Settings.'),
            backgroundColor: granted ? Colors.green[700] : Colors.orange[800],
          ),
        );
      }
      await _loadSyncData();
    } finally {
      if (mounted) setState(() => _isRequestingPermission = false);
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    try {
      final result = await ref.read(triggerGarminAiSyncProvider.future);
      ref.invalidate(activeHabitsProvider);
      await _loadSyncData();

      if (mounted) {
        if (result.workoutsProcessed > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Garmin AI Sync complete! Auto-logged: ${result.matchedHabitNames.join(', ')} 🤖🎉'),
              backgroundColor: Colors.green[700],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync finished. No new un-synced activities found today.'),
            ),
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

  IconData _getActivityIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('meditat') || lower.contains('mindful') || lower.contains('zen')) return Icons.self_improvement;
    if (lower.contains('run') || lower.contains('jog')) return Icons.directions_run;
    if (lower.contains('walk')) return Icons.directions_walk;
    if (lower.contains('cycle') || lower.contains('bike')) return Icons.directions_bike;
    if (lower.contains('swim')) return Icons.pool;
    if (lower.contains('yoga')) return Icons.fitness_center;
    return Icons.watch_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                const Icon(Icons.favorite_outline, color: Colors.redAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Google Fit & Garmin Health Sync',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Permission Card
            Card(
              elevation: 0,
              color: theme.primaryColor.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.security_outlined, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text(
                          'Google Fit & Health Connect Status',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Requires read permissions for Workouts, Meditation, Steps, and Active Calories from Google Fit / Health Connect.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRequestingPermission ? null : _requestHealthPermissions,
                        icon: _isRequestingPermission
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.health_and_safety_outlined),
                        label: Text(_isRequestingPermission ? 'Requesting...' : 'Grant / Refresh Health Permissions'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => ref.read(healthServiceProvider).openHealthConnectSettings(),
                        icon: const Icon(Icons.settings_applications_outlined),
                        label: const Text('Open Health Connect App / Settings'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Google Fit Instructions Card
            Card(
              elevation: 0,
              color: Colors.amber.withOpacity(0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: Colors.amber),
                        const SizedBox(width: 8),
                        Text(
                          'How to Sync Google Fit with Habit Tracker',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.amber[900]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '1. Open your Google Fit App -> Profile -> Settings.\n'
                      '2. Turn ON "Sync Fit with Health Connect".\n'
                      '3. Tap "Grant / Refresh Health Permissions" above and allow Habit Tracker access.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.black87, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),


            // Manual Sync Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isSyncing ? null : _triggerManualSync,
                icon: _isSyncing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync),
                label: Text(
                  _isSyncing ? 'Syncing with On-Device Gemini Nano...' : 'Sync Now with Gemini AI',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Garmin / Health Activities section header with date range selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Garmin / Health Activities',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                DropdownButton<int>(
                  value: _selectedDaysBack,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Today')),
                    DropdownMenuItem(value: 7, child: Text('Past 7 Days')),
                    DropdownMenuItem(value: 30, child: Text('Past 30 Days')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedDaysBack = val);
                      _loadSyncData();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_isLoadingData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_recentWorkouts.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No Garmin/Health activities found in the selected time range ($_selectedDaysBack days).',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )

            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentWorkouts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final workout = _recentWorkouts[index];
                  final isLogged = _processedLogs.any((l) => l.activityId == workout.id);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.primaryColor.withOpacity(0.1),
                        child: Icon(_getActivityIcon(workout.title), color: theme.primaryColor),
                      ),
                      title: Text(workout.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(workout.summaryNote),
                      trailing: Chip(
                        avatar: Icon(
                          isLogged ? Icons.check_circle : Icons.sync,
                          size: 16,
                          color: isLogged ? Colors.green : Colors.orange,
                        ),
                        label: Text(
                          isLogged ? 'Auto-Logged' : 'Detected',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLogged ? Colors.green[800] : Colors.orange[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: isLogged ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Sync History Log
            Text(
              "Recent Auto-Logged History",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            if (_processedLogs.isEmpty)
              Text(
                'No past sync records found.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _processedLogs.length,
                itemBuilder: (context, index) {
                  final item = _processedLogs[index];
                  final timeStr = DateFormat('MMM d, h:mm a').format(item.processedAt);
                  final isLowConfidence = item.confidence == 'low';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isLowConfidence ? Icons.help_outline : Icons.auto_awesome,
                          size: 18,
                          color: isLowConfidence ? Colors.amber[800] : Colors.green[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.note.isNotEmpty ? item.note : 'Garmin Sync (${item.activityTitle})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                timeStr,
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 20),

            // Health Connect Diagnostics Log
            ExpansionTile(
              title: const Text(
                'Health Connect Diagnostic Logs',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              leading: const Icon(Icons.bug_report_outlined, size: 20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    GarminActivityFetcher.lastDiagnosticLog,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

  }
}
