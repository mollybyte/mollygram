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
}

td.Message _message({
  required int id,
  required int chatId,
  required String text,
}) => td.Message(
  id: id,
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
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          _message(id: 10, chatId: 7, text: 'From history').toJson(),
        ],
      },
      'sendMessage' => _message(id: 12, chatId: 7, text: 'Sent text').toJson(),
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
