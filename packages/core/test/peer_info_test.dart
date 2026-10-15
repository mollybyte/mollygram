import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late PeerInfoController peers;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    peers = PeerInfoController(tdlib.createClient());
    await peers.start();
  });

  tearDown(() async {
    await peers.dispose();
    await tdlib.close();
  });

  group('a private chat', () {
    setUp(() {
      json.answers
        ..['getChat'] = _chat(
          10,
          'Alina Petrova',
          type: {'@type': 'chatTypePrivate', 'user_id': 5},
        )
        ..['getUser'] = _user(
          5,
          'Alina',
          'Petrova',
          phone: '79001234567',
          usernames: ['alina_old', 'alina'],
          editable: 'alina',
        )
        ..['getUserFullInfo'] = _userFull(
          bio: 'Designer',
          birthdate: {'@type': 'birthdate', 'day': 3, 'month': 9, 'year': 0},
        )
        ..['getScopeNotificationSettings'] = _scope(muteFor: 0)
        ..['getPhoneNumberInfo'] = {
          '@type': 'phoneNumberInfo',
          'country_calling_code': '7',
          'formatted_phone_number': '900 123 4567',
        };
    });

    test('combines the chat, the user and the full info', () async {
      await peers.load(10);
      final info = peers.info(10)!;

      expect(info.kind, PeerKind.user);
      expect(info.title, 'Alina Petrova');
      expect(info.userId, 5);
      expect(info.phone, '79001234567');
      expect(info.formattedPhone, '+7 900 123 4567');
      expect(info.usernames, ['alina', 'alina_old']);
      expect(info.bio!.text, 'Designer');
      expect(info.birthdate!.month, 9);
      expect(info.isMuted, isFalse);
      expect(info.isBlocked, isFalse);
      expect(info.status, isA<td.UserStatusOffline>());
      expect(info.isSelf, isFalse);
    });

    test('learns which chat is your own after it loaded', () async {
      await peers.load(10);
      final changes = <void>[];
      final subscription = peers.changes.listen(changes.add);
      expect(peers.info(10)!.isSelf, isFalse);
      json.push({
        '@type': 'updateOption',
        'name': 'my_id',
        'value': {'@type': 'optionValueInteger', 'value': '5'},
      });
      await pumpEventQueue();
      expect(peers.info(10)!.isSelf, isTrue);
      expect(changes, isNotEmpty);
      await subscription.cancel();
    });

    test('follows status and notification updates', () async {
      await peers.load(10);
      final changes = <void>[];
      final subscription = peers.changes.listen(changes.add);

      json.push({
        '@type': 'updateUserStatus',
        'user_id': 5,
        'status': {'@type': 'userStatusOnline', 'expires': 99},
      });
      json.push({
        '@type': 'updateChatNotificationSettings',
        'chat_id': 10,
        'notification_settings': _notificationSettings(
          useDefault: false,
          muteFor: PeerInfoController.muteForever,
        ),
      });
      await pumpEventQueue();

      final info = peers.info(10)!;
      expect(info.status, isA<td.UserStatusOnline>());
      expect(info.isMuted, isTrue);
      expect(changes, hasLength(2));
      await subscription.cancel();
    });

    test('uses the scope default when the chat has none', () async {
      json.answers['getScopeNotificationSettings'] = _scope(muteFor: 3600);
      await peers.load(10);
      expect(peers.info(10)!.isMuted, isTrue);
    });

    test('mutes forever and keeps the other settings', () async {
      await peers.load(10);
      await peers.setMuted(10, muted: true);

      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'setChatNotificationSettings',
      );
      final settings = request['notification_settings']! as Map;
      expect(settings['use_default_mute_for'], isFalse);
      expect(settings['mute_for'], PeerInfoController.muteForever);
      expect(settings['use_default_sound'], isTrue);
    });

    test('blocks the user and shows it at once', () async {
      await peers.load(10);
      await peers.setBlocked(10, blocked: true);

      final request = json.sent.firstWhere(
        (r) => r['@type'] == 'setMessageSenderBlockList',
      );
      expect(request['sender_id'], {
        '@type': 'messageSenderUser',
        'user_id': 5,
      });
      expect((request['block_list']! as Map)['@type'], 'blockListMain');
      expect(peers.info(10)!.isBlocked, isTrue);
      expect(peers.info(10)!.bio!.text, 'Designer');
    });

    test('keeps the bio when the refresh after blocking fails', () async {
      await peers.load(10);
      json.answers['getUserFullInfo'] = {
        '@type': 'error',
        'code': 500,
        'message': 'Internal',
      };
      await peers.setBlocked(10, blocked: true);
      expect(peers.info(10)!.isBlocked, isTrue);
      expect(peers.info(10)!.bio!.text, 'Designer');
    });
  });

  group('a supergroup', () {
    setUp(() {
      json.answers
        ..['getChat'] = _chat(
          20,
          'Flutter',
          type: {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 7,
            'is_channel': false,
          },
        )
        ..['getSupergroup'] = {
          '@type': 'supergroup',
          'id': 7,
          'member_count': 120,
          'status': {'@type': 'chatMemberStatusMember'},
          'usernames': {
            '@type': 'usernames',
            'active_usernames': ['flutter_ru'],
            'disabled_usernames': <Object?>[],
            'editable_username': 'flutter_ru',
            'collectible_usernames': <Object?>[],
          },
        }
        ..['getSupergroupFullInfo'] = {
          '@type': 'supergroupFullInfo',
          'description': 'Rules: flutter.dev',
          'member_count': 121,
          'can_get_members': true,
          'bot_commands': <Object?>[],
        }
        ..['getTextEntities'] = {
          '@type': 'textEntities',
          'entities': [
            {
              '@type': 'textEntity',
              'offset': 7,
              'length': 11,
              'type': {'@type': 'textEntityTypeUrl'},
            },
          ],
        }
        ..['getSupergroupMembers'] = {
          '@type': 'chatMembers',
          'total_count': 3,
          'members': [
            _member(1, {'@type': 'chatMemberStatusMember'}),
            _member(2, {'@type': 'chatMemberStatusCreator'}),
            _member(3, {'@type': 'chatMemberStatusMember'}),
          ],
        }
        ..['getScopeNotificationSettings'] = _scope(muteFor: 0);
      json.users = {
        1: _user(1, 'Old', '', status: _offline(100)),
        2: _user(2, 'Owner', '', status: _offline(500)),
        3: _user(
          3,
          'Online',
          '',
          status: {'@type': 'userStatusOnline', 'expires': 1},
        ),
      };
    });

    test('shows the public link, the count and linked description', () async {
      await peers.load(20);
      final info = peers.info(20)!;

      expect(info.kind, PeerKind.group);
      expect(info.inviteLink, 'https://t.me/flutter_ru');
      expect(info.memberCount, 121);
      expect(info.description!.text, 'Rules: flutter.dev');
      expect(info.description!.entities.single.offset, 7);
    });

    test('lists members online first, then by last seen', () async {
      await peers.load(20);
      final members = peers.info(20)!.members;

      expect(members.map((m) => m.name), ['Online', 'Owner', 'Old']);
      expect(members[1].role, MemberRole.owner);
    });

    test('does not ask for members of a channel', () async {
      json.answers['getChat'] = _chat(
        20,
        'News',
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 7,
          'is_channel': true,
        },
      );
      await peers.load(20);

      expect(peers.info(20)!.kind, PeerKind.channel);
      expect(peers.info(20)!.members, isEmpty);
      expect(
        json.sent.map((r) => r['@type']),
        isNot(contains('getSupergroupMembers')),
      );
    });
  });

  test('keeps hidden last-seen statuses below known times', () {
    PeerMember member(String name, td.UserStatus status) =>
        PeerMember(userId: 0, name: name, status: status);
    final sorted = sortByPresence([
      member('empty', const td.UserStatusEmpty()),
      member('month', const td.UserStatusLastMonth(byMyPrivacySettings: false)),
      member(
        'recently',
        const td.UserStatusRecently(byMyPrivacySettings: false),
      ),
      member('offline', const td.UserStatusOffline(wasOnline: 1000)),
      member('online', const td.UserStatusOnline(expires: 1)),
    ]);
    expect(sorted.map((m) => m.name), [
      'online',
      'offline',
      'recently',
      'month',
      'empty',
    ]);
  });
}

Map<String, Object?> _offline(int wasOnline) => {
  '@type': 'userStatusOffline',
  'was_online': wasOnline,
};

Map<String, Object?> _member(int userId, Map<String, Object?> status) => {
  '@type': 'chatMember',
  'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
  'status': status,
};

Map<String, Object?> _notificationSettings({
  bool useDefault = true,
  int muteFor = 0,
}) => {
  '@type': 'chatNotificationSettings',
  'use_default_mute_for': useDefault,
  'mute_for': muteFor,
  'use_default_sound': true,
};

Map<String, Object?> _scope({required int muteFor}) => {
  '@type': 'scopeNotificationSettings',
  'mute_for': muteFor,
};

Map<String, Object?> _chat(
  int id,
  String title, {
  required Map<String, Object?> type,
}) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': title,
  'permissions': {'@type': 'chatPermissions'},
  'positions': <Object?>[],
  'chat_lists': <Object?>[],
  'notification_settings': _notificationSettings(),
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
};

Map<String, Object?> _user(
  int id,
  String first,
  String last, {
  String phone = '',
  List<String> usernames = const [],
  String editable = '',
  Map<String, Object?>? status,
}) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': last,
  'phone_number': phone,
  'status': status ?? _offline(1),
  'type': {'@type': 'userTypeRegular'},
  if (usernames.isNotEmpty)
    'usernames': {
      '@type': 'usernames',
      'active_usernames': usernames,
      'disabled_usernames': <Object?>[],
      'editable_username': editable,
      'collectible_usernames': <Object?>[],
    },
};

Map<String, Object?> _userFull({
  required String bio,
  Map<String, Object?>? birthdate,
}) => {
  '@type': 'userFullInfo',
  'bio': {'@type': 'formattedText', 'text': bio, 'entities': <Object?>[]},
  'birthdate': ?birthdate,
  'gift_settings': {
    '@type': 'giftSettings',
    'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
  },
};

/// Answers each request with the canned object for its type, `ok`
/// otherwise; `getUser` answers from [users] when the id is there.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final answers = <String, Map<String, Object?>>{};
  var users = <int, Map<String, Object?>>{};
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
    sent.add(decoded);
    final type = decoded['@type']! as String;
    final answer = type == 'getUser' && users.containsKey(decoded['user_id'])
        ? users[decoded['user_id']]!
        : answers[type] ?? {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...answer,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (type == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
