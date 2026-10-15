import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

import 'support/messages.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ConversationController controller;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = ConversationController(tdlib.createClient());
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  test('loads text history and applies new-message updates', () async {
    await controller.start();
    await controller.loadHistory(7);

    expect(controller.store.messagesFor(7).map((message) => message.text), [
      'From history',
    ]);

    json.push({
      '@type': 'updateNewMessage',
      'message': _message(id: 11, chatId: 7, text: 'Live').toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.messagesFor(7).map((message) => message.text), [
      'Live',
      'From history',
    ]);
  });

  test(
    'sends plain text through TDLib and adds the response to the timeline',
    () async {
      await controller.start();

      await controller.sendText(7, 'Sent text');

      final request = json.sent.single;
      expect(request['@type'], 'sendMessage');
      expect(request['chat_id'], 7);
      expect(
        (request['input_message_content'] as Map<String, Object?>)['text'],
        {
          '@type': 'formattedText',
          'text': 'Sent text',
          'entities': <Object?>[],
        },
      );
      expect(controller.store.messagesFor(7).single.text, 'Sent text');
    },
  );

  test('replaces the pending copy once the server confirms a send', () async {
    await controller.start();
    await controller.sendText(7, 'Sent text');

    json.push({
      '@type': 'updateMessageSendSucceeded',
      'message': _message(id: 40, chatId: 7, text: 'Sent text').toJson(),
      'old_message_id': 12,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.messagesFor(7).map((message) => message.id), [40]);
  });

  test('applies edits and permanent deletions', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 10,
      'new_content': td.MessageText(
        text: td.FormattedText(text: 'Edited', entities: const []),
      ).toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7).single.text, 'Edited');

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': true,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7), isEmpty);
  });

  test('hides messages that became inaccessible', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': false,
      'from_cache': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7), isEmpty);
  });

  test('keeps messages TDLib only evicted from its cache', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [10],
      'is_permanent': false,
      'from_cache': true,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.messagesFor(7).single.id, 10);
  });

  test('keeps a message that arrived while history was loading', () async {
    json.liveDuringHistory = _message(id: 11, chatId: 7, text: 'Live');
    await controller.start();

    await controller.loadHistory(7);

    expect(controller.store.messagesFor(7).map((message) => message.id), [
      11,
      10,
    ]);
  });

  test('marks a message the server rejected as failed', () async {
    await controller.start();
    await controller.sendText(7, 'Sent text');
    expect(
      controller.store.messagesFor(7).single.sendState,
      MessageSendState.pending,
    );

    json.push({
      '@type': 'updateMessageSendFailed',
      'message': _message(
        id: 13,
        chatId: 7,
        text: 'Sent text',
        sendingState: const td.MessageSendingStateFailed(
          error: td.TdError(code: 403, message: 'CHAT_WRITE_FORBIDDEN'),
          canRetry: false,
          needAnotherSender: false,
          needAnotherReplyQuote: false,
          needDropReply: false,
          requiredPaidMessageStarCount: 0,
          retryAfter: 0,
        ),
      ).toJson(),
      'old_message_id': 12,
      'error': {
        '@type': 'error',
        'code': 403,
        'message': 'CHAT_WRITE_FORBIDDEN',
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final message = controller.store.messagesFor(7).single;
    expect(message.id, 13);
    expect(message.sendState, MessageSendState.failed);
  });

  test('loads older pages until the screen is filled', () async {
    // TDLib answers the first request with just the last message.
    json.history = (from) => from == 0
        ? [_message(id: 100, chatId: 7, text: 'Last')]
        : [
            for (var id = from - 1; id > from - 21 && id > 50; id--)
              _message(id: id, chatId: 7, text: '#$id'),
          ];
    await controller.start();

    await controller.loadHistory(7);

    final ids = controller.store.messagesFor(7).map((m) => m.id);
    expect(ids.length, greaterThanOrEqualTo(30));
    expect(ids.first, 100);

    // Paging to the start stops once a page adds nothing.
    while (await controller.loadOlder(7)) {}
    expect(controller.store.reachedStart(7), isTrue);
    expect(controller.store.oldestId(7), 51);
  });

  test('keeps media messages and their content updates', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 10,
      'new_content': {
        '@type': 'messageSticker',
        'is_premium': false,
        'sticker': {
          '@type': 'sticker',
          'id': '1',
          'set_id': '2',
          'width': 512,
          'height': 512,
          'emoji': '🙂',
          'format': {'@type': 'stickerFormatWebp'},
          'full_type': {'@type': 'stickerFullTypeRegular'},
          'sticker': {
            '@type': 'file',
            'id': 5,
            'size': 100,
            'expected_size': 100,
            'local': {
              '@type': 'localFile',
              'path': '',
              'can_be_downloaded': true,
              'can_be_deleted': false,
              'is_downloading_active': false,
              'is_downloading_completed': false,
              'download_offset': 0,
              'downloaded_prefix_size': 0,
              'downloaded_size': 0,
            },
            'remote': {
              '@type': 'remoteFile',
              'id': 'x',
              'unique_id': 'y',
              'is_uploading_active': false,
              'is_uploading_completed': true,
              'uploaded_size': 100,
            },
          },
        },
      },
    });
    json.push({
      '@type': 'updateMessageEdited',
      'chat_id': 7,
      'message_id': 10,
      'edit_date': 77,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    final message = controller.store.messagesFor(7).single;
    expect(message.content, isA<td.MessageSticker>());
    expect(message.editDate, 77);
  });

  test('fetches a replied-to message outside the timeline once', () async {
    await controller.start();

    await controller.loadReplied(7, 10);
    await controller.loadReplied(7, 10);

    expect(
      json.sent.where((r) => r['@type'] == 'getRepliedMessage'),
      hasLength(1),
    );
    expect(controller.store.message(7, 3)?.text, 'Quoted');
  });

  test('marks a reply as missing only when TDLib has no original', () async {
    await controller.start();

    json.repliedError = 500;
    await controller.loadReplied(7, 10);
    expect(controller.store.isMissing(7, 10), isFalse);

    json.repliedError = 404;
    await controller.loadReplied(7, 10);
    expect(controller.store.isMissing(7, 10), isTrue);
    expect(
      json.sent.where((r) => r['@type'] == 'getRepliedMessage'),
      hasLength(2),
    );
  });

  test('sends a reply to the chosen message', () async {
    await controller.start();

    await controller.sendText(7, 'Sure', replyTo: 10);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    expect(
      send['reply_to'],
      containsPair('@type', 'inputMessageReplyToMessage'),
    );
  });

  test('sends and edits with the formatting the composer gives', () async {
    await controller.start();
    controller.store.replaceHistory(7, [
      ConversationMessage(tdMessage(id: 1, chatId: 7, text: 'Hi')),
    ]);
    const bold = td.TextEntity(
      offset: 0,
      length: 2,
      type: td.TextEntityTypeBold(),
    );

    await controller.sendText(7, 'Hi there', entities: const [bold]);
    await controller.editText(7, 1, 'Hi', entities: const [bold]);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final sent = (send['input_message_content']! as Map)['text']! as Map;
    expect((sent['entities']! as List).single, bold.toJson());
    final edit = json.sent.lastWhere((r) => r['@type'] == 'editMessageText');
    final edited = (edit['input_message_content']! as Map)['text']! as Map;
    expect((edited['entities']! as List).single, bold.toJson());
  });

  test('edits text messages and captions with the right request', () async {
    await controller.start();
    controller.store.replaceHistory(7, [
      ConversationMessage(tdMessage(id: 1, chatId: 7, text: 'Hi')),
      ConversationMessage(
        tdMessage(
          id: 2,
          chatId: 7,
          content: td.MessagePhoto(
            photo: const td.Photo(hasStickers: false, sizes: []),
            caption: const td.FormattedText(text: 'Sea', entities: []),
            showCaptionAboveMedia: false,
            hasSpoiler: false,
            isSecret: false,
          ),
        ),
      ),
    ]);

    await controller.editText(7, 1, 'Hello');
    await controller.editText(7, 2, 'Sea view');

    expect(
      json.sent.map((r) => r['@type']),
      containsAllInOrder(['editMessageText', 'editMessageCaption']),
    );
    final caption = json.sent.last['caption']! as Map;
    expect(caption['text'], 'Sea view');
  });

  test('deletes and forwards through TDLib', () async {
    await controller.start();

    await controller.deleteMessages(7, [1, 2], revoke: true);
    await controller.deleteMessages(7, [], revoke: true);
    await controller.forwardMessages(8, 7, [3]);

    final types = json.sent.map((r) => r['@type']).toList();
    expect(types.where((t) => t == 'deleteMessages'), hasLength(1));
    final delete = json.sent.firstWhere((r) => r['@type'] == 'deleteMessages');
    expect(delete['message_ids'], [1, 2]);
    expect(delete['revoke'], isTrue);
    final forward = json.sent.firstWhere(
      (r) => r['@type'] == 'forwardMessages',
    );
    expect(forward['chat_id'], 8);
    expect(forward['from_chat_id'], 7);
  });

  test('sends files as albums with the caption on the first', () async {
    await controller.start();

    await controller.sendFiles(
      7,
      const [
        OutgoingFile(path: '/a.jpg', kind: OutgoingKind.photo),
        OutgoingFile(path: '/b.mp4', kind: OutgoingKind.video),
        OutgoingFile(path: '/c.pdf', kind: OutgoingKind.document),
      ],
      caption: 'Trip',
      replyTo: 10,
    );

    final album = json.sent.firstWhere((r) => r['@type'] == 'sendMessageAlbum');
    final contents = album['input_message_contents']! as List;
    expect(contents, hasLength(2));
    expect(((contents[0] as Map)['caption']! as Map)['text'], 'Trip');
    expect((contents[1] as Map)['caption'], isNull);
    expect(album['reply_to'], containsPair('message_id', 10));

    final single = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      (single['input_message_content']! as Map)['@type'],
      'inputMessageDocument',
    );
    expect(single['reply_to'], isNull);
    expect(controller.store.message(7, 30), isNotNull);
  });

  test('sends a sticker by its file id', () async {
    await controller.start();
    final sticker = td.Sticker.fromJson({
      '@type': 'sticker',
      'id': 100,
      'set_id': 55,
      'width': 512,
      'height': 480,
      'emoji': '🐱',
      'format': {'@type': 'stickerFormatWebp'},
      'full_type': {'@type': 'stickerFullTypeRegular'},
      'sticker': {
        '@type': 'file',
        'id': 301,
        'size': 1000,
        'expected_size': 1000,
        'local': {
          '@type': 'localFile',
          'path': '',
          'can_be_downloaded': true,
          'is_downloading_completed': false,
        },
        'remote': {'@type': 'remoteFile', 'id': 'r301', 'unique_id': 'u301'},
      },
    });

    await controller.sendSticker(7, sticker, replyTo: 10);

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageSticker');
    expect(content['emoji'], '🐱');
    expect(content['sticker'], {
      '@type': 'inputSticker',
      'sticker': {'@type': 'inputFileId', 'id': 301},
      'width': 512,
      'height': 480,
    });
  });

  test('sends a voice message with its waveform', () async {
    await controller.start();

    await controller.sendVoiceNote(
      7,
      path: '/tmp/voice.ogg',
      duration: const Duration(milliseconds: 2400),
      waveform: Uint8List.fromList([1, 2, 3]),
      replyTo: 10,
    );

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['reply_to'], containsPair('message_id', 10));
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageVoiceNote');
    expect(content['voice_note'], {
      '@type': 'inputVoiceNote',
      'voice_note': {'@type': 'inputFileLocal', 'path': '/tmp/voice.ogg'},
      'duration': 3,
      'waveform': base64Encode([1, 2, 3]),
    });
  });

  test('opens a chat with unread messages at the last read one', () async {
    json.chat = [for (var id = 1; id <= 200; id++) id];
    await controller.start();
    json.push(_chat(lastRead: 100, unread: 100, last: 200));
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await controller.loadHistory(7);

    final request = json.sent.firstWhere((r) => r['@type'] == 'getChatHistory');
    expect(request['from_message_id'], 100);
    expect(request['offset'], -40);
    final ids = controller.store.messagesFor(7).map((m) => m.id);
    expect(ids.first, 140);
    expect(ids.last, 91);
    expect(controller.store.reachedEnd(7), isFalse);
    expect(controller.store.unreadCount(7), 100);
  });

  test('pages newer history up to the last message', () async {
    json.chat = [for (var id = 1; id <= 120; id++) id];
    await controller.start();
    json.push(_chat(lastRead: 0, unread: 0, last: 120));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.loadAround(7, 50);
    expect(controller.store.newestId(7), 75);

    // A message beyond the gap waits for its page.
    json.push({
      '@type': 'updateNewMessage',
      'message': _message(id: 121, chatId: 7, text: 'Live').toJson(),
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.contains(7, 121), isFalse);

    expect(await controller.loadNewer(7), isTrue);
    expect(controller.store.newestId(7), 120);
    expect(controller.store.reachedEnd(7), isTrue);
    expect(await controller.loadNewer(7), isFalse);
  });

  test('keeps unread mention and reaction counts', () async {
    await controller.start();
    json
      ..push(_chat(lastRead: 5, unread: 3, last: 8, mentions: 2, reactions: 1))
      ..push({
        '@type': 'updateMessageMentionRead',
        'chat_id': 7,
        'message_id': 6,
        'unread_mention_count': 1,
      });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.unreadMentionCount(7), 1);
    expect(controller.store.unreadReactionCount(7), 1);

    final mention = await controller.firstUnread(7);
    expect(mention?.id, 30);
  });

  test('keeps the pinned messages of a chat up to date', () async {
    await controller.start();
    await controller.loadPinned(7);
    expect(controller.store.pinnedIds(7), [50, 20]);
    expect(controller.store.message(7, 20)?.text, 'Pinned');

    json.push({
      '@type': 'updateMessageIsPinned',
      'chat_id': 7,
      'message_id': 20,
      'is_pinned': false,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(controller.store.pinnedIds(7), [50]);

    await controller.setPinned(7, 60, pinned: true);
    final pin = json.sent.lastWhere((r) => r['@type'] == 'pinChatMessage');
    expect(pin['message_id'], 60);
    await controller.setPinned(7, 50, pinned: false);
    expect(json.sent.last['@type'], 'unpinChatMessage');
  });

  test('follows membership and mute state of a channel', () async {
    await controller.start();
    json.push(
      _chat(
        lastRead: 0,
        unread: 0,
        last: 8,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 99,
          'is_channel': true,
        },
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final store = controller.store;
    expect(store.membership(7), ChatMembership.unknown);

    json.push(_supergroup(99, {'@type': 'chatMemberStatusLeft'}));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.membership(7), ChatMembership.left);
    expect(store.canPost(7), isFalse);

    await controller.joinChat(7);
    expect(json.sent.last['@type'], 'joinChat');

    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusMember',
        'member_since_date': 0,
      }),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.membership(7), ChatMembership.member);
    // A channel's plain member reads, but can't post.
    expect(store.canPost(7), isFalse);
    expect(store.isMuted(7), isFalse);

    await controller.setMuted(7, muted: true);
    final mute = json.sent.last;
    expect(mute['@type'], 'setChatNotificationSettings');
    final settings = mute['notification_settings']! as Map;
    expect(settings['use_default_mute_for'], isFalse);
    expect(settings['mute_for'], greaterThan(0));

    json.push({
      '@type': 'updateChatNotificationSettings',
      'chat_id': 7,
      'notification_settings': {
        '@type': 'chatNotificationSettings',
        'mute_for': 2147483647,
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(store.isMuted(7), isTrue);
  });

  test('finds photos and videos around a message, oldest first', () async {
    await controller.start();

    final found = await controller.mediaAround(7, 20, newer: 5, limit: 11);

    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'searchChatMessages',
    );
    expect(search['chat_id'], 7);
    expect(search['from_message_id'], 20);
    expect(search['offset'], -5);
    expect(search['limit'], 11);
    expect(
      (search['filter']! as Map)['@type'],
      'searchMessagesFilterPhotoAndVideo',
    );
    expect(found.map((m) => m.id), [18, 20, 22]);
  });

  test('sends a caption too long for media as its own message', () async {
    await controller.start();

    await controller.sendFiles(
      7,
      const [OutgoingFile(path: '/a.jpg', kind: OutgoingKind.photo)],
      caption: 'A rather long caption',
      replyTo: 10,
    );

    final sends = [
      for (final r in json.sent)
        if (r['@type'] == 'sendMessage') r,
    ];
    expect(sends, hasLength(2));
    final text = sends.first['input_message_content']! as Map;
    expect(text['@type'], 'inputMessageText');
    expect((text['text']! as Map)['text'], 'A rather long caption');
    expect(sends.first['reply_to'], containsPair('message_id', 10));
    final photo = sends.last['input_message_content']! as Map;
    expect(photo['@type'], 'inputMessagePhoto');
    expect(photo['caption'], isNull);
    expect(sends.last['reply_to'], isNull);
  });

  test('offers free emoji reactions once each, in order', () async {
    await controller.start();

    expect(await controller.quickReactions(7, 1), ['👍', '❤', '😁']);
    expect(await controller.quickReactions(7, 1, limit: 2), ['👍', '❤']);
    // TDLib takes rows of 5 to 25.
    final rows = [
      for (final r in json.sent)
        if (r['@type'] == 'getMessageAvailableReactions') r['row_size'],
    ];
    expect(rows, [8, 5]);

    json.reactionsUnavailable = {'@type': 'reactionUnavailabilityReasonGuest'};
    expect(await controller.quickReactions(7, 1), isEmpty);
  });

  test('announces a new avatar or colour of a sender', () async {
    await controller.start();
    var changes = 0;
    controller.changes.listen((_) => changes++);

    json.push({
      '@type': 'updateChatAccentColors',
      'chat_id': 7,
      'accent_color_id': 3,
      'background_custom_emoji_id': 0,
      'profile_accent_color_id': -1,
      'profile_background_custom_emoji_id': 0,
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(changes, 1);
    expect(controller.store.colorOf(const MessageSenderId.chat(7)), 3);
  });

  test('shows ephemeral content instead of the regular one', () async {
    await controller.start();
    await controller.loadHistory(7);

    json.push({
      '@type': 'updateMessageEphemeralContent',
      'chat_id': 7,
      'message_id': 10,
      'ephemeral_content': {
        '@type': 'ephemeralMessageContent',
        'can_be_saved': true,
        'has_timestamped_media': false,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'Secret',
            'entities': <Object?>[],
          },
        },
      },
    });
    await Future<void>.delayed(const Duration(milliseconds: 5));

    expect(controller.store.message(7, 10)?.text, 'Secret');
  });

  test('keeps the sender of each message', () async {
    await controller.start();
    await controller.loadHistory(7);
    controller.store.setUserName(1, 'Alina');

    final sender = controller.store.messagesFor(7).single.sender;
    expect(sender, const MessageSenderId.user(1));
    expect(controller.store.nameOf(sender), 'Alina');
    expect(controller.store.nameOf(const MessageSenderId.chat(1)), isNull);
  });

  test('opens, views and closes a chat through TDLib', () async {
    await controller.start();

    await controller.openChat(7);
    await controller.viewMessages(7, [10, 11]);
    await controller.viewMessages(7, []);
    await controller.closeChat(7);

    expect(json.sent.map((request) => request['@type']), [
      'openChat',
      'viewMessages',
      'closeChat',
    ]);
    expect(json.sent[1]['message_ids'], [10, 11]);
    expect(json.sent[1]['force_read'], isFalse);
  });
}

Map<String, Object?> _chat({
  required int lastRead,
  required int unread,
  required int last,
  int mentions = 0,
  int reactions = 0,
  Map<String, Object?> type = const {'@type': 'chatTypePrivate', 'user_id': 2},
}) => {
  '@type': 'updateNewChat',
  'chat': {
    '@type': 'chat',
    'id': 7,
    'type': type,
    'title': 'Boris',
    'last_message': _message(id: last, chatId: 7, text: 'Last').toJson(),
    'unread_count': unread,
    'last_read_inbox_message_id': lastRead,
    'last_read_outbox_message_id': 0,
    'unread_mention_count': mentions,
    'unread_reaction_count': reactions,
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

Map<String, Object?> _supergroup(int id, Map<String, Object?> status) => {
  '@type': 'updateSupergroup',
  'supergroup': {
    '@type': 'supergroup',
    'id': id,
    'date': 0,
    'status': status,
    'member_count': 10,
    'boost_level': 0,
    'has_automatic_translation': false,
    'has_linked_chat': false,
    'has_location': false,
    'sign_messages': false,
    'show_message_sender': false,
    'join_to_send_messages': false,
    'join_by_request': false,
    'is_slow_mode_enabled': false,
    'is_channel': true,
    'is_broadcast_group': false,
    'is_forum': false,
    'is_direct_messages_group': false,
    'is_administered_direct_messages_group': false,
    'has_direct_messages_group': false,
    'has_forum_tabs': false,
    'paid_message_star_count': 0,
  },
};

td.Message _message({
  required int id,
  required int chatId,
  required String text,
  td.MessageSendingState? sendingState,
}) => td.Message(
  id: id,
  sendingState: sendingState,
  senderId: const td.MessageSenderUser(userId: 1),
  chatId: chatId,
  isOutgoing: true,
  isPinned: false,
  isFromOffline: false,
  canBeSaved: true,
  hasTimestampedMedia: false,
  isChannelPost: false,
  isPaidStarSuggestedPost: false,
  isPaidGramSuggestedPost: false,
  containsUnreadMention: false,
  containsUnreadPollVotes: false,
  date: id,
  editDate: 0,
  unreadReactions: const [],
  selfDestructIn: 0,
  autoDeleteIn: 0,
  viaBotUserId: 0,
  senderBusinessBotUserId: 0,
  senderBoostCount: 0,
  senderTag: '',
  paidMessageStarCount: 0,
  authorSignature: '',
  mediaAlbumId: 0,
  effectId: 0,
  summaryLanguageCode: '',
  content: td.MessageText(
    text: td.FormattedText(text: text, entities: const []),
  ),
  ephemeralMessageId: 0,
  chatInstance: 0,
);

/// The ids TDLib returns for a history request over [ids], newest first.
List<int> _page(List<int> ids, int from, int offset, int limit) {
  final newestFirst = [...ids]..sort((a, b) => b.compareTo(a));
  var start = from == 0 ? 0 : newestFirst.indexWhere((id) => id <= from);
  if (start < 0) return const [];
  start = (start + offset).clamp(0, newestFirst.length);
  return newestFirst.skip(start).take(limit).toList();
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// Delivered as `updateNewMessage` before the history response.
  td.Message? liveDuringHistory;

  /// The history page that starts at a message id (0 is the newest).
  List<td.Message> Function(int fromMessageId)? history;

  /// A whole chat of text messages with these ids, paged as TDLib does
  /// with from_message_id, offset and limit; takes the place of [history].
  List<int>? chat;

  /// When set, getRepliedMessage fails with this TDLib error code.
  int? repliedError;

  /// When set, reactions come back unavailable for this reason.
  Map<String, Object?>? reactionsUnavailable;
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
    if (decoded['@type'] == 'getChatHistory' && liveDuringHistory != null) {
      push({
        '@type': 'updateNewMessage',
        'message': liveDuringHistory!.toJson(),
      });
    }
    final response = switch (decoded['@type']) {
      'getChatHistory' when chat != null => {
        '@type': 'messages',
        'total_count': chat!.length,
        'messages': [
          for (final id in _page(
            chat!,
            decoded['from_message_id']! as int,
            decoded['offset']! as int,
            decoded['limit']! as int,
          ))
            _message(id: id, chatId: 7, text: 'm$id').toJson(),
        ],
      },
      'searchChatMessages'
          when (decoded['filter']! as Map)['@type'] ==
              'searchMessagesFilterPinned' =>
        {
          '@type': 'foundChatMessages',
          'total_count': 2,
          'messages': [
            for (final id in [50, 20])
              {
                ..._message(id: id, chatId: 7, text: 'Pinned').toJson(),
                'is_pinned': true,
              },
          ],
          'next_from_message_id': 0,
        },
      'searchChatMessages'
          when (decoded['filter']! as Map)['@type'] ==
              'searchMessagesFilterUnreadMention' =>
        {
          '@type': 'foundChatMessages',
          'total_count': 2,
          'messages': [
            for (final id in [40, 30])
              _message(id: id, chatId: 7, text: '@me').toJson(),
          ],
          'next_from_message_id': 0,
        },
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          for (final message
              in history?.call(decoded['from_message_id']! as int) ??
                  [_message(id: 10, chatId: 7, text: 'From history')])
            message.toJson(),
        ],
      },
      'editMessageText' || 'editMessageCaption' => _message(
        id: decoded['message_id']! as int,
        chatId: 7,
        text: 'Edited',
      ).toJson(),
      'sendMessageAlbum' => {
        '@type': 'messages',
        'total_count': 2,
        'messages': [
          _message(id: 30, chatId: 7, text: '').toJson(),
          _message(id: 31, chatId: 7, text: '').toJson(),
        ],
      },
      'searchChatMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 3,
        'messages': [
          for (final id in [22, 20, 18])
            _message(id: id, chatId: 7, text: '').toJson(),
        ],
        'next_from_message_id': 18,
      },
      'joinChat' => {'@type': 'chatJoinResultSuccess'},
      'forwardMessages' => {
        '@type': 'messages',
        'total_count': 0,
        'messages': <Object?>[],
      },
      'getMessageAvailableReactions' => {
        '@type': 'availableReactions',
        'top_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '👍'}),
          _reaction({
            '@type': 'reactionTypeEmoji',
            'emoji': '🔥',
          }, premium: true),
          _reaction({'@type': 'reactionTypeCustomEmoji', 'custom_emoji_id': 9}),
        ],
        'recent_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '👍'}),
        ],
        'popular_reactions': [
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '❤'}),
          _reaction({'@type': 'reactionTypeEmoji', 'emoji': '😁'}),
        ],
        'allow_custom_emoji': true,
        'are_tags': false,
        'unavailability_reason': reactionsUnavailable,
      },
      'getRepliedMessage' when repliedError != null => {
        '@type': 'error',
        'code': repliedError,
        'message': 'Failed',
      },
      'getRepliedMessage' => _message(
        id: 3,
        chatId: 7,
        text: 'Quoted',
      ).toJson(),
      'sendMessage' => _message(
        id: 12,
        chatId: 7,
        text: 'Sent text',
        sendingState: const td.MessageSendingStatePending(sendingId: 1),
      ).toJson(),
      'getOption' when decoded['name'] == 'message_caption_length_max' => {
        '@type': 'optionValueInteger',
        'value': '10',
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

Map<String, Object?> _reaction(
  Map<String, Object?> type, {
  bool premium = false,
}) => {'@type': 'availableReaction', 'type': type, 'needs_premium': premium};
