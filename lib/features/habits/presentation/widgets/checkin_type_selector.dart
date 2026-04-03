import 'package:flutter/material.dart';

import '../../data/habit_model.dart';

class CheckInTypeSelector extends StatelessWidget {
  final CheckInType value;
  final String? quantityUnit;
  final ValueChanged<CheckInType> onTypeChanged;
  final ValueChanged<String?> onUnitChanged;

  const CheckInTypeSelector({
    super.key,
    required this.value,
    required this.quantityUnit,
    required this.onTypeChanged,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Check-in type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<CheckInType>(
          segments: const [
            ButtonSegment(
              value: CheckInType.tap,
              label: Text('Tap'),
              icon: Icon(Icons.touch_app, size: 16),
            ),
            ButtonSegment(
              value: CheckInType.note,
              label: Text('Note'),
              icon: Icon(Icons.note_alt_outlined, size: 16),
            ),
            ButtonSegment(
              value: CheckInType.quantity,
              label: Text('Quantity'),
              icon: Icon(Icons.123, size: 16),
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
        if (value == CheckInType.quantity) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: quantityUnit,
            decoration: InputDecoration(
              labelText: 'Unit label',
              hintText: 'e.g. miles, glasses, pages',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.straighten_outlined),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (val) => onUnitChanged(val.trim().isEmpty ? null : val.trim()),
          ),
        ],
      ],
    );
  }
}
