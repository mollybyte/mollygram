import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/media_content.dart';
import 'package:mollygram/src/chat_search/chat_search_bar.dart';
import 'package:mollygram/src/chat_search/sender_picker.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/shared_media/shared_link.dart';
import 'package:mollygram/src/shared_media/shared_media_view.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  late _FakeTdJson json;
  late TelegramSession session;

  setUp(() async {
    json = _FakeTdJson();
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(800, 600)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: _WhenSignedIn(child: child)),
        ),
      ),
    );
    await settle(tester);
  }

  group('search bar', () {
    late List<int> shown;
    late int closed;

    Future<void> open(WidgetTester tester) async {
      shown = [];
      closed = 0;
      await pump(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 480,
            child: ChatSearchBar(
              find: (query, sender) =>
                  session.chatSearch.find(7, query, senderUserId: sender),
              onResult: shown.add,
              onClose: () => closed++,
              onPickSender: (position) => pickSearchSender(
                tester.element(find.byType(ChatSearchBar)),
                position: position,
                search: (query) => session.mentions.search(7, query),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump(ChatSearchBar.debounce);
      await settle(tester);
    }

    testWidgets('jumps to the newest match and steps through the rest', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'lease');

      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'searchChatMessages',
      );
      expect(request['chat_id'], 7);
      expect(request['query'], 'lease');
      expect(shown, [30]);
      expect(find.text('1 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(shown, [30, 20]);
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous result'));
      await settle(tester);
      expect(shown, [30, 20, 10]);
      expect(find.text('3 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(shown, [30, 20, 10, 20]);
      expect(find.text('2 of 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(closed, 1);
    });

    testWidgets('narrows the search to one member', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Search by sender'));
      await settle(tester);
      expect(find.text('Boris'), findsOneWidget);

      await tester.tap(find.text('Boris'));
      await settle(tester);
      // The chip names the member and their messages are the results.
      expect(find.text('Boris'), findsOneWidget);
      var request = json.sent.lastWhere(
        (r) => r['@type'] == 'searchChatMessages',
      );
      expect((request['sender_id']! as Map)['user_id'], 2);
      expect(request['query'], '');
      expect(shown, [22]);
      expect(find.text('1 of 1'), findsOneWidget);

      await type(tester, 'lease');
      request = json.sent.lastWhere((r) => r['@type'] == 'searchChatMessages');
      expect((request['sender_id']! as Map)['user_id'], 2);
      expect(request['query'], 'lease');

      // Clearing the chip searches the whole chat again.
      await tester.tap(find.byTooltip('Close').first);
      await settle(tester);
      expect(find.text('Boris'), findsNothing);
      request = json.sent.lastWhere((r) => r['@type'] == 'searchChatMessages');
      expect(request['sender_id'], isNull);
    });

    testWidgets('says when nothing matches', (tester) async {
      await open(tester);
      await type(tester, 'zzz');
      expect(find.text('No results'), findsOneWidget);
      expect(shown, isEmpty);

      await type(tester, '');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('No results'), findsNothing);
    });

    testWidgets('lets go of the old results as soon as the query changes', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'lease');
      expect(find.text('1 of 3'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'leases');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1 of 3'), findsNothing);
      expect(
        tester
            .widget<MgIconButton>(
              find.ancestor(
                of: find.byTooltip('Previous result'),
                matching: find.byType(MgIconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(ChatSearchBar.debounce);
      await settle(tester);
      expect(shown, [30]);
    });

    testWidgets('searches again on Return after a failure', (tester) async {
      await open(tester);
      json.fail = true;
      await type(tester, 'lease');
      expect(find.text('No results'), findsOneWidget);

      json.fail = false;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(shown, [30]);
      expect(find.text('1 of 3'), findsOneWidget);
    });
  });

  group('shared media', () {
    testWidgets('shows photos in a grid and switches tabs', (tester) async {
      final opened = <int>[];
      await pump(
        tester,
        SharedMediaView(chatId: 7, onOpenMessage: (m) => opened.add(m.id)),
      );
      expect(find.byType(PhotoContent), findsNWidgets(2));
      expect(_filters(json), ['searchMessagesFilterPhotoAndVideo']);

      await tester.tap(find.text('Links'));
      await settle(tester);
      expect(_filters(json).last, 'searchMessagesFilterUrl');
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('https://example.com/a'), findsOneWidget);

      await tester.tap(find.byTooltip('Show in chat'));
      expect(opened, [40]);

      await tester.tap(find.text('Music'));
      await settle(tester);
      expect(find.text('No music yet'), findsOneWidget);
    });
  });

  group('shared links', () {
    td.Message message(String text, List<td.TextEntity> entities) =>
        td.Message.fromJson({
          ..._message(1, '').toJson(),
          'content': td.MessageText(
            text: td.FormattedText(text: text, entities: entities),
          ).toJson(),
        });

    test('reads a link from the text', () {
      final link = sharedLinkOf(
        ConversationMessage(
          message('See www.example.com/a now', const [
            td.TextEntity(offset: 4, length: 17, type: td.TextEntityTypeUrl()),
          ]),
        ),
      )!;
      expect(link.url, 'www.example.com/a');
      expect(link.title, 'example.com');
      expect(link.description, 'See www.example.com/a now');
    });

    test('prefers a hidden link target and skips messages without one', () {
      final link = sharedLinkOf(
        ConversationMessage(
          message('docs', const [
            td.TextEntity(
              offset: 0,
              length: 4,
              type: td.TextEntityTypeTextUrl(url: 'https://dart.dev/x'),
            ),
          ]),
        ),
      )!;
      expect(link.url, 'https://dart.dev/x');
      expect(link.title, 'dart.dev');
      expect(
        sharedLinkOf(ConversationMessage(message('plain', const []))),
        isNull,
      );
    });
  });
}

const _tick = Duration(milliseconds: 20);

/// Builds [child] once the session is there, as the signed-in window does.
class _WhenSignedIn extends ConsumerWidget {
  const _WhenSignedIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue ? child : const SizedBox();
}

List<Object?> _filters(_FakeTdJson json) => [
  for (final r in json.sent)
    if (r['@type'] == 'searchChatMessages' && r['filter'] != null)
      (r['filter']! as Map)['@type'],
];

td.Message _message(int id, String text) => td.Message(
  id: id,
  senderId: const td.MessageSenderUser(userId: 2),
  chatId: 7,
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
  date: 1700000000 + id,
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

Map<String, Object?> _photo(int id) => {
  ..._message(id, '').toJson(),
  'content': {
    '@type': 'messagePhoto',
    'photo': {
      '@type': 'photo',
      'sizes': [
        {
          '@type': 'photoSize',
          'type': 'x',
          'photo': _file(400 + id),
          'width': 800,
          'height': 600,
          'progressive_sizes': <Object?>[],
        },
      ],
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
  },
};

Map<String, Object?> _link(int id) => {
  ..._message(id, '').toJson(),
  'content': {
    '@type': 'messageText',
    'text': {
      '@type': 'formattedText',
      'text': 'https://example.com/a',
      'entities': [
        {
          '@type': 'textEntity',
          'offset': 0,
          'length': 21,
          'type': {'@type': 'textEntityTypeUrl'},
        },
      ],
    },
    'link_preview': {
      '@type': 'linkPreview',
      'url': 'https://example.com/a',
      'display_url': 'example.com/a',
      'site_name': 'Example site',
      'title': 'Example',
      'description': {
        '@type': 'formattedText',
        'text': '',
        'entities': <Object?>[],
      },
      'type': {'@type': 'linkPreviewTypeArticle'},
    },
  },
};

Map<String, Object?> _file(int id) => {
  '@type': 'file',
  'id': id,
  'size': 1000,
  'expected_size': 1000,
  'local': {
    '@type': 'localFile',
    'path': '',
    'can_be_downloaded': true,
    'is_downloading_active': true,
    'is_downloading_completed': false,
  },
  'remote': {'@type': 'remoteFile', 'id': 'r$id', 'unique_id': 'u$id'},
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  /// Whether searches fail.
  var fail = false;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  Map<String, Object?> _search(Map<String, Object?> request) {
    final filter = (request['filter'] as Map?)?['@type'];
    final from = request['from_message_id']! as int;
    final List<Map<String, Object?>> all = switch (filter) {
      null when request['sender_id'] != null => [
        _message(22, 'from boris').toJson(),
      ],
      'searchMessagesFilterPhotoAndVideo' => [_photo(15), _photo(14)],
      'searchMessagesFilterUrl' => [_link(40)],
      null when request['query'] == 'lease' => [
        for (final id in [30, 20, 10]) _message(id, 'lease $id').toJson(),
      ],
      _ => [],
    };
    // One result per page, to exercise paging.
    final rest = [
      for (final m in all)
        if (from == 0 || (m['id']! as int) < from) m,
    ];
    final page = filter == null ? rest.take(1).toList() : rest;
    return {
      '@type': 'foundChatMessages',
      'total_count': all.length,
      'messages': page,
      'next_from_message_id': rest.length > page.length ? page.last['id'] : 0,
    };
  }

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final type = decoded['@type'];
    if (type != 'getAuthorizationState' && type != 'loadChats') {
      sent.add(decoded);
    }
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'searchChatMessages' when fail => {
        '@type': 'error',
        'code': 500,
        'message': 'Failed',
      },
      'searchChatMessages' => _search(decoded),
      'searchChatMembers' => {
        '@type': 'chatMembers',
        'total_count': 1,
        'members': [
          {
            '@type': 'chatMember',
            'member_id': {'@type': 'messageSenderUser', 'user_id': 2},
            'inviter_user_id': 0,
            'joined_chat_date': 0,
            'status': {
              '@type': 'chatMemberStatusMember',
              'member_until_date': 0,
            },
          },
        ],
      },
      'getUser' => {
        '@type': 'user',
        'id': 2,
        'first_name': 'Boris',
        'last_name': '',
        'phone_number': '',
        'status': {'@type': 'userStatusRecently'},
        'type': {'@type': 'userTypeRegular'},
        'is_contact': true,
      },
      'getChat' => {
        '@type': 'chat',
        'id': decoded['chat_id'],
        'type': {'@type': 'chatTypePrivate', 'user_id': 2},
        'title': 'Chat',
        'permissions': {'@type': 'chatPermissions'},
        'notification_settings': {'@type': 'chatNotificationSettings'},
        'available_reactions': {
          '@type': 'chatAvailableReactionsAll',
          'max_reaction_count': 11,
        },
        'video_chat': {'@type': 'videoChat'},
      },
      'downloadFile' => _file(decoded['file_id']! as int),
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
