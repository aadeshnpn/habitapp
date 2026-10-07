import 'package:flutter/material.dart';

/// Displays a streak count with a fire emoji.
/// Animates the count value using [AnimatedSwitcher] when it changes.
class StreakCounter extends StatelessWidget {
  final int count;
  final Color color;
  final double fontSize;

  const StreakCounter({
    super.key,
    required this.count,
    required this.color,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('🔥', style: TextStyle(fontSize: fontSize)),
        const SizedBox(width: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              )),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Text(
            '$count',
            key: ValueKey<int>(count),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
