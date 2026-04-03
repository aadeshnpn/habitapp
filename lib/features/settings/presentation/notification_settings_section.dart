import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
          ],
        );
      },
    );
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
  }
}
