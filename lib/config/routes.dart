import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/habits/presentation/home_screen.dart';
import '../features/habits/presentation/habit_detail_screen.dart';
import '../features/habits/presentation/add_habit_screen.dart';
import '../features/habits/presentation/edit_habit_screen.dart';
import '../features/stats/presentation/stats_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/labels/presentation/labels_screen.dart';
import '../features/labels/presentation/label_detail_screen.dart';

// Named route constants
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String habitDetail = '/habit/:id';
  static const String addHabit = '/habit/add';
  static const String editHabit = '/habit/:id/edit';
  static const String stats = '/stats';
  static const String settings = '/settings';
  static const String labels = '/labels';
  static const String labelDetail = '/labels/:id';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_complete') ?? false;
      if (!done && state.uri.path != '/onboarding') return '/onboarding';
      if (done && state.uri.path == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/habit/add',
        name: 'addHabit',
        builder: (context, state) => const AddHabitScreen(),
      ),
      GoRoute(
        path: '/habit/:id',
        name: 'habitDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return HabitDetailScreen(habitId: id);
        },
        routes: [
          GoRoute(
            path: 'edit',
            name: 'editHabit',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              return EditHabitScreen(habitId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/stats',
        name: 'stats',
        builder: (context, state) => const StatsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/labels',
        name: 'labels',
        builder: (context, state) => const LabelsScreen(),
      ),
      GoRoute(
        path: '/labels/:id',
        name: 'labelDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return LabelDetailScreen(labelId: id);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );
});
