import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/habit_model.dart';
import '../domain/habit_providers.dart';
import '../../labels/domain/label_providers.dart';
import '../../labels/presentation/widgets/label_chip_selector.dart';
import 'widgets/frequency_selector.dart';
import 'widgets/checkin_type_selector.dart';

const _kEditEmojis = [
  '🏃', '🏋️', '🧘', '💧', '📚', '✍️', '🎸', '🍎',
  '😴', '🧹', '💊', '🚴', '🏊', '🧠', '🎯', '💪',
  '🌅', '🫁', '🍵', '🚶', '📝', '🎨', '🌿', '💻',
  '🎵', '🤸', '🥗', '🛌', '🎮', '🐕',
];

const _kEditColorOptions = [
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.blue,
  Colors.pink,
  Colors.red,
];

class EditHabitScreen extends ConsumerStatefulWidget {
  final String habitId;

  const EditHabitScreen({super.key, required this.habitId});

  @override
  ConsumerState<EditHabitScreen> createState() => _EditHabitScreenState();
}

class _EditHabitScreenState extends ConsumerState<EditHabitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _loaded = false;
  bool _isSaving = false;

  String _selectedEmoji = _kEditEmojis.first;
  Color _selectedColor = _kEditColorOptions.first;
  FrequencyType _frequencyType = FrequencyType.daily;
  List<int> _selectedDays = [];
  int _timesPerWeek = 3;
  CheckInType _checkInType = CheckInType.tap;
  String? _quantityUnit;
  TimeOfDay? _reminderTime;
  List<String> _selectedLabelIds = [];

  // Holds the original habit for the update call
  Habit? _originalHabit;

  @override
  void initState() {
    super.initState();
    _loadHabit();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadHabit() async {
    final repo = ref.read(habitRepositoryProvider);
    final habit = await repo.getHabitById(widget.habitId);
    if (habit == null || !mounted) return;

    _originalHabit = habit;
    _nameController.text = habit.name;
    _selectedEmoji = habit.icon;

    // Find best-matching color from the palette
    Color matched = _kEditColorOptions.first;
    for (final c in _kEditColorOptions) {
      if (c.value == habit.color) {
        matched = c;
        break;
      }
    }
    _selectedColor = matched;

    _frequencyType = habit.frequencyType;
    _selectedDays = List.from(habit.daysOfWeek);
    _timesPerWeek = habit.timesPerWeek > 0 ? habit.timesPerWeek : 3;
    _checkInType = habit.checkInType;
    _quantityUnit = habit.quantityUnit;

    if (habit.reminderTime != null) {
      final parts = habit.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 8,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    // Load existing label assignments
    final labelRepo = ref.read(labelRepositoryProvider);
    final labelIds = await labelRepo.getLabelsForHabit(widget.habitId);
    _selectedLabelIds = List.from(labelIds);

    setState(() => _loaded = true);
  }

  Future<void> _pickEmoji() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditEmojiPickerSheet(currentEmoji: _selectedEmoji),
    );
    if (picked != null) setState(() => _selectedEmoji = picked);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Set reminder time',
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  void _clearReminder() => setState(() => _reminderTime = null);

  String? _formatReminderTime() {
    if (_reminderTime == null) return null;
    final h = _reminderTime!.hour.toString().padLeft(2, '0');
    final m = _reminderTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_originalHabit == null) return;
    setState(() => _isSaving = true);
    try {
      final updated = _originalHabit!.copyWith(
        name: _nameController.text.trim(),
        icon: _selectedEmoji,
        color: _selectedColor.value,
        frequencyType: _frequencyType,
        daysOfWeek: _frequencyType == FrequencyType.daysOfWeek
            ? List.from(_selectedDays)
            : [],
        timesPerWeek: _frequencyType == FrequencyType.timesPerWeek
            ? _timesPerWeek
            : 0,
        checkInType: _checkInType,
        quantityUnit:
            _checkInType == CheckInType.quantity ? _quantityUnit : null,
        reminderTime: _formatReminderTime(),
      );
      final repo = ref.read(habitRepositoryProvider);
      await repo.updateHabit(updated);
      final labelRepo = ref.read(labelRepositoryProvider);
      await labelRepo.setHabitLabels(updated.id, _selectedLabelIds);
      ref.invalidate(activeHabitsProvider);
      ref.invalidate(allLabelsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating habit: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Habit'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final nameLength = _nameController.text.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Habit'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
        label: const Text('Save'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            // Emoji + Color row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _EditEmojiButton(
                  emoji: _selectedEmoji,
                  color: _selectedColor,
                  onTap: _pickEmoji,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _EditColorPickerRow(
                    selectedColor: _selectedColor,
                    colors: _kEditColorOptions,
                    onColorSelected: (c) => setState(() => _selectedColor = c),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Habit name
            TextFormField(
              controller: _nameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Habit name',
                hintText: 'e.g. Morning run',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.edit_outlined),
                counterText: '$nameLength / 50',
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a habit name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Frequency
            _EditSectionCard(
              child: FrequencySelector(
                value: _frequencyType,
                selectedDays: _selectedDays,
                timesPerWeek: _timesPerWeek,
                onTypeChanged: (t) => setState(() => _frequencyType = t),
                onDaysChanged: (d) => setState(() => _selectedDays = d),
                onTimesPerWeekChanged: (n) =>
                    setState(() => _timesPerWeek = n),
              ),
            ),
            const SizedBox(height: 16),

            // Check-in type
            _EditSectionCard(
              child: CheckInTypeSelector(
                value: _checkInType,
                quantityUnit: _quantityUnit,
                onTypeChanged: (t) => setState(() => _checkInType = t),
                onUnitChanged: (u) => setState(() => _quantityUnit = u),
              ),
            ),
            const SizedBox(height: 16),

            // Labels
            _EditSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Labels',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LabelChipSelector(
                    selectedLabelIds: _selectedLabelIds,
                    onChanged: (ids) => setState(() => _selectedLabelIds = ids),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Reminder
            _EditSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reminder',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickReminderTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withOpacity(0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alarm_outlined,
                            color: _reminderTime != null
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _reminderTime != null
                                  ? 'Remind me at ${_formatReminderTime()}'
                                  : 'No reminder',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: _reminderTime != null
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          if (_reminderTime != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: _clearReminder,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets (edit-screen-local, prefixed to avoid collisions)
// ---------------------------------------------------------------------------

class _EditEmojiButton extends StatelessWidget {
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _EditEmojiButton({
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 2),
            Text('Change', style: TextStyle(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EditColorPickerRow extends StatelessWidget {
  final Color selectedColor;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;

  const _EditColorPickerRow({
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: colors.map((c) {
            final isSelected = c.value == selectedColor.value;
            return GestureDetector(
              onTap: () => onColorSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.withOpacity(0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _EditSectionCard extends StatelessWidget {
  final Widget child;

  const _EditSectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: child,
    );
  }
}

class _EditEmojiPickerSheet extends StatefulWidget {
  final String currentEmoji;

  const _EditEmojiPickerSheet({required this.currentEmoji});

  @override
  State<_EditEmojiPickerSheet> createState() => _EditEmojiPickerSheetState();
}

class _EditEmojiPickerSheetState extends State<_EditEmojiPickerSheet> {
  late String _highlighted;

  @override
  void initState() {
    super.initState();
    _highlighted = widget.currentEmoji;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose an icon',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: _kEditEmojis.length,
              itemBuilder: (_, i) {
                final emoji = _kEditEmojis[i];
                final isSelected = emoji == _highlighted;
                return GestureDetector(
                  onTap: () {
                    setState(() => _highlighted = emoji);
                    Navigator.of(context).pop(emoji);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
