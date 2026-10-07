import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/checkin/domain/checkin_service.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';

class CheckInBottomSheet extends ConsumerStatefulWidget {
  final Habit habit;
  final int habitIndex;
  final CheckInService checkInService;
  final int currentStreak;

  const CheckInBottomSheet({
    super.key,
    required this.habit,
    required this.habitIndex,
    required this.checkInService,
    required this.currentStreak,
  });

  /// Shows the bottom sheet and returns a [CheckInResult] if a check-in was
  /// submitted, or null if the user cancelled.
  static Future<CheckInResult?> show(
    BuildContext context, {
    required Habit habit,
    required int habitIndex,
    required CheckInService checkInService,
    required int currentStreak,
  }) {
    return showModalBottomSheet<CheckInResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CheckInBottomSheet(
        habit: habit,
        habitIndex: habitIndex,
        checkInService: checkInService,
        currentStreak: currentStreak,
      ),
    );
  }

  @override
  ConsumerState<CheckInBottomSheet> createState() =>
      _CheckInBottomSheetState();
}

class _CheckInBottomSheetState extends ConsumerState<CheckInBottomSheet> {
  final _noteController = TextEditingController();
  final _quantityController = TextEditingController();
  bool _isSaving = false;
  String? _validationError;

  @override
  void dispose() {
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  bool _validate() {
    if (widget.habit.checkInType == CheckInType.quantity) {
      final text = _quantityController.text.trim();
      final value = double.tryParse(text);
      if (value == null || value <= 0) {
        setState(() => _validationError = 'Please enter a quantity greater than 0');
        return false;
      }
    }
    setState(() => _validationError = null);
    return true;
  }

  void _stepQuantity(double delta) {
    final current = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final next = (current + delta).clamp(0.0, double.infinity);
    // Format without trailing zeros for whole numbers
    final formatted = next == next.truncateToDouble()
        ? next.toInt().toString()
        : next.toString();
    _quantityController.text = formatted;
    _quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: _quantityController.text.length),
    );
    setState(() => _validationError = null);
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_validate()) return;

    setState(() => _isSaving = true);

    try {
      final note = widget.habit.checkInType == CheckInType.note
          ? _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim()
          : null;
      final quantity = widget.habit.checkInType == CheckInType.quantity
          ? double.tryParse(_quantityController.text.trim())
          : null;

      final result = await widget.checkInService.completeHabit(
        habit: widget.habit,
        habitIndex: widget.habitIndex,
        note: note,
        quantity: quantity,
      );

      if (mounted) {
        Navigator.of(context).pop(result);
        if (!result.alreadyCompleted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Logged!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final isQuantity = widget.habit.checkInType == CheckInType.quantity;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: mediaQuery.viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Habit name header
          Text(
            widget.habit.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Streak badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${widget.currentStreak} day streak',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Text(
            isQuantity ? 'Log your quantity' : 'Add a note for today',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Input field
          if (widget.habit.checkInType == CheckInType.note)
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'How did it go?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              textCapitalization: TextCapitalization.sentences,
              autofocus: true,
            )
          else if (isQuantity) ...[
            Row(
              children: [
                // Decrement stepper
                _StepperButton(
                  icon: Icons.remove,
                  onTap: () => _stepQuantity(-1),
                ),
                const SizedBox(width: 12),
                // Text field
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: widget.habit.quantityUnit,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                      errorText: _validationError,
                    ),
                    textAlign: TextAlign.center,
                    autofocus: true,
                    onChanged: (_) => setState(() => _validationError = null),
                  ),
                ),
                const SizedBox(width: 12),
                // Increment stepper
                _StepperButton(
                  icon: Icons.add,
                  onTap: () => _stepQuantity(1),
                ),
              ],
            ),
          ],

          // Validation error for note type (quantity error shown inline above)
          if (_validationError != null &&
              widget.habit.checkInType != CheckInType.quantity)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _validationError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Action buttons: Cancel + Confirm
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSaving ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A round icon button used as a stepper control.
class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            icon,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
