import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../../shared/widgets/emoji_picker_sheet.dart';
import '../data/interval_reminder_model.dart';
import '../domain/interval_reminder_providers.dart';
import '../domain/interval_reminder_repository.dart';

const _kColorOptions = [
  Color(0xFF0277BD), // blue
  Color(0xFF00838F), // teal
  Color(0xFF2E7D32), // green
  Color(0xFF6A1B9A), // purple
  Color(0xFFE65100), // orange
  Color(0xFFC62828), // red
  Color(0xFF37474F), // slate
  Color(0xFFAD1457), // pink
];

const _intervalOptions = [
  (label: 'Every 30 min', minutes: 30),
  (label: 'Every 1 hour', minutes: 60),
  (label: 'Every 2 hours', minutes: 120),
  (label: 'Every 3 hours', minutes: 180),
  (label: 'Every 4 hours', minutes: 240),
  (label: 'Every 6 hours', minutes: 360),
  (label: 'Every 8 hours', minutes: 480),
  (label: 'Every 12 hours', minutes: 720),
];

class AddIntervalReminderSheet extends ConsumerStatefulWidget {
  /// Pass an existing reminder to edit; null = create new.
  final IntervalReminder? existing;

  const AddIntervalReminderSheet({super.key, this.existing});

  static Future<bool?> show(
    BuildContext context, {
    IntervalReminder? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddIntervalReminderSheet(existing: existing),
    );
  }

  @override
  ConsumerState<AddIntervalReminderSheet> createState() =>
      _AddIntervalReminderSheetState();
}

class _AddIntervalReminderSheetState
    extends ConsumerState<AddIntervalReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String _icon = '💧';
  Color _color = _kColorOptions[0];
  ReminderCategory _category = ReminderCategory.hydration;
  int _intervalMinutes = 240;
  TimeOfDay _windowStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _windowEnd = const TimeOfDay(hour: 22, minute: 0);
  int _targetCount = 0; // 0 = unlimited
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _icon = e.icon;
      _color = Color(e.color);
      _category = e.category;
      _intervalMinutes = e.intervalMinutes;
      _windowStart = _todFromStr(e.windowStart) ??
          const TimeOfDay(hour: 8, minute: 0);
      _windowEnd = _todFromStr(e.windowEnd) ??
          const TimeOfDay(hour: 22, minute: 0);
      _targetCount = e.targetCount;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  TimeOfDay? _todFromStr(String s) {
    final parts = s.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _todToStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // Compute preview of slot count
  int _previewSlotCount() {
    final startM = _windowStart.hour * 60 + _windowStart.minute;
    final endM = _windowEnd.hour * 60 + _windowEnd.minute;
    if (endM <= startM) return 0;
    return ((endM - startM) ~/ _intervalMinutes) + 1;
  }

  Future<void> _pickEmoji() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EmojiPickerSheet(currentEmoji: _icon),
    );
    if (picked != null) setState(() => _icon = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _windowStart : _windowEnd,
      helpText: isStart ? 'Window start' : 'Window end',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _windowStart = picked;
        } else {
          _windowEnd = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final repo = ref.read(intervalReminderRepositoryProvider);
      final e = widget.existing;

      if (e == null) {
        await repo.createReminder(CreateIntervalReminderParams(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color.value,
          category: _category,
          intervalMinutes: _intervalMinutes,
          windowStart: _todToStr(_windowStart),
          windowEnd: _todToStr(_windowEnd),
          targetCount: _targetCount,
        ));
      } else {
        await repo.updateReminder(e.copyWith(
          name: _nameController.text.trim(),
          icon: _icon,
          color: _color.value,
          category: _category,
          intervalMinutes: _intervalMinutes,
          windowStart: _todToStr(_windowStart),
          windowEnd: _todToStr(_windowEnd),
          targetCount: _targetCount,
        ));
      }

      ref.invalidate(activeIntervalRemindersProvider);
      ref.invalidate(reminderTodaySummaryProvider);
      ref.invalidate(scheduleNotificationsProvider);
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
    final insets = MediaQuery.viewInsetsOf(context);
    final slotCount = _previewSlotCount();
    final isEdit = widget.existing != null;

    return Container(
      margin: EdgeInsets.only(bottom: insets.bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isEdit ? 'Edit Reminder' : 'New Interval Reminder',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),

              // Emoji + Color row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Emoji picker
                  GestureDetector(
                    onTap: _pickEmoji,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _color.withOpacity(0.4)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_icon,
                              style: const TextStyle(fontSize: 30)),
                          Text('Change',
                              style:
                                  TextStyle(fontSize: 9, color: _color)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Color picker
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Color',
                            style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kColorOptions.map((c) {
                            final sel = c.value == _color.value;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _color = c),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 180),
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: sel
                                        ? theme.colorScheme.onSurface
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: sel
                                    ? const Icon(Icons.check,
                                        size: 15,
                                        color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name field
              TextFormField(
                controller: _nameController,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: 'Reminder name',
                  hintText: 'e.g. Drink Water',
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 16),

              // Category chips
              Text('Category',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ReminderCategory.values.map((cat) {
                  final sel = cat == _category;
                  return ChoiceChip(
                    label: Text('${cat.emoji} ${cat.label}'),
                    selected: sel,
                    onSelected: (_) =>
                        setState(() => _category = cat),
                    selectedColor: _color.withOpacity(0.18),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          sel ? _color : theme.colorScheme.onSurface,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Interval picker
              Text('Repeat every',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _intervalOptions.map((opt) {
                  final sel = opt.minutes == _intervalMinutes;
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: sel,
                    onSelected: (_) => setState(
                        () => _intervalMinutes = opt.minutes),
                    selectedColor: _color.withOpacity(0.18),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          sel ? _color : theme.colorScheme.onSurface,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Time window
              Text('Active window',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'From',
                      time: _windowStart,
                      color: _color,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeButton(
                      label: 'Until',
                      time: _windowEnd,
                      color: _color,
                      onTap: () => _pickTime(false),
                    ),
                  ),
                ],
              ),
              if (slotCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '$slotCount notification${slotCount == 1 ? '' : 's'} per day',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),

              // Daily target (optional)
              Text('Daily target (optional)',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Set 0 for unlimited — any log counts as "done for the day".',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    onPressed: _targetCount > 0
                        ? () => setState(() => _targetCount--)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _targetCount == 0 ? 'Unlimited' : '$_targetCount',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _targetCount++),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, color: Colors.white),
                  label: Text(
                    isEdit ? 'Save Changes' : 'Create Reminder',
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
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Color color;
  final VoidCallback onTap;

  const _TimeButton({
    required this.label,
    required this.time,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
          color: color.withOpacity(0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text('$h:$m',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }
}
