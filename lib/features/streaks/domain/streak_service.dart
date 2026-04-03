import '../data/streak_model.dart';

// Service interface for streak calculation logic
abstract class StreakService {
  Future<StreakModel> getStreak(String habitId);
  Future<StreakModel> recalculate(String habitId);
}
