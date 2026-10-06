import 'package:flutter/material.dart';
import 'package:habit_tracker/features/checkin/data/checkin_model.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/shared/widgets/empty_state.dart';
import 'package:habit_tracker/shared/widgets/progress_ring.dart';
import 'package:habit_tracker/shared/widgets/streak_counter.dart';

class RingsLayout extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, CheckIn> completedToday;
  final Map<String, int> streakCounts;
  final Set<String> atRiskHabits;
  final Function(String habitId) onComplete;
  final Function(String habitId) onTap;

  const RingsLayout({
    super.key,
    required this.habits,
    required this.completedToday,
    required this.streakCounts,
    required this.atRiskHabits,
    required this.onComplete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return EmptyStateWidget(
        emoji: '🌱',
        title: 'No habits yet',
        subtitle: 'Tap the + button to add your first habit and start building streaks.',
      );
    }

    // Incomplete first, completed last.
    final sorted = [...habits]..sort((a, b) {
        final aComplete = completedToday.containsKey(a.id) ? 1 : 0;
        final bComplete = completedToday.containsKey(b.id) ? 1 : 0;
        return aComplete.compareTo(bComplete);
      });

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 96),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final habit = sorted[index];
        final isCompleted = completedToday.containsKey(habit.id);
        final streak = streakCounts[habit.id] ?? 0;
        final accentColor = Color(habit.color);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () => onComplete(habit.id),
            onLongPress: () => onTap(habit.id),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: Theme.of(context).brightness == Brightness.dark
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // Large progress ring, tappable
                  ProgressRing(
                    progress: isCompleted ? 1.0 : 0.0,
                    size: 80,
                    strokeWidth: 8,
                    color: accentColor,
                    child: Text(
                      habit.icon,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Name + streak counter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          habit.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        StreakCounter(
                          count: streak,
                          color: accentColor,
                          fontSize: 16,
                        ),
                      ],
                    ),
                  ),
                  // Completion status indicator
                  if (isCompleted)
                    Icon(
                      Icons.check_circle_rounded,
                      color: accentColor,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
