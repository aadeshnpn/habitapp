import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../database/database_service.dart';
import '../ai/gemini_nano_service.dart';
import '../health/garmin_activity_fetcher.dart';
import '../../features/habits/data/habit_dao.dart';
import '../../features/habits/data/habit_model.dart';
import '../../features/checkin/data/checkin_dao.dart';
import '../../features/checkin/domain/checkin_repository.dart';
import '../../features/checkin/domain/checkin_service.dart';
import '../../features/streaks/data/streak_dao.dart';
import '../../features/streaks/domain/streak_service.dart';
import '../../features/labels/data/label_dao.dart';
import '../../features/labels/domain/label_repository.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/notification_service.dart';
import '../health/health_service.dart';
import '../../features/habits/domain/garmin_ai_sync_service.dart';


@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (kIsWeb) return Future.value(true);

      final dbService = DatabaseService.instance;
      final habitDao = HabitDao(dbService);
      final checkInDao = CheckInDao(dbService);
      final streakDao = StreakDao(dbService);
      final labelDao = LabelDao(dbService);

      final activeHabits = await habitDao.getAllActive();
      if (activeHabits.isEmpty) return Future.value(true);

      final streakService = StreakService(streakDao);
      final checkInRepo = CheckInRepository(checkInDao, streakDao);
      final labelRepo = LabelRepository(labelDao, checkInRepo);

      final scheduler = NotificationScheduler(NotificationService.instance);

      final checkInService = CheckInService(checkInRepo, streakService, scheduler, labelRepo);
      final geminiNano = GeminiNanoService();
      final fetcher = GarminActivityFetcher();
      final healthService = HealthService();

      final syncService = GarminAiSyncService(dbService, geminiNano, fetcher, checkInService, healthService);

      await syncService.syncWorkoutsWithAi(activeHabits);

      return Future.value(true);
    } catch (e) {
      debugPrint('Background Garmin AI sync error: $e');
      return Future.value(false);
    }
  });
}

class BackgroundSyncManager {
  static const String taskName = 'com.habitapp.garmin_ai_sync';

  static Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      await Workmanager().registerPeriodicTask(
        '1',
        taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,

      );
    } catch (e) {
      debugPrint('Error initializing BackgroundSyncManager: $e');
    }
  }
}
