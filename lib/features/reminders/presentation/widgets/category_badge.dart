import 'package:flutter/material.dart';
import '../../data/interval_reminder_model.dart';

/// A colored pill badge showing the reminder category.
class CategoryBadge extends StatelessWidget {
  final ReminderCategory category;
  final bool small;

  const CategoryBadge({super.key, required this.category, this.small = false});

  Color _bgColor(ReminderCategory cat) => switch (cat) {
        ReminderCategory.hydration => const Color(0xFF0277BD),
        ReminderCategory.medication => const Color(0xFF6A1B9A),
        ReminderCategory.nutrition => const Color(0xFF2E7D32),
        ReminderCategory.movement => const Color(0xFFE65100),
        ReminderCategory.custom => const Color(0xFF37474F),
      };

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(category);
    final fontSize = small ? 10.0 : 11.0;
    final hPad = small ? 7.0 : 9.0;
    final vPad = small ? 3.0 : 4.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.18),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: bg.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(category.emoji, style: TextStyle(fontSize: fontSize)),
          const SizedBox(width: 4),
          Text(
            category.label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: bg,
            ),
          ),
        ],
      ),
    );
  }
}
