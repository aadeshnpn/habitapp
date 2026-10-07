import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

class GarminWorkout {
  final String id;
  final String title;
  final String activityType;
  final double durationMinutes;
  final double distanceKm;
  final double calories;
  final DateTime startTime;
  final DateTime endTime;

  GarminWorkout({
    required this.id,
    required this.title,
    required this.activityType,
    required this.durationMinutes,
    required this.distanceKm,
    required this.calories,
    required this.startTime,
    required this.endTime,
  });

  String get summaryNote {
    final parts = <String>[];
    if (distanceKm > 0) parts.add('${distanceKm.toStringAsFixed(1)} km');
    if (durationMinutes > 0) parts.add('${durationMinutes.round()} mins');
    if (calories > 0) parts.add('${calories.round()} kcal');

    final details = parts.isNotEmpty ? ' (${parts.join(', ')})' : '';
    return '$title$details';
  }
}

class GarminActivityFetcher {
  final Health _health = Health();
  static String lastDiagnosticLog = 'No fetch attempted yet.';

  /// Android Health Connect supported data types only.
  /// We focus on WORKOUT (which includes hiking, running, meditation, yoga, etc.)
  /// and core metrics like STEPS, DISTANCE_DELTA, SLEEP_SESSION.
  /// HEART_RATE produces too many individual readings, so we skip it.
  static const List<HealthDataType> _androidTypes = [
    HealthDataType.WORKOUT,              // Exercise sessions (all activity types)
    HealthDataType.STEPS,                // Step count
    HealthDataType.DISTANCE_DELTA,       // Distance covered
    HealthDataType.ACTIVE_ENERGY_BURNED, // Active calories
    HealthDataType.SLEEP_SESSION,        // Sleep session
    HealthDataType.SLEEP_ASLEEP,         // Sleep stages
  ];

  /// Fetches health activities from Health Connect in the past [daysBack] days.
  Future<List<GarminWorkout>> fetchRecentWorkouts({int daysBack = 7}) async {
    if (kIsWeb) {
      lastDiagnosticLog = 'Web platform: Health Connect is not supported on Web.';
      return [];
    }

    final workouts = <GarminWorkout>[];
    final logBuffer = StringBuffer();

    final now = DateTime.now();
    final startTime = now.subtract(Duration(days: daysBack));
    logBuffer.writeln('=== Health Connect Data Fetch ===');
    logBuffer.writeln('Time: ${now.toIso8601String()}');
    logBuffer.writeln('Range: ${startTime.toIso8601String().substring(0, 10)} → ${now.toIso8601String().substring(0, 10)}');
    logBuffer.writeln('');

    for (var type in _androidTypes) {
      try {
        List<HealthDataPoint> points = await _health.getHealthDataFromTypes(
          startTime: startTime,
          endTime: now,
          types: [type],
        );

        logBuffer.writeln('✅ ${type.name}: ${points.length} records');

        for (var point in points) {
          final durationMins = point.dateTo.difference(point.dateFrom).inMinutes.toDouble();
          // Key the id on the session *window* (start + end) rather than the
          // data type.  A single 30-min run arrives as WORKOUT, STEPS,
          // DISTANCE_DELTA, and ACTIVE_ENERGY_BURNED — all with the same
          // dateFrom/dateTo — and must collapse to ONE id so we don't create
          // multiple processed_activities rows and check-ins for one event.
          final uniqueId =
              'hc_${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}';

          String activityTitle = 'Health Activity';
          double distance = 0.0;
          double calories = 0.0;

          if (type == HealthDataType.WORKOUT) {
            if (point.value is WorkoutHealthValue) {
              final workoutValue = point.value as WorkoutHealthValue;
              final rawName = workoutValue.workoutActivityType.name
                  .replaceAll('_', ' ')
                  .toLowerCase();

              // Capitalize each word
              activityTitle = rawName.split(' ').map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              }).join(' ');

              if (workoutValue.totalDistance != null) {
                distance = workoutValue.totalDistance!.toDouble() / 1000.0;
              }
              if (workoutValue.totalEnergyBurned != null) {
                calories = workoutValue.totalEnergyBurned!.toDouble();
              }

              logBuffer.writeln('   → $activityTitle (${durationMins.round()} min)');
            } else {
              activityTitle = 'Workout (${durationMins.round()} min)';
            }
          } else if (type == HealthDataType.STEPS) {
            int steps = 0;
            if (point.value is NumericHealthValue) {
              steps = (point.value as NumericHealthValue).numericValue.toInt();
            }
            if (steps < 100) continue;
            activityTitle = 'Steps ($steps)';
          } else if (type == HealthDataType.DISTANCE_DELTA) {
            if (point.value is NumericHealthValue) {
              distance = (point.value as NumericHealthValue).numericValue.toDouble() / 1000.0;
            }
            if (distance < 0.1) continue;
            activityTitle = 'Distance (${distance.toStringAsFixed(2)} km)';
          } else if (type == HealthDataType.ACTIVE_ENERGY_BURNED) {
            if (point.value is NumericHealthValue) {
              calories = (point.value as NumericHealthValue).numericValue.toDouble();
            }
            if (calories < 10) continue;
            activityTitle = 'Active Energy (${calories.round()} kcal)';
          } else if (type == HealthDataType.SLEEP_SESSION || type == HealthDataType.SLEEP_ASLEEP) {
            final sleepHours = durationMins / 60.0;
            if (sleepHours < 0.1) continue;
            activityTitle = 'Sleep (${sleepHours.toStringAsFixed(1)} hrs)';
          } else {
            continue;
          }

          workouts.add(
            GarminWorkout(
              id: uniqueId,
              title: activityTitle,
              activityType: point.type.name,
              durationMinutes: durationMins > 0 ? durationMins : 1.0,
              distanceKm: distance,
              calories: calories,
              startTime: point.dateFrom,
              endTime: point.dateTo,
            ),
          );
        }
      } catch (typeErr) {
        logBuffer.writeln('❌ ${type.name}: ERROR → $typeErr');
      }
    }

    // Filter workouts: keep ONLY the single latest activity per category/type.
    // Prevents loading dozens of repetitive walking/step sessions.
    final latestByType = <String, GarminWorkout>{};
    for (final w in workouts) {
      final key = _getCategoryKey(w);
      final existing = latestByType[key];
      if (existing == null || w.startTime.isAfter(existing.startTime)) {
        latestByType[key] = w;
      }
    }

    final finalWorkouts = latestByType.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    logBuffer.writeln('');
    logBuffer.writeln('Total raw activities: ${workouts.length} '
        '(${finalWorkouts.length} latest per type)');

    lastDiagnosticLog = logBuffer.toString();
    debugPrint('GarminActivityFetcher Diagnostic Log:\n$lastDiagnosticLog');
    return finalWorkouts;
  }

  /// Maps a workout to a broad category key to filter for the latest session per type.
  static String _getCategoryKey(GarminWorkout w) {
    final titleLower = w.title.toLowerCase();
    if (titleLower.contains('walk') || titleLower.contains('hike')) return 'walking';
    if (titleLower.contains('run') || titleLower.contains('jog')) return 'running';
    if (titleLower.contains('step')) return 'steps';
    if (titleLower.contains('sleep')) return 'sleep';
    if (titleLower.contains('cycl') || titleLower.contains('bike')) return 'cycling';
    if (titleLower.contains('swim')) return 'swimming';
    if (titleLower.contains('yoga') || titleLower.contains('stretch')) return 'yoga';
    if (titleLower.contains('meditat') || titleLower.contains('zen')) return 'meditation';
    if (titleLower.contains('distance')) return 'distance';
    if (titleLower.contains('active energy') || titleLower.contains('calorie')) return 'calories';
    return w.activityType.toLowerCase();
  }
}
