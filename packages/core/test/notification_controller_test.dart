import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late NotificationController controller;
  late List<NotificationEvent> events;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = NotificationController(
      tdlib.createClient(),
      photoTimeout: const Duration(milliseconds: 50),
    );
    events = [];
    controller.events.listen(events.add);
    await controller.start();
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  Future<void> push(Map<String, Object?> update) async {
    json.push(update);
    // The receive loop polls every millisecond.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await pumpEventQueue();
  }

  test('turns TDLib notifications on and off', () async {
    await controller.setEnabled(true);
    await controller.setEnabled(false);

    final options = [
      for (final request in json.sent)
        if (request['@type'] == 'setOption')
          (request['name'], (request['value'] as Map)['value']),
    ];
    // int64 values travel as strings.
    const size = '${NotificationController.maxGroupSize}';
    expect(options, [
      ('notification_group_size_max', size),
      ('notification_group_count_max', '${NotificationController.maxGroups}'),
      ('notification_group_size_max', size),
      ('notification_group_count_max', '0'),
    ]);
  });

  test('posts a group message with its chat and author', () async {
    await push(_newChat(10, 'Climbing', type: _supergroup));
    await push(_user(7, 'Ada', 'Lovelace'));
    await push(
      _group(
        groupId: 1,
        chatId: 10,
        soundId: 5,
        added: [_notification(100, _message(id: 55, chatId: 10, sender: 7))],
      ),
    );

    final posted = (events.single as NotificationPosted).notification;
    expect(posted.key, '1:100');
    expect(posted.chatId, 10);
    expect(posted.messageId, 55);
    expect(posted.chatTitle, 'Climbing');
    expect(posted.senderName, 'Ada Lovelace');
    expect(posted.text, 'hello');
    expect(posted.playSound, isTrue);
    expect(posted.canReply, isTrue);
    expect(posted.showPreview, isTrue);
  });

  test(
    'keeps private chats unattributed and quiet when sound is off',
    () async {
      await push(_newChat(20, 'Ada', type: _private));
      await push(
        _group(
          groupId: 2,
          chatId: 20,
          soundId: 0,
          added: [_notification(1, _message(id: 3, chatId: 20))],
        ),
      );

      final posted = (events.single as NotificationPosted).notification;
      expect(posted.senderName, isNull);
      expect(posted.playSound, isFalse);
    },
  );

  test('channels have no reply and secret chats no preview', () async {
    await push(_newChat(30, 'News', type: _channel));
    await push(_newChat(31, 'Secret', type: _secret));
    await push(
      _group(
        groupId: 3,
        chatId: 30,
        added: [_notification(1, _message(id: 1, chatId: 30))],
      ),
    );
    await push(
      _group(
        groupId: 4,
        chatId: 31,
        added: [_notification(2, _message(id: 1, chatId: 31))],
      ),
    );

    final [channel, secret] = [
      for (final e in events) (e as NotificationPosted).notification,
    ];
    expect(channel.canReply, isFalse);
    expect(secret.showPreview, isFalse);
  });

  test('passes on removals and the startup list', () async {
    await push(_newChat(10, 'Climbing', type: _supergroup));
    await push(
      _group(
        groupId: 1,
        chatId: 10,
        added: [_notification(100, _message(id: 55, chatId: 10))],
      ),
    );
    await push(_group(groupId: 1, chatId: 10, total: 0, removed: [100]));
    await push({
      '@type': 'updateActiveNotifications',
      'groups': [
        {
          '@type': 'notificationGroup',
          'id': 6,
          'type': {'@type': 'notificationGroupTypeMessages'},
          'chat_id': 10,
          'total_count': 1,
          'notifications': [_notification(9, _message(id: 60, chatId: 10))],
        },
      ],
    });

    expect(events[1], isA<NotificationsRemoved>());
    expect((events[1] as NotificationsRemoved).keys, ['1:100']);
    expect((events[2] as NotificationsSynced).keys, {'6:9'});
  });

  test('replies to the message in groups, plainly in private chats', () async {
    await push(_newChat(10, 'Climbing', type: _supergroup));
    await push(_newChat(20, 'Ada', type: _private));

    await controller.reply(10, 55, ' on my way ');
    await controller.reply(20, 3, 'ok');

    final sent = [
      for (final r in json.sent)
        if (r['@type'] == 'sendMessage') r,
    ];
    expect((sent[0]['reply_to'] as Map)['message_id'], 55);
    expect(
      ((sent[0]['input_message_content'] as Map)['text'] as Map)['text'],
      'on my way',
    );
    expect(sent[1], isNot(contains('reply_to')));
    final reads = json.sent.where((r) => r['@type'] == 'viewMessages');
    expect(reads.map((r) => r['chat_id']), [10, 20]);
    expect(reads.every((r) => r['force_read'] == true), isTrue);
  });

  test('marks read up to the newest notified message of the chat', () async {
    await push(_newChat(10, 'Climbing', type: _supergroup));
    await push(
      _group(
        groupId: 1,
        chatId: 10,
        added: [
          _notification(1, _message(id: 50, chatId: 10)),
          _notification(2, _message(id: 58, chatId: 10)),
        ],
      ),
    );

    await controller.markRead(10, 50);

    final read = json.sent.lastWhere((r) => r['@type'] == 'viewMessages');
    expect(read['message_ids'], [58]);
    expect((read['source'] as Map)['@type'], 'messageSourceNotification');
  });

  test('counts unread chats and messages of the main list only', () async {
    final counts = <UnreadCounts>[];
    controller.unreadChanges.listen(counts.add);
    await push({
      '@type': 'updateUnreadChatCount',
      'chat_list': {'@type': 'chatListMain'},
      'total_count': 40,
      'unread_count': 5,
      'unread_unmuted_count': 3,
    });
    await push({
      '@type': 'updateUnreadMessageCount',
      'chat_list': {'@type': 'chatListArchive'},
      'unread_count': 99,
      'unread_unmuted_count': 99,
    });
    await push({
      '@type': 'updateUnreadMessageCount',
      'chat_list': {'@type': 'chatListMain'},
      'unread_count': 12,
      'unread_unmuted_count': 8,
    });

    expect(counts, hasLength(2));
    expect(
      controller.unreadCounts,
      const UnreadCounts(
        chats: 5,
        unmutedChats: 3,
        messages: 12,
        unmutedMessages: 8,
      ),
    );
  });
}

const _private = {'@type': 'chatTypePrivate', 'user_id': 7};
const _secret = {'@type': 'chatTypeSecret', 'secret_chat_id': 1, 'user_id': 7};
const _supergroup = {
  '@type': 'chatTypeSupergroup',
  'supergroup_id': 1,
  'is_channel': false,
};
const _channel = {
  '@type': 'chatTypeSupergroup',
  'supergroup_id': 2,
  'is_channel': true,
};

Map<String, Object?> _newChat(
  int id,
  String title, {
  required Map<String, Object?> type,
}) => {
  '@type': 'updateNewChat',
  'chat': {
    '@type': 'chat',
    'id': id,
    'type': type,
    'title': title,
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
};

Map<String, Object?> _user(int id, String first, String last) => {
  '@type': 'updateUser',
  'user': {
    '@type': 'user',
    'id': id,
    'first_name': first,
    'last_name': last,
    'phone_number': '',
    'status': {'@type': 'userStatusEmpty'},
    'type': {'@type': 'userTypeRegular'},
  },
};

Map<String, Object?> _message({
  required int id,
  required int chatId,
  int sender = 1,
}) => tdMessage(
  id: id,
  chatId: chatId,
  text: 'hello',
  isOutgoing: false,
  senderUserId: sender,
).toJson();

Map<String, Object?> _notification(int id, Map<String, Object?> message) => {
  '@type': 'notification',
  'id': id,
  'date': 1,
  'is_silent': false,
  'type': {
    '@type': 'notificationTypeNewMessage',
    'message': message,
    'show_preview': true,
  },
};

Map<String, Object?> _group({
  required int groupId,
  required int chatId,
  int soundId = 1,
  int? total,
  List<Map<String, Object?>> added = const [],
  List<int> removed = const [],
}) => {
  '@type': 'updateNotificationGroup',
  'notification_group_id': groupId,
  'type': {'@type': 'notificationGroupTypeMessages'},
  'chat_id': chatId,
  'notification_settings_chat_id': chatId,
  'notification_sound_id': '$soundId',
  'total_count': total ?? added.length,
  'added_notifications': added,
  'removed_notification_ids': removed,
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
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
    sent.add(decoded);
    final response = switch (decoded['@type']) {
      'sendMessage' => _message(id: 1000, chatId: decoded['chat_id'] as int),
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
