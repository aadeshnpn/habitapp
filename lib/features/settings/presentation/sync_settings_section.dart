import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/sync/auth_provider.dart';
import '../../../core/sync/sync_providers.dart';

class SyncSettingsSection extends ConsumerStatefulWidget {
  const SyncSettingsSection({super.key});

  @override
  ConsumerState<SyncSettingsSection> createState() => _SyncSettingsSectionState();
}

class _SyncSettingsSectionState extends ConsumerState<SyncSettingsSection> {
  bool _isSyncing = false;
  bool _autoSync = false;

  @override
  void initState() {
    super.initState();
    _loadAutoSync();
  }

  Future<void> _loadAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoSync = prefs.getBool('auto_sync') ?? false;
      });
    }
  }

  Future<void> _setAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', value);
    if (mounted) {
      setState(() {
        _autoSync = value;
      });
    }
  }

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    final syncService = ref.read(syncServiceProvider);
    final result = await syncService.syncAll();
    if (!mounted) return;
    setState(() => _isSyncing = false);

    // Invalidate so last sync time refreshes
    ref.invalidate(lastSyncTimeProvider);

    final messenger = ScaffoldMessenger.of(context);
    if (result.success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sync complete')),
      );
    } else if (result.notSignedIn) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sign in to sync')),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text('Sync failed: ${result.error}')),
      );
    }
  }

  String _formatSyncTime(DateTime? dt) {
    if (dt == null) return 'Never synced';
    final formatter = DateFormat('MMM d, y h:mm a');
    return 'Last synced: ${formatter.format(dt.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final lastSyncAsync = ref.watch(lastSyncTimeProvider);

    return userAsync.when(
      loading: () => const ListTile(
        leading: Icon(Icons.cloud_outlined),
        title: Text('Sync to cloud'),
        subtitle: Text('Loading...'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.cloud_off_outlined),
        title: const Text('Sync to cloud'),
        subtitle: Text('Error: $e'),
      ),
      data: (user) {
        if (user == null) {
          // Not signed in
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ListTile(
                leading: Icon(Icons.cloud_outlined),
                title: Text('Sync to cloud'),
                subtitle: Text('Back up your habits to Google Drive'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  onPressed: () async {
                    final authService = ref.read(authServiceProvider);
                    final result = await authService.signInWithGoogle();
                    if (result == null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sign-in cancelled or failed')),
                      );
                    }
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                ),
              ),
            ],
          );
        }

        // Signed in
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user.email ?? user.displayName ?? 'Signed in'),
              subtitle: const Text('Google account'),
              trailing: IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Sign out',
                onPressed: () async {
                  final authService = ref.read(authServiceProvider);
                  await authService.signOut();
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(
                lastSyncAsync.when(
                  loading: () => 'Checking sync time...',
                  error: (_, __) => 'Never synced',
                  data: _formatSyncTime,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _isSyncing
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Syncing...'),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: _syncNow,
                      icon: const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.update),
              title: const Text('Auto-sync daily'),
              subtitle: const Text('Automatically back up your data each day'),
              value: _autoSync,
              onChanged: _setAutoSync,
            ),
          ],
        );
      },
    );
  }
}
