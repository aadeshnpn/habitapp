import 'package:uuid/uuid.dart';

import '../data/interval_reminder_dao.dart';
import '../data/interval_reminder_model.dart';
import '../../streaks/data/streak_dao.dart';
import '../../streaks/data/streak_model.dart';

class CreateIntervalReminderParams {
  final String? habitId;
  final String name;
  final String icon;
  final int color;
  final ReminderCategory category;
  final int intervalMinutes;
  final String windowStart; // "HH:MM"
  final String windowEnd; // "HH:MM"
  final int targetCount;

  const CreateIntervalReminderParams({
    this.habitId,
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
    required this.intervalMinutes,
    required this.windowStart,
    required this.windowEnd,
    this.targetCount = 0,
  });
}

class IntervalReminderRepository {
  final IntervalReminderDao _dao;
  final StreakDao _streakDao;

  static const _uuid = Uuid();

  const IntervalReminderRepository(this._dao, this._streakDao);

  // ---------------------------------------------------------------------------
  // Reminder CRUD
  // ---------------------------------------------------------------------------

  Future<List<IntervalReminder>> getActiveReminders() {
    return _dao.getAllActive();
  }

  Future<IntervalReminder?> getReminderById(String id) {
    return _dao.getById(id);
  }

  Future<IntervalReminder> createReminder(
      CreateIntervalReminderParams params) async {
    final reminder = IntervalReminder(
      id: _uuid.v4(),
      habitId: params.habitId,
      name: params.name,
      icon: params.icon,
      color: params.color,
      category: params.category,
      intervalMinutes: params.intervalMinutes,
      windowStart: params.windowStart,
      windowEnd: params.windowEnd,
      targetCount: params.targetCount,
      isActive: true,
      createdAt: DateTime.now(),
    );

    await _dao.insert(reminder);
    return reminder;
  }

  Future<void> updateReminder(IntervalReminder reminder) async {
    await _dao.update(reminder);
  }

  Future<void> deleteReminder(String id) async {
    await _dao.delete(id);
  }

  // ---------------------------------------------------------------------------
  // Check-in / logging
  // ---------------------------------------------------------------------------

  /// Log a single interval check-in for [reminderId].
  Future<IntervalCheckIn> logCheckIn(
    String reminderId, {
    String? note,
    double? quantity,
  }) async {
    final checkIn = IntervalCheckIn(
      id: _uuid.v4(),
      reminderId: reminderId,
      loggedAt: DateTime.now(),
      note: note,
      quantity: quantity,
    );

    await _dao.insertCheckIn(checkIn);
    return checkIn;
  }

  /// Number of times the user has logged the reminder today.
  Future<int> getTodayProgress(String reminderId) {
    return _dao.countTodayCheckIns(reminderId);
  }

  /// Full list of today's check-in objects (for the progress bar).
  Future<List<IntervalCheckIn>> getTodayCheckIns(String reminderId) {
    return _dao.getTodayCheckIns(reminderId);
  }

  // ---------------------------------------------------------------------------
  // Streak calculations (computed dynamically from interval check-ins)
  // ---------------------------------------------------------------------------

  /// Calculates dynamic streak data for this reminder based on completion records.
  Future<StreakData?> getStreak(String reminderId) async {
    final reminder = await _dao.getById(reminderId);
    if (reminder == null) return null;

    final target = reminder.targetCount > 0
        ? reminder.targetCount
        : reminder.dailySlotCount;
    final completedDays = await _dao.getCompletedDays(
      reminderId,
      targetCount: target,
      lookbackDays: 365,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);
    final yesterdayStr = _formatDate(today.subtract(const Duration(days: 1)));

    int currentStreak = 0;
    int bestStreak = 0;
    DateTime? checkDate;

    if (completedDays.contains(todayStr)) {
      checkDate = today;
    } else if (completedDays.contains(yesterdayStr)) {
      checkDate = today.subtract(const Duration(days: 1));
    }

    if (checkDate != null) {
      var current = checkDate;
      while (completedDays.contains(_formatDate(current))) {
        currentStreak++;
        current = current.subtract(const Duration(days: 1));
      }
    }

    final sortedDays = completedDays.toList()..sort();
    int tempStreak = 0;
    DateTime? prevDate;
    for (final dayStr in sortedDays) {
      final d = DateTime.parse(dayStr);
      if (prevDate == null || d.difference(prevDate).inDays == 1) {
        tempStreak++;
      } else {
        tempStreak = 1;
      }
      if (tempStreak > bestStreak) bestStreak = tempStreak;
      prevDate = d;
    }
    if (currentStreak > bestStreak) bestStreak = currentStreak;

    return StreakData(
      habitId: reminderId,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      totalCheckIns: completedDays.length,
      state: currentStreak > 0 ? StreakState.active : StreakState.broken,
    );
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Returns a map of date-string → bool for the last [days] days, indicating
  /// whether the reminder was completed on each day.
  Future<Map<DateTime, bool>> getCompletionMap(
    String reminderId, {
    int days = 90,
    required int targetCount,
  }) async {
    final completedDays =
        await _dao.getCompletedDays(reminderId, targetCount: targetCount);
    final result = <DateTime, bool>{};
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _formatDate(date);
      result[date] = completedDays.contains(key);
    }
    return result;
  }
}
