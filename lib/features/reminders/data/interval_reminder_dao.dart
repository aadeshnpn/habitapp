import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_service.dart';
import 'interval_reminder_model.dart';

class IntervalReminderDao {
  final DatabaseService _db;

  const IntervalReminderDao(this._db);

  static const _remindersTable = 'interval_reminders';
  static const _checkInsTable = 'interval_check_ins';

  // ---------------------------------------------------------------------------
  // IntervalReminder CRUD
  // ---------------------------------------------------------------------------

  Future<List<IntervalReminder>> getAllActive() async {
    final db = await _db.database;
    final rows = await db.query(
      _remindersTable,
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC',
    );
    return rows.map(IntervalReminder.fromMap).toList();
  }

  Future<List<IntervalReminder>> getAll() async {
    final db = await _db.database;
    final rows = await db.query(_remindersTable, orderBy: 'created_at ASC');
    return rows.map(IntervalReminder.fromMap).toList();
  }

  Future<IntervalReminder?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      _remindersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return IntervalReminder.fromMap(rows.first);
  }

  Future<void> insert(IntervalReminder reminder) async {
    final db = await _db.database;
    await db.insert(
      _remindersTable,
      reminder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(IntervalReminder reminder) async {
    final db = await _db.database;
    await db.update(
      _remindersTable,
      reminder.toMap(),
      where: 'id = ?',
      whereArgs: [reminder.id],
    );
  }

  Future<void> deactivate(String id) async {
    final db = await _db.database;
    await db.update(
      _remindersTable,
      {'is_active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      _remindersTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------------------------------------------------------------------------
  // IntervalCheckIn operations
  // ---------------------------------------------------------------------------

  Future<void> insertCheckIn(IntervalCheckIn checkIn) async {
    final db = await _db.database;
    await db.insert(
      _checkInsTable,
      checkIn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all check-ins for [reminderId] on today's date (local time).
  Future<List<IntervalCheckIn>> getTodayCheckIns(String reminderId) async {
    final db = await _db.database;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final todayEnd =
        DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      _checkInsTable,
      where: 'reminder_id = ? AND logged_at >= ? AND logged_at <= ?',
      whereArgs: [reminderId, todayStart, todayEnd],
      orderBy: 'logged_at ASC',
    );
    return rows.map(IntervalCheckIn.fromMap).toList();
  }

  /// Count of check-ins for [reminderId] on today's date.
  Future<int> countTodayCheckIns(String reminderId) async {
    final checkIns = await getTodayCheckIns(reminderId);
    return checkIns.length;
  }

  /// Returns all check-ins for [reminderId] since [since].
  Future<List<IntervalCheckIn>> getCheckInsSince(
    String reminderId,
    DateTime since,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      _checkInsTable,
      where: 'reminder_id = ? AND logged_at >= ?',
      whereArgs: [reminderId, since.toIso8601String()],
      orderBy: 'logged_at DESC',
    );
    return rows.map(IntervalCheckIn.fromMap).toList();
  }

  /// Returns distinct dates (as "YYYY-MM-DD" strings) on which the reminder
  /// met its [targetCount] requirement.  Used for daily streak calculation.
  Future<Set<String>> getCompletedDays(
    String reminderId, {
    required int targetCount,
    int lookbackDays = 90,
  }) async {
    final db = await _db.database;
    final since = DateTime.now().subtract(Duration(days: lookbackDays));
    final rows = await db.rawQuery(
      '''
      SELECT date(logged_at) AS day, COUNT(*) AS cnt
      FROM $_checkInsTable
      WHERE reminder_id = ? AND logged_at >= ?
      GROUP BY date(logged_at)
      ''',
      [reminderId, since.toIso8601String()],
    );

    final completed = <String>{};
    for (final row in rows) {
      final day = row['day'] as String;
      final cnt = row['cnt'] as int;
      // targetCount == 0 means "at least one log counts as done"
      if (targetCount == 0 && cnt > 0) {
        completed.add(day);
      } else if (targetCount > 0 && cnt >= targetCount) {
        completed.add(day);
      }
    }
    return completed;
  }

  /// Returns check-ins for [reminderId] on a specific [date] (local midnight).
  Future<List<IntervalCheckIn>> getCheckInsOnDate(
    String reminderId,
    DateTime date,
  ) async {
    final db = await _db.database;
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd =
        DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();

    final rows = await db.query(
      _checkInsTable,
      where: 'reminder_id = ? AND logged_at >= ? AND logged_at <= ?',
      whereArgs: [reminderId, dayStart, dayEnd],
      orderBy: 'logged_at ASC',
    );
    return rows.map(IntervalCheckIn.fromMap).toList();
  }
}
