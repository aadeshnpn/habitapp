import 'package:uuid/uuid.dart';

import '../../checkin/domain/checkin_repository.dart';
import '../data/label_dao.dart';
import '../data/label_model.dart';
import 'label_streak_calculator.dart';

class LabelRepository {
  final LabelDao _dao;
  final CheckInRepository _checkInRepo;

  static const _uuid = Uuid();

  const LabelRepository(this._dao, this._checkInRepo);

  Future<List<HabitLabel>> getAllLabels() => _dao.getAllLabels();

  Future<HabitLabel?> getLabelById(String id) => _dao.getById(id);

  Future<HabitLabel> createLabel({
    required String name,
    required String emoji,
    required int color,
  }) async {
    final label = HabitLabel(
      id: _uuid.v4(),
      name: name,
      emoji: emoji,
      color: color,
      createdAt: DateTime.now(),
    );
    await _dao.insert(label);
    return label;
  }

  Future<void> updateLabel(HabitLabel label) => _dao.update(label);

  Future<void> deleteLabel(String id) => _dao.delete(id);

  Future<void> setHabitLabels(String habitId, List<String> labelIds) =>
      _dao.setLabelsForHabit(habitId, labelIds);

  Future<List<String>> getLabelsForHabit(String habitId) =>
      _dao.getLabelIdsForHabit(habitId);

  Future<List<String>> getHabitsForLabel(String labelId) =>
      _dao.getHabitIdsForLabel(labelId);

  /// Called after a habit check-in — updates all labels assigned to that habit.
  Future<List<LabelStreak>> onHabitCheckIn(
      String habitId, DateTime checkInTime) async {
    final labelIds = await _dao.getLabelIdsForHabit(habitId);
    final updatedStreaks = <LabelStreak>[];

    for (final labelId in labelIds) {
      final current =
          await _dao.getLabelStreak(labelId) ?? LabelStreak.initial(labelId);
      final updated = LabelStreakCalculator.recordActivity(
        current: current,
        today: checkInTime,
      );
      await _dao.upsertLabelStreak(updated);
      updatedStreaks.add(updated);
    }
    return updatedStreaks;
  }

  /// Get label streak for a given label.
  Future<LabelStreak?> getLabelStreak(String labelId) =>
      _dao.getLabelStreak(labelId);

  /// Get member habit completion map for heatmap.
  /// OR logic: any day at least one member habit was completed = true.
  Future<Map<DateTime, bool>> getLabelCompletionMap(String labelId,
      {int days = 90}) async {
    final habitIds = await _dao.getHabitIdsForLabel(labelId);
    final result = <DateTime, bool>{};
    final now = DateTime.now();

    // Pre-fill all days as false
    for (var i = 0; i < days; i++) {
      final day =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      result[day] = false;
    }

    // For each member habit, mark its check-in days as true
    for (final habitId in habitIds) {
      final checkIns = await _checkInRepo.getHistory(habitId, days: days);
      for (final ci in checkIns) {
        final day = DateTime(
          ci.timestamp.year,
          ci.timestamp.month,
          ci.timestamp.day,
        );
        if (result.containsKey(day)) result[day] = true;
      }
    }
    return result;
  }
}
