// Placeholder model for Streak data
class StreakModel {
  final String habitId;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCheckIn;

  const StreakModel({
    required this.habitId,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCheckIn,
  });
}
