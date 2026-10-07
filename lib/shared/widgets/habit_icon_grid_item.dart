import 'package:flutter/material.dart';

/// Square card used in the habit grid layout view.
///
/// When [isCompleted], the accent color fills the card background.
/// A small streak badge appears in the top-right corner.
class HabitIconGridItem extends StatelessWidget {
  final String name;
  final String icon;
  final Color accentColor;
  final bool isCompleted;
  final int streakCount;
  final VoidCallback onTap;

  const HabitIconGridItem({
    super.key,
    required this.name,
    required this.icon,
    required this.accentColor,
    required this.isCompleted,
    required this.streakCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isCompleted
        ? accentColor
        : (isDark ? const Color(0xFF1E1E1E) : Colors.white);

    final iconBgColor = isCompleted
        ? Colors.white.withOpacity(0.2)
        : accentColor.withOpacity(0.12);

    final nameFgColor = isCompleted
        ? Colors.white
        : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? const []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(icon,
                        style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(height: 8),
                  // Habit name
                  Text(
                    name,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: nameFgColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Streak badge (top-right)
            if (streakCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: _StreakBadge(
                  count: streakCount,
                  isCompleted: isCompleted,
                ),
              ),

            // Completion checkmark overlay (bottom-right)
            if (isCompleted)
              const Positioned(
                bottom: 8,
                right: 8,
                child: Icon(Icons.check_circle_rounded,
                    size: 18, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int count;
  final bool isCompleted;

  const _StreakBadge({required this.count, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.white.withOpacity(0.25)
            : Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 9)),
          const SizedBox(width: 2),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isCompleted ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
