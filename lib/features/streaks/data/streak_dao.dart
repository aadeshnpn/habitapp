import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_service.dart';
import 'streak_model.dart';

class StreakDao {
  final DatabaseService _db;

  const StreakDao(this._db);

  static const String _table = 'streak_data';

  Future<StreakData?> getForHabit(String habitId) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'habit_id = ?',
      whereArgs: [habitId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StreakData.fromMap(rows.first);
  }

  Future<void> upsert(StreakData data) async {
    final db = await _db.database;
    await db.insert(
      _table,
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> initForHabit(String habitId) async {
    final existing = await getForHabit(habitId);
    if (existing != null) return;

    await upsert(StreakData(habitId: habitId));
  }
}
