import 'package:flutter/material.dart';

/// Segmented progress bar showing N completed slots out of M total.
/// Each segment is a small pill that fills with the accent color when done.
class DailyProgressBar extends StatelessWidget {
  final int completed;
  final int total;
  final Color color;
  final double height;

  const DailyProgressBar({
    super.key,
    required this.completed,
    required this.total,
    required this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();
    final clampedDone = completed.clamp(0, total);
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;

    return Row(
      children: List.generate(total, (i) {
        final filled = i < clampedDone;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            height: height,
            margin: EdgeInsets.only(right: i < total - 1 ? 3 : 0),
            decoration: BoxDecoration(
              color: filled ? color : bg,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        );
      }),
    );
  }
}
