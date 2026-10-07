import 'package:flutter/material.dart';

/// A bottom sheet that lets the user pick any emoji from the system keyboard.
///
/// The sheet shows:
///   • A large preview of the currently selected emoji.
///   • A [TextField] configured for emoji input — tapping it opens the OS
///     keyboard in emoji mode on supported devices.
///   • A scrollable grid of quick-suggestion emojis for one-tap selection.
///
/// Returns the chosen emoji [String] via [Navigator.pop], or `null` if the
/// sheet is dismissed without a selection.
///
/// Usage:
/// ```dart
/// final picked = await showModalBottomSheet<String>(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => EmojiPickerSheet(currentEmoji: _selectedEmoji),
/// );
/// if (picked != null) setState(() => _selectedEmoji = picked);
/// ```
class EmojiPickerSheet extends StatefulWidget {
  /// The emoji that is currently active (shown pre-selected in the grid).
  final String currentEmoji;

  /// Quick-suggestion emojis shown in the grid below the text field.
  /// If not provided, [defaultSuggestions] is used.
  final List<String>? suggestions;

  const EmojiPickerSheet({
    super.key,
    required this.currentEmoji,
    this.suggestions,
  });

  /// Default quick-suggestion emoji list (30 entries covering common habits).
  static const List<String> defaultSuggestions = [
    '🏃', '🏋️', '🧘', '💧', '📚', '✍️', '🎸', '🍎',
    '😴', '🧹', '💊', '🚴', '🏊', '🧠', '🎯', '💪',
    '🌅', '🫁', '🍵', '🚶', '📝', '🎨', '🌿', '💻',
    '🎵', '🤸', '🥗', '🛌', '🎮', '🐕',
  ];

  /// Extract the first grapheme cluster from [input].
  /// Returns `null` if [input] contains no grapheme clusters.
  ///
  /// Exposed as a static utility so it can be unit-tested directly.
  static String? firstGrapheme(String input) {
    final chars = input.characters;
    if (chars.isEmpty) return null;
    return chars.first;
  }

  @override
  State<EmojiPickerSheet> createState() => _EmojiPickerSheetState();
}

class _EmojiPickerSheetState extends State<EmojiPickerSheet> {
  late String _preview;
  late final TextEditingController _controller;
  late final List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _preview = widget.currentEmoji;
    _suggestions = widget.suggestions ?? EmojiPickerSheet.defaultSuggestions;
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    final first = EmojiPickerSheet.firstGrapheme(value);
    if (first != null) {
      setState(() => _preview = first);
      // Clear the text field after capturing the first grapheme so the user
      // can type a different emoji without manually deleting the previous one.
      _controller.clear();
      Navigator.of(context).pop(first);
    }
  }

  void _selectSuggestion(String emoji) {
    Navigator.of(context).pop(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Choose an icon',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Preview + keyboard input row
          Row(
            children: [
              // Large preview
              Container(
                key: const ValueKey('emoji_preview'),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.primaryContainer.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _preview,
                  style: const TextStyle(fontSize: 36),
                ),
              ),
              const SizedBox(width: 16),

              // Keyboard input
              Expanded(
                child: TextField(
                  key: const ValueKey('emoji_text_field'),
                  controller: _controller,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    labelText: 'Type or paste an emoji',
                    hintText: '😊',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Open keyboard, switch to emoji panel',
                    helperMaxLines: 2,
                  ),
                  onChanged: _onTextChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick suggestions label
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick pick',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Suggestions grid — shrinkWrap so the entire sheet can scroll
          GridView.builder(
            key: const ValueKey('emoji_suggestions_grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _suggestions.length,
            itemBuilder: (_, i) {
              final emoji = _suggestions[i];
              final isSelected = emoji == _preview;
              return GestureDetector(
                onTap: () => _selectSuggestion(emoji),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
