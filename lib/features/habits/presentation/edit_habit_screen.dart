import 'package:flutter/material.dart';

class EditHabitScreen extends StatelessWidget {
  final String habitId;

  const EditHabitScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Habit')),
      body: Center(
        child: Text('EditHabitScreen — id: $habitId — placeholder'),
      ),
    );
  }
}
