import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase — requires valid google-services.json
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint(
        'Firebase init failed (expected if google-services.json is placeholder): $e');
  }
  runApp(const ProviderScope(child: HabitTrackerApp()));
}
