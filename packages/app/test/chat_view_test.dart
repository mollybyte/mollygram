import 'dart:collection';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _shownChat.value = 7;
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
          chatListProvider.overrideWith(
            (ref, list) => Stream.value([
              ChatListEntry(
                id: 9,
                title: 'Saved',
                unreadCount: 0,
                positions: const [],
              ),
            ]),
          ),
          chatEntryProvider.overrideWith(
            (ref, chatId) => Stream.value(
              ChatListEntry(
                id: chatId,
                title: 'Team',
                unreadCount: 0,
                positions: const [],
                type: group ? ChatType.supergroup : ChatType.private,
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

  testWidgets('names each run outside groups too, as the flat layout does', (
    tester,
  ) async {
    await pump(tester, group: false);

    expect(find.text('Boris'), findsOneWidget);
    expect(find.text('Vera'), findsOneWidget);
  });

  Future<void> rightClick(WidgetTester tester, String text) async {
    await tester.tap(find.text(text), buttons: kSecondaryButton);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
  }

  testWidgets('replies to a message from its menu', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('❤'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    await tester.tap(find.text('Reply'));
    await tester.pump();

    // The bar above the composer names who is being answered.
    expect(find.text('Vera'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'Sure');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect((send['reply_to']! as Map)['message_id'], 12);
    expect(find.byType(ComposerContextBar), findsNothing);
  });

  testWidgets('edits the last sent message with the up arrow', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.enterText(find.byType(TextField), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Mine');
    expect(find.text('Editing'), findsOneWidget);

    field.controller!.text = 'Mine, fixed';
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final edit = json.sent.lastWhere((r) => r['@type'] == 'editMessageText');
    expect(edit['message_id'], 13);
    expect(
      ((edit['input_message_content']! as Map)['text']! as Map)['text'],
      'Mine, fixed',
    );
    expect(find.text('Editing'), findsNothing);
  });

  testWidgets('drops an edit, not the draft, when the chat changes', (
    tester,
  ) async {
    await pump(tester);
    await rightClick(tester, 'Mine');
    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.text('Editing'), findsOneWidget);

    _shownChat.value = 8;
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isEmpty);
    expect(find.text('Editing'), findsNothing);
  });

  testWidgets('deletes a message for everyone after asking', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Boris');
    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Delete message?'), findsOneWidget);
    // The checkbox starts on; the confirm button is the second Delete.
    await tester.tap(find.text('Delete').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final delete = json.sent.lastWhere((r) => r['@type'] == 'deleteMessages');
    expect(delete['message_ids'], [10]);
    expect(delete['revoke'], isTrue);
  });

  testWidgets('forwards a message to the chat picked', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.text('Forward'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Forward to chat'), findsOneWidget);
    await tester.tap(find.text('Saved'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['chat_id'], 9);
    expect(forward['message_ids'], [12]);
  });

  testWidgets('copies the text of a message', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pump(tester);

    await rightClick(tester, 'Boris again');
    await tester.tap(find.text('Copy text'));
    await tester.pump();

    expect(copied, 'Boris again');
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
      ? ValueListenableBuilder(
          valueListenable: _shownChat,
          builder: (context, chatId, _) => ChatView(chatId: chatId),
        )
      : const SizedBox();
}

/// The chat the host shows; tests switch it.
final _shownChat = ValueNotifier(7);

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
      'sendMessage' => _message(
        id: 20,
        senderId: 1,
        text: 'Sent',
        outgoing: true,
      ).toJson(),
      'editMessageText' => _message(
        id: decoded['message_id']! as int,
        senderId: 1,
        text: 'Edited',
        outgoing: true,
      ).toJson(),
      'forwardMessages' => {
        '@type': 'messages',
        'total_count': 0,
        'messages': <Object?>[],
      },
      'getMessageProperties' => {
        '@type': 'messageProperties',
        'can_be_replied': true,
        'can_be_edited': decoded['message_id'] == 13,
        'can_be_forwarded': true,
        'can_be_deleted_only_for_self': true,
        'can_be_deleted_for_all_users': true,
      },
      'getMessageAvailableReactions' => {
        '@type': 'availableReactions',
        'top_reactions': [
          for (final emoji in ['👍', '❤', '👍'])
            {
              '@type': 'availableReaction',
              'type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
              'needs_premium': false,
            },
          {
            '@type': 'availableReaction',
            'type': {'@type': 'reactionTypeCustomEmoji', 'custom_emoji_id': 5},
            'needs_premium': false,
          },
        ],
        'recent_reactions': <Object?>[],
        'popular_reactions': <Object?>[],
        'allow_custom_emoji': true,
        'are_tags': false,
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
