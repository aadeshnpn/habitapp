// Placeholder model for Stats data
class StatsModel {
  final String habitId;
  final int totalCheckIns;
  final double completionRate;
  final int weeklyCount;

  const StatsModel({
    required this.habitId,
    this.totalCheckIns = 0,
    this.completionRate = 0.0,
    this.weeklyCount = 0,
  });
}
