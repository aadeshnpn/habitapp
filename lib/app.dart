import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/routes.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider.dart';

class HabitTrackerApp extends ConsumerWidget {
  const HabitTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeAsync = ref.watch(themeProvider);

    return themeAsync.when(
      data: (themeState) => MaterialApp.router(
        title: 'Habit Tracker',
        theme: AppTheme.buildTheme(palette: themeState.palette, brightness: Brightness.light),
        darkTheme: AppTheme.buildTheme(palette: themeState.palette, brightness: Brightness.dark),
        themeMode: themeState.mode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Theme error: $e'))),
      ),
    );
  }
}
