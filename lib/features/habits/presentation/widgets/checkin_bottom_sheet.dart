import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_tracker/features/checkin/domain/checkin_repository.dart';
import 'package:habit_tracker/features/habits/data/habit_model.dart';
import 'package:habit_tracker/features/habits/domain/habit_providers.dart';

class CheckInBottomSheet extends ConsumerStatefulWidget {
  final String habitId;
  final String habitName;
  final CheckInType checkInType;
  final String? quantityUnit;

  const CheckInBottomSheet({
    super.key,
    required this.habitId,
    required this.habitName,
    required this.checkInType,
    this.quantityUnit,
  });

  static Future<void> show(
    BuildContext context, {
    required String habitId,
    required String habitName,
    required CheckInType checkInType,
    String? quantityUnit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => CheckInBottomSheet(
        habitId: habitId,
        habitName: habitName,
        checkInType: checkInType,
        quantityUnit: quantityUnit,
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

  @override
  void dispose() {
    _noteController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(checkInRepositoryProvider);
      final note = widget.checkInType == CheckInType.note
          ? _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim()
          : null;
      final quantity = widget.checkInType == CheckInType.quantity
          ? double.tryParse(_quantityController.text.trim())
          : null;

      await repo.recordCheckIn(widget.habitId, note: note, quantity: quantity);

      if (mounted) {
        Navigator.of(context).pop();
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
            widget.habitName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            widget.checkInType == CheckInType.note
                ? 'Add a note for today'
                : 'Log your quantity',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Input field
          if (widget.checkInType == CheckInType.note)
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
          else if (widget.checkInType == CheckInType.quantity)
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                hintText: '0',
                suffixText: widget.quantityUnit,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              autofocus: true,
            ),

          const SizedBox(height: 24),

          // Confirm button
          FilledButton(
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
        ],
      ),
    );
  }
}
