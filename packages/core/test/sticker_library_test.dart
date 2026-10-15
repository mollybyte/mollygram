import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late td.Td tdlib;
  tearDown(() => tdlib.close());

  (StickerLibrary, _FakeTdJson) library(
    Map<String, Map<String, Object?>> responses,
  ) {
    final json = _FakeTdJson(responses);
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    return (StickerLibrary(tdlib.createClient()), json);
  }

  test('asks TDLib for regular sticker sets', () async {
    final (stickers, client) = library({
      'getInstalledStickerSets': {
        '@type': 'stickerSets',
        'total_count': 1,
        'sets': [
          {
            '@type': 'stickerSetInfo',
            'id': 55,
            'title': 'Cats',
            'name': 'cats',
            'sticker_type': {'@type': 'stickerTypeRegular'},
            'size': 2,
            'covers': <Object?>[],
          },
        ],
      },
    });
    final sets = await stickers.installedSets();

    expect(sets.single.title, 'Cats');
    expect(client.sent.single, {
      '@type': 'getInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeRegular'},
    });
  });

  test('turns emoji keywords into distinct emoji', () async {
    final (stickers, client) = library({
      'searchEmojis': {
        '@type': 'emojiKeywords',
        'emoji_keywords': [
          {'@type': 'emojiKeyword', 'emoji': '🐈', 'keyword': 'кот'},
          {'@type': 'emojiKeyword', 'emoji': '🐱', 'keyword': 'котик'},
          {'@type': 'emojiKeyword', 'emoji': '🐈', 'keyword': 'кошка'},
        ],
      },
    });
    expect(await stickers.searchEmoji(' кот ', languages: ['ru', 'en']), [
      '🐈',
      '🐱',
    ]);
    expect(client.sent.single, {
      '@type': 'searchEmojis',
      'text': 'кот',
      'input_language_codes': ['ru', 'en'],
    });
    expect(await stickers.searchEmoji('  '), isEmpty);
    expect(client.sent, hasLength(1));
  });
}

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this.responses);

  final Map<String, Map<String, Object?>> responses;
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  @override
  int createClientId() => 1;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final extra = decoded.remove('@extra');
    if (responses.containsKey(decoded['@type'])) sent.add(decoded);
    _queue.add(
      jsonEncode({
        ...responses[decoded['@type']] ?? {'@type': 'ok'},
        '@client_id': clientId,
        '@extra': extra,
      }),
    );
    if (decoded['@type'] == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': clientId,
        }),
      );
    }
  }
}
