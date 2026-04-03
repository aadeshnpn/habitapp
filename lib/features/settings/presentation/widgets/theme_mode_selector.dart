import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/theme_provider.dart';

/// A [SegmentedButton] that lets the user choose between system, light, and
/// dark theme mode.  Reads current selection from [themeProvider] and calls
/// [ThemeNotifier.setMode] on change.
class ThemeModeSelector extends ConsumerWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeProvider);
    final currentMode = themeAsync.valueOrNull?.mode ?? ThemeMode.system;

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment<ThemeMode>(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto),
          label: Text('System'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode),
          label: Text('Light'),
        ),
        ButtonSegment<ThemeMode>(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode),
          label: Text('Dark'),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (Set<ThemeMode> selected) {
        if (selected.isNotEmpty) {
          ref.read(themeProvider.notifier).setMode(selected.first);
        }
      },
    );
  }
}
