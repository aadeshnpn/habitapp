import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/habits/domain/layout_preference_provider.dart';

class LayoutToggleButton extends ConsumerWidget {
  const LayoutToggleButton({super.key});

  static HomeLayout _nextLayout(HomeLayout current) {
    switch (current) {
      case HomeLayout.cardList:
        return HomeLayout.iconGrid;
      case HomeLayout.iconGrid:
        return HomeLayout.rings;
      case HomeLayout.rings:
        return HomeLayout.cardList;
    }
  }

  // Icon and label describe the NEXT layout (what you'll switch TO).
  static IconData _iconFor(HomeLayout next) {
    switch (next) {
      case HomeLayout.cardList:
        return Icons.view_list;
      case HomeLayout.iconGrid:
        return Icons.grid_view;
      case HomeLayout.rings:
        return Icons.donut_large;
    }
  }

  static String _labelFor(HomeLayout current) {
    switch (current) {
      case HomeLayout.cardList:
        return 'List';
      case HomeLayout.iconGrid:
        return 'Grid';
      case HomeLayout.rings:
        return 'Rings';
    }
  }

  static String _tooltipFor(HomeLayout next) {
    switch (next) {
      case HomeLayout.cardList:
        return 'Switch to card list';
      case HomeLayout.iconGrid:
        return 'Switch to icon grid';
      case HomeLayout.rings:
        return 'Switch to rings view';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutAsync = ref.watch(layoutPreferenceProvider);
    final theme = Theme.of(context);

    return layoutAsync.when(
      data: (layout) {
        final next = _nextLayout(layout);
        return Tooltip(
          message: _tooltipFor(next),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              ref.read(layoutPreferenceProvider.notifier).setLayout(next);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconFor(layout), size: 18,
                      color: theme.colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    _labelFor(layout),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(width: 48),
      error: (_, __) => const SizedBox(width: 48),
    );
  }
}
