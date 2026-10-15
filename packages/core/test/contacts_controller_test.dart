import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ContactsController contacts;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    contacts = ContactsController(tdlib.createClient());
    await contacts.start();
  });

  tearDown(() async {
    await contacts.dispose();
    await tdlib.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  test('loads contacts sorted by name, asking for unknown users', () async {
    json
      ..contactIds = [1, 2]
      ..push(_updateUser(2, 'boris', contact: true));
    await settle();

    await contacts.load();

    expect(
      [for (final c in contacts.contacts) c.name],
      ['Anna Petrova', 'boris'],
    );
    expect(json.sent.map((r) => r['@type']), ['getContacts', 'getUser']);
    expect(json.sent.last['user_id'], 1);
    expect(contacts.user(1)!.username, 'anna');
    expect(contacts.isLoaded, isTrue);
  });

  test('follows status changes', () async {
    await contacts.load();
    var changes = 0;
    contacts.changes.listen((_) => changes++);

    json.push({
      '@type': 'updateUserStatus',
      'user_id': 1,
      'status': {'@type': 'userStatusOffline', 'was_online': 1700000000},
    });
    await settle();

    final presence = contacts.user(1)!.presence;
    expect(presence.kind, PresenceKind.offline);
    expect(
      presence.wasOnline,
      DateTime.fromMillisecondsSinceEpoch(1.7e12 ~/ 1),
    );
    expect(changes, 1);
  });

  test('a contact added or removed elsewhere updates the list', () async {
    await contacts.load();
    json.push(_updateUser(3, 'Vera', contact: true));
    json.push(_updateUser(1, 'Anna', contact: false));
    await settle();

    expect([for (final c in contacts.contacts) c.id], [3]);
  });

  test('keeps contact changes that arrive while the list loads', () async {
    json
      ..contactIds = [1]
      // Arrives after getContacts answered, while user 1 is fetched.
      ..beforeUser = [
        _updateUser(3, 'Vera', contact: true),
        _updateUser(1, 'Anna', contact: false),
      ];

    await contacts.load();

    expect([for (final c in contacts.contacts) c.id], [3]);
  });

  test('adds a contact by phone number', () async {
    await contacts.load();
    json.importedUserId = 5;
    json.push(_updateUser(5, 'Gleb', contact: true));
    await settle();

    final result = await contacts.add(
      phoneNumber: '+79990001122',
      firstName: 'Gleb',
    );

    expect(result, isA<ContactAdded>());
    expect((result as ContactAdded).userId, 5);
    final request = json.sent.last;
    expect(request['@type'], 'importContacts');
    expect(
      (request['contacts'] as List).single,
      containsPair('phone_number', '+79990001122'),
    );
    expect(contacts.contacts.map((c) => c.id), contains(5));
  });

  test('reports a number that is not on Telegram', () async {
    json.importedUserId = 0;
    expect(
      await contacts.add(phoneNumber: '+10000000000', firstName: 'Nobody'),
      isA<NotOnTelegram>(),
    );
  });

  test('removes a contact', () async {
    await contacts.load();
    await contacts.remove(1);

    expect(json.sent.last['@type'], 'removeContacts');
    expect(json.sent.last['user_ids'], [1]);
    expect(contacts.contacts, isEmpty);
  });

  test('searches contacts and public usernames', () async {
    final found = await contacts.search('ann');
    expect(found.map((c) => c.id), [1]);
    expect(json.sent.first['@type'], 'searchContacts');

    expect(await contacts.searchPublic('durov'), [42]);
    json.failPublic = true;
    expect(await contacts.searchPublic('durov'), isEmpty);
    expect(await contacts.searchPublic('  '), isEmpty);
  });

  test('finds people with a private chat among known chats', () async {
    final found = await contacts.search('ann', includeChats: true);

    // Contact 1 first, then the private chat 7; the group -100 is skipped.
    expect(found.map((c) => c.id), [1, 7]);
    expect(
      json.sent.map((r) => r['@type']),
      containsAll(['searchContacts', 'searchChats']),
    );
    expect(json.sent.where((r) => r['user_id'] == -100), isEmpty);
  });

  test('opens the private chat of a user', () async {
    expect(await contacts.privateChat(1), 1);
    expect(json.sent.last['@type'], 'createPrivateChat');
  });

  test('reads presence from every status', () {
    expect(
      Presence.from(const td.UserStatusOnline(expires: 1)).kind,
      PresenceKind.online,
    );
    expect(
      Presence.from(const td.UserStatusRecently(byMyPrivacySettings: false))
          .kind,
      PresenceKind.recently,
    );
    expect(
      Presence.from(const td.UserStatusEmpty()).kind,
      PresenceKind.unknown,
    );
  });
}

Map<String, Object?> _user(
  int id,
  String first, {
  String last = '',
  String username = '',
  bool contact = false,
}) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': last,
  'phone_number': '',
  'status': {'@type': 'userStatusOnline', 'expires': 1},
  'type': {'@type': 'userTypeRegular'},
  'is_contact': contact,
  if (username.isNotEmpty)
    'usernames': {
      '@type': 'usernames',
      'active_usernames': [username],
      'disabled_usernames': <String>[],
      'editable_username': username,
      'collectible_usernames': <String>[],
    },
};

Map<String, Object?> _updateUser(
  int id,
  String first, {
  bool contact = false,
}) => {'@type': 'updateUser', 'user': _user(id, first, contact: contact)};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var importedUserId = 0;
  var contactIds = [1];
  var failPublic = false;

  /// Updates delivered just before the next getUser answer.
  var beforeUser = <Map<String, Object?>>[];

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
    if (decoded['@type'] != 'close') sent.add(decoded);
    if (decoded['@type'] == 'getUser') {
      beforeUser.forEach(push);
      beforeUser = [];
    }
    final Map<String, Object?> response = switch (decoded['@type']) {
      'getContacts' => {
        '@type': 'users',
        'total_count': contactIds.length,
        'user_ids': contactIds,
      },
      'searchContacts' => {
        '@type': 'users',
        'total_count': 1,
        'user_ids': [1],
      },
      'getUser' => _user(
        decoded['user_id']! as int,
        'Anna',
        last: 'Petrova',
        username: 'anna',
        contact: true,
      ),
      'searchChats' => {
        '@type': 'chats',
        'total_count': 2,
        'chat_ids': [7, -100],
      },
      'searchPublicChats' when failPublic => {
        '@type': 'error',
        'code': 400,
        'message': 'NETWORK',
      },
      'searchPublicChats' => {
        '@type': 'chats',
        'total_count': 1,
        'chat_ids': [42],
      },
      'importContacts' => {
        '@type': 'importedContacts',
        'user_ids': [importedUserId],
        'importer_count': [0],
      },
      'createPrivateChat' => {
        '@type': 'chat',
        'id': decoded['user_id'],
        'type': {'@type': 'chatTypePrivate', 'user_id': decoded['user_id']},
        'title': 'Anna',
        'permissions': {'@type': 'chatPermissions'},
        'positions': <Object?>[],
        'chat_lists': <Object?>[],
        'notification_settings': {'@type': 'chatNotificationSettings'},
        'available_reactions': {
          '@type': 'chatAvailableReactionsAll',
          'max_reaction_count': 11,
        },
        'video_chat': {'@type': 'videoChat'},
      },
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
