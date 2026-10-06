import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/habits/data/habit_model.dart';
import '../../features/mindfulness_bell/domain/mindfulness_bell_config.dart';
import '../../features/mindfulness_bell/domain/mindfulness_bell_scheduler.dart';
import '../../features/reminders/data/interval_reminder_model.dart';
import '../../features/streaks/data/streak_model.dart';
import '../../features/streaks/domain/streak_calculator.dart';
import 'notification_ids.dart';
import 'notification_service.dart';

class NotificationScheduler {
  final NotificationServiceBase _service;

  const NotificationScheduler(this._service);

  // ---------------------------------------------------------------------------
  // Called after every check-in
  // ---------------------------------------------------------------------------

  /// Cancel the daily + at-risk alerts for this habit, and fire a milestone
  /// celebration if the updated streak sits on a milestone tier.
  Future<void> onCheckInCompleted({
    required String habitId,
    required String habitName,
    required String habitIcon,
    required StreakData updatedStreak,
    @Deprecated('Use habitId for stable notification IDs') int? habitIndex,
  }) async {
    await _service.cancelNotification(NotificationIds.daily(habitId));
    await _service.cancelNotification(NotificationIds.atRisk(habitId));

    final tier =
        StreakCalculator.getMilestoneTier(updatedStreak.currentStreak);
    if (tier != null) {
      final prefs = await SharedPreferences.getInstance();
      final milestoneEnabled = prefs.getBool('notif_milestone') ?? true;
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

  /// Cancel and reschedule every habit notification based on the current habit
  /// list and streak states. Respects user-level toggle preferences.
  Future<void> refreshAll(List<Habit> habits, List<StreakData> streaks,
      Set<String> completedToday) async {
    final prefs = await SharedPreferences.getInstance();
    final dailyEnabled = prefs.getBool('notif_daily') ?? true;
    final atRiskEnabled = prefs.getBool('notif_atrisk') ?? true;
    final repairEnabled = prefs.getBool('notif_repair') ?? true;

    final streakMap = {for (final s in streaks) s.habitId: s};

    for (final habit in habits) {
      final streak = streakMap[habit.id];

      if (dailyEnabled && habit.reminderTime != null) {
        final tod = NotificationScheduler._parseTimeOfDay(habit.reminderTime!);
        if (tod != null) {
          await _service.scheduleHabitReminder(
            habitId: habit.id,
            habitName: habit.name,
            habitIcon: habit.icon,
            time: tod,
            alreadyCompletedToday: completedToday.contains(habit.id),
          );
        }
      } else {
        await _service.cancelNotification(NotificationIds.daily(habit.id));
      }

      if (streak == null) continue;

      if (atRiskEnabled && streak.state == StreakState.atRisk) {
        await _service.scheduleStreakAtRiskAlert(
          habitId: habit.id,
          habitName: habit.name,
          streak: streak.currentStreak,
        );
      } else {
        await _service.cancelNotification(NotificationIds.atRisk(habit.id));
      }

      if (repairEnabled &&
          streak.state == StreakState.broken &&
          streak.freezeTokens > 0 &&
          streak.currentStreak > 0) {
        await _service.scheduleStreakRepairReminder(
          habitId: habit.id,
          habitName: habit.name,
          lostStreak: streak.currentStreak,
        );
      } else {
        await _service.cancelNotification(NotificationIds.repair(habit.id));
      }
    }
  }

  /// Schedule or cancel interval reminder notifications based on [reminders].
  Future<void> refreshIntervalReminders(
      List<IntervalReminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final intervalsEnabled = prefs.getBool('notif_intervals') ?? true;

    for (final reminder in reminders) {
      if (intervalsEnabled && reminder.isActive) {
        await _service.scheduleIntervalReminder(
          reminderId: reminder.id,
          reminderName: reminder.name,
          reminderIcon: reminder.icon,
          slots: reminder.dailySlots,
        );
      } else {
        await _service.cancelIntervalReminder(reminder.id);
      }
    }
  }

  /// Schedule or cancel mindfulness bell one-shots from [config].
  Future<void> refreshMindfulnessBell(MindfulnessBellConfig config) async {
    if (!config.enabled) {
      await _service.cancelMindfulnessBells();
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    final slots = MindfulnessBellScheduler.generateSlots(
      config: config,
      now: now,
    );
    await _service.scheduleMindfulnessBells(
      soundId: config.soundId,
      whenList: slots,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse a reminder_time string stored as "HH:MM" into a [TimeOfDay].
  @visibleForTesting
  static TimeOfDay? parseTimeOfDay(String timeStr) {
    return _parseTimeOfDay(timeStr);
  }

  static TimeOfDay? _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}
