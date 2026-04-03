import '../../../core/database/database_service.dart';
import 'label_model.dart';

class LabelDao {
  final DatabaseService _db;

  const LabelDao(this._db);

  // ---------------------------------------------------------------------------
  // HabitLabel CRUD
  // ---------------------------------------------------------------------------

  Future<List<HabitLabel>> getAllLabels() async {
    final db = await _db.database;
    final rows = await db.query('habit_labels', orderBy: 'created_at ASC');
    return rows.map(HabitLabel.fromMap).toList();
  }

  Future<HabitLabel?> getById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'habit_labels',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return HabitLabel.fromMap(rows.first);
  }

  Future<void> insert(HabitLabel label) async {
    final db = await _db.database;
    await db.insert('habit_labels', label.toMap());
  }

  Future<void> update(HabitLabel label) async {
    final db = await _db.database;
    await db.update(
      'habit_labels',
      label.toMap(),
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('habit_labels', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Assignments
  // ---------------------------------------------------------------------------

  Future<List<String>> getLabelIdsForHabit(String habitId) async {
    final db = await _db.database;
    final rows = await db.query(
      'habit_label_assignments',
      columns: ['label_id'],
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    return rows.map((r) => r['label_id'] as String).toList();
  }

  Future<List<String>> getHabitIdsForLabel(String labelId) async {
    final db = await _db.database;
    final rows = await db.query(
      'habit_label_assignments',
      columns: ['habit_id'],
      where: 'label_id = ?',
      whereArgs: [labelId],
    );
    return rows.map((r) => r['habit_id'] as String).toList();
  }

  Future<void> assignLabelToHabit(String habitId, String labelId) async {
    final db = await _db.database;
    await db.insert(
      'habit_label_assignments',
      {'habit_id': habitId, 'label_id': labelId},
      conflictAlgorithm: 5, // ConflictAlgorithm.replace
    );
  }

  Future<void> removeLabelFromHabit(String habitId, String labelId) async {
    final db = await _db.database;
    await db.delete(
      'habit_label_assignments',
      where: 'habit_id = ? AND label_id = ?',
      whereArgs: [habitId, labelId],
    );
  }

  Future<void> setLabelsForHabit(
      String habitId, List<String> labelIds) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      // Delete all existing assignments for this habit
      await txn.delete(
        'habit_label_assignments',
        where: 'habit_id = ?',
        whereArgs: [habitId],
      );
      // Insert new ones
      for (final labelId in labelIds) {
        await txn.insert(
          'habit_label_assignments',
          {'habit_id': habitId, 'label_id': labelId},
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Label Streaks
  // ---------------------------------------------------------------------------

  Future<LabelStreak?> getLabelStreak(String labelId) async {
    final db = await _db.database;
    final rows = await db.query(
      'label_streaks',
      where: 'label_id = ?',
      whereArgs: [labelId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return LabelStreak.fromMap(rows.first);
  }

  Future<void> upsertLabelStreak(LabelStreak streak) async {
    final db = await _db.database;
    await db.insert(
      'label_streaks',
      streak.toMap(),
      conflictAlgorithm: 5, // ConflictAlgorithm.replace
    );
  }
}
