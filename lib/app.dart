import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/routes.dart';
import 'core/notifications/notification_service.dart';
import 'core/notifications/notification_test_bridge.dart';
import 'shared/theme/app_theme.dart';
import 'shared/theme/theme_provider.dart';

class HabitTrackerApp extends ConsumerStatefulWidget {
  const HabitTrackerApp({super.key});

  @override
  ConsumerState<HabitTrackerApp> createState() => _HabitTrackerAppState();
}

class _HabitTrackerAppState extends ConsumerState<HabitTrackerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!kIsWeb) {
        // Re-ensure channels once the Activity MethodChannel is definitely live.
        await NotificationService.instance.ensureMindfulnessChannels();
      }
      // Emulator/CI notif_test intent bridge — never arm in release.
      if (kDebugMode) {
        await NotificationTestBridge.consumePendingLaunchTest();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeAsync = ref.watch(themeProvider);

    return themeAsync.when(
      data: (themeState) => MaterialApp.router(
        title: 'Habit Tracker',
        theme: AppTheme.buildTheme(
          palette: themeState.palette,
          brightness: Brightness.light,
        ),
        darkTheme: AppTheme.buildTheme(
          palette: themeState.palette,
          brightness: Brightness.dark,
        ),
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
