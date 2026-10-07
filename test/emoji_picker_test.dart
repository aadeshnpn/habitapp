// Tests for the free-form EmojiPickerSheet widget.
//
// Coverage:
//  1. firstGrapheme() — unit tests for grapheme-cluster extraction logic.
//  2. EmojiPickerSheet widget — rendering and interaction tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:habit_tracker/shared/widgets/emoji_picker_sheet.dart';

// ---------------------------------------------------------------------------
// 1. firstGrapheme() unit tests
// ---------------------------------------------------------------------------

void main() {
  group('EmojiPickerSheet.firstGrapheme()', () {
    test('returns null for empty string', () {
      expect(EmojiPickerSheet.firstGrapheme(''), isNull);
    });

    test('returns a simple ASCII character', () {
      expect(EmojiPickerSheet.firstGrapheme('A'), equals('A'));
    });

    test('returns the first of multiple characters', () {
      expect(EmojiPickerSheet.firstGrapheme('AB'), equals('A'));
    });

    test('returns a basic emoji', () {
      expect(EmojiPickerSheet.firstGrapheme('🏃'), equals('🏃'));
    });

    test('returns only the first emoji when multiple are present', () {
      final result = EmojiPickerSheet.firstGrapheme('🏃🧘');
      expect(result, equals('🏃'));
    });

    test('handles multi-codepoint emoji (ZWJ sequence)', () {
      // 👨‍💻 = U+1F468 ZWJ U+1F4BB (man technologist)
      const zwjEmoji = '👨‍💻';
      final result = EmojiPickerSheet.firstGrapheme(zwjEmoji);
      expect(result, equals(zwjEmoji));
    });

    test('handles flag emoji (regional indicator pair)', () {
      // 🇺🇸 = U+1F1FA + U+1F1F8
      const flag = '🇺🇸';
      final result = EmojiPickerSheet.firstGrapheme(flag);
      expect(result, equals(flag));
    });

    test('handles skin-tone modifier sequence', () {
      // 👋🏽 = U+1F44B + U+1F3FD
      const waving = '👋🏽';
      final result = EmojiPickerSheet.firstGrapheme(waving);
      expect(result, equals(waving));
    });

    test('extracts only first emoji from emoji+text mix', () {
      final result = EmojiPickerSheet.firstGrapheme('🎯text');
      expect(result, equals('🎯'));
    });

    test('returns first grapheme even when input starts with whitespace char', () {
      final result = EmojiPickerSheet.firstGrapheme(' 🎵');
      expect(result, equals(' '));
    });

    test('returns first grapheme for single-char non-ASCII', () {
      expect(EmojiPickerSheet.firstGrapheme('é'), equals('é'));
    });
  });

  // -------------------------------------------------------------------------
  // 2. EmojiPickerSheet widget tests
  // -------------------------------------------------------------------------

  group('EmojiPickerSheet widget', () {
    Widget _build({String current = '🏃', List<String>? suggestions}) {
      return MaterialApp(
        home: Scaffold(
          body: EmojiPickerSheet(
            currentEmoji: current,
            suggestions: suggestions,
          ),
        ),
      );
    }

    testWidgets('renders title and preview', (tester) async {
      await tester.pumpWidget(_build(current: '🏃'));
      await tester.pumpAndSettle();

      expect(find.text('Choose an icon'), findsOneWidget);
      // Preview shows current emoji
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('emoji_preview')),
          matching: find.text('🏃'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders the text input field', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('emoji_text_field')), findsOneWidget);
    });

    testWidgets('renders the suggestions grid', (tester) async {
      await tester.pumpWidget(_build(
        suggestions: ['🏃', '🧘', '📚'],
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('emoji_suggestions_grid')), findsOneWidget);
      expect(find.text('🏃'), findsAtLeastNWidgets(1));
      expect(find.text('🧘'), findsOneWidget);
      expect(find.text('📚'), findsOneWidget);
    });

    testWidgets('uses defaultSuggestions when suggestions param is null',
        (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();

      // defaultSuggestions has 30 items; grid should render them all
      expect(
        find.byKey(const ValueKey('emoji_suggestions_grid')),
        findsOneWidget,
      );
      // Spot-check one default suggestion
      expect(find.text('🎯'), findsOneWidget);
    });

    testWidgets('tapping a suggestion closes the sheet via Navigator.pop',
        (tester) async {
      String? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: ctx,
                  builder: (_) => const EmojiPickerSheet(
                    currentEmoji: '🏃',
                    suggestions: ['🏃', '🧘', '📚'],
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));

      // Open the sheet
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Tap '🧘' suggestion
      await tester.tap(find.text('🧘'));
      await tester.pumpAndSettle();

      expect(result, equals('🧘'));
    });

    testWidgets('typing an emoji in TextField pops with that emoji',
        (tester) async {
      String? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: ctx,
                  builder: (_) => const EmojiPickerSheet(
                    currentEmoji: '🏃',
                    suggestions: ['🏃'],
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Simulate typing an emoji into the field
      await tester.enterText(
        find.byKey(const ValueKey('emoji_text_field')),
        '🎵',
      );
      await tester.pump();

      expect(result, equals('🎵'));
    });

    testWidgets('typing multiple emojis pops with only the first one',
        (tester) async {
      String? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: ctx,
                  builder: (_) => const EmojiPickerSheet(
                    currentEmoji: '🏃',
                    suggestions: [],
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Type two emojis — should only capture the first
      await tester.enterText(
        find.byKey(const ValueKey('emoji_text_field')),
        '🎸🏋️',
      );
      await tester.pump();

      expect(result, equals('🎸'));
    });

    testWidgets(
        'typing plain text pops the sheet with the first character',
        (tester) async {
      // The sheet accepts any text input and pops with the first grapheme.
      // If the user types regular letters (e.g. accidentally), the sheet
      // closes with that letter. No emoji-only restriction is enforced.
      String? result;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) {
            return ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<String>(
                  context: ctx,
                  builder: (_) => const EmojiPickerSheet(
                    currentEmoji: '🏃',
                    suggestions: [],
                  ),
                );
              },
              child: const Text('Open'),
            );
          }),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('emoji_text_field')),
        'hello',
      );
      await tester.pumpAndSettle();

      // Only the first grapheme ('h') is captured; the rest is discarded.
      expect(result, equals('h'));
    });

    testWidgets('preview updates to reflect the highlighted suggestion',
        (tester) async {
      // When a suggestion is highlighted (currently selected), it gets a border.
      await tester.pumpWidget(
        _build(current: '🧘', suggestions: ['🏃', '🧘', '📚']),
      );
      await tester.pumpAndSettle();

      // The current emoji is '🧘'; the suggestion grid cell for '🧘' should
      // be rendered with an AnimatedContainer (selected state).
      // We verify it appears at least once in the tree.
      expect(find.text('🧘'), findsAtLeastNWidgets(1));
    });

    testWidgets('quick-pick label is rendered', (tester) async {
      await tester.pumpWidget(_build());
      await tester.pumpAndSettle();

      expect(find.text('Quick pick'), findsOneWidget);
    });
  });
}
