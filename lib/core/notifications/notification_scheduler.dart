import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/habits/data/habit_model.dart';
import '../../features/streaks/data/streak_model.dart';
import '../../features/streaks/domain/streak_calculator.dart';
import 'notification_service.dart';

class NotificationScheduler {
  final NotificationService _service;

  const NotificationScheduler(this._service);

  // ---------------------------------------------------------------------------
  // Called after every check-in
  // ---------------------------------------------------------------------------

  /// Cancel the at-risk alert for this habit, and fire a milestone celebration
  /// if the updated streak sits on a milestone tier.
  Future<void> onCheckInCompleted({
    required int habitIndex,
    required String habitId,
    required String habitName,
    required String habitIcon,
    required StreakData updatedStreak,
  }) async {
    // Always cancel the at-risk notification — the habit has been completed.
    await _service.cancelNotification(2000 + habitIndex);

    // Fire milestone if this streak lands on a celebrated tier.
    final tier =
        StreakCalculator.getMilestoneTier(updatedStreak.currentStreak);
    if (tier != null) {
      final prefs = await SharedPreferences.getInstance();
      final milestoneEnabled =
          prefs.getBool('notif_milestone') ?? true;
      if (milestoneEnabled) {
        await _service.sendMilestoneCelebration(
          habitName: habitName,
          streak: updatedStreak.currentStreak,
          habitIcon: habitIcon,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Called on app open — refresh all scheduled notifications from scratch
  // ---------------------------------------------------------------------------

  /// Cancel and reschedule every notification based on the current habit list
  /// and streak states. Respects user-level toggle preferences stored in
  /// SharedPreferences.
  Future<void> refreshAll(
      List<Habit> habits, List<StreakData> streaks) async {
    final prefs = await SharedPreferences.getInstance();
    final dailyEnabled = prefs.getBool('notif_daily') ?? true;
    final atRiskEnabled = prefs.getBool('notif_atrisk') ?? true;
    final repairEnabled = prefs.getBool('notif_repair') ?? true;

    // Build a fast lookup: habitId -> StreakData
    final streakMap = {for (final s in streaks) s.habitId: s};

    for (var i = 0; i < habits.length; i++) {
      final habit = habits[i];
      final streak = streakMap[habit.id];

      // --- Daily reminder ---
      if (dailyEnabled && habit.reminderTime != null) {
        final tod = _parseTimeOfDay(habit.reminderTime!);
        if (tod != null) {
          await _service.scheduleHabitReminder(
            index: i,
            habitId: habit.id,
            habitName: habit.name,
            habitIcon: habit.icon,
            time: tod,
          );
        }
      } else {
        // Reminder time cleared or toggle off — cancel existing.
        await _service.cancelNotification(1000 + i);
      }

      if (streak == null) continue;

      // --- Streak at-risk alert ---
      if (atRiskEnabled && streak.state == StreakState.atRisk) {
        await _service.scheduleStreakAtRiskAlert(
          index: i,
          habitId: habit.id,
          habitName: habit.name,
          streak: streak.currentStreak,
        );
      } else {
        await _service.cancelNotification(2000 + i);
      }

      // --- Streak repair reminder ---
      if (repairEnabled &&
          streak.state == StreakState.broken &&
          streak.freezeTokens > 0 &&
          streak.currentStreak > 0) {
        await _service.scheduleStreakRepairReminder(
          index: i,
          habitId: habit.id,
          habitName: habit.name,
          lostStreak: streak.currentStreak,
        );
      } else {
        await _service.cancelNotification(3000 + i);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a reminder_time string stored as "HH:MM" into a [TimeOfDay].
  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
