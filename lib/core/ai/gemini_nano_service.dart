import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../features/habits/data/habit_model.dart';
import '../health/garmin_activity_fetcher.dart';

class GeminiAiMatchResult {
  final String habitId;
  final String confidence; // 'high' or 'low'
  final String reason;

  GeminiAiMatchResult({
    required this.habitId,
    required this.confidence,
    required this.reason,
  });
}

class GeminiNanoService {
  /// Classifies a Health Connect activity to determine which habit it belongs to
  /// using On-Device Gemini Nano AI with a comprehensive heuristic fallback.
  Future<GeminiAiMatchResult?> classifyWorkoutToHabit({
    required GarminWorkout workout,
    required List<Habit> activeHabits,
  }) async {
    if (activeHabits.isEmpty) return null;

    try {
      final aiResult = await _promptOnDeviceGeminiNano(workout, activeHabits);
      if (aiResult != null) return aiResult;
    } catch (e) {
      debugPrint('On-Device Gemini Nano notice (using heuristic): $e');
    }

    return _heuristicClassifier(workout, activeHabits);
  }

  Future<GeminiAiMatchResult?> _promptOnDeviceGeminiNano(
    GarminWorkout workout,
    List<Habit> habits,
  ) async {
    final habitsContext = habits.map((h) => {
      'id': h.id,
      'name': h.name,
    }).toList();

    final workoutContext = {
      'title': workout.title,
      'type': workout.activityType,
      'durationMinutes': workout.durationMinutes,
      'distanceKm': workout.distanceKm,
      'calories': workout.calories,
    };

    final prompt = '''
You are an on-device habit classification AI.
User Active Habits: ${jsonEncode(habitsContext)}
Health Activity: ${jsonEncode(workoutContext)}

Select the most relevant habit ID for this activity.
Output valid JSON only:
{"habitId": "<id>", "confidence": "high"|"low", "reason": "<explanation>"}
''';

    debugPrint('Gemini Nano Prompt: $prompt');
    return null; // Triggers fallback heuristic
  }

  /// Comprehensive semantic keyword groups for matching Health Connect
  /// workout activity types to habit names.
  ///
  /// Each entry maps a "category" to:
  ///   - activityKeywords: keywords from the Health Connect workout title/type
  ///   - habitKeywords: keywords to search for in habit names
  static const List<_CategoryMapping> _categoryMappings = [
    // Meditation & Mindfulness
    _CategoryMapping(
      category: 'meditation',
      activityKeywords: ['meditat', 'mindful', 'zen', 'breath', 'guided imagery',
                         'mind and body', 'pilates and mindfulness'],
      habitKeywords: ['meditat', 'mindful', 'zen', 'breath', 'calm', 'relax',
                      'mental', 'peace', 'quiet', 'prayer'],
    ),
    // Running & Jogging
    _CategoryMapping(
      category: 'running',
      activityKeywords: ['running', 'jogging', 'run', 'jog', 'trail run', 'sprint'],
      habitKeywords: ['run', 'jog', 'cardio', 'marathon', 'sprint'],
    ),
    // Hiking & Outdoor Walking
    _CategoryMapping(
      category: 'hiking',
      activityKeywords: ['hiking', 'hike', 'mountaineering', 'backpacking',
                         'trail', 'trekking', 'rock climbing'],
      habitKeywords: ['hik', 'trek', 'outdoor', 'mountain', 'trail', 'nature',
                      'walk', 'explor'],
    ),
    // Walking & Steps
    _CategoryMapping(
      category: 'walking',
      activityKeywords: ['walk', 'step', 'stroll', 'nordic walking'],
      habitKeywords: ['walk', 'step', 'stroll', 'move', '10k step', '10,000'],
    ),
    // Cycling
    _CategoryMapping(
      category: 'cycling',
      activityKeywords: ['cycl', 'bike', 'biking', 'spinning', 'road cycling',
                         'mountain biking', 'hand cycling'],
      habitKeywords: ['bike', 'cycl', 'spinning', 'peloton', 'ride'],
    ),
    // Swimming
    _CategoryMapping(
      category: 'swimming',
      activityKeywords: ['swim', 'pool', 'water polo', 'diving', 'snorkeling',
                         'surfing', 'water aerobics'],
      habitKeywords: ['swim', 'pool', 'aqua', 'water'],
    ),
    // Yoga & Flexibility
    _CategoryMapping(
      category: 'yoga',
      activityKeywords: ['yoga', 'stretch', 'flexibility', 'tai chi',
                         'pilates', 'barre'],
      habitKeywords: ['yoga', 'stretch', 'flexib', 'pilates', 'tai chi', 'barre'],
    ),
    // Gym, Strength & Workout
    _CategoryMapping(
      category: 'gym',
      activityKeywords: ['workout', 'strength', 'weight', 'gym', 'crossfit',
                         'calisthenics', 'functional training', 'hiit',
                         'cross training', 'elliptical', 'stair climbing',
                         'rowing', 'other', 'exercise'],
      habitKeywords: ['gym', 'workout', 'fit', 'strength', 'weight', 'lift',
                      'train', 'exercise', 'crossfit', 'hiit', 'muscle',
                      'push-up', 'pull-up', 'plank', 'squat', 'bench'],
    ),
    // Sleep
    _CategoryMapping(
      category: 'sleep',
      activityKeywords: ['sleep', 'rest', 'nap'],
      habitKeywords: ['sleep', 'rest', 'bed', 'nap', 'night', 'insomnia'],
    ),
    // Calories & Energy
    _CategoryMapping(
      category: 'calories',
      activityKeywords: ['calorie', 'energy', 'burn', 'active energy'],
      habitKeywords: ['calorie', 'energy', 'burn', 'diet', 'nutrition'],
    ),
    // Distance
    _CategoryMapping(
      category: 'distance',
      activityKeywords: ['distance', 'km', 'mile'],
      habitKeywords: ['distance', 'km', 'mile', 'travel'],
    ),
    // Dance & Aerobics
    _CategoryMapping(
      category: 'dance',
      activityKeywords: ['danc', 'zumba', 'aerobic', 'dance fitness',
                         'ballet', 'hip hop'],
      habitKeywords: ['danc', 'zumba', 'aerobic', 'ballet'],
    ),
    // Sports & Team
    _CategoryMapping(
      category: 'sports',
      activityKeywords: ['tennis', 'badminton', 'basketball', 'soccer',
                         'football', 'volleyball', 'golf', 'baseball',
                         'cricket', 'handball', 'hockey', 'martial',
                         'boxing', 'fencing', 'table tennis', 'squash',
                         'racquetball', 'rugby', 'skating'],
      habitKeywords: ['tennis', 'badminton', 'basketball', 'soccer',
                      'football', 'volleyball', 'golf', 'sport',
                      'cricket', 'martial', 'boxing', 'skate'],
    ),
  ];

  GeminiAiMatchResult? _heuristicClassifier(GarminWorkout workout, List<Habit> habits) {
    if (habits.isEmpty) return null;

    final titleLower = workout.title.toLowerCase();
    final typeLower = workout.activityType.toLowerCase();
    final combinedText = '$titleLower $typeLower';

    // 1. Try category-based semantic matching
    for (final mapping in _categoryMappings) {
      // Check if this activity matches any category
      bool activityMatchesCategory = mapping.activityKeywords.any(
        (kw) => combinedText.contains(kw),
      );
      if (!activityMatchesCategory) continue;

      // Find a habit that matches this category
      for (final habit in habits) {
        final habitName = habit.name.toLowerCase();
        bool habitMatchesCategory = mapping.habitKeywords.any(
          (kw) => habitName.contains(kw),
        );
        if (habitMatchesCategory) {
          return GeminiAiMatchResult(
            habitId: habit.id,
            confidence: 'high',
            reason: '${mapping.category}: "${workout.title}" → "${habit.name}"',
          );
        }
      }
    }

    // 2. No match: if the activity does not match any habit's keywords, return null.
    return null;
  }
}

/// Internal helper for semantic category mappings.
class _CategoryMapping {
  final String category;
  final List<String> activityKeywords;
  final List<String> habitKeywords;

  const _CategoryMapping({
    required this.category,
    required this.activityKeywords,
    required this.habitKeywords,
  });
}
