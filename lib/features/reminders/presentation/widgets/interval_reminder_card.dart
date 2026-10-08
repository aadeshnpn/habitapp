import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/interval_reminder_model.dart';
import '../../domain/interval_reminder_providers.dart';
import 'category_badge.dart';
import 'daily_progress_bar.dart';

class IntervalReminderCard extends ConsumerWidget {
  final IntervalReminder reminder;
  final VoidCallback onLogTap;
  final VoidCallback onTap;

  const IntervalReminderCard({
    super.key,
    required this.reminder,
    required this.onLogTap,
    required this.onTap,
  });

  Color get _accentColor => Color(reminder.color);

  String _intervalLabel() {
    final minutes = reminder.intervalMinutes;
    if (minutes < 60) return 'Every ${minutes}min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    if (rem == 0) return 'Every ${hours}h';
    return 'Every ${hours}h ${rem}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(todayProgressProvider(reminder.id));
    final totalSlots = reminder.dailySlotCount;
    final effectiveTarget =
        reminder.targetCount > 0 ? reminder.targetCount : totalSlots;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon circle
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _accentColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _accentColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(reminder.icon,
                        style: const TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  // Name + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule,
                                size: 13,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${_intervalLabel()} · ${reminder.windowStart}–${reminder.windowEnd}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        CategoryBadge(category: reminder.category, small: true),
                      ],
                    ),
                  ),
                  // Log button
                  _LogButton(
                    color: _accentColor,
                    onTap: onLogTap,
                  ),
                ],
              ),
            ),
            // Progress bar section
            progressAsync.when(
              data: (count) {
                final isDone = count >= effectiveTarget;
                return Container(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DailyProgressBar(
                              completed: count,
                              total: effectiveTarget,
                              color: _accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: isDone
                                ? Row(
                                    key: const ValueKey('done'),
                                    children: [
                                      Icon(Icons.check_circle,
                                          size: 16,
                                          color: _accentColor),
                                      const SizedBox(width: 4),
                                      Text('Done!',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _accentColor,
                                          )),
                                    ],
                                  )
                                : Text(
                                    key: const ValueKey('count'),
                                    '$count/$effectiveTarget',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox(height: 14),
              error: (_, __) => const SizedBox(height: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _LogButton({required this.color, required this.onTap});

  @override
  State<_LogButton> createState() => _LogButtonState();
}

class _LogButtonState extends State<_LogButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
