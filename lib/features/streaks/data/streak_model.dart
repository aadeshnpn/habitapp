import 'package:flutter/foundation.dart';

enum StreakState { active, atRisk, broken }

@immutable
class StreakData {
  final String habitId;
  final int currentStreak;
  final int bestStreak;
  final int totalCheckIns;
  final StreakState state;
  final DateTime? lastCheckIn;
  final int freezeTokens; // 0-3

  const StreakData({
    required this.habitId,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCheckIns = 0,
    this.state = StreakState.active,
    this.lastCheckIn,
    this.freezeTokens = 0,
  });

  /// Creates a brand-new streak record — all zeros, state = active.
  factory StreakData.initial(String habitId) {
    return StreakData(
      habitId: habitId,
      currentStreak: 0,
      bestStreak: 0,
      totalCheckIns: 0,
      state: StreakState.active,
      lastCheckIn: null,
      freezeTokens: 0,
    );
  }

  StreakData copyWith({
    String? habitId,
    int? currentStreak,
    int? bestStreak,
    int? totalCheckIns,
    StreakState? state,
    // Use a sentinel object so that passing null explicitly clears lastCheckIn.
    Object? lastCheckIn = _sentinel,
    int? freezeTokens,
  }) {
    return StreakData(
      habitId: habitId ?? this.habitId,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCheckIns: totalCheckIns ?? this.totalCheckIns,
      state: state ?? this.state,
      lastCheckIn: lastCheckIn == _sentinel
          ? this.lastCheckIn
          : lastCheckIn as DateTime?,
      freezeTokens: freezeTokens ?? this.freezeTokens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'habit_id': habitId,
      'current_streak': currentStreak,
      'best_streak': bestStreak,
      'total_check_ins': totalCheckIns,
      'state': state.name,
      'last_check_in': lastCheckIn?.toUtc().toIso8601String(),
      'freeze_tokens': freezeTokens,
    };
  }

  factory StreakData.fromMap(Map<String, dynamic> map) {
    return StreakData(
      habitId: map['habit_id'] as String,
      currentStreak: map['current_streak'] as int? ?? 0,
      bestStreak: map['best_streak'] as int? ?? 0,
      totalCheckIns: map['total_check_ins'] as int? ?? 0,
      state: StreakState.values.byName(map['state'] as String? ?? 'active'),
      lastCheckIn: map['last_check_in'] != null
          ? DateTime.parse(map['last_check_in'] as String).toLocal()
          : null,
      freezeTokens: map['freeze_tokens'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StreakData &&
        other.habitId == habitId &&
        other.currentStreak == currentStreak &&
        other.bestStreak == bestStreak &&
        other.totalCheckIns == totalCheckIns &&
        other.state == state &&
        other.lastCheckIn == lastCheckIn &&
        other.freezeTokens == freezeTokens;
  }

  @override
  int get hashCode {
    return Object.hash(
      habitId,
      currentStreak,
      bestStreak,
      totalCheckIns,
      state,
      lastCheckIn,
      freezeTokens,
    );
  }

  @override
  String toString() {
    return 'StreakData(habitId: $habitId, currentStreak: $currentStreak, '
        'bestStreak: $bestStreak, state: $state, freezeTokens: $freezeTokens)';
  }
}

// Private sentinel used in copyWith to distinguish "not provided" from null.
const Object _sentinel = Object();
