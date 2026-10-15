import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

/// Every request a privacy switch can hold back, by switch.
final _readRequests = <td.TdFunction<td.TdObject>>[
  const td.ViewMessages(
    chatId: 7,
    messageIds: [1, 5, 3],
    source: td.MessageSourceChatHistory(),
    forceRead: false,
  ),
  const td.ReadAllChatMentions(chatId: 7),
  const td.ReadAllChatReactions(chatId: 7),
  const td.ReadAllChatPollVotes(chatId: 7),
  const td.ReadAllForumTopicMentions(chatId: 7, forumTopicId: 1),
  const td.ReadAllForumTopicReactions(chatId: 7, forumTopicId: 1),
  const td.ReadAllForumTopicPollVotes(chatId: 7, forumTopicId: 1),
  const td.ReadAllDirectMessagesChatTopicReactions(chatId: 7, topicId: 1),
  const td.ReadChatList(chatList: td.ChatListMain()),
];
const _typing = td.SendChatAction(
  chatId: 7,
  businessConnectionId: '',
  action: td.ChatActionTyping(),
);
const _online = td.SetOption(
  name: 'online',
  value: td.OptionValueBoolean(value: true),
);
const _opened = td.OpenMessageContent(chatId: 7, messageId: 5);

/// Requests no switch touches.
final _others = <td.TdFunction<td.TdObject>>[
  const td.OpenChat(chatId: 7),
  const td.GetChatHistory(
    chatId: 7,
    fromMessageId: 0,
    offset: 0,
    limit: 10,
    onlyLocal: false,
  ),
  const td.SetOption(
    name: 'online',
    value: td.OptionValueBoolean(value: false),
  ),
  const td.SetOption(
    name: 'notification_group_count_max',
    value: td.OptionValueInteger(value: 3),
  ),
];

final _all = [..._readRequests, _typing, _online, _opened, ..._others];

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late td.TdClient client;
  late PrivacyGuard guard;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    client = tdlib.createClient();
    guard = PrivacyGuard(client);
  });

  tearDown(() async {
    await guard.dispose();
    await tdlib.close();
  });

  /// The request types that reached TDLib out of [_all].
  Future<List<String>> sendAll() async {
    json.sent.clear();
    for (final request in _all) {
      await client.send(request);
    }
    return [for (final r in json.sent) r['@type']! as String];
  }

  List<String> typesOf(Iterable<td.TdFunction<td.TdObject>> requests) => [
    for (final r in requests) r.tdType,
  ];

  test('passes everything while every switch is off', () async {
    expect(await sendAll(), typesOf(_all));
  });

  test('hiding read receipts holds back exactly the reads', () async {
    guard.settings = const PrivacySettings(hideReadReceipts: true);
    expect(await sendAll(), typesOf([_typing, _online, _opened, ..._others]));
  });

  test('hiding typing holds back exactly the chat actions', () async {
    guard.settings = const PrivacySettings(hideTyping: true);
    expect(
      await sendAll(),
      typesOf([..._readRequests, _online, _opened, ..._others]),
    );
  });

  test('staying offline holds back exactly going online', () async {
    guard.settings = const PrivacySettings(stayOffline: true);
    expect(
      await sendAll(),
      typesOf([..._readRequests, _typing, _opened, ..._others]),
    );
  });

  test('hiding opened content holds back exactly openMessageContent', () async {
    guard.settings = const PrivacySettings(hideContentOpened: true);
    expect(
      await sendAll(),
      typesOf([..._readRequests, _typing, _online, ..._others]),
    );
  });

  test('ghost mode holds back all of them', () async {
    guard.settings = const PrivacySettings().withGhost(true);
    expect(guard.settings.isGhost, isTrue);
    expect(await sendAll(), typesOf(_others));
  });

  test('a chat can be read silently on its own', () async {
    guard.settings = const PrivacySettings().withSilentRead(7, true);
    await client.send(_readRequests.first);
    await client.send(
      const td.ViewMessages(
        chatId: 8,
        messageIds: [2],
        source: td.MessageSourceChatHistory(),
        forceRead: false,
      ),
    );
    await client.send(const td.ReadChatList(chatList: td.ChatListMain()));

    expect(json.sent.map((r) => (r['@type'], r['chat_id'])), [
      ('viewMessages', 8),
      ('readChatList', null),
    ]);
  });

  test('remembers what was seen while reads were held back', () async {
    guard.settings = const PrivacySettings(hideReadReceipts: true);
    final changed = <int>[];
    guard.seenChanges.listen(changed.add);

    await client.send(_readRequests.first);
    await client.send(
      const td.ViewMessages(
        chatId: 7,
        messageIds: [2],
        source: td.MessageSourceChatHistory(),
        forceRead: false,
      ),
    );

    expect(guard.readUpTo(7), 5);
    expect(guard.readUpTo(8), 0);
    expect(changed, [7]);
  });

  test('goes offline once signed in, and when the switch turns on', () async {
    final offline = PrivacyGuard(
      tdlib.createClient(),
      settings: const PrivacySettings(stayOffline: true),
    );
    addTearDown(offline.dispose);
    json.push(2, {
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateReady'},
    });
    json.push(1, {
      '@type': 'updateAuthorizationState',
      'authorization_state': {'@type': 'authorizationStateReady'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(json.sent, hasLength(1));
    expect(json.sent.single['@client'], 2);
    expect(json.sent.single['name'], 'online');
    expect(json.sent.single['value'], {
      '@type': 'optionValueBoolean',
      'value': false,
    });

    guard.settings = const PrivacySettings(stayOffline: true);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(json.sent.last['@client'], 1);
    expect(json.sent.last['name'], 'online');
    expect(json.sent.last['value'], {
      '@type': 'optionValueBoolean',
      'value': false,
    });
  });

  group('PrivacySettings', () {
    test('round-trips through JSON', () {
      final settings = const PrivacySettings(
        hideTyping: true,
        stayOffline: true,
      ).withSilentRead(42, true);
      final json = jsonDecode(jsonEncode(settings.toJson()));

      expect(PrivacySettings.fromJson(json), settings);
    });

    test('reads anything unexpected as off', () {
      expect(PrivacySettings.fromJson(null), const PrivacySettings());
      expect(
        PrivacySettings.fromJson({
          'hide_typing': 'yes',
          'silent_read_chats': ['a', 3],
        }),
        const PrivacySettings(silentReadChats: {3}),
      );
    });

    test('ghost mode is every switch at once', () {
      const ghost = PrivacySettings.ghost();
      expect(ghost.isGhost, isTrue);
      expect(ghost.copyWith(hideTyping: false).isGhost, isFalse);
      expect(ghost.withGhost(false), const PrivacySettings());
    });
  });
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();

  /// Requests, each with its client id under `@client`.
  final sent = <Map<String, Object?>>[];
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
    if (decoded['@type'] != 'close') {
      sent.add({...decoded, '@client': clientId});
    }
    final response = decoded['@type'] == 'getChatHistory'
        ? {'@type': 'messages', 'total_count': 0, 'messages': <Object?>[]}
        : {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push(clientId, {
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(int clientId, Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': clientId}));
}
