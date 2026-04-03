import 'dart:convert';

enum FrequencyType { daily, daysOfWeek, timesPerWeek }

enum CheckInType { tap, note, quantity }

class Habit {
  final String id;
  final String name;
  final String icon;
  final int color;
  final FrequencyType frequencyType;
  final List<int> daysOfWeek;
  final int timesPerWeek;
  final CheckInType checkInType;
  final String? quantityUnit;
  final String? reminderTime;
  final bool isArchived;
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.frequencyType,
    this.daysOfWeek = const [],
    this.timesPerWeek = 0,
    required this.checkInType,
    this.quantityUnit,
    this.reminderTime,
    this.isArchived = false,
    required this.createdAt,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? icon,
    int? color,
    FrequencyType? frequencyType,
    List<int>? daysOfWeek,
    int? timesPerWeek,
    CheckInType? checkInType,
    String? quantityUnit,
    String? reminderTime,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      frequencyType: frequencyType ?? this.frequencyType,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      timesPerWeek: timesPerWeek ?? this.timesPerWeek,
      checkInType: checkInType ?? this.checkInType,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      reminderTime: reminderTime ?? this.reminderTime,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'frequency_type': frequencyType.name,
      'days_of_week': jsonEncode(daysOfWeek),
      'times_per_week': timesPerWeek,
      'check_in_type': checkInType.name,
      'quantity_unit': quantityUnit,
      'reminder_time': reminderTime,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: map['color'] as int,
      frequencyType: FrequencyType.values.byName(map['frequency_type'] as String),
      daysOfWeek: List<int>.from(jsonDecode(map['days_of_week'] as String? ?? '[]')),
      timesPerWeek: map['times_per_week'] as int? ?? 0,
      checkInType: CheckInType.values.byName(map['check_in_type'] as String? ?? 'tap'),
      quantityUnit: map['quantity_unit'] as String?,
      reminderTime: map['reminder_time'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Habit &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.color == color &&
        other.frequencyType == frequencyType &&
        _listEquals(other.daysOfWeek, daysOfWeek) &&
        other.timesPerWeek == timesPerWeek &&
        other.checkInType == checkInType &&
        other.quantityUnit == quantityUnit &&
        other.reminderTime == reminderTime &&
        other.isArchived == isArchived &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      icon,
      color,
      frequencyType,
      Object.hashAll(daysOfWeek),
      timesPerWeek,
      checkInType,
      quantityUnit,
      reminderTime,
      isArchived,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'Habit(id: $id, name: $name, frequencyType: $frequencyType, '
        'checkInType: $checkInType, isArchived: $isArchived)';
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
