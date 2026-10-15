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
    final links = <String>[];
    final spans = buildEntitySpans(
      text,
      colors: MgColors.light,
      onLink: (url) {
        links.add(url);
        return TapGestureRecognizer();
      },
    );
    expect(links, ['tg://user?id=55', '#news', '/start']);
    final linked = [
      for (final span in spans)
        if (span is TextSpan && span.recognizer != null) span.text,
    ];
    expect(linked, ['Anna', '#news', '/start']);
  });
}
