import '../data/stats_model.dart';

// Service interface for statistics aggregation
abstract class StatsService {
  Future<StatsModel> getStats(String habitId);
  Future<List<StatsModel>> getAllStats();
}
