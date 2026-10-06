import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A card displaying a single habit with streak info and a completion button.
class HabitCard extends StatefulWidget {
  final String habitId;
  final String name;
  final String icon;
  final int streakCount;
  final bool isCompleted;
  final bool isAutoLogged;
  final bool isAtRisk;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const HabitCard({
    super.key,
    required this.habitId,
    required this.name,
    required this.icon,
    required this.streakCount,
    required this.isCompleted,
    this.isAutoLogged = false,
    required this.isAtRisk,
    required this.accentColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<HabitCard> createState() => _HabitCardState();
}

class _HabitCardState extends State<HabitCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) {
      _scaleController.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;

    final borderColor =
        widget.isAtRisk ? const Color(0xFFFFC107) : Colors.transparent;
    final borderWidth = widget.isAtRisk ? 1.5 : 0.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        onLongPress: widget.onLongPress,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isCompleted ? 0.70 : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: borderWidth),
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
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Icon container
                  _IconContainer(
                    icon: widget.icon,
                    accentColor: widget.accentColor,
                  ),
                  const SizedBox(width: 14),
                  // Name + streak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.streakCount} day streak',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (widget.isAtRisk) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFC107).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'At risk',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFB8860B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (widget.isAutoLogged) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.auto_awesome, size: 10, color: widget.accentColor),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Auto',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: widget.accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Completion button
                  _CompletionButton(
                    isCompleted: widget.isCompleted,
                    accentColor: widget.accentColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  final String icon;
  final Color accentColor;

  const _IconContainer({required this.icon, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(icon, style: const TextStyle(fontSize: 24)),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  final bool isCompleted;
  final Color accentColor;

  const _CompletionButton({
    required this.isCompleted,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? accentColor : Colors.transparent,
        border: Border.all(
          color: isCompleted ? accentColor : Colors.grey.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: isCompleted
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}
