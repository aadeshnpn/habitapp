class CheckIn {
  final String id;
  final String habitId;
  final DateTime timestamp;
  final String? note;
  final double? quantity;

  const CheckIn({
    required this.id,
    required this.habitId,
    required this.timestamp,
    this.note,
    this.quantity,
  });

  CheckIn copyWith({
    String? id,
    String? habitId,
    DateTime? timestamp,
    String? note,
    double? quantity,
  }) {
    return CheckIn(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      timestamp: timestamp ?? this.timestamp,
      note: note ?? this.note,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'timestamp': timestamp.toIso8601String(),
      'note': note,
      'quantity': quantity,
    };
  }

  factory CheckIn.fromMap(Map<String, dynamic> map) {
    return CheckIn(
      id: map['id'] as String,
      habitId: map['habit_id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      note: map['note'] as String?,
      quantity: map['quantity'] != null ? (map['quantity'] as num).toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CheckIn &&
        other.id == id &&
        other.habitId == habitId &&
        other.timestamp == timestamp &&
        other.note == note &&
        other.quantity == quantity;
  }

  @override
  int get hashCode {
    return Object.hash(id, habitId, timestamp, note, quantity);
  }

  @override
  String toString() {
    return 'CheckIn(id: $id, habitId: $habitId, timestamp: $timestamp)';
  }
}
