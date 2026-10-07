import 'package:uuid/uuid.dart';

import '../data/habit_dao.dart';
import '../data/habit_model.dart';
import '../../streaks/data/streak_dao.dart';

class CreateHabitParams {
  final String name;
  final String icon;
  final int color;
  final FrequencyType frequencyType;
  final List<int> daysOfWeek;
  final int timesPerWeek;
  final CheckInType checkInType;
  final String? quantityUnit;
  final String? reminderTime;

  const CreateHabitParams({
    required this.name,
    required this.icon,
    required this.color,
    required this.frequencyType,
    this.daysOfWeek = const [],
    this.timesPerWeek = 0,
    required this.checkInType,
    this.quantityUnit,
    this.reminderTime,
  });
}

class HabitRepository {
  final HabitDao _habitDao;
  final StreakDao _streakDao;

  const HabitRepository(this._habitDao, this._streakDao);

  static const _uuid = Uuid();

  Future<List<Habit>> getActiveHabits() async {
    return _habitDao.getAllActive();
  }

  Future<List<Habit>> getArchivedHabits() async {
    return _habitDao.getAllArchived();
  }

  Future<Habit?> getHabitById(String id) async {
    return _habitDao.getById(id);
  }

  Future<Habit> createHabit(CreateHabitParams params) async {
    final habit = Habit(
      id: _uuid.v4(),
      name: params.name,
      icon: params.icon,
      color: params.color,
      frequencyType: params.frequencyType,
      daysOfWeek: params.daysOfWeek,
      timesPerWeek: params.timesPerWeek,
      checkInType: params.checkInType,
      quantityUnit: params.quantityUnit,
      reminderTime: params.reminderTime,
      isArchived: false,
      createdAt: DateTime.now(),
    );

    await _habitDao.insert(habit);
    await _streakDao.initForHabit(habit.id);

    return habit;
  }


  Future<void> updateHabit(Habit habit) async {
    await _habitDao.update(habit);
  }

  Future<void> archiveHabit(String id) async {
    await _habitDao.archive(id);
  }

  Future<void> deleteHabit(String id) async {
    await _habitDao.delete(id);
  }
}
