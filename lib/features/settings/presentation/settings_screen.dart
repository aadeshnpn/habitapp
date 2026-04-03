import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/habits/domain/layout_preference_provider.dart';
import '../../../shared/theme/theme_provider.dart';
import '../../../shared/widgets/freeze_token_display.dart';
import 'notification_settings_section.dart';
import 'widgets/palette_picker_sheet.dart';
import 'widgets/theme_mode_selector.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeProvider);
    final currentPalette = themeAsync.valueOrNull?.palette;

    final layoutAsync = ref.watch(layoutPreferenceProvider);
    final currentLayout = layoutAsync.valueOrNull ?? HomeLayout.cardList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ----------------------------------------------------------------
          // Section: Appearance
          // ----------------------------------------------------------------
          const _SectionHeader(title: 'Appearance'),

          // Theme palette row
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme palette'),
            subtitle: Text(
              currentPalette?.displayName ?? '—',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => PalettePickerSheet.show(context),
          ),

          // Dark mode selector
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.brightness_6_outlined, size: 24),
                    SizedBox(width: 16),
                    Text(
                      'Dark mode',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Padding(
                  padding: EdgeInsets.only(left: 40),
                  child: ThemeModeSelector(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ----------------------------------------------------------------
          // Section: Home Screen
          // ----------------------------------------------------------------
          const _SectionHeader(title: 'Home Screen'),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_quilt_outlined, size: 24),
                    const SizedBox(width: 16),
                    const Text(
                      'Default layout',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: SegmentedButton<HomeLayout>(
                    segments: const [
                      ButtonSegment<HomeLayout>(
                        value: HomeLayout.cardList,
                        icon: Icon(Icons.view_list),
                        label: Text('List'),
                      ),
                      ButtonSegment<HomeLayout>(
                        value: HomeLayout.iconGrid,
                        icon: Icon(Icons.grid_view),
                        label: Text('Grid'),
                      ),
                      ButtonSegment<HomeLayout>(
                        value: HomeLayout.rings,
                        icon: Icon(Icons.donut_large),
                        label: Text('Rings'),
                      ),
                    ],
                    selected: {currentLayout},
                    onSelectionChanged: (Set<HomeLayout> selected) {
                      if (selected.isNotEmpty) {
                        ref
                            .read(layoutPreferenceProvider.notifier)
                            .setLayout(selected.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ----------------------------------------------------------------
          // Section: Notifications
          // ----------------------------------------------------------------
          const NotificationSettingsSection(),

          const Divider(height: 1),

          // ----------------------------------------------------------------
          // Section: Streak Protection
          // ----------------------------------------------------------------
          const _SectionHeader(title: 'Streak Protection'),

          ListTile(
            leading: const Icon(Icons.ac_unit_outlined),
            title: const Text('Freeze tokens'),
            subtitle: const Text(
              'Earned at 7, 30, and 60-day milestones',
            ),
            trailing: const FreezeTokenDisplay(tokenCount: 0),
          ),

          const Divider(height: 1),

          // ----------------------------------------------------------------
          // Section: About
          // ----------------------------------------------------------------
          const _SectionHeader(title: 'About'),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            trailing: Text(
              '1.0.0',
              style: TextStyle(color: Colors.grey),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export data'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widget: section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
