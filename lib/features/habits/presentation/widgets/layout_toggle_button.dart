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

  static IconData _iconFor(HomeLayout layout) {
    switch (layout) {
      case HomeLayout.cardList:
        return Icons.view_list;
      case HomeLayout.iconGrid:
        return Icons.grid_view;
      case HomeLayout.rings:
        return Icons.donut_large;
    }
  }

  static String _tooltipFor(HomeLayout layout) {
    switch (layout) {
      case HomeLayout.cardList:
        return 'Card list view';
      case HomeLayout.iconGrid:
        return 'Icon grid view';
      case HomeLayout.rings:
        return 'Rings view';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutAsync = ref.watch(layoutPreferenceProvider);

    return layoutAsync.when(
      data: (layout) => IconButton(
        icon: Icon(_iconFor(layout)),
        tooltip: _tooltipFor(layout),
        onPressed: () {
          final next = _nextLayout(layout);
          ref.read(layoutPreferenceProvider.notifier).setLayout(next);
        },
      ),
      loading: () => const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const Icon(Icons.view_list),
    );
  }
}
