import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_service.dart';
import 'checkin_model.dart';

class CheckInDao {
  final DatabaseService _db;

  const CheckInDao(this._db);

  static const String _table = 'check_ins';

  Future<List<CheckIn>> getForHabit(String habitId) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'timestamp DESC',
    );
    return rows.map(CheckIn.fromMap).toList();
  }

  Future<List<CheckIn>> getForHabitSince(String habitId, DateTime since) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'habit_id = ? AND timestamp >= ?',
      whereArgs: [habitId, since.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return rows.map(CheckIn.fromMap).toList();
  }

  Future<CheckIn?> getLatestForHabit(String habitId) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CheckIn.fromMap(rows.first);
  }

  Future<CheckIn?> getTodayForHabit(String habitId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'habit_id = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        habitId,
        startOfDay.toIso8601String(),
        endOfDay.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CheckIn.fromMap(rows.first);
  }

  Future<void> insert(CheckIn checkIn) async {
    final db = await _db.database;
    await db.insert(
      _table,
      checkIn.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete(
      _table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
