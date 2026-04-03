// Placeholder model for Habit data
class HabitModel {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;

  const HabitModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });
}
