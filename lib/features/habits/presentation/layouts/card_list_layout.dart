import 'package:flutter/material.dart';
import 'package:habit_tracker/features/checkin/data/checkin_model.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/shared/widgets/empty_state.dart';
import 'package:habit_tracker/shared/widgets/habit_card.dart';

class CardListLayout extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, CheckIn> completedToday;
  final Map<String, int> streakCounts;
  final Set<String> atRiskHabits;
  final Function(String habitId) onComplete;
  final Function(String habitId) onTap;

  const CardListLayout({
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
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final habit = sorted[index];
        final isCompleted = completedToday.containsKey(habit.id);
        final checkIn = completedToday[habit.id];
        final isAutoLogged = checkIn?.note?.contains('Auto-synced') == true || checkIn?.note?.contains('Linked to Health Activity') == true;
        final streak = streakCounts[habit.id] ?? 0;
        final isAtRisk = atRiskHabits.contains(habit.id);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: HabitCard(
            habitId: habit.id,
            name: habit.name,
            icon: habit.icon,
            streakCount: streak,
            isCompleted: isCompleted,
            isAutoLogged: isAutoLogged,
            isAtRisk: isAtRisk,
            accentColor: Color(habit.color),
            onTap: () => onComplete(habit.id),
            onLongPress: () => onTap(habit.id),
          ),
        );
      },
    );
  }
}
