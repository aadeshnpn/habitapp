import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/ai/gemini_nano_service.dart';
import '../../../core/database/database_service.dart';
import '../../../core/health/garmin_activity_fetcher.dart';
import '../../checkin/domain/checkin_service.dart';
import '../../../core/health/health_service.dart';
import '../data/habit_model.dart';
import 'habit_providers.dart';




final geminiNanoServiceProvider = Provider<GeminiNanoService>((ref) => GeminiNanoService());
final garminActivityFetcherProvider = Provider<GarminActivityFetcher>((ref) => GarminActivityFetcher());

class GarminAiSyncResult {
  final int workoutsProcessed;
  final List<String> matchedHabitNames;

  GarminAiSyncResult({
    required this.workoutsProcessed,
    required this.matchedHabitNames,
  });
}

class GarminAiSyncService {
  final DatabaseService _dbService;
  final GeminiNanoService _geminiNano;
  final GarminActivityFetcher _fetcher;
  final CheckInService _checkInService;
  final HealthService _healthService;

  GarminAiSyncService(
    this._dbService,
    this._geminiNano,
    this._fetcher,
    this._checkInService,
    this._healthService,
  );

  /// Synchronize recent Garmin workouts with On-Device Gemini Nano habit classification.
  Future<GarminAiSyncResult> syncWorkoutsWithAi(List<Habit> activeHabits) async {
    if (activeHabits.isEmpty) {
      return GarminAiSyncResult(workoutsProcessed: 0, matchedHabitNames: []);
    }

    // Ensure permissions are requested
    await _healthService.requestPermissions();

    final db = await _dbService.database;


    // Fetch processed activity IDs
    final processedRows = await db.query('processed_activities', columns: ['activity_id']);
    final processedIds = processedRows.map((r) => r['activity_id'] as String).toSet();

    // Fetch workouts from Health Connect / Apple Health
    final workouts = await _fetcher.fetchRecentWorkouts();
    final newWorkouts = workouts.where((w) => !processedIds.contains(w.id)).toList();

    if (newWorkouts.isEmpty) {
      return GarminAiSyncResult(workoutsProcessed: 0, matchedHabitNames: []);
    }

    int processedCount = 0;
    final matchedNames = <String>[];

    for (final workout in newWorkouts) {
      try {
        final match = await _geminiNano.classifyWorkoutToHabit(
          workout: workout,
          activeHabits: activeHabits,
        );

        if (match != null) {
          // Find target habit
          final targetHabitIndex = activeHabits.indexWhere((h) => h.id == match.habitId);
          if (targetHabitIndex != -1) {
            final targetHabit = activeHabits[targetHabitIndex];

            // Formulate attribution note
            final confidenceTag = match.confidence == 'low' ? ' [AI Confidence: Low]' : '';
            final attributionNote = 'Linked to Health Activity: ${workout.summaryNote}$confidenceTag';

            // ── BUG 6 FIX: claim the guard row BEFORE calling completeHabit ──
            // Two sync arms (background Workmanager + manual) can race.
            // By inserting the processed_activities row first with
            // ConflictAlgorithm.ignore, only the arm that wins the SQLite
            // INSERT (rowId != 0) proceeds to record the check-in.  The
            // losing arm gets rowId == 0 and skips completeHabit entirely,
            // preventing duplicate check-ins.
            final rowId = await db.insert(
              'processed_activities',
              {
                'activity_id': workout.id,
                'habit_id': targetHabit.id,
                'activity_title': workout.title,
                'confidence': match.confidence,
                'note': attributionNote,
                'processed_at': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            if (rowId != 0) {
              // We won the claim — record the check-in.
              final result = await _checkInService.completeHabit(
                habit: targetHabit,
                habitIndex: targetHabitIndex,
                quantity: workout.durationMinutes > 0 ? workout.durationMinutes : 1.0,
                note: attributionNote,
              );

              if (!result.alreadyCompleted) {
                matchedNames.add(targetHabit.name);
              }
              processedCount++;
            }
          }
        }
      } catch (e) {
        debugPrint('Error syncing workout "${workout.title}": $e');
      }
    }


    return GarminAiSyncResult(
      workoutsProcessed: processedCount,
      matchedHabitNames: matchedNames,
    );
  }
}

final garminAiSyncServiceProvider = Provider<GarminAiSyncService>((ref) {
  return GarminAiSyncService(
    ref.watch(databaseServiceProvider),
    ref.watch(geminiNanoServiceProvider),
    ref.watch(garminActivityFetcherProvider),
    ref.watch(checkInServiceProvider),
    ref.watch(healthServiceProvider),
  );
});


final triggerGarminAiSyncProvider = FutureProvider<GarminAiSyncResult>((ref) async {
  final activeHabits = await ref.watch(activeHabitsProvider.future);
  final syncService = ref.read(garminAiSyncServiceProvider);
  final result = await syncService.syncWorkoutsWithAi(activeHabits);
  if (result.workoutsProcessed > 0) {
    ref.invalidate(activeHabitsProvider);
  }
  return result;
});
