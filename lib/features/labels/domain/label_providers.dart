import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../habits/domain/habit_providers.dart';
import '../data/label_dao.dart';
import '../data/label_model.dart';
import 'label_repository.dart';

final labelDaoProvider = Provider<LabelDao>((ref) {
  return LabelDao(ref.watch(databaseServiceProvider));
});

final labelRepositoryProvider = Provider<LabelRepository>((ref) {
  return LabelRepository(
    ref.watch(labelDaoProvider),
    ref.watch(checkInRepositoryProvider),
  );
});

final allLabelsProvider = FutureProvider<List<HabitLabel>>((ref) {
  return ref.watch(labelRepositoryProvider).getAllLabels();
});

final labelStreakProvider =
    FutureProvider.family<LabelStreak?, String>((ref, labelId) async {
  return ref.watch(labelDaoProvider).getLabelStreak(labelId);
});

final labelCompletionMapProvider =
    FutureProvider.family<Map<DateTime, bool>, String>((ref, labelId) {
  return ref.watch(labelRepositoryProvider).getLabelCompletionMap(labelId);
});

final labelHabitIdsProvider =
    FutureProvider.family<List<String>, String>((ref, labelId) {
  return ref.watch(labelRepositoryProvider).getHabitsForLabel(labelId);
});
