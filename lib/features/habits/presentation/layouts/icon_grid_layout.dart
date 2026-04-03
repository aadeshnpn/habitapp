import 'package:flutter/material.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/shared/widgets/empty_state.dart';
import 'package:habit_tracker/shared/widgets/habit_icon_grid_item.dart';

class IconGridLayout extends StatelessWidget {
  final List<Habit> habits;
  final Set<String> completedToday;
  final Map<String, int> streakCounts;
  final Set<String> atRiskHabits;
  final Function(String habitId) onComplete;
  final Function(String habitId) onTap;

  const IconGridLayout({
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
        final aComplete = completedToday.contains(a.id) ? 1 : 0;
        final bComplete = completedToday.contains(b.id) ? 1 : 0;
        return aComplete.compareTo(bComplete);
      });

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final habit = sorted[index];
        final isCompleted = completedToday.contains(habit.id);
        final streak = streakCounts[habit.id] ?? 0;

        return HabitIconGridItem(
          name: habit.name,
          icon: habit.icon,
          accentColor: Color(habit.color),
          isCompleted: isCompleted,
          streakCount: streak,
          onTap: () => onComplete(habit.id),
        );
      },
    );
  }
}
