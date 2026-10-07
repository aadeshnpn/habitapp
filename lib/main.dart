import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service.dart';
import 'core/background/background_sync_manager.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use in-browser SQLite (no web worker required) on web platform
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }

  // Web needs explicit options; Android reads from google-services.json automatically.
  try {
    await Firebase.initializeApp(
      options: kIsWeb ? DefaultFirebaseOptions.web : null,
    );
  } catch (e) {
    debugPrint('Firebase initializeApp notice: $e');
  }

  // Initialize notifications, background Garmin AI sync, and request permission on Android.
  if (!kIsWeb) {
    await NotificationService.instance.initialize();
    await NotificationService.instance.requestPermission();
    await BackgroundSyncManager.initialize();
  }

  final container = ProviderContainer();
  if (!kIsWeb) {
    // Kick a full reschedule at startup (not only when Home is visible).
    container.read(scheduleNotificationsProvider);
  }

  runApp(UncontrolledProviderScope(
    container: container,
    child: const HabitTrackerApp(),
  ));
}
