import 'package:uuid/uuid.dart';

import '../data/checkin_dao.dart';
import '../data/checkin_model.dart';
import '../../streaks/data/streak_dao.dart';
import '../../streaks/data/streak_model.dart';

class CheckInRepository {
  final CheckInDao _checkInDao;
  final StreakDao _streakDao;

  const CheckInRepository(this._checkInDao, this._streakDao);

  static const _uuid = Uuid();

  Future<CheckIn> recordCheckIn(
    String habitId, {
    String? note,
    double? quantity,
  }) async {
    final checkIn = CheckIn(
      id: _uuid.v4(),
      habitId: habitId,
      timestamp: DateTime.now(),
      note: note,
      quantity: quantity,
    );

    await _checkInDao.insert(checkIn);

    // Update streak counters.
    final existing = await _streakDao.getForHabit(habitId);
    if (existing != null) {
      final updated = _applyCheckIn(existing, checkIn.timestamp);
      await _streakDao.upsert(updated);
    }

    return checkIn;
  }

  Future<List<CheckIn>> getHistory(String habitId, {int days = 90}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    return _checkInDao.getForHabitSince(habitId, since);
  }

  Future<bool> isCompletedToday(String habitId) async {
    final checkIn = await _checkInDao.getTodayForHabit(habitId);
    return checkIn != null;
  }

  Future<Map<DateTime, bool>> getCompletionMap(
    String habitId, {
    int days = 90,
  }) async {
    final history = await getHistory(habitId, days: days);
    final Map<DateTime, bool> result = {};

    for (final checkIn in history) {
      final date = DateTime(
        checkIn.timestamp.year,
        checkIn.timestamp.month,
        checkIn.timestamp.day,
      );
      result[date] = true;
    }

    // Fill in missing days as false within the window.
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      result.putIfAbsent(date, () => false);
    }

    return result;
  }

  /// Minimal streak update applied at check-in time.
  /// Full streak recalculation lives in EPIC 8.
  StreakData _applyCheckIn(StreakData existing, DateTime timestamp) {
    final newTotal = existing.totalCheckIns + 1;
    final now = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final last = existing.lastCheckIn != null
        ? DateTime(
            existing.lastCheckIn!.year,
            existing.lastCheckIn!.month,
            existing.lastCheckIn!.day,
          )
        : null;

    int newCurrent = existing.currentStreak;
    if (last == null) {
      newCurrent = 1;
    } else {
      final diff = now.difference(last).inDays;
      if (diff == 1) {
        // Consecutive day.
        newCurrent = existing.currentStreak + 1;
      } else if (diff == 0) {
        // Same day, no change to streak count.
        newCurrent = existing.currentStreak;
      } else {
        // Gap — streak resets.
        newCurrent = 1;
      }
    }

    final newBest =
        newCurrent > existing.bestStreak ? newCurrent : existing.bestStreak;

    return existing.copyWith(
      currentStreak: newCurrent,
      bestStreak: newBest,
      totalCheckIns: newTotal,
      state: StreakState.active,
      lastCheckIn: timestamp,
    );
  }
}
