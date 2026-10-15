import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatSearchController search;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    search = ChatSearchController(tdlib.createClient());
  });

  tearDown(() => tdlib.close());

  test('sends the query, the sender and the filter', () async {
    json.matches = [30, 20];
    final page = await search.search(
      7,
      query: 'lease',
      senderUserId: 5,
      kind: SharedMediaKind.files,
    );
    final request = json.sent.single;
    expect(request['@type'], 'searchChatMessages');
    expect(request['chat_id'], 7);
    expect(request['query'], 'lease');
    expect(request['from_message_id'], 0);
    expect((request['sender_id']! as Map)['user_id'], 5);
    expect(
      (request['filter']! as Map)['@type'],
      'searchMessagesFilterDocument',
    );
    expect([for (final m in page.messages) m.id], [30, 20]);
    expect(page.totalCount, 2);
    expect(page.hasMore, isFalse);
  });

  test('maps every shared media tab to a filter', () {
    expect(
      [for (final k in SharedMediaKind.values) k.filter.tdType],
      [
        'searchMessagesFilterPhotoAndVideo',
        'searchMessagesFilterDocument',
        'searchMessagesFilterUrl',
        'searchMessagesFilterVoiceNote',
        'searchMessagesFilterAudio',
      ],
    );
  });

  group('results', () {
    test('start at the newest and step to older ones', () async {
      json.matches = [50, 40, 30];
      final results = search.find(7, 'hi');
      expect(await results.start(), 50);
      expect(results.index, 0);
      expect(results.count, 3);
      expect(results.hasNewer, isFalse);
      expect(results.hasOlder, isTrue);
      expect(await results.older(), 40);
      expect(await results.older(), 30);
      expect(await results.older(), isNull);
      expect(results.index, 2);
      expect(results.newer(), 40);
      expect(results.newer(), 50);
      expect(results.newer(), isNull);
    });

    test('load the next page at the end of the loaded ones', () async {
      json
        ..matches = [90, 80, 70, 60, 50]
        ..pageSize = 2;
      final results = search.find(7, 'hi');
      await results.start();
      expect(results.count, 5);
      expect(json.sent, hasLength(1));
      await results.older();
      expect(await results.older(), 70);
      expect(json.sent, hasLength(2));
      expect(json.sent.last['from_message_id'], 80);
      expect(await results.older(), 60);
      expect(await results.older(), 50);
      expect(results.hasOlder, isFalse);
      expect(await results.older(), isNull);
      expect(json.sent, hasLength(3));
    });

    test('are empty when nothing matches', () async {
      json.matches = [];
      final results = search.find(7, 'zzz');
      expect(await results.start(), isNull);
      expect(results.index, isNull);
      expect(results.count, 0);
      expect(await results.older(), isNull);
      expect(results.newer(), isNull);
    });

    test('pressing the arrow twice loads one page', () async {
      json
        ..matches = [90, 80, 70]
        ..pageSize = 1;
      final results = search.find(7, 'hi');
      await results.start();
      final first = results.older();
      final second = results.older();
      expect(await first, 80);
      expect(await second, 70);
      expect(json.sent, hasLength(3));
    });
  });

  test('shared media loads page by page until complete', () async {
    json
      ..matches = [9, 8, 7]
      ..pageSize = 2;
    final list = search.sharedMedia(7, SharedMediaKind.media);
    expect(list.totalCount, -1);
    expect(await list.loadMore(), isTrue);
    expect([for (final m in list.messages) m.id], [9, 8]);
    expect(list.isComplete, isFalse);
    expect(list.totalCount, 3);
    expect(await list.loadMore(), isTrue);
    expect([for (final m in list.messages) m.id], [9, 8, 7]);
    expect(list.isComplete, isTrue);
    expect(await list.loadMore(), isFalse);
    expect(json.sent, hasLength(2));
    expect(
      (json.sent.first['filter']! as Map)['@type'],
      'searchMessagesFilterPhotoAndVideo',
    );
  });
}

/// Answers `searchChatMessages` from [matches] (newest first), [pageSize]
/// at a time, the way TDLib pages: from_message_id excludes itself.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var matches = <int>[];
  var pageSize = 100;
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    if (decoded['@type'] != 'close') sent.add(decoded);
    Map<String, Object?> response = {'@type': 'ok'};
    if (decoded['@type'] == 'searchChatMessages') {
      final from = decoded['from_message_id']! as int;
      final rest = [
        for (final id in matches)
          if (from == 0 || id < from) id,
      ];
      final page = rest.take(pageSize).toList();
      response = {
        '@type': 'foundChatMessages',
        'total_count': matches.length,
        'messages': [
          for (final id in page) tdMessage(id: id, chatId: 7).toJson(),
        ],
        'next_from_message_id': rest.length > page.length ? page.last : 0,
      };
    }
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': 1,
        }),
      );
    }
  }
}
