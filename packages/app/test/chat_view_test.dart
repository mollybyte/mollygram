import 'dart:collection';
import 'dart:convert';
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
    session.conversations.store
      ..setUserName(2, 'Boris')
      ..setUserName(3, 'Vera');
  });

  tearDown(() => session.dispose());

  Future<void> pump(WidgetTester tester, {bool group = true}) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          chatEntryProvider.overrideWith(
            (ref, chatId) => Stream.value(
              ChatListEntry(
                id: chatId,
                title: 'Team',
                unreadCount: 0,
                positions: const [],
                isGroup: group,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(child: _Host()),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
  }

  List<Object?> requests() => [for (final r in json.sent) r['@type']];

  testWidgets('opens the chat, marks shown messages read and closes it', (
    tester,
  ) async {
    await pump(tester);

    expect(requests(), containsAllInOrder(['openChat', 'getChatHistory']));
    final view = json.sent.singleWhere((r) => r['@type'] == 'viewMessages');
    expect(view['chat_id'], 7);
    // Only incoming messages are reported.
    expect(view['message_ids'], unorderedEquals([10, 11, 12]));

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(_tick));
    expect(requests().last, 'closeChat');
  });

  testWidgets('marks only the messages on screen as viewed', (tester) async {
    json.history = [
      for (var id = 200; id > 100; id--)
        _message(id: id, senderId: 2, text: 'Message $id'),
    ];
    await pump(tester);

    final viewed = {
      for (final r in json.sent)
        if (r['@type'] == 'viewMessages') ...(r['message_ids']! as List),
    };
    // The newest ones fill the 800 px window; the rest are loaded but
    // not on screen.
    expect(viewed, contains(200));
    expect(viewed, isNot(contains(101)));
    const screen = Rect.fromLTWH(0, 0, 1200, 800);
    for (final id in viewed) {
      final rect = tester.getRect(
        find.textContaining('Message $id', findRichText: true),
      );
      expect(
        rect.overlaps(screen),
        isTrue,
        reason: 'message $id is off screen',
      );
    }
  });

  testWidgets('names the sender once per run in a group', (tester) async {
    await pump(tester);

    expect(find.text('Team'), findsOneWidget);
    expect(find.text('Boris'), findsOneWidget);
    expect(find.text('Vera'), findsOneWidget);
  });

  testWidgets('shows no sender names outside groups', (tester) async {
    await pump(tester, group: false);

    expect(find.text('Boris'), findsNothing);
    expect(find.text('Vera'), findsNothing);
  });

  testWidgets('gives the text back when sending fails', (tester) async {
    json.failSend = true;
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.pump();
    // The composer is cleared while the message is on its way.
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    expect(requests(), contains('sendMessage'));
    expect(find.text("The message wasn't sent. Try again"), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Hello there');
  });
}

const _tick = Duration(milliseconds: 20);

/// Shows the chat once the session is up, as the app does.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue
      ? const ChatView(chatId: 7)
      : const SizedBox();
}

/// Oldest first: two messages from Boris, one from Vera, one from us.
final _history = [
  _message(id: 13, senderId: 1, text: 'Mine', outgoing: true),
  _message(id: 12, senderId: 3, text: 'From Vera'),
  _message(id: 11, senderId: 2, text: 'Boris again'),
  _message(id: 10, senderId: 2, text: 'From Boris'),
];

td.Message _message({
  required int id,
  required int senderId,
  required String text,
  bool outgoing = false,
}) => td.Message(
  id: id,
  senderId: td.MessageSenderUser(userId: senderId),
  chatId: 7,
  isOutgoing: outgoing,
  isPinned: false,
  isFromOffline: false,
  canBeSaved: true,
  hasTimestampedMedia: false,
  isChannelPost: false,
  isPaidStarSuggestedPost: false,
  isPaidGramSuggestedPost: false,
  containsUnreadMention: false,
  containsUnreadPollVotes: false,
  date: 1760000000 + id,
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
  var failSend = false;
  var history = _history;
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
    if (type != 'getAuthorizationState' && type != 'loadChats') {
      sent.add(decoded);
    }
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': history.length,
        'messages': [
          // TDLib returns messages older than from_message_id.
          for (final m in history)
            if (decoded['from_message_id'] == 0 ||
                m.id < (decoded['from_message_id']! as int))
              m.toJson(),
        ],
      },
      'sendMessage' when failSend => {
        '@type': 'error',
        'code': 403,
        'message': 'CHAT_WRITE_FORBIDDEN',
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
