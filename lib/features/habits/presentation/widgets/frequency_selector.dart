import 'package:flutter/material.dart';

import '../../data/habit_model.dart';

class FrequencySelector extends StatelessWidget {
  final FrequencyType value;
  final List<int> selectedDays; // 1=Mon..7=Sun
  final int timesPerWeek;
  final ValueChanged<FrequencyType> onTypeChanged;
  final ValueChanged<List<int>> onDaysChanged;
  final ValueChanged<int> onTimesPerWeekChanged;

  const FrequencySelector({
    super.key,
    required this.value,
    required this.selectedDays,
    required this.timesPerWeek,
    required this.onTypeChanged,
    required this.onDaysChanged,
    required this.onTimesPerWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Frequency',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<FrequencyType>(
          segments: const [
            ButtonSegment(
              value: FrequencyType.daily,
              label: Text('Daily'),
              icon: Icon(Icons.repeat, size: 16),
            ),
            ButtonSegment(
              value: FrequencyType.daysOfWeek,
              label: Text('Days'),
              icon: Icon(Icons.calendar_view_week, size: 16),
            ),
            ButtonSegment(
              value: FrequencyType.timesPerWeek,
              label: Text('X/Week'),
              icon: Icon(Icons.format_list_numbered, size: 16),
            ),
          ],
          selected: {value},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              onTypeChanged(selection.first);
            }
          },
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(
              theme.textTheme.labelSmall,
            ),
          ),
        ),
        if (value == FrequencyType.daysOfWeek) ...[
          const SizedBox(height: 12),
          _DaysOfWeekPicker(
            selectedDays: selectedDays,
            onDaysChanged: onDaysChanged,
          ),
        ],
        if (value == FrequencyType.timesPerWeek) ...[
          const SizedBox(height: 12),
          _TimesPerWeekPicker(
            timesPerWeek: timesPerWeek,
            onTimesPerWeekChanged: onTimesPerWeekChanged,
          ),
        ],
      ],
    );
  }
}

class _DaysOfWeekPicker extends StatelessWidget {
  final List<int> selectedDays;
  final ValueChanged<List<int>> onDaysChanged;

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const _DaysOfWeekPicker({
    required this.selectedDays,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (i) {
        final dayNum = i + 1; // 1=Mon..7=Sun
        final isSelected = selectedDays.contains(dayNum);
        return FilterChip(
          label: Text(
            _dayLabels[i],
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            final updated = List<int>.from(selectedDays);
            if (selected) {
              updated.add(dayNum);
              updated.sort();
            } else {
              updated.remove(dayNum);
            }
            onDaysChanged(updated);
          },
          selectedColor: theme.colorScheme.primary,
          checkmarkColor: theme.colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }),
    );
  }
}

class _TimesPerWeekPicker extends StatelessWidget {
  final int timesPerWeek;
  final ValueChanged<int> onTimesPerWeekChanged;

  const _TimesPerWeekPicker({
    required this.timesPerWeek,
    required this.onTimesPerWeekChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effective = timesPerWeek < 1 ? 1 : timesPerWeek;

    return Row(
      children: [
        Text(
          'Times per week:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: effective > 1
              ? () => onTimesPerWeekChanged(effective - 1)
              : null,
          color: theme.colorScheme.primary,
          iconSize: 28,
        ),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$effective',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: effective < 7
              ? () => onTimesPerWeekChanged(effective + 1)
              : null,
          color: theme.colorScheme.primary,
          iconSize: 28,
        ),
      ],
    );
  }
}
