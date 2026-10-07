import '../../checkin/domain/checkin_repository.dart';
import '../../habits/data/habit_model.dart';
import '../../streaks/data/streak_dao.dart';
import '../../streaks/data/streak_model.dart';

// ---------------------------------------------------------------------------
// Insight models
// ---------------------------------------------------------------------------

enum InsightType {
  neverMissedDay,
  nearPersonalBest,
  bestDayOfWeek,
  currentChampion,
  consistencyStreak,
}

class InsightCard {
  final String emoji;
  final String title;
  final String subtitle;
  final InsightType type;

  const InsightCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.type,
  });
}

// ---------------------------------------------------------------------------
// StatsService
// ---------------------------------------------------------------------------

class StatsService {
  final CheckInRepository _checkInRepo;
  final StreakDao _streakDao;

  const StatsService(this._checkInRepo, this._streakDao);

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Overall completion rate for all habits over the last 30 days (0.0–1.0).
  /// Returns 0.0 if there are no habits.
  Future<double> overallCompletionRate(List<Habit> habits) async {
    if (habits.isEmpty) return 0.0;

    double total = 0.0;
    for (final habit in habits) {
      total += await habitCompletionRate(habit.id, days: 30);
    }
    return total / habits.length;
  }

  /// Completion rate for a single habit over the last [days] days (0.0–1.0).
  Future<double> habitCompletionRate(String habitId, {int days = 30}) async {
    if (days == 0) return 0.0;
    final history = await _checkInRepo.getHistory(habitId, days: days);

    // Collect unique completed dates.
    final completedDates = <DateTime>{};
    for (final ci in history) {
      completedDates.add(
        DateTime(ci.timestamp.year, ci.timestamp.month, ci.timestamp.day),
      );
    }

    return (completedDates.length / days).clamp(0.0, 1.0);
  }

  /// Best (longest current) streak across all provided habits.
  /// Returns null when no streak data exists.
  Future<StreakData?> longestActiveStreak(List<Habit> habits) async {
    StreakData? best;
    for (final habit in habits) {
      final data = await _streakDao.getForHabit(habit.id);
      if (data == null) continue;
      if (best == null || data.currentStreak > best.currentStreak) {
        best = data;
      }
    }
    return best;
  }

  /// Day-of-week completion breakdown for a single habit over up to 90 days.
  /// Returns a map of weekday index → rate, where 1 = Monday … 7 = Sunday
  /// (matches [DateTime.weekday]).
  Future<Map<int, double>> dayOfWeekBreakdown(String habitId) async {
    return _weekdayBreakdownForDays(habitId, days: 90);
  }

  /// Generate insight cards based on habit history and streak data.
  Future<List<InsightCard>> generateInsights(List<Habit> habits) async {
    if (habits.isEmpty) return [];

    final insights = <InsightCard>[];

    // Per-habit completion rates over 30 days.
    final completionRates = <String, double>{};
    for (final habit in habits) {
      completionRates[habit.id] = await habitCompletionRate(habit.id, days: 30);
    }

    // -----------------------------------------------------------------------
    // "You've never missed a Monday" — 100% completion on some weekday over
    // the last 8 weeks (56 days).
    // -----------------------------------------------------------------------
    for (final habit in habits) {
      final breakdown = await _weekdayBreakdownForDays(habit.id, days: 56);
      for (final entry in breakdown.entries) {
        if (entry.value >= 1.0) {
          final dayName = _weekdayName(entry.key);
          insights.add(InsightCard(
            emoji: '🌟',
            title: "You've never missed a $dayName",
            subtitle: '${habit.name} has a perfect $dayName record!',
            type: InsightType.neverMissedDay,
          ));
          // Only one insight of this type per habit.
          break;
        }
      }
    }

    // -----------------------------------------------------------------------
    // "3 days from your longest streak!" — currentStreak >= bestStreak - 3
    // -----------------------------------------------------------------------
    for (final habit in habits) {
      final data = await _streakDao.getForHabit(habit.id);
      if (data == null) continue;
      final gap = data.bestStreak - data.currentStreak;
      if (gap > 0 && gap <= 3 && data.currentStreak > 0) {
        insights.add(InsightCard(
          emoji: '🔥',
          title: '$gap ${gap == 1 ? 'day' : 'days'} from your longest streak!',
          subtitle:
              '${habit.name}: current ${data.currentStreak}, best ${data.bestStreak}',
          type: InsightType.nearPersonalBest,
        ));
      }
    }

    // -----------------------------------------------------------------------
    // "Your best day is Wednesday" — highest day-of-week rate per habit.
    // -----------------------------------------------------------------------
    for (final habit in habits) {
      final breakdown = await dayOfWeekBreakdown(habit.id);
      if (breakdown.isEmpty) continue;
      final nonZero = breakdown.entries.where((e) => e.value > 0).toList();
      if (nonZero.isEmpty) continue;
      final best = nonZero.reduce((a, b) => a.value >= b.value ? a : b);
      final dayName = _weekdayName(best.key);
      final pct = (best.value * 100).round();
      insights.add(InsightCard(
        emoji: '📅',
        title: 'Your best day is $dayName',
        subtitle: '${habit.name}: $pct% completion on ${dayName}s',
        type: InsightType.bestDayOfWeek,
      ));
    }

    // -----------------------------------------------------------------------
    // "🏆 {habit} is your strongest habit" — highest 30-day completion rate.
    // -----------------------------------------------------------------------
    if (habits.length > 1 && completionRates.isNotEmpty) {
      final nonZeroRates =
          completionRates.entries.where((e) => e.value > 0).toList();
      if (nonZeroRates.isNotEmpty) {
        final best =
            nonZeroRates.reduce((a, b) => a.value >= b.value ? a : b);
        final habit = habits.firstWhere((h) => h.id == best.key);
        final pct = (best.value * 100).round();
        insights.add(InsightCard(
          emoji: '🏆',
          title: '${habit.name} is your strongest habit',
          subtitle: '$pct% completion rate this month',
          type: InsightType.currentChampion,
        ));
      }
    }

    // -----------------------------------------------------------------------
    // "You've completed {habit} {n} times" — milestone total completions.
    // -----------------------------------------------------------------------
    const milestones = [10, 25, 50, 100, 200, 500, 1000];
    for (final habit in habits) {
      final data = await _streakDao.getForHabit(habit.id);
      if (data == null) continue;
      final total = data.totalCheckIns;

      // Exact milestone hit.
      if (milestones.contains(total)) {
        insights.add(InsightCard(
          emoji: '🎉',
          title: "You've completed ${habit.name} $total times!",
          subtitle: 'Incredible consistency — keep it up!',
          type: InsightType.consistencyStreak,
        ));
        continue;
      }

      // Nearly at the next milestone (within 5).
      int? lastMilestone;
      for (final m in milestones) {
        if (total >= m) lastMilestone = m;
      }
      if (lastMilestone != null) {
        final nextIdx = milestones.indexOf(lastMilestone) + 1;
        if (nextIdx < milestones.length) {
          final next = milestones[nextIdx];
          final remaining = next - total;
          if (remaining <= 5) {
            insights.add(InsightCard(
              emoji: '🎉',
              title: '$remaining more to reach $next completions!',
              subtitle: '${habit.name} is at $total — almost there!',
              type: InsightType.consistencyStreak,
            ));
          }
        }
      }
    }

    return insights;
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<Map<int, double>> _weekdayBreakdownForDays(
    String habitId, {
    required int days,
  }) async {
    final history = await _checkInRepo.getHistory(habitId, days: days);

    final completedPerDay = <int, Set<DateTime>>{};
    for (final ci in history) {
      final date = DateTime(
        ci.timestamp.year,
        ci.timestamp.month,
        ci.timestamp.day,
      );
      completedPerDay.putIfAbsent(date.weekday, () => <DateTime>{}).add(date);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final occurrencesPerDay = <int, int>{};
    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      occurrencesPerDay[date.weekday] =
          (occurrencesPerDay[date.weekday] ?? 0) + 1;
    }

    final result = <int, double>{};
    for (int wd = 1; wd <= 7; wd++) {
      final total = occurrencesPerDay[wd] ?? 0;
      if (total == 0) {
        result[wd] = 0.0;
      } else {
        final completed = completedPerDay[wd]?.length ?? 0;
        result[wd] = completed / total;
      }
    }
    return result;
  }

  static String _weekdayName(int weekday) {
    const names = {
      1: 'Monday',
      2: 'Tuesday',
      3: 'Wednesday',
      4: 'Thursday',
      5: 'Friday',
      6: 'Saturday',
      7: 'Sunday',
    };
    return names[weekday] ?? 'Unknown';
  }
}
