import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'harness.dart';

const _b = TextFormat.bold;
const _i = TextFormat.italic;
const _m = TextFormat.monospace;

void main() {
  group('ranges', () {
    test('join when they overlap or touch, apart from mentions', () {
      expect(
        normalizeRanges([
          const FormatRange(4, 8, _b),
          const FormatRange(0, 4, _b),
          const FormatRange(6, 6, _i),
          const FormatRange(0, 2, TextFormat.mention, userId: 1),
          const FormatRange(2, 4, TextFormat.mention, userId: 1),
        ]),
        [
          const FormatRange(0, 2, TextFormat.mention, userId: 1),
          const FormatRange(0, 8, _b),
          const FormatRange(2, 4, TextFormat.mention, userId: 1),
        ],
      );
    });

    test('toggle on, then off for part of a range', () {
      var ranges = toggleFormat(const [], _b, 0, 10);
      expect(ranges, [const FormatRange(0, 10, _b)]);
      ranges = toggleFormat(ranges, _b, 3, 5);
      expect(ranges, [
        const FormatRange(0, 3, _b),
        const FormatRange(5, 10, _b),
      ]);
      // Partly bold: the whole selection becomes bold.
      ranges = toggleFormat(ranges, _b, 2, 6);
      expect(ranges, [const FormatRange(0, 10, _b)]);
    });

    test('a new link replaces the old one', () {
      var ranges = toggleFormat(
        const [],
        TextFormat.link,
        0,
        5,
        url: 'https://a.example',
      );
      ranges = toggleFormat(
        ranges,
        TextFormat.link,
        2,
        5,
        url: 'https://b.example',
      );
      expect(ranges, [
        const FormatRange(0, 2, TextFormat.link, url: 'https://a.example'),
        const FormatRange(2, 5, TextFormat.link, url: 'https://b.example'),
      ]);
      expect(toggleFormat(ranges, TextFormat.link, 0, 5), isEmpty);
    });
  });

  group('edits', () {
    const bold = [FormatRange(4, 9, _b)]; // "say *hello* now"

    test('typing inside a range joins it, at its edges does not', () {
      expect(shiftForEdit(bold, 'say hello now', 'say helXlo now'), [
        const FormatRange(4, 10, _b),
      ]);
      expect(shiftForEdit(bold, 'say hello now', 'say helloX now'), bold);
      expect(shiftForEdit(bold, 'say hello now', 'say Xhello now'), [
        const FormatRange(5, 10, _b),
      ]);
    });

    test('deleting text shortens or removes a range', () {
      expect(shiftForEdit(bold, 'say hello now', 'say hlo now'), [
        const FormatRange(4, 7, _b),
      ]);
      expect(shiftForEdit(bold, 'say hello now', 'say  now'), isEmpty);
      expect(shiftForEdit(bold, 'say hello now', 'hello now'), [
        const FormatRange(0, 5, _b),
      ]);
    });

    test('typing over a whole range keeps its format', () {
      expect(shiftForEdit(bold, 'say hello now', 'say bye now'), [
        const FormatRange(4, 7, _b),
      ]);
    });

    test('an edited mention is dropped', () {
      const mention = [FormatRange(0, 4, TextFormat.mention, userId: 7)];
      expect(shiftForEdit(mention, 'Vera hi', 'Veda hi'), isEmpty);
      expect(shiftForEdit(mention, 'Vera hi', 'Vera hi!'), mention);
    });

    test('typing formats go on the inserted text', () {
      expect(shiftForEdit(const [], 'ab', 'aXYb', typing: {_i}), [
        const FormatRange(1, 3, _i),
      ]);
    });

    test('never split an emoji', () {
      // Deleting 😀 before a bold 😁: the texts share the high surrogate.
      expect(shiftForEdit([const FormatRange(2, 4, _b)], '😀😁', '😁'), [
        const FormatRange(0, 2, _b),
      ]);
      // Typing 😀 with bold on, between two other emoji.
      expect(shiftForEdit(const [], '😁😂', '😁😀😂', typing: {_b}), [
        const FormatRange(2, 4, _b),
      ]);
      expect(snapToCharacter('a😀', 2), 1);
      expect(snapToCharacter('a😀', 3), 3);
    });

    test('the selection says where text went when the texts cannot', () {
      // An "a" typed at the start of "a": the bold one stays second.
      expect(
        shiftForEdit(
          [const FormatRange(0, 1, _b)],
          'a',
          'aa',
          selection: (0, 0),
        ),
        [const FormatRange(1, 2, _b)],
      );
      expect(shiftForEdit([const FormatRange(0, 1, _b)], 'a', 'aa'), [
        const FormatRange(0, 1, _b),
      ]);
    });
  });

  group('markdown', () {
    /// The text and the formats, comparable with `expect`.
    List<Object> md(String text, [List<FormatRange>? r]) {
      final (converted, formats) = applyMarkdown(text, r ?? const []);
      return [converted, formats];
    }

    test('turns markers into formats', () {
      expect(md('a **b** c'), [
        'a b c',
        [const FormatRange(2, 3, _b)],
      ]);
      expect(md('__it__ ~~s~~ ||x||'), [
        'it s x',
        [
          const FormatRange(0, 2, _i),
          const FormatRange(3, 4, TextFormat.strikethrough),
          const FormatRange(5, 6, TextFormat.spoiler),
        ],
      ]);
      expect(md('run `ls -la` now'), [
        'run ls -la now',
        [const FormatRange(4, 10, _m)],
      ]);
    });

    test('code blocks drop their own lines and keep markers inside', () {
      expect(md('see:\n```\nx **y**\n```'), [
        'see:\nx **y**',
        [const FormatRange(5, 12, _m)],
      ]);
    });

    test('leaves lone and empty markers alone', () {
      expect(md('2 ** 3 and ****'), ['2 ** 3 and ****', isEmpty]);
      expect(md('a*b*c'), ['a*b*c', isEmpty]);
    });

    test('a backslash keeps a marker as text', () {
      expect(md(r'\_\_init\_\_ and \*\*x\*\*'), [
        '__init__ and **x**',
        isEmpty,
      ]);
      expect(md(r'\__init__'), ['__init__', isEmpty]);
      expect(md(r'a \\ b'), [r'a \ b', isEmpty]);
      expect(md(r'C:\path'), [r'C:\path', isEmpty]);
      // Inside code the backslash is part of the code.
      expect(md(r'`a\*b`'), [
        r'a\*b',
        [const FormatRange(0, 4, _m)],
      ]);
    });

    test('double backticks hold code with backticks', () {
      expect(md('`` `x` ``'), [
        '`x`',
        [const FormatRange(0, 3, _m)],
      ]);
      expect(md('a ` ` b'), ['a ` ` b', isEmpty]);
    });

    test('formats may wrap code', () {
      expect(md('**a `b` c**'), [
        'a b c',
        [const FormatRange(0, 5, _b), const FormatRange(2, 3, _m)],
      ]);
      // A marker inside code stays text.
      expect(md('**a `b** c`'), [
        '**a b** c',
        [const FormatRange(4, 9, _m)],
      ]);
    });

    test('moves existing formats with the text', () {
      expect(
        md('**a** link', [const FormatRange(6, 10, TextFormat.link, url: 'u')]),
        [
          'a link',
          [
            const FormatRange(0, 1, _b),
            const FormatRange(2, 6, TextFormat.link, url: 'u'),
          ],
        ],
      );
    });
  });

  test('recognizes web addresses on the clipboard', () {
    expect(looksLikeUrl('https://telegram.org/faq'), isTrue);
    expect(looksLikeUrl('telegram.org'), isTrue);
    expect(looksLikeUrl('hello'), isFalse);
    expect(looksLikeUrl('two words.com'), isFalse);
  });

  group('controller', () {
    test('keeps ranges through typing and clears them with the text', () {
      final c = RichTextEditingController(text: 'hello world')
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      c.toggle(_b);
      expect(c.ranges, [const FormatRange(0, 5, _b)]);
      expect(c.isActive(_b), isTrue);

      c.value = const TextEditingValue(
        text: 'hello, world',
        selection: TextSelection.collapsed(offset: 6),
      );
      expect(c.ranges, [const FormatRange(0, 5, _b)]);
      c.clear();
      expect(c.ranges, isEmpty);
    });

    test('custom emoji stay apart and drop out when edited into', () {
      final c = RichTextEditingController(text: 'ab')
        ..selection = const TextSelection.collapsed(offset: 1);
      c.insertCustomEmoji('😀', 5);
      c.insertCustomEmoji('😀', 5);
      expect(c.text, 'a😀😀b');
      expect(c.ranges, [
        const FormatRange(1, 3, TextFormat.customEmoji, emojiId: 5),
        const FormatRange(3, 5, TextFormat.customEmoji, emojiId: 5),
      ]);
      // Typing in front moves both along.
      c.value = const TextEditingValue(
        text: 'xa😀😀b',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(c.ranges.first.start, 2);
      // Deleting one code unit of the second emoji drops its range.
      c.value = const TextEditingValue(
        text: 'xa😀\ud83dc',
        selection: TextSelection.collapsed(offset: 5),
      );
      expect(c.ranges.length, 1);
    });

    test('a format toggled at the caret applies to what is typed next', () {
      final c = RichTextEditingController(text: 'ab')
        ..selection = const TextSelection.collapsed(offset: 2);
      c.toggle(_i);
      expect(c.isActive(_i), isTrue);
      c.value = const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
      );
      c.value = const TextEditingValue(
        text: 'abcd',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(c.ranges, [const FormatRange(2, 4, _i)]);
      // Moving the caret forgets it.
      c.selection = const TextSelection.collapsed(offset: 0);
      expect(c.typingFormats, isEmpty);
    });

    test('finds the :word at the caret and inserts an emoji', () {
      final c = RichTextEditingController(text: 'ok :smi')
        ..selection = const TextSelection.collapsed(offset: 7);
      expect(c.emojiQuery, 'smi');
      c.insertEmoji('😀');
      expect(c.text, 'ok 😀');
      expect(c.selection.baseOffset, 5);

      c.value = const TextEditingValue(
        text: 'at 10:30',
        selection: TextSelection.collapsed(offset: 8),
      );
      expect(c.emojiQuery, isNull);
      c.value = const TextEditingValue(
        text: ':s',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(c.emojiQuery, isNull);
    });

    test('finds the bot command being typed', () {
      final c = RichTextEditingController(text: '/sta')
        ..selection = const TextSelection.collapsed(offset: 4);
      expect(c.commandQuery, 'sta');
      c.value = const TextEditingValue(
        text: '/',
        selection: TextSelection.collapsed(offset: 1),
      );
      expect(c.commandQuery, '');
      c.value = const TextEditingValue(
        text: '/start now',
        selection: TextSelection.collapsed(offset: 10),
      );
      expect(c.commandQuery, isNull);
      c.value = const TextEditingValue(
        text: 'a /b',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(c.commandQuery, isNull);
    });

    test('finds the @word at the caret and inserts a mention', () {
      final c = RichTextEditingController(text: 'hi @ve')
        ..selection = const TextSelection.collapsed(offset: 6);
      expect(c.mentionQuery, 've');
      c.insertMention(name: 'Vera', userId: 9);
      expect(c.text, 'hi Vera ');
      expect(c.ranges, [
        const FormatRange(3, 7, TextFormat.mention, userId: 9),
      ]);

      c.value = const TextEditingValue(
        text: 'mail a@b',
        selection: TextSelection.collapsed(offset: 8),
      );
      expect(c.mentionQuery, isNull);
      c.value = const TextEditingValue(
        text: '@bo',
        selection: TextSelection.collapsed(offset: 3),
      );
      c.insertMention(name: 'Boris', username: 'boris', userId: 2);
      expect(c.text, '@boris ');
      expect(c.ranges, isEmpty);
    });

    test('undo brings the formatting back with the text', () {
      final c = RichTextEditingController(text: 'one two');
      addTearDown(c.dispose);
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.toggle(_b);
      // Deleting the bold word, then undoing it as the field does.
      c.value = const TextEditingValue(
        text: 'one ',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(c.ranges, isEmpty);
      expect(c.prepareUndo(), isFalse);
      c.value = const TextEditingValue(
        text: 'one two',
        selection: TextSelection(baseOffset: 4, extentOffset: 7),
      );
      expect(c.ranges, [const FormatRange(4, 7, _b)]);
      // The next undo takes the ⌘B back.
      expect(c.prepareUndo(), isTrue);
      expect(c.ranges, isEmpty);
    });

    testWidgets('keeps the formatting while an input method composes', (
      tester,
    ) async {
      final c = RichTextEditingController(text: 'bold é');
      addTearDown(c.dispose);
      c
        ..selection = const TextSelection(baseOffset: 0, extentOffset: 4)
        ..toggle(_b)
        ..value = c.value.copyWith(
          composing: const TextRange(start: 5, end: 6),
        );
      late TextSpan span;
      await tester.pumpWidget(
        themed(
          Builder(
            builder: (context) {
              span = c.buildTextSpan(context: context, withComposing: true);
              return const SizedBox();
            },
          ),
        ),
      );
      final pieces = span.children!.cast<TextSpan>();
      expect(pieces.first.text, 'bold');
      expect(pieces.first.style!.fontWeight, FontWeight.w600);
      expect(pieces.last.text, 'é');
      expect(pieces.last.style!.decoration, TextDecoration.underline);
    });

    test('loads formatted text for editing', () {
      final c = RichTextEditingController()
        ..text = 'old'
        ..setFormatted('new text', const [FormatRange(0, 3, _b)]);
      expect(c.text, 'new text');
      expect(c.ranges, [const FormatRange(0, 3, _b)]);
      expect(c.selection, const TextSelection.collapsed(offset: 8));
    });
  });

  group('composer shortcuts', () {
    const labels = ComposerLabels(
      hint: 'Message',
      attach: 'Attach',
      emoji: 'Emoji',
      record: 'Record',
      send: 'Send',
      format: FormatLabels(
        bold: 'Bold',
        italic: 'Italic',
        underline: 'Underline',
        strikethrough: 'Strikethrough',
        monospace: 'Monospace',
        spoiler: 'Spoiler',
        quote: 'Quote',
        link: 'Link',
        plain: 'Plain text',
        linkTitle: 'Add link',
        linkHint: 'URL',
        apply: 'Apply',
        cancel: 'Cancel',
      ),
    );

    Future<RichTextEditingController> pump(WidgetTester tester) async {
      final c = RichTextEditingController(text: 'hello world');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.bottomCenter,
            child: Composer(labels: labels, controller: c, onSend: (_) {}),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();
      return c;
    }

    Future<void> press(
      WidgetTester tester,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) async {
      final command = defaultTargetPlatform == TargetPlatform.macOS
          ? LogicalKeyboardKey.metaLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(command);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(command);
      await tester.pump();
    }

    testWidgets('format the selection', (tester) async {
      final c = await pump(tester);
      await press(tester, LogicalKeyboardKey.keyB);
      await press(tester, LogicalKeyboardKey.keyI);
      await press(tester, LogicalKeyboardKey.keyX, shift: true);
      expect(c.ranges.map((r) => r.format).toSet(), {
        _b,
        _i,
        TextFormat.strikethrough,
      });
      await press(tester, LogicalKeyboardKey.keyB);
      expect(c.isActive(_b), isFalse);
      expect(c.text, 'hello world');
    });

    testWidgets('the selection menu formats and copies', (tester) async {
      final c = await pump(tester);
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      expect(state.showToolbar(), isTrue);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(SelectionMenu), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Plain text'), findsOneWidget);
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(c.isActive(_b), isTrue);
      expect(find.byType(SelectionMenu), findsNothing);
    });

    testWidgets('⌘K asks for a link', (tester) async {
      final c = await pump(tester);
      await press(tester, LogicalKeyboardKey.keyK);
      await tester.pumpAndSettle();
      expect(find.text('Add link'), findsOneWidget);

      await tester.enterText(
        find.byType(EditableText).last,
        'https://telegram.org',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(c.ranges, [
        const FormatRange(0, 5, TextFormat.link, url: 'https://telegram.org'),
      ]);
    });

    testWidgets('⌘Z takes back a format', (tester) async {
      final c = await pump(tester);
      await press(tester, LogicalKeyboardKey.keyB);
      expect(c.ranges, [const FormatRange(0, 5, _b)]);
      await press(tester, LogicalKeyboardKey.keyZ);
      expect(c.ranges, isEmpty);
      expect(c.text, 'hello world');
    });

    testWidgets('picks a suggestion with the keyboard', (tester) async {
      final picked = <int>[];
      final c = RichTextEditingController(text: '@');
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.bottomCenter,
            child: Composer(
              labels: labels,
              controller: c,
              onSend: (_) => fail('Enter picks the suggestion'),
              suggestions: const [
                ComposerSuggestion(title: 'Boris', subtitle: '@boris'),
                ComposerSuggestion(title: 'Vera'),
              ],
              onSuggestion: picked.add,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(find.text('Vera'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(picked, [1]);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(picked, [1, 1]);
    });

    testWidgets(
      'suggestions float over the chat and leave the composer alone',
      (tester) async {
        final c = RichTextEditingController();
        addTearDown(c.dispose);
        Widget build(List<ComposerSuggestion> suggestions) => themed(
          Align(
            alignment: Alignment.bottomCenter,
            child: Composer(
              labels: labels,
              controller: c,
              onSend: (_) {},
              suggestions: suggestions,
              onSuggestion: (_) {},
            ),
          ),
        );
        await tester.pumpWidget(build(const []));
        final bar = tester.getRect(find.byType(Composer));
        await tester.pumpWidget(
          build(const [
            ComposerSuggestion(title: 'Boris'),
            ComposerSuggestion(title: 'Vera'),
          ]),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.getRect(find.byType(Composer)), bar);
        final list = tester.getRect(find.byType(ComposerSuggestionList));
        expect(list.bottom, lessThanOrEqualTo(bar.top));
      },
    );

    testWidgets('suggestions stay inside a narrow pane', (tester) async {
      final c = RichTextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: 200,
              child: Composer(
                labels: labels,
                controller: c,
                onSend: (_) {},
                suggestions: const [ComposerSuggestion(title: 'Boris')],
                onSuggestion: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final list = tester.getRect(find.byType(ComposerSuggestionList));
      expect(list.right, lessThanOrEqualTo(200));
    });

    testWidgets('suggestions clear a bar above the composer', (tester) async {
      final c = RichTextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          Align(
            alignment: Alignment.bottomCenter,
            child: Composer(
              labels: labels,
              controller: c,
              onSend: (_) {},
              suggestionsLift: 80,
              suggestions: const [ComposerSuggestion(title: 'Boris')],
              onSuggestion: (_) {},
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final bar = tester.getRect(find.byType(Composer));
      final list = tester.getRect(find.byType(ComposerSuggestionList));
      expect(list.bottom, lessThanOrEqualTo(bar.top - 80));
    });

    testWidgets('the bar is 50 px and the action is a 32 px accent square', (
      tester,
    ) async {
      final c = RichTextEditingController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        themed(
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [Composer(labels: labels, controller: c, onSend: (_) {})],
          ),
        ),
      );
      // 50 px plus the hairline above it.
      expect(tester.getSize(find.byType(Composer)).height, 51);
      expect(find.byType(MgRecordButton), findsOneWidget);
      expect(find.byType(MgSendButton), findsNothing);
      expect(tester.getSize(find.byType(MgRecordButton)), const Size(32, 32));
      await tester.enterText(find.byType(EditableText), 'Hi');
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MgSendButton), findsOneWidget);
      expect(tester.getSize(find.byType(MgSendButton)), const Size(32, 32));
    });
  });
}
