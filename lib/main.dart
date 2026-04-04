import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use in-browser SQLite (no web worker required) on web platform
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }

  // Initialize Firebase — requires valid google-services.json
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint(
        'Firebase init failed (expected if google-services.json is placeholder): $e');
  }
  runApp(const ProviderScope(child: HabitTrackerApp()));
}
