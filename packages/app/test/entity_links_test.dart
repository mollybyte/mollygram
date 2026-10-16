import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/chat/formatted_text.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  test('mentions by name, hashtags and bot commands are links', () {
    const text = td.FormattedText(
      text: 'Anna #news /start',
      entities: [
        td.TextEntity(
          offset: 0,
          length: 4,
          type: td.TextEntityTypeMentionName(userId: 55),
        ),
        td.TextEntity(offset: 5, length: 5, type: td.TextEntityTypeHashtag()),
        td.TextEntity(
          offset: 11,
          length: 6,
          type: td.TextEntityTypeBotCommand(),
        ),
      ],
    );
    final taps = <String>[];
    List<String?> linked({bool inChat = true}) => [
      for (final span in buildEntitySpans(
        text,
        colors: MgColors.light,
        onLink: (url) {
          taps.add('link $url');
          return TapGestureRecognizer();
        },
        onHashtag: (tag) {
          taps.add('hashtag $tag');
          return TapGestureRecognizer();
        },
        onBotCommand: inChat
            ? (command) {
                taps.add('command $command');
                return TapGestureRecognizer();
              }
            : null,
      ))
        if (span is TextSpan && span.recognizer != null) span.text,
    ];
    expect(linked(), ['Anna', '#news', '/start']);
    expect(taps, ['link tg://user?id=55', 'hashtag #news', 'command /start']);
    // Outside a chat a command has nowhere to go.
    expect(linked(inChat: false), ['Anna', '#news']);
  });

  test('a link whose target reads like a command stays a link', () {
    const text = td.FormattedText(
      text: 'press',
      entities: [
        td.TextEntity(
          offset: 0,
          length: 5,
          type: td.TextEntityTypeTextUrl(url: '/start'),
        ),
      ],
    );
    final taps = <String>[];
    buildEntitySpans(
      text,
      colors: MgColors.light,
      onLink: (url) {
        taps.add('link $url');
        return TapGestureRecognizer();
      },
      onBotCommand: (command) {
        taps.add('command $command');
        return TapGestureRecognizer();
      },
    );
    expect(taps, ['link /start']);
  });

  test('inline code and code blocks hand their text to be copied', () {
    const text = td.FormattedText(
      text: 'key abc-123 and x = 1',
      entities: [
        td.TextEntity(offset: 4, length: 7, type: td.TextEntityTypeCode()),
        td.TextEntity(offset: 16, length: 5, type: td.TextEntityTypePre()),
      ],
    );
    final copied = <String>[];
    final spans = buildEntitySpans(
      text,
      colors: MgColors.light,
      onCode: (code) {
        copied.add(code);
        return TapGestureRecognizer();
      },
    );
    expect(copied, ['abc-123', 'x = 1']);
    expect(
      [
        for (final span in spans)
          if (span is TextSpan && span.recognizer != null) span.text,
      ],
      ['abc-123', 'x = 1'],
    );
  });
}
