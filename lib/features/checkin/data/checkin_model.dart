// Placeholder model for CheckIn data
class CheckInModel {
  final String id;
  final String habitId;
  final DateTime date;
  final bool completed;

  const CheckInModel({
    required this.id,
    required this.habitId,
    required this.date,
    this.completed = false,
  });
}
