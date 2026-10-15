import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late PresenceController presence;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    presence = PresenceController(
      tdlib.createClient(),
      chatTitle: (id) => id == -100 ? 'News' : '',
    );
    await presence.start();
  });

  tearDown(() async {
    await presence.dispose();
    await tdlib.close();
  });

  ChatListEntry private(int userId) => ChatListEntry(
    id: userId,
    title: 'Chat',
    unreadCount: 0,
    positions: const [],
    peerId: userId,
  );

  test('follows a user going online and offline', () async {
    json.push(
      _user(5, 'Alina', {
        '@type': 'userStatusRecently',
        'by_my_privacy_settings': false,
      }),
    );
    await _settle();
    expect(
      (presence.statusOf(private(5)) as ChatStatusUser).presence,
      isA<PresenceRecently>(),
    );

    final expires = DateTime.now().add(const Duration(minutes: 5));
    json.push({
      '@type': 'updateUserStatus',
      'user_id': 5,
      'status': {
        '@type': 'userStatusOnline',
        'expires': expires.millisecondsSinceEpoch ~/ 1000,
      },
    });
    await _settle();
    expect(presence.isOnline(private(5), DateTime.now()), isTrue);
    expect(
      presence.isOnline(
        private(5),
        DateTime.now().add(const Duration(minutes: 10)),
      ),
      isFalse,
    );

    json.push({
      '@type': 'updateUserStatus',
      'user_id': 5,
      'status': {'@type': 'userStatusOffline', 'was_online': 1000},
    });
    await _settle();
    expect(presence.isOnline(private(5), DateTime.now()), isFalse);
    final status = presence.statusOf(private(5)) as ChatStatusUser;
    expect(
      (status.presence as PresenceOffline).wasOnline,
      DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
    );
  });

  test('says nothing for Saved Messages and "bot" for bots', () async {
    json
      ..push({
        '@type': 'updateOption',
        'name': 'my_id',
        'value': {'@type': 'optionValueInteger', 'value': '7'},
      })
      ..push(_user(7, 'Me', {'@type': 'userStatusEmpty'}))
      ..push(_user(8, 'Helper', {'@type': 'userStatusEmpty'}, bot: true));
    await _settle();
    expect(presence.myId, 7);
    expect(presence.statusOf(private(7)), const ChatStatusNone());
    expect(presence.statusOf(private(8)), const ChatStatusBot());
    expect(
      presence.statusOf(private(PresenceController.serviceUserId)),
      const ChatStatusService(),
    );
  });

  test('keeps who is doing what until TDLib cancels it', () async {
    json
      ..push(_user(5, 'Alina', {'@type': 'userStatusEmpty'}))
      ..push(_user(6, 'Boris', {'@type': 'userStatusEmpty'}))
      ..push(_action(1, 5, {'@type': 'chatActionTyping'}))
      ..push(_action(1, 6, {'@type': 'chatActionRecordingVoiceNote'}))
      ..push(_action(1, -100, {'@type': 'chatActionTyping'}, chat: true));
    await _settle();
    expect(presence.activityIn(1), const [
      ChatActor(name: 'Alina', activity: ChatActivity.typing),
      ChatActor(name: 'Boris', activity: ChatActivity.recordingVoice),
      ChatActor(name: 'News', activity: ChatActivity.typing),
    ]);

    json
      ..push(_action(1, 5, {'@type': 'chatActionCancel'}))
      ..push(_action(1, -100, {'@type': 'chatActionCancel'}, chat: true));
    await _settle();
    expect(presence.activityIn(1), const [
      ChatActor(name: 'Boris', activity: ChatActivity.recordingVoice),
    ]);
    expect(presence.activityIn(2), isEmpty);
  });

  test('ignores the signed-in user typing on another device', () async {
    json
      ..push({
        '@type': 'updateOption',
        'name': 'my_id',
        'value': {'@type': 'optionValueInteger', 'value': '7'},
      })
      ..push(_action(1, 7, {'@type': 'chatActionTyping'}));
    await _settle();
    expect(presence.activityIn(1), isEmpty);
  });

  test('counts group members and those online', () async {
    json
      ..push({
        '@type': 'updateBasicGroup',
        'basic_group': {
          '@type': 'basicGroup',
          'id': 3,
          'member_count': 12,
          'status': {'@type': 'chatMemberStatusMember', 'member_until_date': 0},
          'is_active': true,
          'upgraded_to_supergroup_id': 0,
        },
      })
      ..push({
        '@type': 'updateChatOnlineMemberCount',
        'chat_id': -3,
        'online_member_count': 4,
      });
    await _settle();
    final group = ChatListEntry(
      id: -3,
      title: 'Team',
      unreadCount: 0,
      positions: const [],
      type: ChatType.basicGroup,
      peerId: 3,
    );
    expect(
      presence.statusOf(group),
      const ChatStatusGroup(members: 12, online: 4),
    );
  });

  test('loads an unknown supergroup member count once', () async {
    json.memberCount = 1500;
    final channel = ChatListEntry(
      id: -1009,
      title: 'News',
      unreadCount: 0,
      positions: const [],
      type: ChatType.channel,
      peerId: 9,
    );
    await presence.loadMemberCount(channel);
    await presence.loadMemberCount(channel);
    expect(
      presence.statusOf(channel),
      const ChatStatusChannel(subscribers: 1500),
    );
    expect(
      json.sent.where((r) => r['@type'] == 'getSupergroupFullInfo'),
      hasLength(1),
    );
  });
}

Map<String, Object?> _user(
  int id,
  String name,
  Map<String, Object?> status, {
  bool bot = false,
}) => {
  '@type': 'updateUser',
  'user': {
    '@type': 'user',
    'id': id,
    'first_name': name,
    'last_name': '',
    'phone_number': '',
    'status': status,
    'accent_color_id': 0,
    'background_custom_emoji_id': '0',
    'profile_accent_color_id': -1,
    'profile_background_custom_emoji_id': '0',
    'is_contact': false,
    'is_mutual_contact': false,
    'is_close_friend': false,
    'is_premium': false,
    'is_support': false,
    'restricts_new_chats': false,
    'paid_message_star_count': 0,
    'have_access': true,
    'type': bot
        ? {
            '@type': 'userTypeBot',
            'can_be_edited': false,
            'can_join_groups': true,
            'can_read_all_group_messages': false,
            'has_main_web_app': false,
            'has_topics': false,
            'allows_users_to_create_topics': false,
            'is_inline': false,
            'inline_query_placeholder': '',
            'need_location': false,
            'can_connect_to_business': false,
            'can_be_added_to_attachment_menu': false,
            'active_user_count': 0,
          }
        : {'@type': 'userTypeRegular'},
    'language_code': '',
    'added_to_attachment_menu': false,
  },
};

Map<String, Object?> _action(
  int chatId,
  int senderId,
  Map<String, Object?> action, {
  bool chat = false,
}) => {
  '@type': 'updateChatAction',
  'chat_id': chatId,
  'sender_id': chat
      ? {'@type': 'messageSenderChat', 'chat_id': senderId}
      : {'@type': 'messageSenderUser', 'user_id': senderId},
  'action': action,
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var memberCount = 0;
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
    final reply = switch (decoded['@type']) {
      'getSupergroupFullInfo' => _fullInfo(memberCount),
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({
        ...reply,
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

Map<String, Object?> _fullInfo(int members) => {
  '@type': 'supergroupFullInfo',
  'member_count': members,
};

/// The fake TDLib is polled on a timer, so updates need real time.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));
