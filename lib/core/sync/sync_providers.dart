import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_service.dart';
import '../../features/habits/domain/habit_providers.dart';
import 'auth_service.dart';
import 'sync_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(databaseServiceProvider), AuthService.instance);
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final s = prefs.getString('last_sync');
  return s != null ? DateTime.tryParse(s) : null;
});
