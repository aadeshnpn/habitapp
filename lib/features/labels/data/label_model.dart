import 'package:flutter/foundation.dart';

import '../../streaks/data/streak_model.dart';

@immutable
class HabitLabel {
  final String id;
  final String name;
  final String emoji;
  final int color;
  final DateTime createdAt;

  const HabitLabel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.createdAt,
  });

  HabitLabel copyWith({
    String? id,
    String? name,
    String? emoji,
    int? color,
    DateTime? createdAt,
  }) {
    return HabitLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'color': color,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory HabitLabel.fromMap(Map<String, dynamic> map) {
    return HabitLabel(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String? ?? '🏷️',
      color: map['color'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HabitLabel &&
        other.id == id &&
        other.name == name &&
        other.emoji == emoji &&
        other.color == color &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, emoji, color, createdAt);
  }

  @override
  String toString() {
    return 'HabitLabel(id: $id, name: $name, emoji: $emoji)';
  }
}

@immutable
class LabelStreak {
  final String labelId;
  final int currentStreak;
  final int bestStreak;
  final int totalDays;
  final StreakState state;
  final DateTime? lastActiveDay;

  const LabelStreak({
    required this.labelId,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalDays = 0,
    this.state = StreakState.active,
    this.lastActiveDay,
  });

  factory LabelStreak.initial(String labelId) {
    return LabelStreak(
      labelId: labelId,
      currentStreak: 0,
      bestStreak: 0,
      totalDays: 0,
      state: StreakState.active,
      lastActiveDay: null,
    );
  }

  LabelStreak copyWith({
    String? labelId,
    int? currentStreak,
    int? bestStreak,
    int? totalDays,
    StreakState? state,
    Object? lastActiveDay = _sentinel,
  }) {
    return LabelStreak(
      labelId: labelId ?? this.labelId,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalDays: totalDays ?? this.totalDays,
      state: state ?? this.state,
      lastActiveDay: lastActiveDay == _sentinel
          ? this.lastActiveDay
          : lastActiveDay as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label_id': labelId,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'total_days': totalDays,
      'state': state.name,
      'last_active_day': lastActiveDay?.toIso8601String(),
    };
  }

  factory LabelStreak.fromMap(Map<String, dynamic> map) {
    return LabelStreak(
      labelId: map['label_id'] as String,
      currentStreak: map['current_streak'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      totalDays: map['total_days'] as int? ?? 0,
      state: StreakState.values.byName(map['state'] as String? ?? 'active'),
      lastActiveDay: map['last_active_day'] != null
          ? DateTime.parse(map['last_active_day'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LabelStreak &&
        other.labelId == labelId &&
        other.currentStreak == currentStreak &&
        other.bestStreak == bestStreak &&
        other.totalDays == totalDays &&
        other.state == state &&
        other.lastActiveDay == lastActiveDay;
  }

  @override
  int get hashCode {
    return Object.hash(
      labelId,
      currentStreak,
      bestStreak,
      totalDays,
      state,
      lastActiveDay,
    );
  }

  @override
  String toString() {
    return 'LabelStreak(labelId: $labelId, currentStreak: $currentStreak, '
        'bestStreak: $bestStreak, state: $state)';
  }
}

const Object _sentinel = Object();
