/// Stable notification ID helpers.
///
/// Ranges (avoids collisions):
/// - Daily reminders:     1000–1899
/// - Streak at-risk:      2000–2899
/// - Streak repair:       3000–3899
/// - Milestone celebrate: 4000–4999
/// - Interval reminders:  5000–5899 (45 blocks × 20 slots)
/// - Mindfulness bell:    6000–6047
/// - Snooze:              9000–9999
class NotificationIds {
  NotificationIds._();

  static const maxSlotsPerReminder = 20;
  static const maxMindfulnessSlots = 48;
  static const _intervalBlocks = 45; // 5000..5899

  /// Maps an entity id to a stable slot in `0..899`.
  static int stableSlot(String id) => id.hashCode.abs() % 900;

  static int daily(String habitId) => 1000 + stableSlot(habitId);

  static int atRisk(String habitId) => 2000 + stableSlot(habitId);

  static int repair(String habitId) => 3000 + stableSlot(habitId);

  static int milestone(String habitName, int streak) =>
      4000 + (streak ^ habitName.hashCode).abs() % 1000;

  /// Base block for an interval reminder (multiples of [maxSlotsPerReminder]).
  static int intervalBlock(String reminderId) =>
      (reminderId.hashCode.abs() % _intervalBlocks) * maxSlotsPerReminder;

  static int intervalSlot(String reminderId, int slotIndex) =>
      5000 + intervalBlock(reminderId) + slotIndex;

  static int mindfulness(int slotIndex) => 6000 + slotIndex;

  static int snooze(int originalNotifId) => 9000 + (originalNotifId % 1000);
}
