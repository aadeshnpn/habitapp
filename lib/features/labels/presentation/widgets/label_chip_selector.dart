import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/label_model.dart';
import '../../domain/label_providers.dart';
import '../../domain/label_repository.dart';

const _kLabelEmojis = [
  '💪', '🧘', '📚', '🏃', '💧', '🎯', '🌿', '🎨',
  '💻', '🎵', '🚴', '🤸', '🏊', '🍎', '😴', '🧹',
  '💊', '🌅', '🍵', '🚶', '📝', '🎸', '🏋️', '✍️',
  '🧠', '🥗', '🐕', '🎮', '🌟', '🔥',
];

const _kLabelColorOptions = [
  Color(0xFF4CAF50), // green
  Color(0xFFFF9800), // orange
  Color(0xFF9C27B0), // purple
  Color(0xFF2196F3), // blue
  Color(0xFFE91E63), // pink
  Color(0xFFF44336), // red
];

class LabelChipSelector extends ConsumerStatefulWidget {
  final List<String> selectedLabelIds;
  final ValueChanged<List<String>> onChanged;

  const LabelChipSelector({
    super.key,
    required this.selectedLabelIds,
    required this.onChanged,
  });

  @override
  ConsumerState<LabelChipSelector> createState() => _LabelChipSelectorState();
}

class _LabelChipSelectorState extends ConsumerState<LabelChipSelector> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedLabelIds);
  }

  @override
  void didUpdateWidget(LabelChipSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLabelIds != widget.selectedLabelIds) {
      _selected = List.from(widget.selectedLabelIds);
    }
  }

  void _toggle(String labelId) {
    setState(() {
      if (_selected.contains(labelId)) {
        _selected.remove(labelId);
      } else {
        _selected.add(labelId);
      }
    });
    widget.onChanged(List.from(_selected));
  }

  Future<void> _showCreateDialog() async {
    final repo = ref.read(labelRepositoryProvider);
    final result = await showDialog<HabitLabel>(
      context: context,
      builder: (ctx) => _CreateLabelDialog(labelRepository: repo),
    );
    if (result != null) {
      ref.invalidate(allLabelsProvider);
      setState(() {
        _selected.add(result.id);
      });
      widget.onChanged(List.from(_selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelsAsync = ref.watch(allLabelsProvider);
    final theme = Theme.of(context);

    return labelsAsync.when(
      loading: () => const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Error loading labels: $e'),
      data: (labels) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...labels.map((label) {
              final isSelected = _selected.contains(label.id);
              final labelColor = Color(label.color);
              return FilterChip(
                label: Text('${label.emoji} ${label.name}'),
                selected: isSelected,
                onSelected: (_) => _toggle(label.id),
                selectedColor: labelColor.withOpacity(0.2),
                checkmarkColor: labelColor,
                side: BorderSide(
                  color: isSelected
                      ? labelColor
                      : theme.colorScheme.outline.withOpacity(0.4),
                ),
              );
            }),
            ActionChip(
              label: const Text('+ New label'),
              onPressed: _showCreateDialog,
              avatar: const Icon(Icons.add, size: 16),
            ),
          ],
        );
      },
    );
  }
}

class _CreateLabelDialog extends StatefulWidget {
  final LabelRepository labelRepository;

  const _CreateLabelDialog({required this.labelRepository});

  @override
  State<_CreateLabelDialog> createState() => _CreateLabelDialogState();
}

class _CreateLabelDialogState extends State<_CreateLabelDialog> {
  final _nameController = TextEditingController();
  String _selectedEmoji = _kLabelEmojis.first;
  Color _selectedColor = _kLabelColorOptions.first;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final label = await widget.labelRepository.createLabel(
        name: name,
        emoji: _selectedEmoji,
        color: _selectedColor.value,
      );
      if (mounted) Navigator.of(context).pop(label);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Create Label'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji display + name field
            Row(
              children: [
                GestureDetector(
                  onTap: () => _showEmojiPicker(context),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _selectedColor.withOpacity(0.4), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedEmoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'Label name',
                      hintText: 'e.g. Physical Exercise',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      counterText: '',
                    ),
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Color',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _kLabelColorOptions.map((c) {
                final isSelected = c.value == _selectedColor.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text(
              'Emoji',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kLabelEmojis.map((emoji) {
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedColor.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? _selectedColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _create,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  void _showEmojiPicker(BuildContext context) {
    // Emoji is picked inline in the grid — nothing extra needed.
  }
}
