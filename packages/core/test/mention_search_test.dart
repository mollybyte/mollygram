import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late MentionSearch mentions;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    mentions = MentionSearch(tdlib.createClient());
    await mentions.start();
  });

  tearDown(() async {
    await mentions.dispose();
    await tdlib.close();
  });

  test('offers members with their usernames, never yourself', () async {
    json.push({
      '@type': 'updateOption',
      'name': 'my_id',
      'value': {'@type': 'optionValueInteger', 'value': '1'},
    });
    await pumpEventQueue();

    final found = await mentions.search(20, 'b');

    final request = json.sent.firstWhere(
      (r) => r['@type'] == 'searchChatMembers',
    );
    expect(request['query'], 'b');
    expect((request['filter']! as Map)['@type'], 'chatMembersFilterMention');
    expect(
      [for (final c in found) (c.userId, c.name, c.username)],
      [(2, 'Boris Ivanov', 'boris'), (3, 'Bella', '')],
    );
  });
}

Map<String, Object?> _user(int id, String first, String last, String name) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': last,
  'status': {'@type': 'userStatusEmpty'},
  'type': {'@type': 'userTypeRegular'},
  if (name.isNotEmpty)
    'usernames': {
      '@type': 'usernames',
      'active_usernames': [name],
      'editable_username': name,
    },
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  final _users = {
    1: _user(1, 'Me', '', 'me'),
    2: _user(2, 'Boris', 'Ivanov', 'boris'),
    3: _user(3, 'Bella', '', ''),
  };

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
    sent.add(decoded);
    final response = switch (decoded['@type']) {
      'searchChatMembers' => {
        '@type': 'chatMembers',
        'total_count': 3,
        'members': [
          for (final id in [1, 2, 3])
            {
              '@type': 'chatMember',
              'member_id': {'@type': 'messageSenderUser', 'user_id': id},
              'status': {'@type': 'chatMemberStatusMember'},
            },
        ],
      },
      'getUser' => _users[decoded['user_id']]!,
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
