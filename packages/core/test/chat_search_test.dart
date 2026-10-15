import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatSearch search;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    search = ChatSearch(tdlib.createClient());
  });

  tearDown(() => tdlib.close());

  test('merges own chats and server results without duplicates', () async {
    expect(await search.chats('ann'), [1, 2, 3]);
    expect(json.sent.map((r) => r['@type']), [
      'searchChats',
      'searchChatsOnServer',
    ]);
  });

  test('keeps own chats when the server search fails', () async {
    json.serverFails = true;
    expect(await search.chats('ann'), [1, 2]);
  });

  test('respects the limit', () async {
    expect(await search.chats('ann', limit: 2), [1, 2]);
  });

  test('does not search for blank text', () async {
    expect(await search.chats('  '), isEmpty);
    expect(await search.messages(''), isEmpty);
    expect(json.sent, isEmpty);
  });

  test(
    'looks for a hashtag in the chat, own messages or public posts',
    () async {
      final inChat = await search.hashtag(
        '#lease',
        scope: HashtagScope.thisChat,
        chatId: 7,
      );
      expect(json.sent.last['@type'], 'searchChatMessages');
      expect(json.sent.last['chat_id'], 7);
      expect(json.sent.last['query'], '#lease');
      expect(inChat.messages.map((m) => m.id), [30, 20]);
      expect(inChat.nextFromMessageId, 20);

      final mine = await search.hashtag(
        '#lease',
        scope: HashtagScope.myMessages,
      );
      expect(json.sent.last['@type'], 'searchMessages');
      expect(json.sent.last['query'], '#lease');
      expect(mine.messages.map((m) => m.id), [10, 11, 12]);
      expect(mine.nextOffset, '');

      final public = await search.hashtag(
        '#lease',
        scope: HashtagScope.publicPosts,
        offset: 'page2',
      );
      expect(json.sent.last['@type'], 'searchPublicMessagesByTag');
      expect(json.sent.last['tag'], '#lease');
      expect(json.sent.last['offset'], 'page2');
      expect(public.messages.map((m) => m.id), [40]);
      expect(public.nextOffset, 'page3');
      expect(public.totalCount, 5);
    },
  );

  test('finds messages with text, captions and file names', () async {
    final found = await search.messages('lease');
    expect(json.sent.single['@type'], 'searchMessages');
    expect(json.sent.single['query'], 'lease');
    expect(
      [for (final m in found) (m.chatId, m.messageId, m.text, m.isFile)],
      [(7, 10, 'Lease ends in May', false), (8, 11, 'lease.pdf', true)],
    );
  });
}

td.Message _message({
  required int id,
  required int chatId,
  required td.MessageContent content,
}) => td.Message(
  id: id,
  senderId: const td.MessageSenderUser(userId: 1),
  chatId: chatId,
  isOutgoing: false,
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
  content: content,
  ephemeralMessageId: 0,
  chatInstance: 0,
);

td.FormattedText _text(String text) =>
    td.FormattedText(text: text, entities: const []);

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var serverFails = false;
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
      'searchChats' => {
        '@type': 'chats',
        'total_count': 2,
        'chat_ids': [1, 2],
      },
      'searchChatsOnServer' when serverFails => {
        '@type': 'error',
        'code': 400,
        'message': 'Network',
      },
      'searchChatsOnServer' => {
        '@type': 'chats',
        'total_count': 2,
        'chat_ids': [2, 3],
      },
      'searchChatMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 2,
        'next_from_message_id': 20,
        'messages': [
          _message(
            id: 30,
            chatId: 7,
            content: td.MessageText(text: _text('#lease soon')),
          ).toJson(),
          _message(
            id: 20,
            chatId: 7,
            content: td.MessageText(text: _text('#lease done')),
          ).toJson(),
        ],
      },
      'searchPublicMessagesByTag' => {
        '@type': 'foundMessages',
        'total_count': 5,
        'next_offset': 'page3',
        'messages': [
          _message(
            id: 40,
            chatId: -100,
            content: td.MessageText(text: _text('#lease news')),
          ).toJson(),
        ],
      },
      'searchMessages' => {
        '@type': 'foundMessages',
        'total_count': 3,
        'next_offset': '',
        'messages': [
          _message(
            id: 10,
            chatId: 7,
            content: td.MessageText(text: _text('Lease ends in May')),
          ).toJson(),
          _message(
            id: 11,
            chatId: 8,
            content: td.MessageDocument(
              document: td.Document.fromJson({
                'file_name': 'lease.pdf',
                'mime_type': 'application/pdf',
                'document': _file,
              }),
              caption: _text(''),
            ),
          ).toJson(),
          // A service message has nothing to show in the results.
          _message(
            id: 12,
            chatId: 8,
            content: const td.MessageScreenshotTaken(),
          ).toJson(),
        ],
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
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': 1,
        }),
      );
    }
  }
}

const _file = {
  '@type': 'file',
  'id': 1,
  'size': 0,
  'expected_size': 0,
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
    'id': '',
    'unique_id': '',
    'is_uploading_active': false,
    'is_uploading_completed': true,
    'uploaded_size': 0,
  },
};
