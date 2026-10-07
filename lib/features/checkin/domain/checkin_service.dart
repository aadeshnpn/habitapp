import '../../habits/data/habit_model.dart';
import '../../labels/domain/label_repository.dart';
import '../../streaks/data/streak_model.dart';
import '../../streaks/domain/streak_calculator.dart';
import '../../streaks/domain/streak_service.dart';
import '../../../core/notifications/notification_scheduler.dart';
import 'checkin_repository.dart';

/// Orchestrates the full check-in flow:
///   1. Records the check-in in the DB
///   2. Updates the streak via StreakService
///   3b. Updates label streaks for any labels assigned to this habit
///   3. Triggers notifications (cancel at-risk, send milestone if earned)
///   4. Returns a CheckInResult describing what happened
class CheckInService {
  final CheckInRepository _checkInRepo;
  final StreakService _streakService;
  final NotificationScheduler _scheduler;
  final LabelRepository _labelRepo;

  const CheckInService(
    this._checkInRepo,
    this._streakService,
    this._scheduler,
    this._labelRepo,
  );

  Future<CheckInResult> completeHabit({
    required Habit habit,
    required int habitIndex,
    String? note,
    double? quantity,
  }) async {
    // 1. Guard: already completed today?
    final alreadyDone = await _checkInRepo.isCompletedToday(habit.id);
    if (alreadyDone) {
      return CheckInResult(
        alreadyCompleted: true,
        streak: null,
        milestone: null,
      );
    }

    // 2. Record check-in
    await _checkInRepo.recordCheckIn(habit.id, note: note, quantity: quantity);

    // 3. Update streak
    final updatedStreak = await _streakService.onCheckIn(
      habitId: habit.id,
      checkInTime: DateTime.now(),
      frequencyType: habit.frequencyType,
      daysOfWeek: habit.daysOfWeek,
    );

    // 3b. Update label streaks for any labels assigned to this habit
    await _labelRepo.onHabitCheckIn(habit.id, DateTime.now());

    // 4. Detect milestone
    final milestone =
        StreakCalculator.getMilestoneTier(updatedStreak.currentStreak);

    // 5. Notify scheduler (stable IDs from habitId)
    await _scheduler.onCheckInCompleted(
      habitId: habit.id,
      habitName: habit.name,
      habitIcon: habit.icon,
      updatedStreak: updatedStreak,
      habitIndex: habitIndex,
    );

    return CheckInResult(
      alreadyCompleted: false,
      streak: updatedStreak,
      milestone: milestone,
    );
  }
}

class CheckInResult {
  final bool alreadyCompleted;
  final StreakData? streak;
  final MilestoneTier? milestone; // non-null = show celebration
  final bool isNewPersonalBest;

  CheckInResult({
    required this.alreadyCompleted,
    required this.streak,
    required this.milestone,
  }) : isNewPersonalBest = streak != null &&
            streak.currentStreak > 0 &&
            streak.currentStreak == streak.bestStreak &&
            streak.currentStreak > 1;
}
