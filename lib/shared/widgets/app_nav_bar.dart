import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shared bottom navigation bar used on all top-level screens.
/// [currentIndex]: 0=Today, 1=Stats, 2=Labels, 3=Settings
class AppNavBar extends StatelessWidget {
  final int currentIndex;

  const AppNavBar({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: 'Stats',
        ),
        NavigationDestination(
          icon: Icon(Icons.label_outline),
          selectedIcon: Icon(Icons.label),
          label: 'Labels',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
      onDestinationSelected: (i) {
        if (i == currentIndex) return; // already here
        switch (i) {
          case 0:
            context.go('/home');
          case 1:
            context.go('/stats');
          case 2:
            context.go('/labels');
          case 3:
            context.go('/settings');
        }
      },
    );
  }
}
