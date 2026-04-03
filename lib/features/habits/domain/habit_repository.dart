import '../data/habit_model.dart';

// Abstract repository interface for habit data operations
abstract class HabitRepository {
  Future<List<HabitModel>> getAll();
  Future<HabitModel?> getById(String id);
  Future<void> save(HabitModel habit);
  Future<void> delete(String id);
}
