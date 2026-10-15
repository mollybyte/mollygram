import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/chat/describe.dart';
import 'package:mollygram/src/chat/file_content.dart';
import 'package:mollygram/src/chat/message_tile.dart';
import 'package:mollygram/src/chat/timeline.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

void main() {
  test('groups an album into one row and dates each day', () {
    final day = 1760011200;
    final items = timelineItems([
      _message(5, date: day + 300, sender: 2),
      _message(4, date: day + 200, sender: 2, album: 9),
      _message(3, date: day + 100, sender: 2, album: 9),
      _message(2, date: day - 86400, sender: 3),
    ], reachedStart: true);

    expect(items.map((i) => i.runtimeType), [
      TimelineRow,
      TimelineRow,
      TimelineDate,
      TimelineRow,
      TimelineDate,
    ]);
    final album = items[1] as TimelineRow;
    expect(album.row.messages.map((m) => m.id), [3, 4]);
    // Boris's text continues the run his album started.
    expect((items[0] as TimelineRow).startsRun, isFalse);
    expect(album.startsRun, isTrue);
  });

  test('leaves the oldest day undated until the start is loaded', () {
    final items = timelineItems([
      _message(2, date: 1760011200, sender: 2),
    ], reachedStart: false);
    expect(items.single, isA<TimelineRow>());
  });

  test('gives every channel post its own name and photo', () {
    final day = 1760011200;
    final messages = [
      _message(3, date: day + 200, sender: 2),
      _message(2, date: day + 100, sender: 2),
    ];
    final group = timelineItems(messages, reachedStart: false);
    final channel = timelineItems(
      messages,
      reachedStart: false,
      isChannel: true,
    );

    expect((group.first as TimelineRow).startsRun, isFalse);
    expect((channel.first as TimelineRow).startsRun, isTrue);
    expect((channel.first as TimelineRow).endsRun, isTrue);
  });

  test('says "Forwarded messages" once over forwards in a row', () {
    final day = 1760011200;
    final items = timelineItems([
      _message(4, date: day + 300, sender: 2, forwarded: true),
      _message(3, date: day + 200, sender: 2, forwarded: true),
      _message(2, date: day + 100, sender: 2),
    ], reachedStart: false);
    final rows = items.cast<TimelineRow>();

    expect(rows.map((r) => r.startsForwards), [false, true, false]);
  });

  test('splits albums into rows', () {
    expect(albumRows(1, 1), [1]);
    expect(albumRows(3, 1.6), [1, 2]);
    expect(albumRows(3, 0.7), [3]);
    expect(albumRows(10, 1), [2, 2, 3, 3]);
  });

  test('draws only short emoji-only texts large', () {
    expect(isEmojiOnly('👍'), isTrue);
    expect(isEmojiOnly('👍🏔️'), isTrue);
    expect(isEmojiOnly('🇷🇺'), isTrue);
    expect(isEmojiOnly('👍👍👍👍'), isFalse);
    expect(isEmojiOnly('ok 👍'), isFalse);
    expect(isEmojiOnly('1'), isFalse);
  });

  test('formats durations and decodes waveforms', () {
    expect(formatDuration(7), '0:07');
    expect(formatDuration(3723), '1:02:03');
    // Two samples of 5 bits: 31 and 1.
    expect(decodeWaveform(Uint8List.fromList([0x3F, 0x00])).take(2), [31, 1]);
  });
}

ConversationMessage _message(
  int id, {
  required int date,
  required int sender,
  int album = 0,
  bool forwarded = false,
}) => ConversationMessage(
  td.Message.fromJson({
    '@type': 'message',
    'id': id,
    if (forwarded)
      'forward_info': {
        '@type': 'messageForwardInfo',
        'origin': {'@type': 'messageOriginUser', 'sender_user_id': 4},
        'date': date - 600,
      },
    'sender_id': {'@type': 'messageSenderUser', 'user_id': sender},
    'chat_id': 7,
    'date': date,
    'media_album_id': '$album',
    'content': album == 0
        ? {
            '@type': 'messageText',
            'text': {
              '@type': 'formattedText',
              'text': 'x',
              'entities': <Object?>[],
            },
          }
        : {
            '@type': 'messagePhoto',
            'photo': {'@type': 'photo', 'sizes': <Object?>[]},
            'caption': {
              '@type': 'formattedText',
              'text': '',
              'entities': <Object?>[],
            },
          },
  }),
);
