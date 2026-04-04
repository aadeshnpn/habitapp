import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_nav_bar.dart';
import '../data/label_model.dart';
import '../domain/label_providers.dart';
import '../domain/label_repository.dart';
import 'widgets/label_card.dart';

class LabelsScreen extends ConsumerWidget {
  const LabelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labelsAsync = ref.watch(allLabelsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Labels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateLabelSheet(context, ref),
            tooltip: 'Create label',
          ),
        ],
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 2),
      body: labelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (labels) {
          if (labels.isEmpty) {
            return _EmptyLabelsState(
              onCreatePressed: () => _showCreateLabelSheet(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(allLabelsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final label = labels[index];
                return LabelCard(
                  label: label,
                  onTap: () => context.push('/labels/${label.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateLabelSheet(
      BuildContext context, WidgetRef ref) async {
    final repo = ref.read(labelRepositoryProvider);
    final created = await showModalBottomSheet<HabitLabel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateLabelSheet(labelRepository: repo),
    );
    if (created != null) {
      ref.invalidate(allLabelsProvider);
    }
  }
}

class _EmptyLabelsState extends StatelessWidget {
  final VoidCallback onCreatePressed;

  const _EmptyLabelsState({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏷️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              'No labels yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Group habits under labels and track a shared streak.\nComplete any member habit to keep the streak alive.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: const Text('Create your first label'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Label Bottom Sheet
// ---------------------------------------------------------------------------

const _kLabelEmojis = [
  '💪', '🧘', '📚', '🏃', '💧', '🎯', '🌿', '🎨',
  '💻', '🎵', '🚴', '🤸', '🏊', '🍎', '😴', '🧹',
  '💊', '🌅', '🍵', '🚶', '📝', '🎸', '🏋️', '✍️',
  '🧠', '🥗', '🐕', '🎮', '🌟', '🔥',
];

const _kLabelColorOptions = [
  Color(0xFF4CAF50),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF2196F3),
  Color(0xFFE91E63),
  Color(0xFFF44336),
];

class _CreateLabelSheet extends StatefulWidget {
  final LabelRepository labelRepository;

  const _CreateLabelSheet({required this.labelRepository});

  @override
  State<_CreateLabelSheet> createState() => _CreateLabelSheetState();
}

class _CreateLabelSheetState extends State<_CreateLabelSheet> {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('New Label', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _selectedColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _selectedColor.withOpacity(0.4), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(_selectedEmoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _nameController,
                  maxLength: 30,
                  decoration: InputDecoration(
                    labelText: 'Label name',
                    hintText: 'e.g. Physical Exercise',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    counterText: '',
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Color', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                      color: isSelected ? theme.colorScheme.onSurface : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text('Emoji', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
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
                    color: isSelected ? _selectedColor.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? _selectedColor : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _create,
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create Label'),
            ),
          ),
        ],
      ),
    );
  }
}
