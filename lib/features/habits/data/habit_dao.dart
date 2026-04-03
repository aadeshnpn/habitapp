import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_service.dart';
import 'habit_model.dart';

class HabitDao {
  final DatabaseService _db;

  const HabitDao(this._db);

  static const String _table = 'habits';

  Future<List<Habit>> getAllActive() async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'is_archived = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<List<Habit>> getAllArchived() async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'is_archived = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC',
    );
    return rows.map(Habit.fromMap).toList();
  }

  Future<Habit?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Habit.fromMap(rows.first);
  }

  Future<void> insert(Habit habit) async {
    final db = await _db.database;
    await db.insert(
      _table,
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> update(Habit habit) async {
    final db = await _db.database;
    await db.update(
      _table,
      habit.toMap(),
      where: 'id = ?',
      whereArgs: [habit.id],
    );
  }

  Future<void> archive(String id) async {
    final db = await _db.database;
    await db.update(
      _table,
      {'is_archived': 1},
      where: 'id = ?',
      whereArgs: [id],
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
