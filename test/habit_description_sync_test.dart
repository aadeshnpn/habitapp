import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/ai/gemini_nano_service.dart';
import 'package:habit_tracker/core/health/garmin_activity_fetcher.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';

Habit _habit({
  required String id,
  required String name,
  String? description,
}) {
  return Habit(
    id: id,
    name: name,
    description: description,
    icon: '🏃',
    color: 0xFF4CAF50,
    frequencyType: FrequencyType.daily,
    checkInType: CheckInType.tap,
    createdAt: DateTime(2026, 1, 1),
  );
}

GarminWorkout _workout({
  required String title,
  String activityType = 'OTHER',
}) {
  final now = DateTime(2026, 4, 1, 8);
  return GarminWorkout(
    id: 'w-$title',
    title: title,
    activityType: activityType,
    durationMinutes: 30,
    distanceKm: 0,
    calories: 100,
    startTime: now,
    endTime: now.add(const Duration(minutes: 30)),
  );
}

void main() {
  group('Habit description model', () {
    test('toMap/fromMap round-trips description', () {
      final habit = _habit(
        id: 'h1',
        name: 'Cardio',
        description: 'running, trail run',
      );
      final restored = Habit.fromMap(habit.toMap());
      expect(restored.description, 'running, trail run');
      expect(restored.matchText, 'Cardio running, trail run');
    });

    test('fromMap treats missing/blank description as null', () {
      final map = _habit(id: 'h1', name: 'Walk').toMap()
        ..remove('description');
      expect(Habit.fromMap(map).description, isNull);

      final blank = _habit(id: 'h1', name: 'Walk').toMap()
        ..['description'] = '   ';
      expect(Habit.fromMap(blank).description, isNull);
    });

    test('copyWith can set and clear description', () {
      final habit = _habit(id: 'h1', name: 'Walk', description: 'stroll');
      expect(habit.copyWith(description: 'hike').description, 'hike');
      expect(habit.copyWith(description: null).description, isNull);
      expect(habit.copyWith(name: 'Run').description, 'stroll');
    });
  });

  group('Health Connect matching via name + description', () {
    final service = GeminiNanoService();

    test('matches activity using keywords in habit description', () async {
      final habits = [
        _habit(
          id: 'cardio',
          name: 'Cardio',
          description: 'running, trail run, jogging',
        ),
        _habit(id: 'yoga', name: 'Yoga', description: 'stretch, flexibility'),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(title: 'Morning Trail Run', activityType: 'RUNNING'),
        activeHabits: habits,
      );

      expect(match, isNotNull);
      expect(match!.habitId, 'cardio');
    });

    test('matches when habit name alone is generic but description fits',
        () async {
      final habits = [
        _habit(
          id: 'move',
          name: 'Daily move',
          description: 'yoga, pilates',
        ),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(title: 'Evening Yoga', activityType: 'YOGA'),
        activeHabits: habits,
      );

      expect(match, isNotNull);
      expect(match!.habitId, 'move');
    });

    test('matches when activity title contains habit name', () async {
      final habits = [
        _habit(id: 'hike', name: 'Hiking'),
        _habit(id: 'gym', name: 'Gym'),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(title: 'Weekend Hiking', activityType: 'HIKING'),
        activeHabits: habits,
      );

      expect(match, isNotNull);
      expect(match!.habitId, 'hike');
    });

    test('category match still uses description when name has no keywords',
        () async {
      final habits = [
        _habit(
          id: 'fitness',
          name: 'Stay active',
          description: 'I go to the gym for strength training',
        ),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(
          title: 'Strength Training',
          activityType: 'STRENGTH_TRAINING',
        ),
        activeHabits: habits,
      );

      expect(match, isNotNull);
      expect(match!.habitId, 'fitness');
    });

    test('returns null when neither name nor description match', () async {
      final habits = [
        _habit(
          id: 'read',
          name: 'Read',
          description: 'fiction novels before bed',
        ),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(title: 'Open Water Swim', activityType: 'SWIMMING'),
        activeHabits: habits,
      );

      expect(match, isNull);
    });

    test('prefers description token match over unrelated habit', () async {
      final habits = [
        _habit(id: 'a', name: 'Habit A', description: 'swimming, pool'),
        _habit(id: 'b', name: 'Habit B', description: 'cycling, bike'),
      ];

      final match = await service.classifyWorkoutToHabit(
        workout: _workout(title: 'Pool Swim', activityType: 'SWIMMING'),
        activeHabits: habits,
      );

      expect(match, isNotNull);
      expect(match!.habitId, 'a');
    });
  });
}
