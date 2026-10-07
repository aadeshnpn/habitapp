import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_service.dart';

class SyncedActivityItem {
  final String activityId;
  final String habitId;
  final String activityTitle;
  final String confidence;
  final String note;
  final DateTime processedAt;
  final String habitName;
  final String habitIcon;
  final int habitColor;

  SyncedActivityItem({
    required this.activityId,
    required this.habitId,
    required this.activityTitle,
    required this.confidence,
    required this.note,
    required this.processedAt,
    required this.habitName,
    required this.habitIcon,
    required this.habitColor,
  });
}

final syncedActivitiesProvider = FutureProvider<List<SyncedActivityItem>>((ref) async {
  final db = await DatabaseService.instance.database;

  final rows = await db.rawQuery('''
    SELECT 
      pa.activity_id,
      pa.habit_id,
      pa.activity_title,
      pa.confidence,
      pa.note,
      pa.processed_at,
      COALESCE(h.name, 'Archived / Unknown Habit') as habit_name,
      COALESCE(h.icon, '⚡') as habit_icon,
      COALESCE(h.color, 4282339765) as habit_color
    FROM processed_activities pa
    LEFT JOIN habits h ON pa.habit_id = h.id
    ORDER BY pa.processed_at DESC
  ''');

  return rows.map((r) {
    return SyncedActivityItem(
      activityId: r['activity_id'] as String? ?? '',
      habitId: r['habit_id'] as String? ?? '',
      activityTitle: r['activity_title'] as String? ?? 'Health Activity',
      confidence: r['confidence'] as String? ?? 'high',
      note: r['note'] as String? ?? '',
      processedAt: DateTime.tryParse(r['processed_at'] as String? ?? '') ?? DateTime.now(),
      habitName: r['habit_name'] as String? ?? 'Unknown Habit',
      habitIcon: r['habit_icon'] as String? ?? '⚡',
      habitColor: (r['habit_color'] as int?) ?? 0xFF4CAF50,
    );
  }).toList();
});
