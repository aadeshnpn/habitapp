


enum ReminderCategory { hydration, medication, nutrition, movement, custom }

extension ReminderCategoryX on ReminderCategory {
  String get label => switch (this) {
        ReminderCategory.hydration => 'Hydration',
        ReminderCategory.medication => 'Medication',
        ReminderCategory.nutrition => 'Nutrition',
        ReminderCategory.movement => 'Movement',
        ReminderCategory.custom => 'Custom',
      };

  String get emoji => switch (this) {
        ReminderCategory.hydration => '💧',
        ReminderCategory.medication => '💊',
        ReminderCategory.nutrition => '🍎',
        ReminderCategory.movement => '🚶',
        ReminderCategory.custom => '✏️',
      };
}

class IntervalReminder {
  final String id;
  final String? habitId; // optional link to a regular daily habit
  final String name;
  final String icon;
  final int color;
  final ReminderCategory category;
  final int intervalMinutes; // e.g. 240 = every 4 hours
  final String windowStart; // "HH:MM"
  final String windowEnd; // "HH:MM"
  final int targetCount; // 0 = unlimited (fire every interval); >0 = daily goal
  final bool isActive;
  final DateTime createdAt;

  const IntervalReminder({
    required this.id,
    this.habitId,
    required this.name,
    required this.icon,
    required this.color,
    required this.category,
    required this.intervalMinutes,
    required this.windowStart,
    required this.windowEnd,
    this.targetCount = 0,
    this.isActive = true,
    required this.createdAt,
  });

  /// Compute explicit fire times within the window for a given day.
  /// Returns a list of "HH:MM" strings.
  List<String> get dailySlots {
    final startParts = windowStart.split(':');
    final endParts = windowEnd.split(':');
    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    final slots = <String>[];
    int current = startMinutes;
    while (current <= endMinutes) {
      final h = (current ~/ 60).toString().padLeft(2, '0');
      final m = (current % 60).toString().padLeft(2, '0');
      slots.add('$h:$m');
      current += intervalMinutes;
    }
    return slots;
  }

  /// Number of intervals expected today (= length of dailySlots).
  int get dailySlotCount => dailySlots.length;

  IntervalReminder copyWith({
    String? id,
    Object? habitId = _sentinel,
    String? name,
    String? icon,
    int? color,
    ReminderCategory? category,
    int? intervalMinutes,
    String? windowStart,
    String? windowEnd,
    int? targetCount,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return IntervalReminder(
      id: id ?? this.id,
      habitId: habitId == _sentinel ? this.habitId : habitId as String?,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      category: category ?? this.category,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      windowStart: windowStart ?? this.windowStart,
      windowEnd: windowEnd ?? this.windowEnd,
      targetCount: targetCount ?? this.targetCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'name': name,
      'icon': icon,
      'color': color,
      'category': category.name,
      'interval_minutes': intervalMinutes,
      'window_start': windowStart,
      'window_end': windowEnd,
      'target_count': targetCount,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory IntervalReminder.fromMap(Map<String, dynamic> map) {
    return IntervalReminder(
      id: map['id'] as String,
      habitId: map['habit_id'] as String?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      category: ReminderCategory.values.byName(
          map['category'] as String? ?? 'hydration'),
      intervalMinutes: map['interval_minutes'] as int,
      windowStart: map['window_start'] as String,
      windowEnd: map['window_end'] as String,
      targetCount: map['target_count'] as int? ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IntervalReminder && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'IntervalReminder(id: $id, name: $name, every: ${intervalMinutes}min, '
      'window: $windowStart–$windowEnd)';
}

// ---------------------------------------------------------------------------
// IntervalCheckIn — a single log event for an interval reminder
// ---------------------------------------------------------------------------

class IntervalCheckIn {
  final String id;
  final String reminderId;
  final DateTime loggedAt;
  final String? note;
  final double? quantity;

  const IntervalCheckIn({
    required this.id,
    required this.reminderId,
    required this.loggedAt,
    this.note,
    this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reminder_id': reminderId,
      'logged_at': loggedAt.toIso8601String(),
      'note': note,
      'quantity': quantity,
    };
  }

  factory IntervalCheckIn.fromMap(Map<String, dynamic> map) {
    return IntervalCheckIn(
      id: map['id'] as String,
      reminderId: map['reminder_id'] as String,
      loggedAt: DateTime.parse(map['logged_at'] as String),
      note: map['note'] as String?,
      quantity:
          map['quantity'] != null ? (map['quantity'] as num).toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IntervalCheckIn && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// ignore: unused_element
const Object _sentinel = Object();
