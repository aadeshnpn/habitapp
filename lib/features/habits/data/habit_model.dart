import 'dart:convert';

enum FrequencyType { daily, daysOfWeek, timesPerWeek }

enum CheckInType { tap, note, quantity }

/// Sentinel so [Habit.copyWith] can clear nullable [description].
const Object _unset = Object();

class Habit {
  final String id;
  final String name;
  /// Optional free-text used for UI and Health Connect activity matching.
  final String? description;
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
    this.description,
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

  /// Name + description text used when matching Health Connect activities.
  String get matchText {
    final desc = description?.trim();
    if (desc == null || desc.isEmpty) return name;
    return '$name $desc';
  }

  Habit copyWith({
    String? id,
    String? name,
    Object? description = _unset,
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
      description: identical(description, _unset)
          ? this.description
          : description as String?,
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
      'description': description,
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
    final rawDescription = map['description'] as String?;
    return Habit(
      id: map['id'] as String,
      name: map['name'] as String,
      description: (rawDescription == null || rawDescription.trim().isEmpty)
          ? null
          : rawDescription,
      icon: map['icon'] as String,
      color: map['color'] as int,
      frequencyType: FrequencyType.values.byName(map['frequency_type'] as String),
      daysOfWeek: () {
        try {
          return List<int>.from(
              jsonDecode(map['days_of_week'] as String? ?? '[]') as List);
        } catch (_) {
          return <int>[];
        }
      }(),
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
        other.description == description &&
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
      description,
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
    return 'Habit(id: $id, name: $name, description: $description, '
        'frequencyType: $frequencyType, checkInType: $checkInType, '
        'isArchived: $isArchived)';
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

