import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/theme/app_palette.dart';
import '../../../../shared/theme/theme_provider.dart';

/// A modal bottom sheet that lets the user pick one of the three [AppPalette]
/// options.  Each option is shown as a card containing the palette name, three
/// colour swatches (primary, accent, streak) and a checkmark when it is the
/// currently-active palette.
class PalettePickerSheet extends ConsumerWidget {
  const PalettePickerSheet({super.key});

  /// Convenience helper — call this instead of [showModalBottomSheet] directly.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PalettePickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeProvider);
    final currentPalette =
        themeAsync.valueOrNull?.palette ?? AppPalette.calmGreen;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Choose palette',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            ...AppPalette.values.map((palette) {
              final isSelected = palette == currentPalette;
              return _PaletteCard(
                palette: palette,
                isSelected: isSelected,
                onTap: () {
                  ref.read(themeProvider.notifier).setPalette(palette);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _PaletteCard extends StatelessWidget {
  final AppPalette palette;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaletteCard({
    required this.palette,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? palette.primaryColor : colorScheme.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
          color: isSelected
              ? palette.primaryColor.withOpacity(0.08)
              : colorScheme.surface,
        ),
        child: Row(
          children: [
            // Three colour swatches
            _ColorSwatch(color: palette.primaryColor),
            const SizedBox(width: 6),
            _ColorSwatch(color: palette.accentColor),
            const SizedBox(width: 6),
            _ColorSwatch(color: palette.streakColor),
            const SizedBox(width: 14),
            // Palette name
            Expanded(
              child: Text(
                palette.displayName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected
                          ? palette.primaryColor
                          : colorScheme.onSurface,
                    ),
              ),
            ),
            // Checkmark if selected
            if (isSelected)
              Icon(Icons.check_circle, color: palette.primaryColor, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;

  const _ColorSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
