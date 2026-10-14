import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

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

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// Delivered as `updateNewMessage` before the history response.
  td.Message? liveDuringHistory;

  /// The history page that starts at a message id (0 is the newest).
  List<td.Message> Function(int fromMessageId)? history;
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
