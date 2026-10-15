import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/media_content.dart';
import 'package:mollygram/src/chat/recent_emoji.dart';
import 'package:mollygram/src/chat/save_file.dart';
import 'package:mollygram/src/chat/timeline_view.dart';
import 'package:mollygram/src/home/chat_view.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/shared_media/message_jump.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    bool group = true,
    String? downloadFolder,
  }) async {
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          initialPreferencesProvider.overrideWithValue(
            Preferences(downloadFolder: downloadFolder),
          ),
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
          recentEmojiStorageProvider.overrideWithValue(
            MemoryRecentEmojiStorage(),
          ),
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

  Future<void> rightClick(WidgetTester tester, String text) async {
    await tester.tap(find.text(text), buttons: kSecondaryButton);
    // The menu asks for the message's properties, then who saw it.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
  }

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

  testWidgets('opens at the first unread message and goes back down', (
    tester,
  ) async {
    json.chat = [for (var id = 1; id <= 120; id++) id];
    json.push(_chat(lastRead: 80, unread: 40, last: 120));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();

    // The band sits above message 81, which is on screen; the newest
    // message is not loaded yet.
    expect(find.text('Unread messages'), findsOneWidget);
    final band = tester.getRect(find.text('Unread messages'));
    final first = tester.getRect(
      find.textContaining('Message 81', findRichText: true),
    );
    expect(band.bottom, lessThanOrEqualTo(first.top));
    expect(band.top, greaterThan(72));
    expect(
      find.textContaining('Message 120', findRichText: true),
      findsNothing,
    );
    final viewed = {
      for (final r in json.sent)
        if (r['@type'] == 'viewMessages') ...(r['message_ids']! as List),
    };
    expect(viewed, contains(81));
    expect(viewed, isNot(contains(120)));

    // The down button shows, since the newest message is further down.
    final down = find.byTooltip('Scroll to the newest message');
    expect(down, findsOneWidget);
    await tester.tap(down);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Message 120', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Unread messages'), findsNothing);
  });

  testWidgets('scrolls to the message a reply answers', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    // The newest message answers the oldest, far above the screen.
    json.repliesTo = {60: 1};
    json.texts = {60: 'Answer'};
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'Message 1(?!\d)'), findRichText: true),
      findsNothing,
    );

    // A little way up from the bottom, so there is somewhere to return.
    await tester.drag(find.byType(TimelineView), const Offset(0, 120));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReplyHeader));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final target = tester.getRect(
      find.textContaining(RegExp(r'Message 1(?!\d)'), findRichText: true),
    );
    expect(target.top, inInclusiveRange(0, 800));

    // The down button first goes back to where the user was.
    final back = find.byTooltip('Back to where you were');
    expect(back, findsOneWidget);
    await tester.tap(back);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Answer', findRichText: true), findsOneWidget);
    expect(find.byTooltip('Back to where you were'), findsNothing);
  });

  testWidgets('scrolls to a message another panel asks for', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();
    final first = find.textContaining(
      RegExp(r'Message 1(?!\d)'),
      findRichText: true,
    );
    expect(first, findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatView)),
    );
    container.read(messageJumpProvider.notifier).request(7, 1);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    expect(tester.getRect(first).top, inInclusiveRange(0, 800));
    expect(container.read(messageJumpProvider), isEmpty);
  });

  testWidgets('floats the date of the top row while scrolling', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();
    final floating = find.byKey(const ValueKey('floatingDate'));
    expect(floating, findsNothing);

    final gesture = await tester.startGesture(const Offset(600, 400));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(floating, findsOneWidget);
    final pill = tester.widget<AnimatedOpacity>(
      find.ancestor(of: floating, matching: find.byType(AnimatedOpacity)),
    );
    expect(pill.opacity, 1);

    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.ancestor(of: floating, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      0,
    );
  });

  testWidgets('shows the pinned messages and cycles through them', (
    tester,
  ) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.pinned = [50, 20];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();

    // The newest pinned message shows first, numbered from the oldest.
    final bar = find.byType(PinnedBar);
    expect(find.text('Pinned message #2'), findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Message 50')),
      findsOneWidget,
    );

    // A click goes to it and the bar moves on to the older one.
    await tester.tap(find.byType(PinnedBar));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Pinned message #1'), findsOneWidget);
    expect(
      find.descendant(of: bar, matching: find.text('Message 20')),
      findsOneWidget,
    );
    final target = tester.getRect(
      find.textContaining(RegExp(r'Message 50(?!\d)'), findRichText: true),
    );
    expect(target.top, inInclusiveRange(0, 800));

    // Unpinning the last one takes the bar away.
    json
      ..push({
        '@type': 'updateMessageIsPinned',
        'chat_id': 7,
        'message_id': 50,
        'is_pinned': false,
      })
      ..push({
        '@type': 'updateMessageIsPinned',
        'chat_id': 7,
        'message_id': 20,
        'is_pinned': false,
      });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(PinnedBar), findsNothing);
  });

  testWidgets('lists the pinned messages and unpins them all', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.pinned = [50, 20];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pinned messages'));
    await tester.pumpAndSettle();
    expect(find.text('2 pinned messages'), findsOneWidget);
    expect(find.byType(PinnedBar), findsNothing);
    expect(find.byType(Composer), findsNothing);
    // Only the pinned messages are in the list.
    expect(find.text('Message 20'), findsOneWidget);
    expect(find.text('Message 50'), findsOneWidget);
    expect(find.text('Message 49'), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsOneWidget);
    expect(find.byType(PinnedBar), findsOneWidget);

    await tester.tap(find.byTooltip('Pinned messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin all messages'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin all 2 messages?'), findsOneWidget);
    await tester.tap(find.text('Unpin all messages').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    expect(requests(), contains('unpinAllChatMessages'));
    expect(find.byType(Composer), findsOneWidget);
    expect(find.byType(PinnedBar), findsNothing);
  });

  testWidgets('pins and unpins a message from its menu', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.text('Pin'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    final pin = json.sent.lastWhere((r) => r['@type'] == 'pinChatMessage');
    expect(pin['message_id'], 12);
    expect(pin['only_for_self'], isFalse);

    json.push({
      '@type': 'updateMessageIsPinned',
      'chat_id': 7,
      'message_id': 12,
      'is_pinned': true,
    });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Pinned message'), findsOneWidget);

    // The bar now says "From Vera" too; the message comes first.
    await tester.tap(find.text('From Vera').first, buttons: kSecondaryButton);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpin'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    final unpin = json.sent.lastWhere((r) => r['@type'] == 'unpinChatMessage');
    expect(unpin['message_id'], 12);
  });

  testWidgets('says why a member may not write in a group', (tester) async {
    json.chat = [for (var id = 1; id <= 10; id++) id];
    json
      ..push(
        _chat(
          lastRead: 10,
          unread: 0,
          last: 10,
          type: {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 99,
            'is_channel': false,
          },
          canSendText: false,
        ),
      )
      ..push(
        _supergroup(99, {
          '@type': 'chatMemberStatusMember',
          'member_since_date': 0,
        }),
      );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: false);
    await tester.pumpAndSettle();

    expect(find.byType(Composer), findsNothing);
    expect(
      find.text("Text messages aren't allowed in this group"),
      findsOneWidget,
    );

    // The group opens up again, but this member is restricted for a while.
    json
      ..push({
        '@type': 'updateChatPermissions',
        'chat_id': 7,
        'permissions': {
          '@type': 'chatPermissions',
          'can_send_basic_messages': true,
        },
      })
      ..push(
        _supergroup(99, {
          '@type': 'chatMemberStatusRestricted',
          'is_member': true,
          'restricted_until_date': 1800000000,
          'permissions': {'@type': 'chatPermissions'},
        }),
      );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsNothing);
    expect(find.textContaining("You can't write here until"), findsOneWidget);

    // Free to write, under slowmode.
    json
      ..push(
        _supergroup(99, {
          '@type': 'chatMemberStatusMember',
          'member_since_date': 0,
        }),
      )
      ..push({
        '@type': 'updateSupergroupFullInfo',
        'supergroup_id': 99,
        'supergroup_full_info': {
          '@type': 'supergroupFullInfo',
          'slow_mode_delay': 30,
          'slow_mode_delay_expires_in': 25.0,
        },
      });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsOneWidget);
    expect(find.textContaining('Slowmode is on'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  });

  testWidgets('offers to join a channel, then to mute it', (tester) async {
    json.chat = [for (var id = 1; id <= 10; id++) id];
    json
      ..push(
        _chat(
          lastRead: 10,
          unread: 0,
          last: 10,
          type: {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 99,
            'is_channel': true,
          },
        ),
      )
      ..push(_supergroup(99, {'@type': 'chatMemberStatusLeft'}));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: false);
    await tester.pumpAndSettle();

    expect(find.byType(Composer), findsNothing);
    await tester.tap(find.text('Join channel'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    expect(json.sent.last['@type'], 'joinChat');

    json.push(
      _supergroup(99, {
        '@type': 'chatMemberStatusMember',
        'member_since_date': 0,
      }),
    );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsNothing);
    await tester.tap(find.text('Mute'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    final mute = json.sent.lastWhere(
      (r) => r['@type'] == 'setChatNotificationSettings',
    );
    expect((mute['notification_settings']! as Map)['mute_for'], greaterThan(0));
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

  testWidgets('opens the full reaction picker and reacts from it', (
    tester,
  ) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.byTooltip('More reactions'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.byType(ReactionGrid), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(ReactionGrid), matching: find.text('🎉')),
    );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    expect(find.byType(ReactionGrid), findsNothing);
    final added = json.sent.lastWhere(
      (r) => r['@type'] == 'addMessageReaction',
    );
    expect(added['message_id'], 12);
    expect((added['reaction_type']! as Map)['emoji'], '🎉');
  });

  testWidgets('shows the server draft and saves what is typed', (tester) async {
    json.chat = [for (var id = 1; id <= 10; id++) id];
    json.push(_chat(lastRead: 10, unread: 0, last: 10, draft: 'Unsent words'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Unsent words');

    await tester.enterText(find.byType(TextField), 'Unsent words, more');
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    var saved = json.sent.lastWhere((r) => r['@type'] == 'setChatDraftMessage');
    var content = (saved['draft_message']! as Map)['content']! as Map;
    expect((content['text']! as Map)['text'], 'Unsent words, more');

    // Leaving the chat saves at once and the next chat starts clean.
    await tester.enterText(find.byType(TextField), 'Final');
    _shownChat.value = 8;
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    saved = json.sent.lastWhere((r) => r['@type'] == 'setChatDraftMessage');
    expect(saved['chat_id'], 7);
    content = (saved['draft_message']! as Map)['content']! as Map;
    expect((content['text']! as Map)['text'], 'Final');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('previews a typed link, moves it above the text or drops it', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'See https://example.com/a');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('An example page'), findsOneWidget);

    // Above the text, then sent that way.
    await tester.tap(find.byTooltip('Show the preview above the text'));
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    var sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    var options =
        (sent['input_message_content']! as Map)['link_preview_options']! as Map;
    expect(options['show_above_text'], isTrue);
    expect(options['is_disabled'], isFalse);
    expect(find.text('An example page'), findsNothing);

    // Removed: the bar goes, and the message says so.
    await tester.enterText(
      find.byType(TextField),
      'Again https://example.com/a',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('An example page'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove the link preview'));
    await tester.pump();
    expect(find.text('An example page'), findsNothing);
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    options =
        (sent['input_message_content']! as Map)['link_preview_options']! as Map;
    expect(options['is_disabled'], isTrue);

    // Plain words carry no options at all.
    await tester.enterText(find.byType(TextField), 'No link here');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      (sent['input_message_content']! as Map).containsKey(
        'link_preview_options',
      ),
      isFalse,
    );
  });

  testWidgets('reports a message with a reason and details', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.text('Report'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    // The server names the reasons.
    expect(find.text('Report for'), findsOneWidget);
    await tester.tap(find.text('Spam'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    // Then asks for details, which are required here.
    expect(find.text('Add details'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'Adverts');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final reports = json.sent.where((r) => r['@type'] == 'reportChat');
    expect(reports, hasLength(3));
    expect(reports.first['message_ids'], [12]);
    expect(reports.last['option_id'], 'AQ==');
    expect(reports.last['text'], 'Adverts');
    expect(find.text('Thank you, the report is on its way.'), findsOneWidget);
    // The toast goes away by itself.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Thank you, the report is on its way.'), findsNothing);
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
    expect(forward['send_copy'], isFalse);
  });

  testWidgets('selects text with the mouse and replies with it quoted', (
    tester,
  ) async {
    await pump(tester);

    // Drag across the whole of "From Vera".
    final text = tester.getRect(find.text('From Vera'));
    final gesture = await tester.startGesture(
      Offset(text.left + 1, text.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(Offset(text.right + 30, text.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    await rightClick(tester, 'From Vera');
    // The selection hands focus over before the menu shows.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quote'));
    await tester.pumpAndSettle();
    // The composer's reply bar carries the quote.
    expect(find.byType(ComposerContextBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ComposerContextBar),
        matching: find.text('From Vera'),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'Noted');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final replyTo = send['reply_to']! as Map;
    expect(replyTo['message_id'], 12);
    final quote = replyTo['quote']! as Map;
    expect((quote['text']! as Map)['text'], 'From Vera');
    expect(quote['position'], 0);
  });

  testWidgets('tells who saw a message and lists them', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Boris');
    await tester.pumpAndSettle();
    expect(find.text('Seen by 1'), findsOneWidget);
    await tester.tap(find.text('Seen by 1'));
    await tester.pumpAndSettle();

    expect(find.byType(MgPeopleList), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MgPeopleList),
        matching: find.text('Vera'),
      ),
      findsOneWidget,
    );

    // A message TDLib keeps no viewers for has no such row.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    await rightClick(tester, 'From Vera');
    await tester.pumpAndSettle();
    expect(find.textContaining('Seen by'), findsNothing);
  });

  testWidgets('forwards without the sender name when asked', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.text('Forward'));
    await tester.pump();
    await tester.pump();
    // A text message has no caption to hide.
    expect(find.text('Hide captions'), findsNothing);
    await tester.tap(find.text('Hide sender names'));
    await tester.pump();
    await tester.tap(find.text('Saved'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['send_copy'], isTrue);
    expect(forward['remove_caption'], isFalse);
  });

  Future<void> selectTwo(WidgetTester tester) async {
    await rightClick(tester, 'From Boris');
    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    // While selecting, the row's content doesn't take clicks; the row does.
    await tester.tap(find.text('From Vera'), warnIfMissed: false);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);
  }

  testWidgets('selects messages and forwards them together', (tester) async {
    await pump(tester);
    await selectTwo(tester);

    await tester.tap(find.text('Forward'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SelectionBar), findsNothing);
    await tester.tap(find.text('Saved'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['message_ids'], [10, 12]);
  });

  testWidgets('copies the selected texts oldest first', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
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
    await selectTwo(tester);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(copied, ['From Boris\n\nFrom Vera']);
    expect(find.byType(SelectionBar), findsNothing);
  });

  testWidgets('deletes the selected messages after asking', (tester) async {
    await pump(tester);
    await selectTwo(tester);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(find.text('Delete 2 messages?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final delete = json.sent.lastWhere((r) => r['@type'] == 'deleteMessages');
    expect(delete['message_ids'], [10, 12]);
    expect(find.byType(SelectionBar), findsNothing);
  });

  testWidgets('a click takes a message out again and Esc ends selecting', (
    tester,
  ) async {
    await pump(tester);
    await selectTwo(tester);

    await tester.tap(find.text('From Vera'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(SelectionBar), findsNothing);
    expect(find.byType(Composer), findsOneWidget);
  });

  testWidgets('opens a calendar from a date pill and jumps to the day', (
    tester,
  ) async {
    await pump(tester);

    // The date pill above the first message comes once the start of the
    // chat is known, a page later.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    // The history is from October 2025.
    await tester.tap(find.byType(DatePill).first);
    await tester.pump();
    expect(find.text('October 2025'), findsOneWidget);
    // Days after today can't be picked; the month can't go past it.
    expect(find.byType(MgCalendar), findsOneWidget);

    await tester.tap(find.text('9'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    expect(find.byType(MgCalendar), findsNothing);
    final request = json.sent.lastWhere(
      (r) => r['@type'] == 'getChatMessageByDate',
    );
    expect(request['chat_id'], 7);
    expect(
      request['date'],
      DateTime(2025, 10, 10).millisecondsSinceEpoch ~/ 1000 - 1,
    );
    expect(tester.widget<TimelineView>(find.byType(TimelineView)).anchor, 11);
  });

  testWidgets('opens a photo full screen and pages through the chat media', (
    tester,
  ) async {
    json.history = [td.Message.fromJson(_photo(15)), ..._history];
    await pump(tester);

    await tester.tap(find.byType(PhotoContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'searchChatMessages',
    );
    expect(search['from_message_id'], 15);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Boris'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsNothing);
  });

  testWidgets('saves a file to the download folder and shows it', (
    tester,
  ) async {
    // Real files: created and removed outside the test's fake clock.
    final folder = await tester.runAsync(
      () => Directory.systemTemp.createTemp('mollygram_save'),
    );
    addTearDown(() => folder!.delete(recursive: true));
    final source = File('${folder!.path}/td_70.pdf')..writeAsStringSync('pdf');
    json.history = [
      td.Message.fromJson(_document(16, source.path)),
      ..._history,
    ];
    await pump(tester, downloadFolder: folder.path);

    await rightClick(tester, 'route_saturday.pdf');
    await tester.tap(find.text('Save to Downloads'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(File('${folder.path}/route_saturday.pdf').existsSync(), isTrue);
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    // Again: the first copy stays, the next gets a number.
    await rightClick(tester, 'route_saturday.pdf');
    await tester.tap(find.text('Save to Downloads'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(File('${folder.path}/route_saturday 2.pdf').existsSync(), isTrue);
    await tester.pump(const Duration(seconds: 3));

    String? revealed;
    final system = revealFile;
    revealFile = (path) async => revealed = path;
    addTearDown(() => revealFile = system);
    await rightClick(tester, 'route_saturday.pdf');
    await tester.tap(
      find.text(Platform.isMacOS ? 'Show in Finder' : 'Show in folder'),
    );
    await tester.pump();
    expect(revealed, source.path);
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

  testWidgets('puts an emoji at the caret and keeps the panel open', (
    tester,
  ) async {
    await pump(tester);
    final field = find.byType(TextField);
    await tester.enterText(field, 'hi there');
    final controller = tester.widget<TextField>(field).controller!;
    controller.selection = const TextSelection.collapsed(offset: 2);
    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pump();
    // Past the panel's opening animation.
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('😀'));
    await tester.pump();
    expect(controller.text, 'hi😀 there');
    expect(controller.selection, const TextSelection.collapsed(offset: 4));
    // The panel stays, and the emoji now leads its recent row.
    expect(find.text('Recently used'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(EmojiPanel), findsNothing);
  });

  testWidgets('sends a sticker from the panel and closes it', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pump();
    // Past the panel's opening animation.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Stickers'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    expect(find.text('Recently used'), findsWidgets);
    expect(find.text('Cats'), findsWidgets);
    // The recent sticker, then the set's two.
    expect(find.byType(StickerContent), findsAtLeastNWidgets(3));

    await tester.tap(find.bySemanticsLabel('😺').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageSticker');
    expect((content['sticker']! as Map)['sticker'], {
      '@type': 'inputFileId',
      'id': 303,
    });
    expect(find.byType(EmojiPanel), findsNothing);
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

/// The ids TDLib returns for a history request over [ids], newest first.
List<int> _page(List<int> ids, int from, int offset, int limit) {
  final newestFirst = [...ids]..sort((a, b) => b.compareTo(a));
  var start = from == 0 ? 0 : newestFirst.indexWhere((id) => id <= from);
  if (start < 0) return const [];
  start = (start + offset).clamp(0, newestFirst.length);
  return newestFirst.skip(start).take(limit).toList();
}

/// TDLib's description of chat 7, with what the user has read of it.
Map<String, Object?> _chat({
  required int lastRead,
  required int unread,
  required int last,
  Map<String, Object?> type = const {'@type': 'chatTypePrivate', 'user_id': 2},
  bool canSendText = true,
  String? draft,
}) => {
  '@type': 'updateNewChat',
  'chat': {
    '@type': 'chat',
    'id': 7,
    'type': type,
    'title': 'Boris',
    'last_message': _message(
      id: last,
      senderId: 2,
      text: 'Message $last',
    ).toJson(),
    'unread_count': unread,
    'last_read_inbox_message_id': lastRead,
    'last_read_outbox_message_id': 0,
    if (draft != null)
      'draft_message': {
        '@type': 'draftMessage',
        'date': 1700000000,
        'content': {
          '@type': 'draftMessageContentText',
          'text': {
            '@type': 'formattedText',
            'text': draft,
            'entities': <Object?>[],
          },
        },
        'effect_id': 0,
      },
    'permissions': {
      '@type': 'chatPermissions',
      'can_send_basic_messages': canSendText,
    },
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

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var failSend = false;
  var history = _history;

  /// A whole chat from Boris with these ids, paged as TDLib does with
  /// from_message_id, offset and limit; takes the place of [history].
  List<int>? chat;

  /// Which message of [chat] each of these answers.
  var repliesTo = <int, int>{};

  /// The pinned messages, newest first.
  var pinned = <int>[];

  /// Texts of [chat] messages other than "Message N".
  var texts = <int, String>{};
  var _nextClientId = 0;

  /// Delivers [update] as TDLib would.
  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

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
            {
              ..._message(
                id: id,
                senderId: 2,
                text: texts[id] ?? 'Message $id',
              ).toJson(),
              if (repliesTo[id] case final original?)
                'reply_to': {
                  '@type': 'messageReplyToMessage',
                  'chat_id': 7,
                  'message_id': original,
                },
            },
        ],
      },
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
      'getRecentStickers' => {
        '@type': 'stickers',
        'stickers': [_sticker(1, '🐱')],
      },
      'getFavoriteStickers' => {'@type': 'stickers', 'stickers': <Object?>[]},
      'getInstalledStickerSets' => {
        '@type': 'stickerSets',
        'total_count': 1,
        'sets': [
          {
            '@type': 'stickerSetInfo',
            'id': 55,
            'title': 'Cats',
            'name': 'cats',
            'sticker_type': {'@type': 'stickerTypeRegular'},
            'size': 2,
            'covers': [_sticker(2, '😸')],
          },
        ],
      },
      'getStickerSet' => {
        '@type': 'stickerSet',
        'id': 55,
        'title': 'Cats',
        'name': 'cats',
        'sticker_type': {'@type': 'stickerTypeRegular'},
        'stickers': [_sticker(2, '😸'), _sticker(3, '😺')],
        'emojis': <Object?>[],
      },
      'searchChatMessages'
          when (decoded['filter']! as Map)['@type'] ==
              'searchMessagesFilterPinned' =>
        {
          '@type': 'foundChatMessages',
          'total_count': pinned.length,
          'messages': [
            for (final id in pinned)
              {
                ..._message(id: id, senderId: 2, text: 'Message $id').toJson(),
                'is_pinned': true,
              },
          ],
          'next_from_message_id': 0,
        },
      'searchChatMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 2,
        'messages': [_photo(15), _photo(14)],
        'next_from_message_id': 0,
      },
      'downloadFile' => _stickerFile(decoded['file_id']! as int),
      'joinChat' => {'@type': 'chatJoinResultSuccess'},
      'getChatMessageByDate' => _message(
        id: 11,
        senderId: 2,
        text: 'Boris again',
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
        'can_be_pinned': true,
        'can_be_deleted_only_for_self': true,
        'can_be_deleted_for_all_users': true,
        'can_get_viewers': decoded['message_id'] == 10,
        'can_get_added_reactions': true,
        'can_report_chat': true,
      },
      'reportChat' when decoded['option_id'] == '' => {
        '@type': 'reportChatResultOptionRequired',
        'title': 'Report for',
        'options': [
          {'@type': 'reportOption', 'id': 'AQ==', 'text': 'Spam'},
          {'@type': 'reportOption', 'id': 'Ag==', 'text': 'Violence'},
        ],
      },
      'reportChat' when decoded['text'] == '' => {
        '@type': 'reportChatResultTextRequired',
        'option_id': decoded['option_id'],
        'is_optional': false,
      },
      'reportChat' => {'@type': 'reportChatResultOk'},
      'getMessageViewers' => {
        '@type': 'messageViewers',
        'viewers': [
          {'@type': 'messageViewer', 'user_id': 3, 'view_date': 1760000500},
        ],
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
        'popular_reactions': [
          for (final emoji in ['🔥', '🎉'])
            {
              '@type': 'availableReaction',
              'type': {'@type': 'reactionTypeEmoji', 'emoji': emoji},
              'needs_premium': false,
            },
        ],
        'allow_custom_emoji': true,
        'are_tags': false,
      },
      'getLinkPreview'
          when ((decoded['text']! as Map)['text']! as String).contains(
            'example.com',
          ) =>
        {
          '@type': 'linkPreview',
          'url': 'https://example.com/a',
          'display_url': 'example.com/a',
          'site_name': 'Example',
          'title': 'An example page',
          'description': {
            '@type': 'formattedText',
            'text': 'Nothing to see',
            'entities': <Object?>[],
          },
          'author': '',
          'type': {'@type': 'linkPreviewTypeArticle'},
          'has_large_media': false,
          'show_large_media': false,
          'show_media_above_description': false,
          'skip_confirmation': false,
          'show_above_text': false,
          'instant_view_version': 0,
        },
      'getLinkPreview' => {
        '@type': 'error',
        'code': 404,
        'message': 'Not Found',
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

/// A downloaded PDF from Boris, kept at [path].
Map<String, Object?> _document(int id, String path) => {
  ..._message(id: id, senderId: 2, text: '').toJson(),
  'content': {
    '@type': 'messageDocument',
    'document': {
      '@type': 'document',
      'file_name': 'route_saturday.pdf',
      'mime_type': 'application/pdf',
      'document': {
        ..._stickerFile(70),
        'local': {
          '@type': 'localFile',
          'path': path,
          'can_be_downloaded': true,
          'is_downloading_active': false,
          'is_downloading_completed': true,
        },
      },
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
  },
};

/// A photo from Boris as TDLib sends it.
Map<String, Object?> _photo(int id) => {
  ..._message(id: id, senderId: 2, text: '').toJson(),
  'content': {
    '@type': 'messagePhoto',
    'photo': {
      '@type': 'photo',
      'sizes': [
        {
          '@type': 'photoSize',
          'type': 'x',
          'photo': _stickerFile(400 + id),
          'width': 800,
          'height': 600,
          'progressive_sizes': <Object?>[],
        },
      ],
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
  },
};

Map<String, Object?> _sticker(int id, String emoji) => {
  '@type': 'sticker',
  'id': 100 + id,
  'set_id': 55,
  'width': 512,
  'height': 512,
  'emoji': emoji,
  'format': {'@type': 'stickerFormatWebp'},
  'full_type': {'@type': 'stickerFullTypeRegular'},
  'sticker': _stickerFile(300 + id),
};

Map<String, Object?> _stickerFile(int id) => {
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
