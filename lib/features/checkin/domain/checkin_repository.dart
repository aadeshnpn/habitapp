import '../data/checkin_model.dart';

// Abstract repository interface for check-in data operations
abstract class CheckInRepository {
  Future<List<CheckInModel>> getByHabit(String habitId);
  Future<void> save(CheckInModel checkIn);
  Future<void> delete(String id);
}
