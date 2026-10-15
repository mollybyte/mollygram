import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatListController controller;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = ChatListController(tdlib.createClient());
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  test('loads the main list through TDLib updates', () async {
    await controller.start();

    expect(json.sent.single['@type'], 'loadChats');
    expect(json.sent.single['limit'], 100);
    expect(json.sent.single, isNot(contains('chat_list')));
  });

  test('projects server folders in their declared order', () async {
    final changes = <void>[];
    final subscription = controller.changes.listen(changes.add);
    await controller.start();

    json.push({
      '@type': 'updateChatFolders',
      'chat_folders': [
        _folder(id: 7, name: 'Work', icon: 'Work'),
        _folder(id: 4, name: 'Family', icon: 'Favorite'),
      ],
      'main_chat_list_position': 0,
      'are_tags_enabled': false,
    });
    await pumpEventQueue();

    expect(controller.store.folders.map((folder) => folder.title), [
      'Work',
      'Family',
    ]);
    expect(changes, isNotEmpty);
    await subscription.cancel();
  });

  test('keeps the sender, the thumbnail and the read mark of the last '
      'message', () async {
    await controller.start();
    Map<String, Object?> photo({required bool spoiler}) => {
      '@type': 'message',
      'id': 30,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 9},
      'chat_id': 6,
      'is_outgoing': true,
      'date': 100,
      'content': {
        '@type': 'messagePhoto',
        'photo': {
          '@type': 'photo',
          'minithumbnail': {
            '@type': 'minithumbnail',
            'width': 8,
            'height': 8,
            'data': 'AAAA',
          },
          'sizes': <Object?>[],
        },
        'caption': {'@type': 'formattedText', 'text': 'lake'},
        'has_spoiler': spoiler,
        'is_secret': false,
      },
    };
    json.push({
      '@type': 'updateNewChat',
      'chat': {
        ..._chat(6, {'@type': 'chatTypeBasicGroup', 'basic_group_id': 2}),
        'last_message': photo(spoiler: false),
        'last_read_outbox_message_id': 20,
      },
    });
    await _polled();

    var chat = controller.store.chat(6)!;
    expect(chat.lastMessage!.senderUserId, 9);
    expect(chat.lastMessage!.thumbnail, isNotNull);
    expect(chat.lastMessageRead, isFalse);

    json
      ..push({
        '@type': 'updateChatReadOutbox',
        'chat_id': 6,
        'last_read_outbox_message_id': 30,
      })
      ..push({
        '@type': 'updateChatLastMessage',
        'chat_id': 6,
        'last_message': photo(spoiler: true),
        'positions': <Object?>[],
      });
    await _polled();

    chat = controller.store.chat(6)!;
    expect(chat.lastMessageRead, isTrue);
    // A spoiler keeps its picture to itself.
    expect(chat.lastMessage!.thumbnail, isNull);
  });

  test('reports a chat TDLib no longer has', () async {
    json.missingChats.add(42);
    expect(await controller.loadChat(42), isFalse);
    expect(json.sent.single, {
      '@type': 'getChat',
      'chat_id': 42,
      '@extra': json.sent.single['@extra'],
    });
  });

  test('keeps loading pages until TDLib reports the end', () async {
    await controller.start();
    expect(controller.hasMore(), isTrue);

    await controller.loadMore();
    expect(controller.hasMore(), isTrue);

    json.endOfList = true;
    await controller.loadMore();
    expect(controller.hasMore(), isFalse);

    // Nothing is requested once the list is exhausted.
    await controller.loadMore();
    expect(json.sent.where((r) => r['@type'] == 'loadChats'), hasLength(3));
  });

  test('shares one request between overlapping loads of a list', () async {
    await controller.start();
    await Future.wait([controller.loadMore(), controller.loadMore()]);

    expect(json.sent.where((r) => r['@type'] == 'loadChats'), hasLength(2));
  });

  test('keeps the chat photo and follows updateChatPhoto', () async {
    await controller.start();
    json.push({
      '@type': 'updateNewChat',
      'chat': {
        ..._chat(7, {'@type': 'chatTypePrivate', 'user_id': 7}),
        'photo': _photo(70),
      },
    });
    await _polled();
    expect(controller.store.chat(7)!.photo!.small.id, 70);
    expect(controller.store.chat(7)!.photo!.minithumbnail, isNotNull);

    json.push({'@type': 'updateChatPhoto', 'chat_id': 7, 'photo': _photo(71)});
    await _polled();
    expect(controller.store.chat(7)!.photo!.small.id, 71);

    json.push({'@type': 'updateChatPhoto', 'chat_id': 7, 'photo': null});
    await _polled();
    expect(controller.store.chat(7)!.photo, isNull);
    expect(controller.store.chat(7)!.title, 'Chat 7');
  });

  test('applies positions sent with a draft change', () async {
    const main = ChatListLocation.main();
    await controller.start();
    controller.store.upsert(
      ChatListEntry(
        id: 5,
        title: 'Draft',
        unreadCount: 0,
        positions: [ChatListPosition(list: main, order: 10, isPinned: false)],
      ),
    );
    json.push({
      '@type': 'updateChatDraftMessage',
      'chat_id': 5,
      'positions': [
        {
          '@type': 'chatPosition',
          'list': {'@type': 'chatListMain'},
          'order': '99',
          'is_pinned': false,
        },
      ],
    });
    await pumpEventQueue();

    expect(controller.store.chat(5)!.positionFor(main)!.order, 99);
  });

  test('ignores a draft older than the one shown', () {
    const main = ChatListLocation.main();
    final positions = [
      ChatListPosition(list: main, order: 10, isPinned: false),
    ];
    controller.store
      ..upsert(
        ChatListEntry(
          id: 5,
          title: 'Draft',
          unreadCount: 0,
          positions: positions,
        ),
      )
      ..updateDraft(5, const ChatDraft(text: 'new', date: 200), positions)
      ..updateDraft(5, const ChatDraft(text: 'old', date: 100), positions);
    expect(controller.store.chat(5)!.draft?.text, 'new');
  });

  test('keeps the draft text and date, and drops a cleared draft', () async {
    const main = ChatListLocation.main();
    await controller.start();
    controller.store.upsert(
      ChatListEntry(
        id: 5,
        title: 'Draft',
        unreadCount: 0,
        positions: [ChatListPosition(list: main, order: 10, isPinned: false)],
      ),
    );
    final positions = [
      {
        '@type': 'chatPosition',
        'list': {'@type': 'chatListMain'},
        'order': '99',
        'is_pinned': false,
      },
    ];
    json.push({
      '@type': 'updateChatDraftMessage',
      'chat_id': 5,
      'draft_message': {
        '@type': 'draftMessage',
        'date': 1700000000,
        'effect_id': '0',
        'content': {
          '@type': 'draftMessageContentText',
          'text': {
            '@type': 'formattedText',
            'text': 'hello',
            'entities': <Object?>[],
          },
        },
      },
      'positions': positions,
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final draft = controller.store.chat(5)!.draft;
    expect(draft?.text, 'hello');
    expect(draft?.date, 1700000000);

    json.push({
      '@type': 'updateChatDraftMessage',
      'chat_id': 5,
      'positions': positions,
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(controller.store.chat(5)!.draft, isNull);
  });

  group('chat state and actions', () {
    const main = ChatListLocation.main();

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    Future<void> addChat(Map<String, Object?> type, {int id = 5}) async {
      await controller.start();
      json.push({'@type': 'updateNewChat', 'chat': _chat(id, type)});
      await settle();
    }

    List<Map<String, Object?>> sent(String type) =>
        json.sent.where((r) => r['@type'] == type).toList();

    test('reads the chat type, mute and unread state', () async {
      await addChat({
        '@type': 'chatTypeSupergroup',
        'supergroup_id': 77,
        'is_channel': true,
      });
      final chat = controller.store.chat(5)!;
      expect(chat.type, ChatType.channel);
      expect(chat.peerId, 77);
      expect(chat.isMuted, isFalse);
      expect(chat.isPinnedIn(main), isTrue);

      json
        ..push({
          '@type': 'updateChatIsMarkedAsUnread',
          'chat_id': 5,
          'is_marked_as_unread': true,
        })
        ..push({
          '@type': 'updateChatUnreadMentionCount',
          'chat_id': 5,
          'unread_mention_count': 2,
        })
        ..push({
          '@type': 'updateMessageUnreadReactions',
          'chat_id': 5,
          'message_id': 1,
          'unread_reactions': <Object?>[],
          'unread_reaction_count': 1,
        });
      await settle();
      final updated = controller.store.chat(5)!;
      expect(updated.isUnread, isTrue);
      expect(updated.unreadMentionCount, 2);
      expect(updated.unreadReactionCount, 1);
    });

    test('follows the default mute of the chat scope', () async {
      await addChat({'@type': 'chatTypePrivate', 'user_id': 5});
      json.push({
        '@type': 'updateScopeNotificationSettings',
        'scope': {'@type': 'notificationSettingsScopePrivateChats'},
        'notification_settings': {
          '@type': 'scopeNotificationSettings',
          'mute_for': 1000,
        },
      });
      await settle();
      expect(controller.store.chat(5)!.isMuted, isTrue);

      // Unmuting overrides the muted default.
      await controller.setMuted(5, null);
      final request = sent('setChatNotificationSettings').single;
      final settings = request['notification_settings']! as Map;
      expect(settings['use_default_mute_for'], isFalse);
      expect(settings['mute_for'], 0);

      json.push({
        '@type': 'updateChatNotificationSettings',
        'chat_id': 5,
        'notification_settings': {
          '@type': 'chatNotificationSettings',
          'use_default_mute_for': false,
          'mute_for': 0,
        },
      });
      await settle();
      expect(controller.store.chat(5)!.isMuted, isFalse);
    });

    test('mutes for a while or forever', () async {
      await addChat({'@type': 'chatTypePrivate', 'user_id': 5});
      await controller.setMuted(5, const Duration(hours: 8));
      await controller.setMuted(5, ChatListController.muteForever);
      final mutes = [
        for (final r in sent('setChatNotificationSettings'))
          (r['notification_settings']! as Map)['mute_for'],
      ];
      expect(mutes, [8 * 3600, ChatListController.muteForever.inSeconds]);
    });

    test('pins, archives and marks as unread', () async {
      await addChat({'@type': 'chatTypePrivate', 'user_id': 5});
      await controller.setPinned(5, main, false);
      await controller.setPinned(5, const ChatListLocation.folder(3), true);
      await controller.setArchived(5, true);
      await controller.markAsUnread(5);

      expect(sent('toggleChatIsPinned').map((r) => r['chat_list']), [
        {'@type': 'chatListMain'},
        {'@type': 'chatListFolder', 'chat_folder_id': 3},
      ]);
      expect(sent('addChatToList').single['chat_list'], {
        '@type': 'chatListArchive',
      });
      expect(
        sent('toggleChatIsMarkedAsUnread').single['is_marked_as_unread'],
        isTrue,
      );
    });

    test('marking as read reads the last message and the mention', () async {
      await addChat({'@type': 'chatTypePrivate', 'user_id': 5});
      controller.store.update(
        5,
        (chat) => chat.copyWith(
          unreadMentionCount: 1,
          isMarkedAsUnread: true,
          lastMessage: () => const ChatPreview(
            messageId: 42,
            kind: ChatPreviewKind.text,
            text: 'hi',
            date: 1,
            isOutgoing: false,
          ),
        ),
      );
      await controller.markAsRead(5);
      final view = sent('viewMessages').single;
      expect(view['message_ids'], [42]);
      expect(view['force_read'], isTrue);
      expect(sent('readAllChatMentions'), hasLength(1));
      expect(sent('readAllChatReactions'), isEmpty);
      expect(
        sent('toggleChatIsMarkedAsUnread').single['is_marked_as_unread'],
        isFalse,
      );
    });

    test('deletes a private chat and leaves groups the right way', () async {
      await addChat({'@type': 'chatTypePrivate', 'user_id': 5});
      await controller.deleteChat(5, forEveryone: true);
      expect(sent('deleteChatHistory').single, containsPair('revoke', true));
      expect(
        sent('deleteChatHistory').single,
        containsPair('remove_from_chat_list', true),
      );

      json.push({
        '@type': 'updateNewChat',
        'chat': _chat(6, {'@type': 'chatTypeBasicGroup', 'basic_group_id': 2}),
      });
      json.push({
        '@type': 'updateNewChat',
        'chat': _chat(7, {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 3,
          'is_channel': false,
        }),
      });
      await settle();
      await controller.deleteChat(6);
      await controller.deleteChat(7);
      expect(sent('leaveChat').map((r) => r['chat_id']), [6, 7]);
      // A left basic group's history is deleted to drop it from the list.
      expect(sent('deleteChatHistory').map((r) => r['chat_id']), [5, 6]);
    });
  });
}

Map<String, Object?> _folder({
  required int id,
  required String name,
  required String icon,
}) => {
  '@type': 'chatFolderInfo',
  'id': id,
  'name': {
    '@type': 'chatFolderName',
    'text': {'@type': 'formattedText', 'text': name, 'entities': <Object?>[]},
    'animate_custom_emoji': false,
  },
  'icon': {'@type': 'chatFolderIcon', 'name': icon},
  'color_id': -1,
  'is_shareable': false,
  'has_my_invite_links': false,
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var endOfList = false;
  final missingChats = <int>{};
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
    if (decoded['@type'] == 'getChat' &&
        missingChats.contains(decoded['chat_id'])) {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 400,
          'message': 'Chat not found',
          '@client_id': clientId,
          '@extra': decoded['@extra'],
        }),
      );
      return;
    }
    if (endOfList && decoded['@type'] == 'loadChats') {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 404,
          'message': 'Not Found',
          '@client_id': clientId,
          '@extra': decoded['@extra'],
        }),
      );
      return;
    }
    _queue.add(
      jsonEncode({
        '@type': 'ok',
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

Map<String, Object?> _chat(int id, Map<String, Object?> type) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': 'Chat $id',
  'permissions': {'@type': 'chatPermissions'},
  'positions': [
    {
      '@type': 'chatPosition',
      'list': {'@type': 'chatListMain'},
      'order': '10',
      'is_pinned': true,
    },
  ],
  'can_be_deleted_for_all_users': true,
  'notification_settings': {
    '@type': 'chatNotificationSettings',
    'use_default_mute_for': true,
    'mute_for': 0,
  },
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
};

/// Waits for the event source's poll timer to deliver a pushed update.
Future<void> _polled() async {
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await pumpEventQueue();
}

Map<String, Object?> _photo(int fileId) => {
  '@type': 'chatPhotoInfo',
  'small': _file(fileId),
  'big': _file(fileId + 1),
  'minithumbnail': {
    '@type': 'minithumbnail',
    'width': 8,
    'height': 8,
    'data': 'AAAA',
  },
  'has_animation': false,
  'is_personal': false,
};

Map<String, Object?> _file(int id) => {
  '@type': 'file',
  'id': id,
  'size': 100,
  'expected_size': 100,
  'local': {
    '@type': 'localFile',
    'path': '',
    'can_be_downloaded': true,
    'is_downloading_active': false,
    'is_downloading_completed': false,
    'downloaded_size': 0,
  },
  'remote': {'@type': 'remoteFile', 'id': 'r$id', 'unique_id': 'u$id'},
};
