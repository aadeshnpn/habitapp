import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/interval_reminder_model.dart';
import '../domain/interval_reminder_providers.dart';
import '../domain/interval_reminder_repository.dart';

/// Quick-log bottom sheet. Shown when user taps the log button on a card
/// or arrives from a notification "Log it ✓" action.
class IntervalReminderLogSheet extends ConsumerStatefulWidget {
  final IntervalReminder reminder;

  const IntervalReminderLogSheet({super.key, required this.reminder});

  static Future<bool?> show(
    BuildContext context, {
    required IntervalReminder reminder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IntervalReminderLogSheet(reminder: reminder),
    );
  }

  @override
  ConsumerState<IntervalReminderLogSheet> createState() =>
      _IntervalReminderLogSheetState();
}

class _IntervalReminderLogSheetState
    extends ConsumerState<IntervalReminderLogSheet> {
  final _noteController = TextEditingController();
  double? _quantity;
  bool _isSaving = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(intervalReminderRepositoryProvider);
      await repo.logCheckIn(
        widget.reminder.id,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        quantity: _quantity,
      );
      ref.invalidate(todayProgressProvider(widget.reminder.id));
      ref.invalidate(todayCheckInsProvider(widget.reminder.id));
      ref.invalidate(reminderTodaySummaryProvider);
      ref.invalidate(reminderStreakProvider(widget.reminder.id));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = Color(widget.reminder.color);
    final insets = MediaQuery.viewInsetsOf(context);

    return Container(
      margin: EdgeInsets.only(bottom: insets.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            const SizedBox(height: 20),
            // Header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(widget.reminder.icon,
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.reminder.name,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text('Log a completion',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Optional note
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                prefixIcon: const Icon(Icons.edit_note_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 28),
            // Log button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSaving ? null : _log,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  'Log it ✓',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
