import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/compose/mention_suggester.dart';
import 'package:mollygram/src/compose/rich_text_bridge.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  group('draft to TDLib', () {
    test('applies Markdown and maps every format to an entity', () {
      final text = formattedDraft('**hi** `x` code\nblock link Vera', const [
        FormatRange(11, 21, TextFormat.monospace),
        FormatRange(22, 26, TextFormat.link, url: 'https://t.me'),
        FormatRange(27, 31, TextFormat.mention, userId: 9),
        FormatRange(0, 6, TextFormat.spoiler),
      ]);
      expect(text.text, 'hi x code\nblock link Vera');
      expect(
        [for (final e in text.entities) (e.offset, e.length, e.type.tdType)],
        [
          (0, 2, 'textEntityTypeBold'),
          (0, 2, 'textEntityTypeSpoiler'),
          (3, 1, 'textEntityTypeCode'),
          (5, 10, 'textEntityTypePre'),
          (16, 4, 'textEntityTypeTextUrl'),
          (21, 4, 'textEntityTypeMentionName'),
        ],
      );
    });

    test('sends custom emoji as entities and reads them back', () {
      final text = formattedDraft('a😀😀b', const [
        FormatRange(1, 3, TextFormat.customEmoji, emojiId: 7),
        FormatRange(3, 5, TextFormat.customEmoji, emojiId: 7),
      ]);
      expect(text.entities.map((e) => (e.offset, e.length)), [(1, 2), (3, 2)]);
      expect(
        (text.entities.first.type as td.TextEntityTypeCustomEmoji)
            .customEmojiId,
        7,
      );
      expect(draftRanges(text), [
        const FormatRange(1, 3, TextFormat.customEmoji, emojiId: 7),
        const FormatRange(3, 5, TextFormat.customEmoji, emojiId: 7),
      ]);
    });

    test('sends no mention without a user', () {
      final text = formattedDraft('Vera', const [
        FormatRange(0, 4, TextFormat.mention),
      ]);
      expect(text.entities, isEmpty);
    });

    test('reads back what the composer can show, not detected links', () {
      const sent = td.FormattedText(
        text: 'bold t.me @boris',
        entities: [
          td.TextEntity(offset: 0, length: 4, type: td.TextEntityTypeBold()),
          td.TextEntity(offset: 5, length: 4, type: td.TextEntityTypeUrl()),
          td.TextEntity(
            offset: 10,
            length: 6,
            type: td.TextEntityTypeMention(),
          ),
        ],
      );
      expect(draftRanges(sent), [const FormatRange(0, 4, TextFormat.bold)]);
      expect(
        sameDraft(sent, formattedDraft('**bold** t.me @boris', const [])),
        isTrue,
      );
      expect(
        sameDraft(sent, formattedDraft('bold t.me @boris', const [])),
        isFalse,
      );
    });
  });

  group('mentions', () {
    late RichTextEditingController draft;
    late MentionSuggester suggester;
    final queries = <String>[];

    setUp(() {
      queries.clear();
      draft = RichTextEditingController();
      suggester = MentionSuggester(
        controller: draft,
        search: (query) async {
          queries.add(query);
          return [
            const MentionCandidate(userId: 2, name: 'Boris', username: 'boris'),
            const MentionCandidate(userId: 3, name: 'Bella'),
          ];
        },
        delay: Duration.zero,
      );
    });

    tearDown(() {
      suggester.dispose();
      draft.dispose();
    });

    void type(String text) => draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test('searches for the @word and inserts the pick', () async {
      type('hey @b');
      await settle();
      expect(queries, ['b']);
      expect(suggester.suggestions.map((s) => s.subtitle), ['@boris', '']);

      suggester.pick(1);
      expect(draft.text, 'hey Bella ');
      expect(draft.ranges, [
        const FormatRange(4, 9, TextFormat.mention, userId: 3),
      ]);
      expect(suggester.suggestions, isEmpty);
    });

    test('Esc hides the popup until the word changes', () async {
      type('@b');
      await settle();
      suggester.dismiss();
      expect(suggester.suggestions, isEmpty);
      draft.selection = const TextSelection.collapsed(offset: 2);
      await settle();
      expect(suggester.suggestions, isEmpty);

      type('@bo');
      await settle();
      expect(suggester.suggestions, hasLength(2));
    });

    test('another chat offers the dismissed word again', () async {
      type('@b');
      await settle();
      suggester.dismiss();
      suggester.reset();
      await settle();
      expect(suggester.suggestions, hasLength(2));
    });

    test('a search that ends after dispose stays quiet', () async {
      final pending = Completer<List<MentionCandidate>>();
      final other = RichTextEditingController();
      final quiet = MentionSuggester(
        controller: other,
        search: (_) => pending.future,
        delay: Duration.zero,
      );
      quiet.addListener(() => fail('notified after dispose'));
      other.value = const TextEditingValue(
        text: '@b',
        selection: TextSelection.collapsed(offset: 2),
      );
      await settle();
      quiet.dispose();
      pending.complete(const [MentionCandidate(userId: 2, name: 'Boris')]);
      await settle();
      other.dispose();
    });
  });
}
