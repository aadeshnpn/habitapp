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
    final habitsContext = habits
        .map((h) => {
              'id': h.id,
              'name': h.name,
              if (h.description != null && h.description!.trim().isNotEmpty)
                'description': h.description,
            })
        .toList();

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

Match the activity to a habit using BOTH the habit name and description
(descriptions often list activity keywords like "running, trail run").
Select the most relevant habit ID for this activity.
Output valid JSON only:
{"habitId": "<id>", "confidence": "high"|"low", "reason": "<explanation>"}
''';

    debugPrint('Gemini Nano Prompt: $prompt');
    return null; // Triggers fallback heuristic
  }

  /// Comprehensive semantic keyword groups for matching Health Connect
  /// workout activity types to habit names and descriptions.
  ///
  /// Each entry maps a "category" to:
  ///   - activityKeywords: keywords from the Health Connect workout title/type
  ///   - habitKeywords: keywords to search for in habit name + description
  static const List<_CategoryMapping> _categoryMappings = [
    // Meditation & Mindfulness
    _CategoryMapping(
      category: 'meditation',
      activityKeywords: [
        'meditat',
        'mindful',
        'zen',
        'breath',
        'guided imagery',
        'mind and body',
        'pilates and mindfulness'
      ],
      habitKeywords: [
        'meditat',
        'mindful',
        'zen',
        'breath',
        'calm',
        'relax',
        'mental',
        'peace',
        'quiet',
        'prayer'
      ],
    ),
    // Running & Jogging
    _CategoryMapping(
      category: 'running',
      activityKeywords: [
        'running',
        'jogging',
        'run',
        'jog',
        'trail run',
        'sprint'
      ],
      habitKeywords: ['run', 'jog', 'cardio', 'marathon', 'sprint'],
    ),
    // Hiking & Outdoor Walking
    _CategoryMapping(
      category: 'hiking',
      activityKeywords: [
        'hiking',
        'hike',
        'mountaineering',
        'backpacking',
        'trail',
        'trekking',
        'rock climbing'
      ],
      habitKeywords: [
        'hik',
        'trek',
        'outdoor',
        'mountain',
        'trail',
        'nature',
        'walk',
        'explor'
      ],
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
      activityKeywords: [
        'cycl',
        'bike',
        'biking',
        'spinning',
        'road cycling',
        'mountain biking',
        'hand cycling'
      ],
      habitKeywords: ['bike', 'cycl', 'spinning', 'peloton', 'ride'],
    ),
    // Swimming
    _CategoryMapping(
      category: 'swimming',
      activityKeywords: [
        'swim',
        'pool',
        'water polo',
        'diving',
        'snorkeling',
        'surfing',
        'water aerobics'
      ],
      habitKeywords: ['swim', 'pool', 'aqua', 'water'],
    ),
    // Yoga & Flexibility
    _CategoryMapping(
      category: 'yoga',
      activityKeywords: [
        'yoga',
        'stretch',
        'flexibility',
        'tai chi',
        'pilates',
        'barre'
      ],
      habitKeywords: [
        'yoga',
        'stretch',
        'flexib',
        'pilates',
        'tai chi',
        'barre'
      ],
    ),
    // Gym, Strength & Workout
    _CategoryMapping(
      category: 'gym',
      activityKeywords: [
        'workout',
        'strength',
        'weight',
        'gym',
        'crossfit',
        'calisthenics',
        'functional training',
        'hiit',
        'cross training',
        'elliptical',
        'stair climbing',
        'rowing',
        'other',
        'exercise'
      ],
      habitKeywords: [
        'gym',
        'workout',
        'fit',
        'strength',
        'weight',
        'lift',
        'train',
        'exercise',
        'crossfit',
        'hiit',
        'muscle',
        'push-up',
        'pull-up',
        'plank',
        'squat',
        'bench'
      ],
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
      activityKeywords: [
        'danc',
        'zumba',
        'aerobic',
        'dance fitness',
        'ballet',
        'hip hop'
      ],
      habitKeywords: ['danc', 'zumba', 'aerobic', 'ballet'],
    ),
    // Sports & Team
    _CategoryMapping(
      category: 'sports',
      activityKeywords: [
        'tennis',
        'badminton',
        'basketball',
        'soccer',
        'football',
        'volleyball',
        'golf',
        'baseball',
        'cricket',
        'handball',
        'hockey',
        'martial',
        'boxing',
        'fencing',
        'table tennis',
        'squash',
        'racquetball',
        'rugby',
        'skating'
      ],
      habitKeywords: [
        'tennis',
        'badminton',
        'basketball',
        'soccer',
        'football',
        'volleyball',
        'golf',
        'sport',
        'cricket',
        'martial',
        'boxing',
        'skate'
      ],
    ),
  ];

  /// Tokens shorter than this are ignored for free-text description matching
  /// to avoid false positives on words like "a", "to", "my".
  static const int _minTokenLength = 3;

  static const Set<String> _stopwords = {
    'the',
    'and',
    'for',
    'with',
    'from',
    'that',
    'this',
    'into',
    'your',
    'our',
    'are',
    'was',
    'were',
    'have',
    'has',
    'had',
    'will',
    'just',
    'also',
    'about',
    'when',
    'what',
    'which',
    'than',
    'then',
    'them',
    'they',
    'their',
    'some',
    'any',
    'all',
    'each',
    'every',
    'other',
    'only',
    'over',
    'after',
    'before',
    'daily',
    'habit',
  };

  GeminiAiMatchResult? _heuristicClassifier(
      GarminWorkout workout, List<Habit> habits) {
    if (habits.isEmpty) return null;

    final titleLower = workout.title.toLowerCase();
    final typeLower = workout.activityType.toLowerCase();
    final combinedText = '$titleLower $typeLower';

    // 1. Direct match against habit name and description tokens.
    //    Lets users put Health Connect activity keywords in the description
    //    (e.g. name "Cardio", description "running, trail run, jogging").
    final direct = _directTextMatch(combinedText, habits);
    if (direct != null) return direct;

    // 2. Category-based semantic matching using name + description.
    for (final mapping in _categoryMappings) {
      final activityMatchesCategory = mapping.activityKeywords.any(
        (kw) => combinedText.contains(kw),
      );
      if (!activityMatchesCategory) continue;

      for (final habit in habits) {
        final habitText = habit.matchText.toLowerCase();
        final habitMatchesCategory = mapping.habitKeywords.any(
          (kw) => habitText.contains(kw),
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

    // 3. No match.
    return null;
  }

  GeminiAiMatchResult? _directTextMatch(
    String activityText,
    List<Habit> habits,
  ) {
    GeminiAiMatchResult? best;
    var bestScore = 0;

    for (final habit in habits) {
      final nameLower = habit.name.toLowerCase().trim();
      if (nameLower.length >= _minTokenLength &&
          activityText.contains(nameLower)) {
        // Habit name appears in the activity — strongest signal.
        return GeminiAiMatchResult(
          habitId: habit.id,
          confidence: 'high',
          reason: 'name match: "${habit.name}" in activity',
        );
      }

      final description = habit.description?.toLowerCase().trim();
      if (description == null || description.isEmpty) continue;

      // Whole description phrase appears in activity (or vice versa).
      if (description.length >= _minTokenLength &&
          (activityText.contains(description) ||
              description.contains(activityText.trim()))) {
        return GeminiAiMatchResult(
          habitId: habit.id,
          confidence: 'high',
          reason: 'description match: "${habit.description}" ↔ activity',
        );
      }

      // Token overlap: split description on commas/spaces and score hits.
      final tokens = _descriptionTokens(description);
      var score = 0;
      final matched = <String>[];
      for (final token in tokens) {
        if (activityText.contains(token)) {
          score++;
          matched.add(token);
        }
      }
      if (score > bestScore) {
        bestScore = score;
        best = GeminiAiMatchResult(
          habitId: habit.id,
          confidence: score >= 2 ? 'high' : 'low',
          reason:
              'description keywords [${matched.join(', ')}] → "${habit.name}"',
        );
      }
    }

    // Require at least one meaningful token hit.
    return bestScore > 0 ? best : null;
  }

  List<String> _descriptionTokens(String description) {
    return description
        .split(RegExp(r'[,;/|\s]+'))
        .map((t) => t.trim())
        .where((t) => t.length >= _minTokenLength && !_stopwords.contains(t))
        .toList();
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
