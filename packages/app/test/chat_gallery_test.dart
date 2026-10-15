import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/home/chat_view.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Every kind of message the chat draws, as a golden image per theme: the
/// visual check of the flat message layout.
void main() {
  late Directory files;
  late String photoPath;

  setUpAll(() async {
    files = Directory.systemTemp.createTempSync('mollygram_gallery');
    photoPath = '${files.path}/photo.png';
    File(photoPath).writeAsBytesSync(_gradientPng(640, 420));
  });

  tearDownAll(() => files.deleteSync(recursive: true));

  late TelegramSession session;

  setUp(() async {
    final json = _FakeTdJson(_history(photoPath));
    session = await TelegramSession.attach(
      td.Td.custom(json, td.InlineTdEventSource(json)),
      parameters: TdlibParameters(
        api: const TelegramApiConfig(
          apiId: 12345,
          apiHash: '0123456789abcdef0123456789abcdef',
        ),
        databaseDirectory: '/tmp/mollygram/database',
        filesDirectory: '/tmp/mollygram/files',
        databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
        systemLanguageCode: 'en',
        deviceModel: 'Mac',
        applicationVersion: '0.1.0',
      ),
    );
  });

  tearDown(() => session.dispose());

  for (final dark in [false, true]) {
    testWidgets('message gallery ${dark ? 'dark' : 'light'}', (tester) async {
      session.conversations.store
        ..setUserName(1, 'Alina')
        ..setUserName(2, 'Boris Petrov')
        ..setUserName(3, 'Vera')
        ..setColor(const MessageSenderId.user(2), 1)
        ..setColor(const MessageSenderId.user(3), 4)
        ..setColor(const MessageSenderId.user(1), 5)
        ..setChatTitle(9, 'Flutter Dev')
        ..setReadOutbox(7, 1000);

      tester.view
        ..physicalSize = const Size(1000, 2700)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final colors = dark ? MgColors.dark : MgColors.light;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramSessionProvider.overrideWith((ref) async => session),
            chatEntryProvider.overrideWith(
              (ref, chatId) => Stream.value(
                ChatListEntry(
                  id: chatId,
                  title: 'Weekend trip',
                  unreadCount: 0,
                  positions: const [],
                  type: ChatType.supergroup,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildMgTheme(colors),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: colors.windowBackground),
                  ),
                  const _Host(),
                ],
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump();
      }
      // Let the photo files load and decode.
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump();
      }

      // A spoiler stays covered; a call Boris made is an incoming one.
      expect(find.text('Spoiler'), findsOneWidget);
      expect(find.text('Incoming call'), findsOneWidget);

      await expectLater(
        find.byType(ChatView),
        matchesGoldenFile(
          'goldens/chat_gallery_${dark ? 'dark' : 'light'}.png',
        ),
      );
    });
  }
}

const _tick = Duration(milliseconds: 20);

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue
      ? const ChatView(chatId: 7)
      : const SizedBox();
}

/// A diagonal green-to-blue gradient as a PNG, standing in for a photo.
Uint8List _gradientPng(int width, int height) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0);
    for (var x = 0; x < width; x++) {
      final t = (x / width + y / height) / 2;
      raw.add([
        (0x6B + (0x8F - 0x6B) * t).round(),
        (0xA5 + (0xA2 - 0xA5) * t).round(),
        (0x87 + (0xD3 - 0x87) * t).round(),
        255,
      ]);
    }
  }
  Uint8List chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return Uint8List.fromList([
      ..._be32(data.length),
      ...body,
      ..._be32(_crc32(body)),
    ]);
  }

  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ...chunk('IHDR', [..._be32(width), ..._be32(height), 8, 6, 0, 0, 0]),
    ...chunk('IDAT', zlib.encode(raw.takeBytes())),
    ...chunk('IEND', const []),
  ]);
}

List<int> _be32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

Map<String, Object?> _file(int id, {String? path, int size = 2400000}) => {
  '@type': 'file',
  'id': id,
  'size': size,
  'expected_size': size,
  'local': {
    '@type': 'localFile',
    'path': path ?? '',
    'can_be_downloaded': false,
    'can_be_deleted': false,
    'is_downloading_active': false,
    'is_downloading_completed': path != null,
    'download_offset': 0,
    'downloaded_prefix_size': 0,
    'downloaded_size': path == null ? 0 : size,
  },
  'remote': {
    '@type': 'remoteFile',
    'id': 'r$id',
    'unique_id': 'u$id',
    'is_uploading_active': false,
    'is_uploading_completed': true,
    'uploaded_size': size,
  },
};

Map<String, Object?> _text(String text, [List<Object?> entities = const []]) =>
    {'@type': 'formattedText', 'text': text, 'entities': entities};

Map<String, Object?> _entity(
  int offset,
  int length,
  Map<String, Object?> type,
) => {'@type': 'textEntity', 'offset': offset, 'length': length, 'type': type};

Map<String, Object?> _photo(int fileId, String path) => {
  '@type': 'photo',
  'has_stickers': false,
  'sizes': [
    {
      '@type': 'photoSize',
      'type': 'x',
      'photo': _file(fileId, path: path),
      'width': 640,
      'height': 420,
      'progressive_sizes': <int>[],
    },
  ],
};

td.Message _message(
  int id,
  int sender,
  Map<String, Object?> content, {
  bool outgoing = false,
  int dayOffset = 0,
  Map<String, Object?>? replyTo,
  Map<String, Object?>? forward,
  Map<String, Object?>? interaction,
  int albumId = 0,
  int editDate = 0,
}) => td.Message.fromJson({
  '@type': 'message',
  'id': id,
  'sender_id': {'@type': 'messageSenderUser', 'user_id': sender},
  'chat_id': 7,
  'is_outgoing': outgoing,
  // 2025-10-09 12:00 UTC plus a minute per message.
  'date': 1760011200 - dayOffset * 86400 + id * 60,
  'edit_date': editDate,
  'reply_to': ?replyTo,
  'forward_info': ?forward,
  'interaction_info': ?interaction,
  'media_album_id': '$albumId',
  'content': content,
});

/// Oldest first.
List<td.Message> _history(String photo) => [
  _message(1, 2, {
    '@type': 'messageChatAddMembers',
    'member_user_ids': [3],
  }, dayOffset: 1),
  _message(2, 2, {
    '@type': 'messageText',
    'text': _text(
      'Plan for Saturday: meet at 10, train at 10:40. Tickets on tutu.ru',
      [
        _entity(0, 17, {'@type': 'textEntityTypeBold'}),
        _entity(58, 7, {'@type': 'textEntityTypeUrl'}),
      ],
    ),
  }, dayOffset: 1),
  _message(3, 2, {
    '@type': 'messageText',
    'text': _text('Bring a jacket, it gets cold by the lake'),
  }, dayOffset: 1),
  _message(4, 3, {
    '@type': 'messageVoiceNote',
    'voice_note': {
      '@type': 'voiceNote',
      'duration': 18,
      'waveform': base64.encode(
        List<int>.generate(63, (i) => (i * 37 + 11) % 256),
      ),
      'mime_type': 'audio/ogg',
      'voice': _file(40),
    },
    'caption': _text(''),
    'is_listened': true,
  }),
  _message(
    5,
    1,
    {'@type': 'messageText', 'text': _text('Sure, I will take the big one')},
    outgoing: true,
    replyTo: {'@type': 'messageReplyToMessage', 'chat_id': 7, 'message_id': 3},
  ),
  _message(
    6,
    1,
    {
      '@type': 'messagePhoto',
      'photo': _photo(50, photo),
      'caption': _text('The view from last time'),
    },
    outgoing: true,
    interaction: {
      '@type': 'messageInteractionInfo',
      'view_count': 0,
      'forward_count': 0,
      'reactions': {
        '@type': 'messageReactions',
        'reactions': [
          {
            '@type': 'messageReaction',
            'type': {'@type': 'reactionTypeEmoji', 'emoji': '❤️'},
            'total_count': 2,
            'is_chosen': true,
            'recent_sender_ids': <Object?>[],
          },
          {
            '@type': 'messageReaction',
            'type': {'@type': 'reactionTypeEmoji', 'emoji': '🔥'},
            'total_count': 1,
            'is_chosen': false,
            'recent_sender_ids': <Object?>[],
          },
        ],
        'are_tags': false,
        'paid_reactors': <Object?>[],
        'can_get_added_reactions': true,
      },
    },
  ),
  for (var i = 0; i < 3; i++)
    _message(7 + i, 3, {
      '@type': 'messagePhoto',
      'photo': _photo(60 + i, photo),
      'caption': _text(''),
    }, albumId: 99),
  _message(10, 2, {
    '@type': 'messageDocument',
    'document': {
      '@type': 'document',
      'file_name': 'route_saturday.pdf',
      'mime_type': 'application/pdf',
      'document': _file(70, size: 412000),
    },
    'caption': _text(''),
  }),
  _message(
    11,
    2,
    {'@type': 'messageText', 'text': _text('Weather looks good')},
    forward: {
      '@type': 'messageForwardInfo',
      'origin': {
        '@type': 'messageOriginHiddenUser',
        'sender_name': 'Weather Bot',
      },
      'date': 1760000000,
    },
  ),
  _message(12, 3, {'@type': 'messageText', 'text': _text('👍🏔️')}),
  _message(13, 3, {
    '@type': 'messagePoll',
    'poll': {
      '@type': 'poll',
      'id': '1',
      'question': _text('Lunch?'),
      'options': [
        {
          '@type': 'pollOption',
          'id': 'a',
          'text': _text('Picnic'),
          'voter_count': 2,
          'vote_percentage': 67,
          'is_chosen': true,
        },
        {
          '@type': 'pollOption',
          'id': 'b',
          'text': _text('Cafe'),
          'voter_count': 1,
          'vote_percentage': 33,
        },
      ],
      'total_voter_count': 3,
      'can_see_results': true,
      'type': {'@type': 'pollTypeRegular', 'allow_multiple_answers': false},
    },
    'description': _text(''),
    'can_add_option': false,
  }),
  _message(
    14,
    1,
    {'@type': 'messageText', 'text': _text('Picnic then. See you')},
    outgoing: true,
    editDate: 1760020000,
  ),
  _message(15, 3, {
    '@type': 'messagePhoto',
    'photo': _photo(70, photo),
    'caption': _text(''),
    'has_spoiler': true,
  }),
  _message(16, 2, {
    '@type': 'messageCall',
    'is_video': false,
    'discard_reason': {'@type': 'callDiscardReasonHungUp'},
    'duration': 95,
  }),
];

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this.history);

  final List<td.Message> history;
  final _queue = Queue<String>();
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
    final type = decoded['@type'];
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getChatHistory' when decoded['from_message_id'] == 0 => {
        '@type': 'messages',
        'total_count': history.length,
        'messages': [for (final m in history.reversed) m.toJson()],
      },
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': 0,
        'messages': <Object?>[],
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
    if (type == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': clientId,
        }),
      );
    }
  }
}
