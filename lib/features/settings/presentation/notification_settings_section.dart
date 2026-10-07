import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// State provider backed by SharedPreferences
// ---------------------------------------------------------------------------

/// Loads all four notification toggles from SharedPreferences.
/// Returns a map of key -> bool.
final _notifPrefsProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'notif_daily': prefs.getBool('notif_daily') ?? true,
    'notif_atrisk': prefs.getBool('notif_atrisk') ?? true,
    'notif_repair': prefs.getBool('notif_repair') ?? true,
    'notif_milestone': prefs.getBool('notif_milestone') ?? true,
  };
});

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

/// A settings section with four [SwitchListTile] entries controlling which
/// types of notifications the user receives. Each preference is persisted to
/// [SharedPreferences].
class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  // Local state mirrors what is in SharedPreferences so that toggles respond
  // immediately without waiting for an async round-trip.
  bool _daily = true;
  bool _atRisk = true;
  bool _repair = true;
  bool _milestone = true;
  bool _loaded = false;

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(_notifPrefsProvider);

    return prefsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => ListTile(
        title: const Text('Notifications'),
        subtitle: Text('Could not load preferences: $err'),
      ),
      data: (prefs) {
        // Seed local state from SharedPreferences on first load.
        if (!_loaded) {
          _daily = prefs['notif_daily'] ?? true;
          _atRisk = prefs['notif_atrisk'] ?? true;
          _repair = prefs['notif_repair'] ?? true;
          _milestone = prefs['notif_milestone'] ?? true;
          _loaded = true;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'Notifications',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            SwitchListTile(
              title: const Text('Daily reminders'),
              subtitle: const Text(
                  "Remind me at my habit's set time each day"),
              value: _daily,
              onChanged: (value) => _toggle('notif_daily', value, () {
                setState(() => _daily = value);
              }),
            ),
            SwitchListTile(
              title: const Text('Streak at-risk alerts'),
              subtitle: const Text(
                  'Warn me before I lose an active streak'),
              value: _atRisk,
              onChanged: (value) => _toggle('notif_atrisk', value, () {
                setState(() => _atRisk = value);
              }),
            ),
            SwitchListTile(
              title: const Text('Repair reminders'),
              subtitle: const Text(
                  'Remind me when I can repair a broken streak'),
              value: _repair,
              onChanged: (value) => _toggle('notif_repair', value, () {
                setState(() => _repair = value);
              }),
            ),
            SwitchListTile(
              title: const Text('Milestone celebrations'),
              subtitle:
                  const Text('Celebrate when I hit a streak milestone'),
              value: _milestone,
              onChanged: (value) => _toggle('notif_milestone', value, () {
                setState(() => _milestone = value);
              }),
            ),
            const Divider(height: 24),
            // Manual delivery tests — debug / profile builds only.
            if (kDebugMode) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Send test notification now'),
                subtitle: const Text(
                  'Debug only — checks permission and channels',
                ),
                onTap: () => _runTest(() async {
                  await NotificationService.instance.showTestNotification();
                  return 'Test notification sent';
                }),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('Schedule test in 1 minute'),
                subtitle: const Text(
                  'Debug only — verifies background scheduling',
                ),
                onTap: () => _runTest(() async {
                  await NotificationService.instance
                      .scheduleTestNotification(minutesFromNow: 1);
                  final exact = await NotificationService.instance
                      .canScheduleExactNotifications();
                  if (!exact) {
                    return 'Scheduled (~1 min, may be a bit late). '
                        'For on-time delivery, enable Alarms & reminders.';
                  }
                  return 'Scheduled in ~1 minute. Leave the app and wait.';
                }),
              ),
            ],
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.alarm_on_outlined),
              title: const Text('Open Alarms & reminders permission'),
              subtitle: const Text(
                'Required on Pixel / Android 14+ for on-time alerts',
              ),
              onTap: () => _runTest(() async {
                final exact = await NotificationService.instance
                    .requestExactAlarmsPermissionOnly();
                return exact
                    ? 'Exact alarms allowed'
                    : 'Exact alarms still denied — grant Alarms & reminders '
                        'for Habit Tracker in system settings';
              }),
            ),
          ],
        );
      },
    );
  }

  Future<void> _runTest(Future<String> Function() action) async {
    try {
      final message = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      final friendly = e.toString().contains('exact_alarms_not_permitted')
          ? 'Exact alarms are blocked. Tap “Open Alarms & reminders '
              'permission”, enable it, then try Schedule test again.'
          : e.toString().replaceFirst('Bad state: ', '').replaceFirst(
                'StateError: ',
                '',
              );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _toggle(
    String key,
    bool value,
    VoidCallback updateState,
  ) async {
    updateState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    // Invalidate the provider so any other listener picks up the new value.
    ref.invalidate(_notifPrefsProvider);
    // Reschedule OS notifications to match the new toggles.
    ref.invalidate(scheduleNotificationsProvider);
  }
}
