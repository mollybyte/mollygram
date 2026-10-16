import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/bot_keyboard.dart';
import 'package:mollygram/src/chat/load_spinner.dart';
import 'package:mollygram/src/chat/location_content.dart';
import 'package:mollygram/src/chat/media_content.dart';
import 'package:mollygram/src/chat/media_providers.dart';
import 'package:mollygram/src/chat/recent_emoji.dart';
import 'package:mollygram/src/chat/save_file.dart';
import 'package:mollygram/src/chat/sticker_suggestions.dart';
import 'package:mollygram/src/chat/timeline_view.dart';
import 'package:mollygram/src/chat_search/chat_search_bar.dart';
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
    await tester.drag(find.byType(TimelineView), const Offset(0, 70));
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

    // It is a full-width strip, flush under the header.
    final card = tester.getRect(find.byType(ChatView));
    final strip = tester.getRect(bar);
    expect(strip.left, card.left);
    expect(strip.right, card.right);
    expect(strip.top, card.top + ChatHeaderBar.height);
    expect(strip.height, PinnedBar.height);

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

  testWidgets('comes back to where a chat was left', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();
    final newest = find.textContaining('Message 60', findRichText: true);
    expect(newest, findsOneWidget);

    // Up a few screens, then away and back.
    await tester.drag(find.byType(TimelineView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(newest, findsNothing);
    final shown = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText())
        .where((t) => t.contains('Message '))
        .toSet();
    expect(shown, isNotEmpty);

    _shownChat.value = 8;
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    _shownChat.value = 7;
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(newest, findsNothing);
    final back = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText())
        .where((t) => t.contains('Message '))
        .toSet();
    expect(back.intersection(shown), isNotEmpty);
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

  testWidgets('reacts with a custom emoji from the menu', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    // The reaction bar asks for the custom emoji's sticker in a batch.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final icon = find.descendant(
      of: find.byType(ReactionBar),
      matching: find.byType(StickerContent),
    );
    expect(icon, findsOneWidget);

    await tester.tap(icon);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final added = json.sent.lastWhere(
      (r) => r['@type'] == 'addMessageReaction',
    );
    expect(added['message_id'], 12);
    final type = added['reaction_type']! as Map;
    expect(type['@type'], 'reactionTypeCustomEmoji');
    // Int64 ids travel as strings.
    expect('${type['custom_emoji_id']}', '5');
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

  testWidgets('sends when the person comes online from the send menu', (
    tester,
  ) async {
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Morning');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Send when online'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      ((sent['options']! as Map)['scheduling_state']! as Map)['@type'],
      'messageSchedulingStateSendWhenOnline',
    );
    expect(find.text('Will be sent when they come online'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('sends without sound or schedules from the send menu', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'Quiet one');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Send without sound'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    var sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect((sent['options']! as Map)['disable_notification'], isTrue);
    expect(find.text('Sent'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Later one');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Schedule message…'));
    await tester.pump();
    expect(find.text('Schedule message'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '23:59');
    await tester.pump();
    await tester.tap(find.text('Schedule'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final state = (sent['options']! as Map)['scheduling_state']! as Map;
    final when = DateTime.fromMillisecondsSinceEpoch(
      (state['send_date']! as int) * 1000,
    );
    expect(when.hour, 23);
    expect(when.minute, 59);
    expect(when.isAfter(DateTime.now()), isTrue);
    // It goes to the scheduled list, so the timeline shows a toast, not it.
    expect(find.text('Later one'), findsNothing);
    expect(find.textContaining('Scheduled for'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('votes in a poll, follows its results and stops it', (
    tester,
  ) async {
    json.history = [_pollMessage(chosen: null), ..._history];
    await pump(tester);
    expect(find.text('Tea or coffee?'), findsOneWidget);
    expect(find.text('Anonymous poll'), findsOneWidget);
    expect(find.text('3 votes'), findsOneWidget);
    expect(find.text('75%'), findsNothing);

    await tester.tap(find.text('Coffee'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    var sent = json.sent.lastWhere((r) => r['@type'] == 'setPollAnswer');
    expect(sent['message_id'], 16);
    expect(sent['option_ids'], [1]);

    json.push({'@type': 'updatePoll', 'poll': _poll(chosen: 1).toJson()});
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Retract vote'), findsOneWidget);

    await tester.tap(find.text('Retract vote'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    sent = json.sent.lastWhere((r) => r['@type'] == 'setPollAnswer');
    expect(sent['option_ids'], isEmpty);

    await rightClick(tester, 'Tea or coffee?');
    await tester.tap(find.text('Stop poll'));
    await tester.pump();
    expect(find.text('Stop this poll?'), findsOneWidget);
    await tester.tap(find.text('Stop poll').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    sent = json.sent.lastWhere((r) => r['@type'] == 'stopPoll');
    expect(sent['message_id'], 16);
  });

  testWidgets('opens the comments of a post and writes one', (tester) async {
    json.history = [
      _message(id: 14, senderId: 2, text: 'Post', comments: 2),
      ..._history,
    ];
    await pump(tester, group: false);
    expect(find.text('2 comments'), findsOneWidget);

    await tester.tap(find.text('2 comments'));
    // The thread, then its first page.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('First comment'), findsOneWidget);
    expect(find.text('Second comment'), findsOneWidget);
    expect(find.text('Mine'), findsNothing);
    // The capsule now counts the comments.
    expect(find.text('2 comments'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My comment');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['chat_id'], -100);
    expect((send['topic_id']! as Map)['message_thread_id'], 40);
    expect(find.text('My comment'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to the chat'));
    await tester.pump();
    expect(find.text('First comment'), findsNothing);
    expect(find.text('Mine'), findsOneWidget);
  });

  testWidgets('scrolls up through a long thread of comments', (tester) async {
    json
      ..history = [
        _message(id: 14, senderId: 2, text: 'Post', comments: 120),
        ..._history,
      ]
      ..commentIds = [for (var id = 41; id <= 160; id++) id];
    await pump(tester, group: false);
    await tester.tap(find.text('120 comments'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    // It opens on the newest comment.
    expect(find.text('Comment 160'), findsOneWidget);

    // Dragging down goes back in time, loading older pages on the way.
    for (var i = 0; i < 40; i++) {
      await tester.drag(
        find.byKey(const ValueKey('commentsThread')),
        const Offset(0, 600),
      );
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Comment 41'), findsOneWidget);
  });

  testWidgets('selects comments from their menu', (tester) async {
    json.history = [
      _message(id: 14, senderId: 2, text: 'Post', comments: 2),
      ..._history,
    ];
    await pump(tester, group: false);
    await tester.tap(find.text('2 comments'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    await rightClick(tester, 'First comment');
    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    // The selection bar stands in for the comment composer.
    expect(find.text('Copy'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('answers a comment from its menu, quoting it', (tester) async {
    json.history = [
      _message(id: 14, senderId: 2, text: 'Post', comments: 2),
      ..._history,
    ];
    await pump(tester, group: false);
    await tester.tap(find.text('2 comments'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    await rightClick(tester, 'First comment');
    expect(find.text('Select'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pump();
    expect(find.byType(ComposerContextBar), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Answer');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['chat_id'], -100);
    expect((send['topic_id']! as Map)['message_thread_id'], 40);
    expect((send['reply_to']! as Map)['message_id'], 41);
    expect(find.byType(ComposerContextBar), findsNothing);

    // Esc with nothing to cancel goes back to the chat.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('First comment'), findsNothing);
  });

  testWidgets('drops a file into the comments', (tester) async {
    final directory = Directory.systemTemp.createTempSync('comments');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/notes.txt')..writeAsStringSync('hi');
    json.history = [
      _message(id: 14, senderId: 2, text: 'Post', comments: 2),
      ..._history,
    ];
    await pump(tester, group: false);
    await tester.tap(find.text('2 comments'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Read this');
    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [DropItemFile(file.path)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(send['chat_id'], -100);
    expect((send['topic_id']! as Map)['message_thread_id'], 40);
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageDocument');
    expect((content['caption']! as Map)['text'], 'Read this');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('sends a dropped file without sound', (tester) async {
    final directory = Directory.systemTemp.createTempSync('drop');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/notes.txt')..writeAsStringSync('hi');
    await pump(tester);
    tester.widget<DropTarget>(find.byType(DropTarget)).onDragDone!(
      DropDoneDetails(
        files: [DropItemFile(file.path)],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send'), buttons: kSecondaryButton);
    await tester.pump();
    await tester.tap(find.text('Send without sound'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      (send['input_message_content']! as Map)['@type'],
      'inputMessageDocument',
    );
    expect((send['options']! as Map)['disable_notification'], isTrue);
  });

  testWidgets('marks a post whose comments are unread', (tester) async {
    json.history = [
      _message(id: 14, senderId: 2, text: 'Post', comments: 2, unread: true),
      _message(id: 15, senderId: 2, text: 'Read post', comments: 1),
      ..._history,
    ];
    await pump(tester, group: false);
    expect(find.byKey(const ValueKey('unreadComments')), findsOneWidget);
  });

  testWidgets('opens the replies to a group message as a thread', (
    tester,
  ) async {
    json.history = [
      _message(id: 17, senderId: 2, text: 'Question', comments: 3, post: false),
      _message(id: 15, senderId: 2, text: 'Aside', comments: 0, post: false),
      ..._history,
    ];
    await pump(tester);
    expect(find.text('3 replies'), findsWidgets);
    // A group message nobody answered has no row.
    expect(find.text('Leave a comment'), findsNothing);

    await tester.tap(find.text('3 replies'));
    // The thread, then its first page.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('An answer'), findsOneWidget);
    expect(find.text('Mine'), findsNothing);
    // The capsule counts the replies and the composer offers a reply.
    expect(find.text('3 replies'), findsWidgets);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.byTooltip('Back to the chat'), findsOneWidget);
  });

  testWidgets('shows a checklist and marks a task done', (tester) async {
    json.history = [_checklistMessage(), ..._history];
    await pump(tester);
    expect(
      find.textContaining('Groceries', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('1 of 2 completed'), findsOneWidget);

    await tester.tap(find.textContaining('Bread', findRichText: true));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere(
      (r) => r['@type'] == 'markChecklistTasksAsDone',
    );
    expect(sent['message_id'], 18);
    expect(sent['marked_as_done_task_ids'], [2]);
    expect(sent['marked_as_not_done_task_ids'], isEmpty);
  });

  testWidgets('opens the set of a tapped sticker', (tester) async {
    json.history = [_stickerMessage(), ..._history];
    await pump(tester);
    await tester.tap(find.byType(StickerContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    final request = json.sent.lastWhere((r) => r['@type'] == 'getStickerSet');
    expect('${request['set_id']}', '55');
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('2 stickers'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
  });

  testWidgets('asks for a voice message transcript and shows it', (
    tester,
  ) async {
    json.history = [td.Message.fromJson(_voiceMessage(7, 3)), ..._history];
    await pump(tester);
    await tester.tap(find.byTooltip('Transcribe'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final request = json.sent.lastWhere((r) => r['@type'] == 'recognizeSpeech');
    expect(request['message_id'], 7);
    expect(find.text('Transcribing…'), findsOneWidget);

    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 7,
      'new_content': _voiceMessage(
        7,
        3,
        transcript: {
          '@type': 'speechRecognitionResultText',
          'text': 'Hello there',
        },
      )['content'],
    });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Hello there'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide transcript'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Hello there'), findsNothing);
  });

  testWidgets('draws a dice as its result sticker and a slot machine as its '
      'parts', (tester) async {
    json.history = [_diceMessage(), _slotMachineMessage(), ..._history];
    await pump(tester);
    expect(find.text('🎲'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is StickerContent && w.sticker.id == 109),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is StickerContent && w.sticker.emoji == '🎰',
      ),
      findsNWidgets(5),
    );
  });

  testWidgets('lists who voted for an option of a public poll', (tester) async {
    json.history = [_pollMessage(chosen: 1, public: true), ..._history];
    await pump(tester);
    expect(find.text('Poll'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);

    await tester.tap(find.text('Coffee'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final request = json.sent.lastWhere((r) => r['@type'] == 'getPollVoters');
    expect(request['message_id'], 16);
    expect(request['option_id'], 1);
    expect(find.text('3 votes'), findsOneWidget);
    // Vera is named in the chat too; the popover adds her row.
    expect(find.text('Vera'), findsNWidgets(2));

    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.text('3 votes'), findsNothing);
  });

  testWidgets('collects several answers and votes on the button', (
    tester,
  ) async {
    json.history = [_pollMessage(chosen: null, multiple: true), ..._history];
    await pump(tester);

    await tester.tap(find.text('Tea'));
    await tester.pump();
    expect(json.sent.where((r) => r['@type'] == 'setPollAnswer'), isEmpty);
    await tester.tap(find.text('Coffee'));
    await tester.pump();
    await tester.tap(find.text('Vote'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'setPollAnswer');
    expect(sent['option_ids'], [0, 1]);
  });

  testWidgets('presses a bot\'s inline button and shows its answer', (
    tester,
  ) async {
    json.history = [_inlineKeyboardMessage(), ..._history];
    await pump(tester);
    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.text('Ping'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere(
      (r) => r['@type'] == 'getCallbackQueryAnswer',
    );
    expect(sent['message_id'], 16);
    expect((sent['payload']! as Map)['data'], base64.encode([1, 2, 3]));
    expect(find.text('Pong'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('shows a venue on a map with its name and address', (
    tester,
  ) async {
    json.history = [
      td.Message.fromJson({
        ..._message(id: 18, senderId: 2, text: '').toJson(),
        'content': {
          '@type': 'messageVenue',
          'venue': {
            '@type': 'venue',
            'location': {
              '@type': 'location',
              'latitude': 55.7539,
              'longitude': 37.6208,
              'horizontal_accuracy': 0,
            },
            'title': 'Red Square',
            'address': 'Moscow',
            'provider': '',
            'id': '',
            'type': '',
          },
        },
      }),
      ..._history,
    ];
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('Red Square'), findsOneWidget);
    expect(find.text('Moscow'), findsOneWidget);
    final map = json.sent.lastWhere((r) => r['@type'] == 'getMapThumbnailFile');
    expect((map['location']! as Map)['latitude'], 55.7539);
    expect(map['zoom'], 15);
    expect(map['chat_id'], 7);
    expect(find.byType(LocationContent), findsOneWidget);
  });

  testWidgets('shows Saved Messages as the chats they came from', (
    tester,
  ) async {
    json.push({
      '@type': 'updateOption',
      'name': 'my_id',
      'value': {'@type': 'optionValueInteger', 'value': 7},
    });
    json.push(
      _chat(
        lastRead: 13,
        unread: 0,
        last: 13,
        type: {'@type': 'chatTypePrivate', 'user_id': 7},
      ),
    );
    await pump(tester);
    await tester.tap(find.byTooltip('Show as chats'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(
      json.sent.where((r) => r['@type'] == 'loadSavedMessagesTopics'),
      isNotEmpty,
    );
    for (final (id, type, order) in [
      (1, {'@type': 'savedMessagesTopicTypeMyNotes'}, 5),
      (2, {'@type': 'savedMessagesTopicTypeSavedFromChat', 'chat_id': 7}, 9),
    ]) {
      json.push({
        '@type': 'updateSavedMessagesTopic',
        'topic': {
          '@type': 'savedMessagesTopic',
          'id': id,
          'type': type,
          'is_pinned': id == 1,
          'order': order,
          'last_message': _message(
            id: 40 + id,
            senderId: 2,
            text: 'Saved $id',
          ).toJson(),
        },
      });
    }
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('My notes'), findsOneWidget);
    expect(find.text('Saved 2'), findsOneWidget);
    // Pinned first, whatever the order.
    final rows = tester.getTopLeft(find.byKey(const ValueKey('saved-topic-1')));
    expect(
      rows.dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('saved-topic-2'))).dy,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('saved-topic-2')));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final history = json.sent.lastWhere(
      (r) => r['@type'] == 'getSavedMessagesTopicHistory',
    );
    expect(history['saved_messages_topic_id'], 2);
    expect(find.text('Kept for later'), findsOneWidget);
    expect(find.byTooltip('Back to topics'), findsOneWidget);
  });

  testWidgets('filters Saved Messages by a tag from the bar', (tester) async {
    json.push({
      '@type': 'updateOption',
      'name': 'my_id',
      'value': {'@type': 'optionValueInteger', 'value': 7},
    });
    json.push(
      _chat(
        lastRead: 13,
        unread: 0,
        last: 13,
        type: {'@type': 'chatTypePrivate', 'user_id': 7},
      ),
    );
    await pump(tester);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(
      json.sent.lastWhere(
        (r) => r['@type'] == 'getSavedMessagesTags',
      )['saved_messages_topic_id'],
      0,
    );
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('saved-tag-🔥')));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'searchSavedMessages',
    );
    expect((search['tag']! as Map)['emoji'], '🔥');
    expect(search['query'], '');
    expect(find.text('Tagged two'), findsOneWidget);
    expect(find.byTooltip('All saved messages'), findsOneWidget);
    // The bar stays, so another tag is one click away; the capsule names
    // the tag.
    expect(find.byKey(const ValueKey('saved-tag-🔥')), findsOneWidget);
    expect(find.text('Work'), findsNWidgets(2));

    // The same chip again shows every saved message.
    await tester.tap(find.byKey(const ValueKey('saved-tag-🔥')));
    await tester.pump();
    expect(find.text('Tagged two'), findsNothing);
    expect(find.byTooltip('All saved messages'), findsNothing);

    // A new label arrives with the update.
    json.push({
      '@type': 'updateSavedMessagesTags',
      'saved_messages_topic_id': 0,
      'tags': {
        '@type': 'savedMessagesTags',
        'tags': [
          {
            '@type': 'savedMessagesTag',
            'tag': {'@type': 'reactionTypeEmoji', 'emoji': '🔥'},
            'label': 'Ideas',
            'count': 3,
          },
        ],
      },
    });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('Ideas'), findsOneWidget);
  });

  testWidgets('shows kept deleted messages and the edit history', (
    tester,
  ) async {
    // A session that keeps what others delete and edit, in a store in
    // memory.
    final plain = session;
    addTearDown(plain.dispose);
    await tester.runAsync(() async {
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
        privacy: const PrivacySettings(
          keepDeletedMessages: true,
          keepEditHistory: true,
        ),
        openStore: MessageStore.memory,
      );
      // Opened here, under real async, so the view finds it ready.
      await session.capture.store;
    });
    session.conversations.store
      ..setUserName(2, 'Boris')
      ..setUserName(3, 'Vera');
    await pump(tester);
    expect(find.text('Boris again'), findsOneWidget);

    // Boris deletes a message: it stays, marked.
    json.push({
      '@type': 'updateDeleteMessages',
      'chat_id': 7,
      'message_ids': [11],
      'is_permanent': true,
      'from_cache': false,
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(_tick);
      await session.capture.flush();
      await Future<void>.delayed(_tick);
    });
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('Boris again'), findsOneWidget);
    expect(find.text('deleted'), findsOneWidget);

    // Boris edits another: the menu opens its earlier version.
    json.push({
      '@type': 'updateMessageContent',
      'chat_id': 7,
      'message_id': 10,
      'new_content': {
        '@type': 'messageText',
        'text': {
          '@type': 'formattedText',
          'text': 'From Boris, fixed',
          'entities': <Object?>[],
        },
      },
    });
    json.push({
      '@type': 'updateMessageEdited',
      'chat_id': 7,
      'message_id': 10,
      'edit_date': 1700000000,
    });
    await tester.runAsync(() async {
      await Future<void>.delayed(_tick);
      await session.capture.flush();
    });
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('From Boris, fixed'), findsOneWidget);
    await rightClick(tester, 'From Boris, fixed');
    // The store's watch keeps the view busy, so the menu takes a beat more.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.tap(find.text('Edit history'));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('From Boris'), findsOneWidget);
    expect(find.text('Current version'), findsOneWidget);
    expect(find.byKey(const ValueKey('version-current')), findsOneWidget);
  });

  testWidgets('puts a switch-to-inline button\'s query in the composer', (
    tester,
  ) async {
    json.history = [_inlineKeyboardMessage(), ..._history];
    await pump(tester);
    await tester.tap(find.text('Search'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '@gif cats');
    expect(field.controller!.selection.baseOffset, '@gif cats'.length);
  });

  testWidgets('shares the phone number from a bot\'s keyboard after asking', (
    tester,
  ) async {
    json.history = [_replyKeyboardMessage(), ..._history];
    json.push(_chat(lastRead: 13, unread: 0, last: 13, replyMarkup: 17));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.tap(find.text('Share phone'));
    await tester.pumpAndSettle();
    expect(find.text('Share your phone number?'), findsOneWidget);
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final contact = (sent['input_message_content']! as Map)['contact']! as Map;
    expect(contact['phone_number'], '79990000000');
    expect(contact['user_id'], 7);
  });

  testWidgets('sends a place and shares a chat from a bot\'s keyboard', (
    tester,
  ) async {
    json.history = [_replyKeyboardMessage(), ..._history];
    json.push(_chat(lastRead: 13, unread: 0, last: 13, replyMarkup: 17));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);

    await tester.tap(find.text('Where'));
    await tester.pumpAndSettle();
    expect(find.text('Send location'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '55.7558, 37.6173');
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send-this-location')));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = sent['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageLocation');
    expect((content['location']! as Map)['latitude'], closeTo(55.7558, 1e-6));

    // The one-time keyboard folded away; bring it back for the next button.
    await tester.tap(find.byTooltip('Bot keyboard'));
    await tester.pump();
    await tester.tap(find.text('Pick chat'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Forward to chat'), findsOneWidget);
    await tester.tap(find.text('Saved'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final share = json.sent.lastWhere((r) => r['@type'] == 'shareChatWithBot');
    expect(share['shared_chat_id'], 9);
    expect(share['button_id'], 3);
    expect((share['source']! as Map)['message_id'], 17);
  });

  testWidgets('shows a bot\'s reply keyboard and sends a button', (
    tester,
  ) async {
    json.history = [_replyKeyboardMessage(), ..._history];
    json.push(_chat(lastRead: 13, unread: 0, last: 13, replyMarkup: 17));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    expect(find.text('Menu'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);

    await tester.tap(find.text('Help'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      ((sent['input_message_content']! as Map)['text']! as Map)['text'],
      'Help',
    );
    // A one-time keyboard folds away; the toggle brings it back.
    expect(find.text('Menu'), findsNothing);
    await tester.tap(find.byTooltip('Bot keyboard'));
    await tester.pump();
    expect(find.text('Menu'), findsOneWidget);
  });

  testWidgets('opens the channel a message was forwarded from', (tester) async {
    json.history = [
      td.Message.fromJson({
        ..._message(id: 14, senderId: 2, text: 'Fresh pizza today').toJson(),
        'forward_info': {
          '@type': 'messageForwardInfo',
          'origin': {
            '@type': 'messageOriginChannel',
            'chat_id': 55,
            'message_id': 77,
            'author_signature': '',
          },
          'date': 1760000000,
        },
      }),
      ..._history,
    ];
    json.push(_chat(lastRead: 14, unread: 0, last: 14));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatView)),
    );
    expect(container.read(messageJumpProvider), isEmpty);
    // The name of the source is a link; the message itself is not.
    // Both the sender and the source are unknown here; the link is the
    // one that comes first in the tree.
    final names = find
        .text(
          AppLocalizations.of(tester.element(find.byType(ChatView)))
              .unknownSender,
        )
        .first;
    await tester.tap(names);
    await tester.pump();
    expect(container.read(messageJumpProvider)[55]?.messageId, 77);
    await tester.pump(const Duration(seconds: 1));
  });

  /// A chat whose incoming messages are in Russian.
  List<td.Message> russianHistory() => [
    _message(id: 13, senderId: 2, text: 'Привет, как дела у вас сегодня?'),
    _message(id: 12, senderId: 2, text: 'Мы собираемся встретиться завтра'),
    _message(id: 11, senderId: 2, text: 'Не забудьте взять с собой ключи'),
    _message(
      id: 10,
      senderId: 1,
      text: 'Спасибо большое за напоминание',
      outgoing: true,
    ),
  ];

  Future<void> openRussianChat(WidgetTester tester) async {
    json.history = russianHistory();
    json.push(_chat(lastRead: 13, unread: 0, last: 13));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pump();
  }

  Future<void> settleTranslation(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('translates the whole chat from the bar under the header', (
    tester,
  ) async {
    await openRussianChat(tester);
    expect(find.text('Translate to English'), findsOneWidget);
    // Nothing is translated until asked, and no message offers a link.
    expect(find.textContaining('Привет', findRichText: true), findsOneWidget);
    expect(find.textContaining('Translate from'), findsNothing);
    expect(
      json.sent.where((r) => r['@type'] == 'translateMessageText'),
      isEmpty,
    );

    await tester.tap(find.text('Translate to English'));
    await settleTranslation(tester);
    expect(find.text('Translated from Russian'), findsOneWidget);
    expect(find.text('Show original'), findsOneWidget);
    expect(
      find.textContaining('Translated 13', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('Привет', findRichText: true), findsNothing);
    // The user's own message is left as written.
    expect(find.textContaining('Спасибо', findRichText: true), findsOneWidget);
    final asked = {
      for (final r in json.sent.where(
        (r) => r['@type'] == 'translateMessageText',
      ))
        r['message_id']: r['to_language_code'],
    };
    expect(asked, {13: 'en', 12: 'en', 11: 'en'});

    await tester.tap(find.text('Show original'));
    await settleTranslation(tester);
    expect(find.textContaining('Привет', findRichText: true), findsOneWidget);
    expect(find.text('Translate to English'), findsOneWidget);
  });

  testWidgets('hides the translation bar from its menu', (tester) async {
    await openRussianChat(tester);
    await tester.tap(find.byTooltip('Translation options'));
    await tester.pumpAndSettle();
    expect(find.text('Translate to…'), findsOneWidget);
    expect(find.text("Don't translate Russian"), findsOneWidget);
    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();
    expect(find.text('Translate to English'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('stops offering a language the user does not want translated', (
    tester,
  ) async {
    await openRussianChat(tester);
    await tester.tap(find.byTooltip('Translation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't translate Russian"));
    await tester.pumpAndSettle();
    expect(find.text('Translate to English'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('makes room under the messages for a bot\'s keyboard', (
    tester,
  ) async {
    json.history = [_replyKeyboardMessage(), ..._history];
    json.push(_chat(lastRead: 13, unread: 0, last: 13, replyMarkup: 17));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pump();
    TimelineView timeline() =>
        tester.widget<TimelineView>(find.byType(TimelineView));
    final keyboard = tester.getSize(find.byType(ReplyKeyboard));
    expect(keyboard.height, greaterThan(60));
    // The room covers everything under the strip's buttons: the keyboard
    // and the composer.
    final chatBottom = tester.getBottomLeft(find.byType(ChatView)).dy;
    final keyboardTop = tester.getTopLeft(find.byType(ReplyKeyboard)).dy;
    expect(
      timeline().bottomInset,
      greaterThanOrEqualTo(chatBottom - keyboardTop),
    );
    // The newest message sits above the keyboard, not under it.
    final newest = tester.getBottomLeft(find.text('Mine'));
    expect(
      newest.dy,
      lessThan(tester.getTopLeft(find.byType(ReplyKeyboard)).dy),
    );

    // Hidden, the keyboard gives the space back.
    final withKeyboard = timeline().bottomInset;
    await tester.tap(find.byTooltip('Bot keyboard'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(ReplyKeyboard), findsNothing);
    expect(
      timeline().bottomInset,
      lessThan(withKeyboard - keyboard.height + 1),
    );
  });

  testWidgets('offers emoji for a :word and stickers for an emoji', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'ok :smi');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('smile'), findsOneWidget);
    expect(find.text('smile cat'), findsOneWidget);

    // Past the popup's fade-in.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('smile cat'));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'ok 😸');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('smile'), findsNothing);

    await tester.enterText(find.byType(TextField), '🐱');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.pump();
    expect(find.byType(StickerSuggestionStrip), findsOneWidget);
    expect(find.byType(StickerContent), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(StickerContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageSticker');
    expect(field.controller!.text, isEmpty);
    expect(find.byType(StickerSuggestionStrip), findsNothing);
  });

  testWidgets('posts as a channel picked from the composer', (tester) async {
    final group = _chat(
      lastRead: 13,
      unread: 0,
      last: 13,
      type: {
        '@type': 'chatTypeSupergroup',
        'supergroup_id': 99,
        'is_channel': false,
      },
      sendAs: {'@type': 'messageSenderUser', 'user_id': 1},
    );
    json
      ..push(group)
      ..push(
        _supergroup(99, {
          '@type': 'chatMemberStatusMember',
          'member_since_date': 0,
        }),
      )
      ..push({
        '@type': 'updateNewChat',
        'chat': {
          ...group['chat']! as Map<String, Object?>,
          'id': 8,
          'title': 'News',
          'type': {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 98,
            'is_channel': true,
          },
        },
      });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sendAs')));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Send as'), findsOneWidget);
    expect(find.text('Personal account'), findsOneWidget);
    expect(find.text('News'), findsOneWidget);

    await tester.tap(find.text('News'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    final sent = json.sent.lastWhere(
      (r) => r['@type'] == 'setChatMessageSender',
    );
    expect(sent['chat_id'], 7);
    expect((sent['message_sender_id']! as Map)['chat_id'], 8);
  });

  testWidgets('composes a quiz from the attach menu and sends it', (
    tester,
  ) async {
    json
      ..push(
        _chat(
          lastRead: 13,
          unread: 0,
          last: 13,
          type: {
            '@type': 'chatTypeSupergroup',
            'supergroup_id': 99,
            'is_channel': false,
          },
        ),
      )
      ..push(
        _supergroup(99, {
          '@type': 'chatMemberStatusMember',
          'member_since_date': 0,
        }),
      );
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();
    await tester.tap(find.text('Poll…'));
    await tester.pump();
    expect(find.text('New poll'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'Tea or coffee?');
    await tester.enterText(fields.at(2), 'Tea');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(3), 'Coffee');
    await tester.pump();
    // A third, empty option appeared; the two filled ones can be removed.
    expect(find.byTooltip('Remove option'), findsNWidgets(2));

    await tester.tap(find.text('Quiz mode'));
    await tester.pump();
    expect(find.text('New quiz'), findsOneWidget);
    await tester.tap(find.byTooltip('Correct answer').at(1));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessagePoll');
    expect((content['question']! as Map)['text'], 'Tea or coffee?');
    expect(
      [for (final o in content['options']! as List) (o as Map)['text']],
      [
        {'@type': 'formattedText', 'text': 'Tea', 'entities': <Object?>[]},
        {'@type': 'formattedText', 'text': 'Coffee', 'entities': <Object?>[]},
      ],
    );
    expect((content['type']! as Map)['correct_option_ids'], [1]);
    expect(content['is_anonymous'], isTrue);
    expect(find.text('New quiz'), findsNothing);
  });

  testWidgets('sends a place or a venue from the attach menu', (tester) async {
    await pump(tester, group: false);
    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();
    await tester.tap(find.text('Location…'));
    await tester.pump();
    expect(find.text('Send location'), findsOneWidget);

    // Coordinates in the field move the pin there, whatever the sheet
    // remembered from an earlier opening.
    await tester.enterText(find.byType(TextField).last, '48.8566, 2.3522');
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final map = json.sent.lastWhere((r) => r['@type'] == 'getMapThumbnailFile');
    final shown = map['location']! as Map;
    expect(shown['latitude'], closeTo(48.8566, 1e-6));
    expect(map['zoom'], 15);
    expect(find.text('48.85660, 2.35220'), findsOneWidget);

    // A place name searches venues around the pin.
    await tester.enterText(find.byType(TextField).last, 'tower');
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    final search = json.sent.lastWhere(
      (r) => r['@type'] == 'getInlineQueryResults',
    );
    expect(search['query'], 'tower');
    expect(
      (search['user_location']! as Map)['latitude'],
      closeTo(48.8566, 1e-6),
    );
    expect(find.text('Eiffel Tower'), findsOneWidget);
    expect(find.text('Champ de Mars, Paris'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('send-this-location')));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump(const Duration(milliseconds: 200));
    var send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    var content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageLocation');
    expect((content['location']! as Map)['longitude'], closeTo(2.3522, 1e-6));
    await tester.pumpAndSettle();
    expect(find.text('Send location'), findsNothing);

    // The sheet opens where it was left; a venue row sends the venue.
    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();
    await tester.tap(find.text('Location…'));
    await tester.pump();
    expect(find.text('48.85660, 2.35220'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'tower');
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    await tester.tap(find.text('Eiffel Tower'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump(const Duration(milliseconds: 200));
    send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageVenue');
    expect((content['venue']! as Map)['title'], 'Eiffel Tower');
    await tester.pumpAndSettle();
  });

  testWidgets('sends a contact from the attach menu', (tester) async {
    await pump(tester, group: false);
    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();
    await tester.tap(find.text('Contact…'));
    await tester.pump();
    expect(find.text('Send contact'), findsOneWidget);
    // The contacts and their users arrive over a few round trips.
    for (var i = 0; i < 10 && !session.contacts.isLoaded; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
    }
    await tester.pump(const Duration(milliseconds: 50));
    // The senders' names are in the chat; the rows add one of each.
    expect(find.text('Vera'), findsNWidgets(2));
    expect(find.text('Boris'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).last, 'ver');
    await tester.pump();
    expect(find.text('Boris'), findsOneWidget);
    await tester.tap(find.text('Vera').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump(const Duration(milliseconds: 200));

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageContact');
    final contact = content['contact']! as Map;
    expect(contact['user_id'], 3);
    expect(contact['first_name'], 'Vera');
    expect(contact['phone_number'], '79990001122');
    await tester.pumpAndSettle();
    expect(find.text('Send contact'), findsNothing);
  });

  testWidgets('starts a bot and offers its commands after a slash', (
    tester,
  ) async {
    session.conversations.store
      ..setBot(2, true)
      ..setBotMenu(7, const BotMenu(text: '', url: ''))
      ..setBotCommands(7, const [
        BotCommand(botUserId: 2, command: 'start', description: 'Begin'),
        BotCommand(botUserId: 2, command: 'settings', description: 'Set up'),
      ]);
    json.chat = const [];
    json.push(_chat(lastRead: 0, unread: 0, last: 0, empty: true));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: false);
    await tester.pumpAndSettle();

    expect(find.byType(Composer), findsNothing);
    await tester.tap(find.text('Start'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final start = json.sent.lastWhere(
      (r) => r['@type'] == 'sendBotStartMessage',
    );
    expect(start['bot_user_id'], 2);
    expect(start['chat_id'], 7);

    // The bot answered: the composer is back, and / lists its commands.
    json.push({
      '@type': 'updateNewMessage',
      'message': _message(id: 20, senderId: 2, text: 'Hello').toJson(),
    });
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(Composer), findsOneWidget);
    await tester.enterText(find.byType(TextField), '/se');
    await tester.pumpAndSettle();
    expect(find.text('/settings'), findsOneWidget);
    expect(find.text('/start'), findsNothing);

    await tester.tap(find.text('/settings'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      ((sent['input_message_content']! as Map)['text']! as Map)['text'],
      '/settings',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );

    // The menu button lists every command.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '/',
    );
    expect(find.text('/settings'), findsOneWidget);
    expect(find.text('/start'), findsOneWidget);
  });

  testWidgets("opens a bot's Web App from its menu button", (tester) async {
    session.conversations.store
      ..setBot(2, true)
      ..setBotMenu(7, const BotMenu(text: 'Shop', url: 'https://shop.example'));
    json.push(_chat(lastRead: 13, unread: 0, last: 13));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester, group: false);
    expect(find.text('Menu'), findsNothing);
    expect(find.byType(BotMenuPill), findsOneWidget);

    await tester.tap(find.text('Shop'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final request = json.sent.lastWhere((r) => r['@type'] == 'getWebAppUrl');
    expect(request['bot_user_id'], 2);
    expect(request['url'], 'https://shop.example');
    expect(
      ((request['parameters']! as Map)['theme']! as Map)['button_color'],
      isA<int>(),
    );
  });

  testWidgets('lists the scheduled messages and acts on one', (tester) async {
    json.chat = [for (var id = 1; id <= 10; id++) id];
    json.push(_chat(lastRead: 10, unread: 0, last: 10, scheduled: true));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);

    await tester.tap(find.byTooltip('Scheduled messages'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    expect(find.text('1 scheduled message'), findsOneWidget);
    expect(find.text('Later one'), findsOneWidget);
    expect(find.text('Message 10'), findsNothing);

    await rightClick(tester, 'Later one');
    await tester.tap(find.text('Send now'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    var sent = json.sent.lastWhere(
      (r) => r['@type'] == 'editMessageSchedulingState',
    );
    expect(sent['message_id'], 30);
    expect(sent.containsKey('scheduling_state'), isFalse);

    await rightClick(tester, 'Later one');
    await tester.tap(find.text('Delete'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    sent = json.sent.lastWhere((r) => r['@type'] == 'deleteMessages');
    expect(sent['message_ids'], [30]);
    expect(sent['revoke'], isTrue);

    // Back to the chat on Esc.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('1 scheduled message'), findsNothing);
    expect(find.byType(Composer), findsOneWidget);
    expect(find.text('Message 10'), findsOneWidget);
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
    // A click ticks the chat; the comment and Send come in.
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(json.sent.where((r) => r['@type'] == 'forwardMessages'), isEmpty);
    await tester.enterText(find.byType(TextField).last, 'Look at this');
    await tester.tap(find.text('Send 1'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['chat_id'], 9);
    expect(forward['message_ids'], [12]);
    expect(forward['send_copy'], isFalse);
    // The comment went first.
    final comment = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(comment['chat_id'], 9);
    expect(json.sent.indexOf(comment), lessThan(json.sent.indexOf(forward)));
  });

  testWidgets('Enter forwards to the highlighted chat at once', (tester) async {
    await pump(tester);

    await rightClick(tester, 'From Vera');
    await tester.tap(find.text('Forward'));
    await tester.pump();
    await tester.pump();
    // Nothing ticked: Enter sends to the highlighted first chat.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    expect(find.text('Forward to chat'), findsNothing);
    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['message_ids'], [12]);
  });

  testWidgets('forwards from the recent chats in the menu', (tester) async {
    await pump(tester);
    // The sidebar keeps the chat list loaded; here it is asked for.
    ProviderScope.containerOf(tester.element(find.byType(ChatView)))
        .listen(chatListProvider(const ChatListLocation.main()), (_, _) {});
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    await rightClick(tester, 'From Vera');
    final forward = find.text('Forward');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(forward));
    await mouse.moveTo(tester.getCenter(forward));
    await tester.pump();
    expect(find.text('Choose chat…'), findsOneWidget);
    await tester.tap(find.text('Saved'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    expect(find.text('Forward to chat'), findsNothing);
    final sent = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(sent['chat_id'], 9);
    expect(sent['message_ids'], [12]);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send 1'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final forward = json.sent.lastWhere((r) => r['@type'] == 'forwardMessages');
    expect(forward['send_copy'], isTrue);
    expect(forward['remove_caption'], isFalse);
  });

  testWidgets('the message menu keeps every action, in order', (tester) async {
    await pump(tester);
    await rightClick(tester, 'Mine');
    const labels = [
      'Reply',
      'Edit',
      'Copy text',
      'Forward',
      'Pin',
      'Select',
      'Report',
      'Delete',
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final tops = [
      for (final label in labels) tester.getTopLeft(find.text(label)).dy,
    ];
    for (var i = 1; i < tops.length; i++) {
      expect(tops[i], greaterThan(tops[i - 1]), reason: labels[i]);
    }
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send 1'));
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
    // chat is known, a page later (after one more ask to be sure it is empty).
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
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

  testWidgets('shows the playing voice message in the header', (tester) async {
    json.chat = [for (var id = 1; id <= 60; id++) id];
    json.push(_chat(lastRead: 60, unread: 0, last: 60));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show in chat'), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatView)),
    );
    final player = container.read(audioPlayerProvider);
    player.debugLoad(
      (chatId: 7, messageId: 20),
      duration: const Duration(seconds: 45),
      position: const Duration(seconds: 12),
    );
    await tester.pumpAndSettle();
    final capsule = find.byTooltip('Show in chat');
    expect(capsule, findsOneWidget);
    expect(
      find.descendant(of: capsule, matching: find.text('Boris')),
      findsOneWidget,
    );
    expect(find.text('0:12 / 0:45'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);

    // The title scrolls to the message; before that only the capsule's
    // own subtitle names it.
    final twentieth = find.textContaining(
      RegExp(r'Message 20(?!\d)'),
      findRichText: true,
    );
    expect(twentieth, findsOneWidget);
    await tester.tap(capsule);
    await tester.pump();
    expect(twentieth, findsNWidgets(2));
    expect(tester.getRect(twentieth.first).top, inInclusiveRange(0, 800));

    await tester.tap(
      find.descendant(
        of: find.byType(Glass),
        matching: find.byTooltip('Close'),
      ),
    );
    await tester.pumpAndSettle();
    expect(player.track.value, isNull);
    expect(find.byTooltip('Show in chat'), findsNothing);
  });

  testWidgets('lists the chat\'s voice messages as the player\'s playlist', (
    tester,
  ) async {
    json.history = [
      td.Message.fromJson(_voiceMessage(23, 3)),
      td.Message.fromJson(_voiceMessage(21, 2)),
      ..._history,
    ];
    await pump(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatView)),
    );
    final player = container.read(audioPlayerProvider);
    player.debugLoad((
      chatId: 7,
      messageId: 21,
    ), duration: const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Playlist'));
    await tester.pumpAndSettle();
    expect(find.text('Playlist'), findsOneWidget);
    final panel = find
        .ancestor(of: find.text('Playlist'), matching: find.byType(Glass))
        .first;
    expect(
      find.descendant(of: panel, matching: find.text('0:03')),
      findsNWidgets(2),
    );

    // Vera's message is the other one; picking it downloads and plays it.
    await tester.tap(find.text('Vera').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Playlist'), findsNothing);
    final download = json.sent.lastWhere((r) => r['@type'] == 'downloadFile');
    expect(download['file_id'], 523);
  });

  testWidgets('jumps to a day from the search bar', (tester) async {
    await pump(tester);
    // The shortcut needs the focus inside the chat.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.byType(ChatSearchBar), findsOneWidget);

    await tester.tap(find.byTooltip('Jump to date'));
    await tester.pump();
    expect(find.byType(MgCalendar), findsOneWidget);
    await tester.tap(find.text('1').first);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.byType(MgCalendar), findsNothing);
    final request = json.sent.lastWhere(
      (r) => r['@type'] == 'getChatMessageByDate',
    );
    expect(request['chat_id'], 7);
    // The search stays open for the next step.
    expect(find.byType(ChatSearchBar), findsOneWidget);
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

    // The strip under the page goes straight to a thumbnail.
    expect(find.byKey(const ValueKey('viewer-thumbnails')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('viewer-thumbnail-1')));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsNothing);
  });

  testWidgets('swipes between the chat media and rotates a photo', (
    tester,
  ) async {
    json.history = [td.Message.fromJson(_photo(15)), ..._history];
    await pump(tester);
    await tester.tap(find.byType(PhotoContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    // Two fingers to the right bring the previous page, once per swipe.
    final center = tester.getCenter(find.byType(InteractiveViewer));
    final swipe = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await swipe.panZoomStart(center);
    await swipe.panZoomUpdate(center, pan: const Offset(30, 4));
    await tester.pump();
    expect(find.text('2 of 2'), findsOneWidget);
    await swipe.panZoomUpdate(center, pan: const Offset(70, 6));
    await swipe.panZoomUpdate(center, pan: const Offset(140, 6));
    await swipe.panZoomEnd();
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);

    // R turns the photo a quarter clockwise.
    AnimatedRotation rotation() =>
        tester.widget<AnimatedRotation>(find.byType(AnimatedRotation));
    expect(rotation().turns, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();
    expect(rotation().turns, 0.25);
    await tester.tap(find.bySemanticsLabel('Rotate'));
    await tester.pumpAndSettle();
    expect(rotation().turns, 0.5);

    // A page turn starts the next page upright.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(rotation().turns, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
  });

  testWidgets('deletes the photo on screen from the viewer', (tester) async {
    json.history = [td.Message.fromJson(_photo(15)), ..._history];
    await pump(tester);
    await tester.tap(find.byType(PhotoContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    final delete = json.sent.lastWhere((r) => r['@type'] == 'deleteMessages');
    expect(delete['message_ids'], [15]);
    expect(find.text('2 of 2'), findsNothing);
  });

  testWidgets('leaves the viewer for the message in the chat', (tester) async {
    json.history = [td.Message.fromJson(_photo(15)), ..._history];
    await pump(tester);
    await tester.tap(find.byType(PhotoContent));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Show in chat'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsNothing);
    expect(find.byType(PhotoContent), findsOneWidget);
  });

  testWidgets('a clicked file download goes on the downloads list', (
    tester,
  ) async {
    json.history = [
      td.Message.fromJson(_document(16, '', downloaded: false)),
      ..._history,
    ];
    await pump(tester);

    await tester.tap(find.text('route_saturday.pdf'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final added = json.sent.lastWhere(
      (r) => r['@type'] == 'addFileToDownloads',
    );
    expect(added['file_id'], 70);
    expect(added['chat_id'], 7);
    expect(added['message_id'], 16);
  });

  testWidgets('a photo waits for a click when photos do not auto-download', (
    tester,
  ) async {
    json.history = [td.Message.fromJson(_photo(15, idle: true)), ..._history];
    // What the Data and storage switches set on a real session.
    session.files.autoDownloadKinds = {MediaDownloadKind.videos};
    await pump(tester);

    // Nothing was fetched on its own; the preview carries a download button.
    expect(
      json.sent.where(
        (r) => r['@type'] == 'downloadFile' && r['file_id'] == 415,
      ),
      isEmpty,
    );
    await tester.tap(find.bySemanticsLabel('Download'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final download = json.sent.lastWhere((r) => r['@type'] == 'downloadFile');
    expect(download['file_id'], 415);
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

    if (Platform.isMacOS) {
      String? previewed;
      final look = quickLookFile;
      quickLookFile = (path) async => previewed = path;
      addTearDown(() => quickLookFile = look);
      await rightClick(tester, 'route_saturday.pdf');
      await tester.tap(find.text('Quick Look'));
      await tester.pump();
      expect(previewed, source.path);
    }
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

  testWidgets('finds stickers by a word in the panel', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Stickers'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Search stickers',
    );
    await tester.enterText(field, 'love');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final search = json.sent.lastWhere((r) => r['@type'] == 'searchStickers');
    expect(search['query'], 'love');
    expect(search['input_language_codes'], contains('en'));
    expect(find.text('Found'), findsOneWidget);
    // The sets' bar steps aside for the results.
    expect(find.text('Cats'), findsNothing);

    await tester.tap(find.bySemanticsLabel('😻'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(
      ((send['input_message_content']! as Map)['sticker']! as Map)['sticker'],
      {'@type': 'inputFileId', 'id': 304},
    );
  });

  testWidgets('a tapped hashtag lists the messages that carry it', (
    tester,
  ) async {
    json.history = [
      td.Message.fromJson({
        ..._message(id: 14, senderId: 2, text: '').toJson(),
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': '#news',
            'entities': [
              {
                '@type': 'textEntity',
                'offset': 0,
                'length': 5,
                'type': {'@type': 'textEntityTypeHashtag'},
              },
            ],
          },
          'link_preview_options': null,
        },
      }),
      ..._history,
    ];
    await pump(tester);

    // The sheet sends its search on its first frame, then hears back.
    Future<void> roundtrip() async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('#news'));
    await roundtrip();
    // This chat first: the photos the chat search returns, in the chat.
    expect(find.text('This chat'), findsOneWidget);
    final inChat = json.sent.lastWhere(
      (r) => r['@type'] == 'searchChatMessages',
    );
    expect(inChat['query'], '#news');
    expect(inChat['chat_id'], 7);
    // Rows name the sender in a group: "Boris: Photo".
    expect(find.textContaining('Photo'), findsNWidgets(2));

    await tester.tap(find.text('My messages'));
    await roundtrip();
    final mine = json.sent.lastWhere((r) => r['@type'] == 'searchMessages');
    expect(mine['query'], '#news');
    expect(find.textContaining('Vera: Mine with #news'), findsOneWidget);

    await tester.tap(find.text('Public posts'));
    await roundtrip();
    expect(
      json.sent.lastWhere(
        (r) => r['@type'] == 'searchPublicMessagesByTag',
      )['tag'],
      '#news',
    );
    expect(find.text('No messages with #news'), findsOneWidget);

    // A row closes the sheet and asks the chat to show its message.
    await tester.tap(find.text('My messages'));
    await roundtrip();
    await tester.tap(find.textContaining('Mine with #news'));
    await tester.pumpAndSettle();
    expect(find.text('My messages'), findsNothing);
  });

  testWidgets('draws a custom emoji as its sticker', (tester) async {
    json.history = [
      td.Message.fromJson({
        ..._message(id: 14, senderId: 2, text: '').toJson(),
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': 'Hot 🔥 take',
            'entities': [
              {
                '@type': 'textEntity',
                'offset': 4,
                'length': 2,
                'type': {
                  '@type': 'textEntityTypeCustomEmoji',
                  'custom_emoji_id': 777,
                },
              },
            ],
          },
          'link_preview_options': null,
        },
      }),
      ..._history,
    ];
    await pump(tester);
    expect(find.byType(StickerContent), findsNothing);
    // The stickers arrive in one batch after the first build.
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final request = json.sent.lastWhere(
      (r) => r['@type'] == 'getCustomEmojiStickers',
    );
    expect(request['custom_emoji_ids'], ['777']);
    expect(find.byType(StickerContent), findsOneWidget);
    expect(find.textContaining('Hot ', findRichText: true), findsOneWidget);
    expect(find.textContaining('🔥', findRichText: true), findsNothing);
  });

  testWidgets('shows an inline bot\'s results and sends one via the bot', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '@gif cats');
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    final query = json.sent.lastWhere(
      (r) => r['@type'] == 'getInlineQueryResults',
    );
    expect(query['bot_user_id'], 50);
    expect(query['query'], 'cats');
    expect(find.bySemanticsLabel('Grumpy cat'), findsOneWidget);
    expect(find.bySemanticsLabel('gif2.mp4'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Grumpy cat'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere(
      (r) => r['@type'] == 'sendInlineQueryResultMessage',
    );
    expect(sent['query_id'], '777');
    expect(sent['result_id'], 'a1');
    expect(find.bySemanticsLabel('Grumpy cat'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
  });

  testWidgets('opens a forum as its topics and a topic as a chat', (
    tester,
  ) async {
    json.push(
      _supergroup(98, {'@type': 'chatMemberStatusMember'}, forum: true),
    );
    json.push(
      _chat(
        lastRead: 60,
        unread: 0,
        last: 60,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 98,
          'is_channel': false,
        },
      ),
    );
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Bugs'), findsOneWidget);
    expect(find.text('Message 60'), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Bugs'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    final history = json.sent.lastWhere(
      (r) => r['@type'] == 'getForumTopicHistory',
    );
    expect(history['forum_topic_id'], 5);
    expect(find.text('Repro steps'), findsOneWidget);
    expect(find.text('General'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Fixed');
    await tester.pump();
    await tester.tap(find.byType(MgSendButton));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final sent = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    expect(sent['topic_id'], {
      '@type': 'messageTopicForum',
      'forum_topic_id': 5,
    });
    expect(sent['reply_to'], isNull);

    await tester.tap(find.byTooltip('Back to topics'));
    await tester.pump();
    expect(find.text('Bugs'), findsOneWidget);
    expect(find.text('Repro steps'), findsNothing);
  });

  testWidgets('asks for the topics again when the first load fails', (
    tester,
  ) async {
    json.failTopics = 1;
    json.push(
      _supergroup(98, {'@type': 'chatMemberStatusMember'}, forum: true),
    );
    json.push(
      _chat(
        lastRead: 60,
        unread: 0,
        last: 60,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 98,
          'is_channel': false,
        },
      ),
    );
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    expect(find.text('General'), findsNothing);
    expect(find.byType(LoadSpinner), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    expect(find.text('General'), findsOneWidget);
    expect(find.text('Bugs'), findsOneWidget);
    expect(json.sent.where((r) => r['@type'] == 'getForumTopics').length, 2);
  });

  testWidgets('manages forum topics: closes one and starts a new one', (
    tester,
  ) async {
    json.push(
      _supergroup(98, {
        '@type': 'chatMemberStatusCreator',
        'is_anonymous': false,
        'is_member': true,
        'custom_title': '',
      }, forum: true),
    );
    json.push(
      _chat(
        lastRead: 60,
        unread: 0,
        last: 60,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 98,
          'is_channel': false,
        },
      ),
    );
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    await tester.tap(find.text('Bugs'), buttons: kSecondaryButton);
    await tester.pump();
    expect(find.text('Pin'), findsOneWidget);
    await tester.tap(find.text('Close topic'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final closed = json.sent.lastWhere(
      (r) => r['@type'] == 'toggleForumTopicIsClosed',
    );
    expect(closed['forum_topic_id'], 5);
    expect(closed['is_closed'], isTrue);

    await tester.tap(find.text('New topic'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Ideas');
    await tester.pump();
    // The colour tiles show the name's initial; a default icon replaces
    // the tile.
    expect(find.text('I'), findsNWidgets(6));
    await tester.tap(find.byKey(const ValueKey('topic-icon-5')));
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pumpAndSettle();
    final created = json.sent.lastWhere(
      (r) => r['@type'] == 'createForumTopic',
    );
    expect(created['name'], 'Ideas');
    expect((created['icon']! as Map)['custom_emoji_id'], '5');
    expect(find.text('Topic name'), findsNothing);
  });

  testWidgets('shows a channel\'s sponsored message and counts the click', (
    tester,
  ) async {
    json.push(_supergroup(98, {'@type': 'chatMemberStatusMember'}));
    json.push(
      _chat(
        lastRead: 60,
        unread: 0,
        last: 60,
        type: {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 98,
          'is_channel': true,
        },
      ),
    );
    await pump(tester);
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    expect(find.text('Example Co'), findsOneWidget);
    expect(find.text('Sponsored'), findsOneWidget);
    expect(find.text('Try Example today'), findsOneWidget);
    final viewed = json.sent.lastWhere(
      (r) =>
          r['@type'] == 'viewMessages' &&
          (r['message_ids'] as List).contains(1000),
    );
    expect(viewed['chat_id'], 7);

    await tester.tap(find.text('Learn more'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    final clicked = json.sent.lastWhere(
      (r) => r['@type'] == 'clickChatSponsoredMessage',
    );
    expect(clicked['message_id'], 1000);
  });

  testWidgets('sends a saved GIF from the panel', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('GIFs'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('gif2.mp4'));
    await tester.runAsync(() => Future<void>.delayed(_tick));
    await tester.pump();

    final send = json.sent.lastWhere((r) => r['@type'] == 'sendMessage');
    final content = send['input_message_content']! as Map;
    expect(content['@type'], 'inputMessageAnimation');
    expect((content['animation']! as Map)['animation'], {
      '@type': 'inputFileId',
      'id': 402,
    });
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

  testWidgets('the composer has the cursor on opening and takes typing', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump();
    final field = find.descendant(
      of: find.byType(Composer),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);

    // Focus somewhere else in the chat, then type: the letter lands in the
    // composer and the cursor follows it.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);
    await tester.tapAt(
      tester.getCenter(find.byType(Composer)) - const Offset(0, 200),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH, character: 'h');
    await tester.pump();
    expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
    expect(tester.widget<EditableText>(field).controller.text, 'h');
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
  int chatId = 7,
  int? comments,
  bool unread = false,
  bool post = true,
}) => td.Message(
  id: id,
  senderId: td.MessageSenderUser(userId: senderId),
  chatId: chatId,
  isOutgoing: outgoing,
  isPinned: false,
  isFromOffline: false,
  canBeSaved: true,
  hasTimestampedMedia: false,
  isChannelPost: comments != null && post,
  interactionInfo: comments == null
      ? null
      : td.MessageInteractionInfo(
          viewCount: 0,
          forwardCount: 0,
          replyInfo: td.MessageReplyInfo(
            replyCount: comments,
            recentReplierIds: const [],
            lastReadInboxMessageId: 0,
            lastReadOutboxMessageId: 0,
            lastMessageId: unread ? 1 : 0,
          ),
        ),
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
  bool scheduled = false,
  int replyMarkup = 0,
  bool empty = false,
  Map<String, Object?>? sendAs,
}) => {
  '@type': 'updateNewChat',
  'chat': {
    '@type': 'chat',
    'id': 7,
    'has_scheduled_messages': scheduled,
    'reply_markup_message_id': replyMarkup,
    'message_sender_id': ?sendAs,
    'type': type,
    'title': 'Boris',
    if (!empty)
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

Map<String, Object?> _supergroup(
  int id,
  Map<String, Object?> status, {
  bool forum = false,
}) => {
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
    'is_forum': forum,
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

  /// How many getForumTopics requests still fail before one succeeds.
  var failTopics = 0;
  var history = _history;

  /// A whole chat from Boris with these ids, paged as TDLib does with
  /// from_message_id, offset and limit; takes the place of [history].
  List<int>? chat;

  /// Which message of [chat] each of these answers.
  var repliesTo = <int, int>{};

  /// The pinned messages, newest first.
  var pinned = <int>[];

  /// Ids of the comments under the post, when a test wants a long thread.
  List<int>? commentIds;

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
      'sendMessage' when decoded['chat_id'] == -100 => _message(
        id: 44,
        senderId: 1,
        text: 'My comment',
        chatId: -100,
        outgoing: true,
      ).toJson(),
      'sendMessage' => {
        ..._message(id: 20, senderId: 1, text: 'Sent', outgoing: true).toJson(),
        'scheduling_state': ?(decoded['options'] as Map?)?['scheduling_state'],
      },
      'editMessageText' => _message(
        id: decoded['message_id']! as int,
        senderId: 1,
        text: 'Edited',
        outgoing: true,
      ).toJson(),
      'searchEmojis' => {
        '@type': 'emojiKeywords',
        'emoji_keywords': [
          for (final (emoji, keyword) in [('😀', 'smile'), ('😸', 'smile cat')])
            if (keyword.startsWith(decoded['text']! as String))
              {'@type': 'emojiKeyword', 'emoji': emoji, 'keyword': keyword},
        ],
      },
      'getStickers' => {
        '@type': 'stickers',
        'stickers': [if (decoded['query'] == '🐱') _sticker(1, '🐱')],
      },
      'getRecentStickers' => {
        '@type': 'stickers',
        'stickers': [_sticker(1, '🐱')],
      },
      'getFavoriteStickers' => {'@type': 'stickers', 'stickers': <Object?>[]},
      'getSavedAnimations' => {
        '@type': 'animations',
        'animations': [_animation(1), _animation(2)],
      },
      'searchStickers' => {
        '@type': 'stickers',
        'stickers': [_sticker(4, '😻')],
      },
      'getCustomEmojiStickers' => {
        '@type': 'stickers',
        'stickers': [
          // Int64 ids travel as strings.
          for (final id in decoded['custom_emoji_ids']! as List)
            if ('$id' == '777' || '$id' == '5')
              {
                ..._sticker(7, '🔥'),
                'full_type': {
                  '@type': 'stickerFullTypeCustomEmoji',
                  'custom_emoji_id': int.parse('$id'),
                  'needs_repainting': false,
                },
              },
        ],
      },
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
          when (decoded['filter'] as Map?)?['@type'] ==
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
      'addFileToDownloads' => _stickerFile(decoded['file_id']! as int),
      'searchMessages' => {
        '@type': 'foundMessages',
        'total_count': 1,
        'next_offset': '',
        'messages': [
          _message(id: 31, senderId: 3, text: 'Mine with #news').toJson(),
        ],
      },
      'searchPublicMessagesByTag' => {
        '@type': 'foundMessages',
        'total_count': 0,
        'next_offset': '',
        'messages': <Object?>[],
      },
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
        'can_be_edited':
            decoded['message_id'] == 13 || decoded['message_id'] == 16,
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
      'translateMessageText' => {
        '@type': 'formattedText',
        'text': 'Translated ${decoded['message_id']}',
        'entities': <Object?>[],
      },
      'getLinkPreview' => {
        '@type': 'error',
        'code': 404,
        'message': 'Not Found',
      },
      'getChatScheduledMessages' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          {
            ..._message(
              id: 30,
              senderId: 1,
              text: 'Later one',
              outgoing: true,
            ).toJson(),
            'date': 1900000000,
            'scheduling_state': {
              '@type': 'messageSchedulingStateSendAtDate',
              'send_date': 1900000000,
              'repeat_period': 0,
            },
          },
        ],
      },
      'getCallbackQueryAnswer' => {
        '@type': 'callbackQueryAnswer',
        'text': 'Pong',
        'show_alert': false,
        'url': '',
      },
      // The replies to message 17 of the group itself.
      'getMessageThread' when decoded['message_id'] == 17 => {
        '@type': 'messageThreadInfo',
        'chat_id': 7,
        'message_thread_id': 17,
        'reply_info': {
          '@type': 'messageReplyInfo',
          'reply_count': 3,
          'recent_replier_ids': <Object?>[],
          'last_read_inbox_message_id': 0,
          'last_read_outbox_message_id': 0,
          'last_message_id': 19,
        },
        'unread_message_count': 0,
        'messages': [
          _message(
            id: 17,
            senderId: 2,
            text: 'Question',
            comments: 3,
            post: false,
          ).toJson(),
        ],
      },
      'getMessageThreadHistory' when decoded['message_id'] == 17 => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [_message(id: 19, senderId: 3, text: 'An answer').toJson()],
      },
      'getMessageThread' => {
        '@type': 'messageThreadInfo',
        'chat_id': -100,
        'message_thread_id': 40,
        'reply_info': {
          '@type': 'messageReplyInfo',
          'reply_count': 2,
          'recent_replier_ids': <Object?>[],
          'last_read_inbox_message_id': 0,
          'last_read_outbox_message_id': 0,
          'last_message_id': 42,
        },
        'unread_message_count': 0,
        'messages': [
          _message(id: 40, senderId: 2, text: 'Post', chatId: -100).toJson(),
        ],
      },
      'getMessageThreadHistory' when commentIds != null => () {
        final from = decoded['from_message_id']! as int;
        final page =
            (commentIds!.where((id) => from == 0 || id < from).toList()
                  ..sort((a, b) => b.compareTo(a)))
                .take(decoded['limit']! as int);
        return {
          '@type': 'messages',
          'total_count': commentIds!.length,
          'messages': [
            for (final id in page)
              _message(
                id: id,
                senderId: 3,
                text: 'Comment $id',
                chatId: -100,
              ).toJson(),
          ],
        };
      }(),
      'getMessageThreadHistory' => {
        '@type': 'messages',
        'total_count': 2,
        'messages': [
          _message(
            id: 42,
            senderId: 3,
            text: 'Second comment',
            chatId: -100,
          ).toJson(),
          _message(
            id: 41,
            senderId: 2,
            text: 'First comment',
            chatId: -100,
          ).toJson(),
        ],
      },
      'getPollVoters' => {
        '@type': 'pollVoters',
        'total_count': 1,
        'voters': [
          {
            '@type': 'pollVoter',
            'voter_id': {'@type': 'messageSenderUser', 'user_id': 3},
            'date': 0,
          },
        ],
      },
      'getContacts' => {
        '@type': 'users',
        'total_count': 2,
        'user_ids': [2, 3],
      },
      'getWebAppUrl' => {
        '@type': 'webAppUrl',
        'url': 'https://shop.example/app',
      },
      'getForumTopics' when failTopics-- > 0 => {
        '@type': 'error',
        'code': 400,
        'message': 'Chat not found',
      },
      'getForumTopics' => {
        '@type': 'forumTopics',
        'total_count': 2,
        'topics': [
          _forumTopic(5, 'Bugs', lastId: 51, unread: 2),
          _forumTopic(1, 'General', general: true),
        ],
        'next_offset_date': 0,
        'next_offset_message_id': 0,
        'next_offset_forum_topic_id': 0,
      },
      'getForumTopic' => _forumTopic(5, 'Bugs', lastId: 51, unread: 2),
      'getChatSponsoredMessages' => {
        '@type': 'sponsoredMessages',
        'messages': [
          {
            '@type': 'sponsoredMessage',
            'message_id': 1000,
            'is_recommended': false,
            'can_be_reported': true,
            'content': {
              '@type': 'messageText',
              'text': {
                '@type': 'formattedText',
                'text': 'Try Example today',
                'entities': <Object?>[],
              },
            },
            'sponsor': {
              '@type': 'advertisementSponsor',
              'url': 'https://example.com',
              'info': 'Ads by Example',
            },
            'title': 'Example Co',
            'button_text': 'Learn more',
            'accent_color_id': 0,
            'background_custom_emoji_id': 0,
            'additional_info': '',
          },
        ],
        'messages_between': 0,
      },
      'getForumTopicDefaultIcons' => {
        '@type': 'stickers',
        'stickers': [
          {
            ..._sticker(8, '💡'),
            'full_type': {
              '@type': 'stickerFullTypeCustomEmoji',
              'custom_emoji_id': 5,
              'needs_repainting': false,
            },
          },
        ],
      },
      'createForumTopic' => {
        ...(_forumTopic(9, decoded['name']! as String)['info']!
            as Map<String, Object?>),
      },
      'getForumTopicHistory' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          {
            ..._message(id: 51, senderId: 2, text: 'Repro steps').toJson(),
            'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': 5},
          },
        ],
      },
      'getUser' when decoded['user_id'] == 2 => _user(2, 'Boris'),
      'getMe' => _user(7, 'Me', '79990000000'),
      'getUser' when decoded['user_id'] == 7 => _user(7, 'Me'),
      'getSavedMessagesTags' => {
        '@type': 'savedMessagesTags',
        'tags': [
          {
            '@type': 'savedMessagesTag',
            'tag': {'@type': 'reactionTypeEmoji', 'emoji': '🔥'},
            'label': 'Work',
            'count': 2,
          },
        ],
      },
      'searchSavedMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 2,
        'messages': [
          _message(id: 62, senderId: 7, text: 'Tagged two').toJson(),
          _message(id: 61, senderId: 7, text: 'Tagged one').toJson(),
        ],
        'next_from_message_id': 0,
      },
      'getSavedMessagesTopicHistory' => {
        '@type': 'messages',
        'total_count': 1,
        'messages': [
          {
            ..._message(id: 52, senderId: 2, text: 'Kept for later').toJson(),
            'topic_id': {
              '@type': 'messageTopicSavedMessages',
              'saved_messages_topic_id': 2,
            },
          },
        ],
      },
      'getMapThumbnailFile' => _stickerFile(900),
      'getUser' when decoded['user_id'] == 50 => {
        ..._user(50, 'GIF Search'),
        'usernames': {
          '@type': 'usernames',
          'active_usernames': ['gif'],
          'disabled_usernames': <String>[],
          'editable_username': 'gif',
        },
        'type': {
          '@type': 'userTypeBot',
          'is_inline': true,
          'inline_query_placeholder': 'Search GIFs',
        },
      },
      'getUser' when decoded['user_id'] == 60 => {
        ..._user(60, 'Foursquare'),
        'type': {
          '@type': 'userTypeBot',
          'is_inline': true,
          'inline_query_placeholder': 'Search places',
        },
      },
      'searchPublicChat' when decoded['username'] == 'foursquare' => {
        ...(_chat(
              lastRead: 0,
              unread: 0,
              last: 1,
              type: {'@type': 'chatTypePrivate', 'user_id': 60},
              empty: true,
            )['chat']!
            as Map<String, Object?>),
        'id': 60,
        'title': 'Foursquare',
      },
      'getInlineQueryResults' when decoded['user_location'] != null => {
        '@type': 'inlineQueryResults',
        'inline_query_id': 778,
        'next_offset': '',
        'results': [
          {
            '@type': 'inlineQueryResultVenue',
            'id': 'v1',
            'venue': {
              '@type': 'venue',
              'location': {
                '@type': 'location',
                'latitude': 48.8584,
                'longitude': 2.2945,
                'horizontal_accuracy': 0,
              },
              'title': 'Eiffel Tower',
              'address': 'Champ de Mars, Paris',
              'provider': 'foursquare',
              'id': 'ft',
              'type': 'landmark',
            },
          },
        ],
      },
      'searchPublicChat' when decoded['username'] == 'gif' => {
        ...(_chat(
              lastRead: 0,
              unread: 0,
              last: 1,
              type: {'@type': 'chatTypePrivate', 'user_id': 50},
              empty: true,
            )['chat']!
            as Map<String, Object?>),
        'id': 50,
        'title': 'GIF Search',
      },
      'getInlineQueryResults' => {
        '@type': 'inlineQueryResults',
        'inline_query_id': 777,
        'next_offset': '',
        'results': [
          {
            '@type': 'inlineQueryResultAnimation',
            'id': 'a1',
            'animation': _animation(1),
            'title': 'Grumpy cat',
          },
          {
            '@type': 'inlineQueryResultAnimation',
            'id': 'a2',
            'animation': _animation(2),
            'title': '',
          },
        ],
      },
      'getUser' when decoded['user_id'] == 3 => _user(3, 'Vera', '79990001122'),
      'getChatAvailableMessageSenders' => {
        '@type': 'chatMessageSenders',
        'senders': [
          {
            '@type': 'chatMessageSender',
            'sender': {'@type': 'messageSenderUser', 'user_id': 1},
            'needs_premium': false,
          },
          {
            '@type': 'chatMessageSender',
            'sender': {'@type': 'messageSenderChat', 'chat_id': 8},
            'needs_premium': false,
          },
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
td.Message _inlineKeyboardMessage() => td.Message.fromJson({
  ..._message(id: 16, senderId: 2, text: 'Pick one').toJson(),
  'via_bot_user_id': 50,
  'reply_markup': {
    '@type': 'replyMarkupInlineKeyboard',
    'rows': [
      [
        {
          '@type': 'inlineKeyboardButton',
          'text': 'Search',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStyleDefault'},
          'type': {
            '@type': 'inlineKeyboardButtonTypeSwitchInline',
            'query': 'cats',
            'target_chat': {'@type': 'targetChatCurrent'},
          },
        },
      ],
      [
        {
          '@type': 'inlineKeyboardButton',
          'text': 'Open',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStyleDefault'},
          'type': {
            '@type': 'inlineKeyboardButtonTypeUrl',
            'url': 'https://example.com',
          },
        },
        {
          '@type': 'inlineKeyboardButton',
          'text': 'Ping',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStylePrimary'},
          'type': {
            '@type': 'inlineKeyboardButtonTypeCallback',
            'data': base64.encode([1, 2, 3]),
          },
        },
      ],
    ],
  },
});

td.Message _replyKeyboardMessage() => td.Message.fromJson({
  ..._message(id: 17, senderId: 2, text: 'What now?').toJson(),
  'reply_markup': {
    '@type': 'replyMarkupShowKeyboard',
    'rows': [
      [
        for (final text in ['Menu', 'Help'])
          {
            '@type': 'keyboardButton',
            'text': text,
            'icon_custom_emoji_id': 0,
            'style': {'@type': 'buttonStyleDefault'},
            'type': {'@type': 'keyboardButtonTypeText'},
          },
      ],
      [
        {
          '@type': 'keyboardButton',
          'text': 'Share phone',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStyleDefault'},
          'type': {'@type': 'keyboardButtonTypeRequestPhoneNumber'},
        },
      ],
      [
        {
          '@type': 'keyboardButton',
          'text': 'Where',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStyleDefault'},
          'type': {'@type': 'keyboardButtonTypeRequestLocation'},
        },
        {
          '@type': 'keyboardButton',
          'text': 'Pick chat',
          'icon_custom_emoji_id': 0,
          'style': {'@type': 'buttonStyleDefault'},
          'type': {
            '@type': 'keyboardButtonTypeRequestChat',
            'id': 3,
            'chat_is_channel': false,
          },
        },
      ],
    ],
    'is_persistent': false,
    'resize_keyboard': false,
    'one_time': true,
    'is_personal': false,
    'force_reply': false,
    'input_field_placeholder': '',
  },
});

td.Message _pollMessage({
  required int? chosen,
  bool multiple = false,
  bool public = false,
}) => td.Message.fromJson({
  ..._message(id: 16, senderId: 1, text: '', outgoing: true).toJson(),
  'content': td.MessagePoll(
    poll: _poll(chosen: chosen, multiple: multiple, public: public),
    description: const td.FormattedText(text: '', entities: []),
    canAddOption: false,
  ).toJson(),
});

td.Message _stickerMessage() => td.Message.fromJson({
  ..._message(id: 21, senderId: 3, text: '').toJson(),
  'content': {
    '@type': 'messageSticker',
    'sticker': _sticker(2, '😸'),
    'is_premium': false,
  },
});

td.Message _diceMessage() => td.Message.fromJson({
  ..._message(id: 19, senderId: 3, text: '').toJson(),
  'content': {
    '@type': 'messageDice',
    'initial_state': {
      '@type': 'diceStickersRegular',
      'sticker': _sticker(8, '🎲'),
    },
    'final_state': {
      '@type': 'diceStickersRegular',
      'sticker': _sticker(9, '🎲'),
    },
    'emoji': '🎲',
    'value': 4,
    'success_animation_frame_number': 0,
  },
});

td.Message _slotMachineMessage() => td.Message.fromJson({
  ..._message(id: 20, senderId: 2, text: '').toJson(),
  'content': {
    '@type': 'messageDice',
    'initial_state': null,
    'final_state': {
      '@type': 'diceStickersSlotMachine',
      'background': _sticker(10, '🎰'),
      'lever': _sticker(11, '🎰'),
      'left_reel': _sticker(12, '🎰'),
      'center_reel': _sticker(13, '🎰'),
      'right_reel': _sticker(14, '🎰'),
    },
    'emoji': '🎰',
    'value': 7,
    'success_animation_frame_number': 0,
  },
});

td.Message _checklistMessage() => td.Message.fromJson({
  ..._message(id: 18, senderId: 1, text: '', outgoing: true).toJson(),
  'content': td.MessageChecklist(
    list: td.Checklist(
      title: const td.FormattedText(text: 'Groceries', entities: []),
      tasks: [
        td.ChecklistTask(
          id: 1,
          text: const td.FormattedText(text: 'Milk', entities: []),
          completedBy: const td.MessageSenderUser(userId: 2),
          completionDate: 1760000400,
        ),
        td.ChecklistTask(
          id: 2,
          text: const td.FormattedText(text: 'Bread', entities: []),
          completedBy: null,
          completionDate: 0,
        ),
      ],
      othersCanAddTasks: false,
      canAddTasks: true,
      othersCanMarkTasksAsDone: true,
      canMarkTasksAsDone: true,
    ),
  ).toJson(),
});

td.Poll _poll({
  required int? chosen,
  bool multiple = false,
  bool public = false,
}) => td.Poll(
  id: 555,
  question: const td.FormattedText(text: 'Tea or coffee?', entities: []),
  options: [
    for (final (i, text) in ['Tea', 'Coffee'].indexed)
      td.PollOption(
        id: '$i',
        text: td.FormattedText(text: text, entities: const []),
        voterCount: i == chosen ? 3 : 1,
        votePercentage: i == chosen ? 75 : 25,
        recentVoterIds: const [],
        isChosen: i == chosen,
        isBeingChosen: false,
        additionDate: 0,
      ),
  ],
  totalVoterCount: chosen == null ? 3 : 4,
  recentVoterIds: public
      ? const [td.MessageSenderUser(userId: 3), td.MessageSenderUser(userId: 2)]
      : const [],
  canGetVoters: public,
  canSeeResults: chosen != null,
  isAnonymous: !public,
  allowsMultipleAnswers: multiple,
  allowsRevoting: true,
  membersOnly: false,
  countryCodes: const [],
  optionOrder: const [0, 1],
  type: const td.PollTypeRegular(),
  openPeriod: 0,
  closeDate: 0,
  isClosed: false,
);

Map<String, Object?> _document(
  int id,
  String path, {
  bool downloaded = true,
}) => {
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
          'is_downloading_completed': downloaded,
        },
      },
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
  },
};

/// A photo from Boris as TDLib sends it; [idle] when its file is neither
/// downloaded nor downloading.
Map<String, Object?> _photo(int id, {bool idle = false}) => {
  ..._message(id: id, senderId: 2, text: '').toJson(),
  'content': {
    '@type': 'messagePhoto',
    'photo': {
      '@type': 'photo',
      'sizes': [
        {
          '@type': 'photoSize',
          'type': 'x',
          'photo': idle ? _idleFile(400 + id) : _stickerFile(400 + id),
          'width': 800,
          'height': 600,
          'progressive_sizes': <Object?>[],
        },
      ],
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
  },
};

Map<String, Object?> _voiceMessage(
  int id,
  int senderId, {
  Map<String, Object?>? transcript,
}) => {
  ..._message(id: id, senderId: senderId, text: '').toJson(),
  'content': {
    '@type': 'messageVoiceNote',
    'voice_note': {
      '@type': 'voiceNote',
      'duration': 3,
      'waveform': '',
      'mime_type': 'audio/ogg',
      'speech_recognition_result': ?transcript,
      'voice': _stickerFile(500 + id),
    },
    'caption': {'@type': 'formattedText', 'text': '', 'entities': <Object?>[]},
    'is_listened': false,
  },
};

Map<String, Object?> _forumTopic(
  int id,
  String name, {
  int? lastId,
  int unread = 0,
  bool general = false,
}) => {
  '@type': 'forumTopic',
  'info': {
    '@type': 'forumTopicInfo',
    'chat_id': 7,
    'forum_topic_id': id,
    'name': name,
    'icon': {
      '@type': 'forumTopicIcon',
      'color': 0x6FB9F0,
      'custom_emoji_id': 0,
    },
    'creation_date': 1700000000,
    'creator_id': {'@type': 'messageSenderUser', 'user_id': 2},
    'is_general': general,
    'is_outgoing': false,
    'is_closed': false,
    'is_hidden': false,
    'is_name_implicit': false,
  },
  if (lastId != null)
    'last_message': {
      ..._message(id: lastId, senderId: 2, text: 'Repro steps').toJson(),
      'topic_id': {'@type': 'messageTopicForum', 'forum_topic_id': id},
    },
  'order': '$id',
  'is_pinned': false,
  'unread_count': unread,
  'last_read_inbox_message_id': 0,
  'last_read_outbox_message_id': 0,
  'unread_mention_count': 0,
  'unread_reaction_count': 0,
  'unread_poll_vote_count': 0,
  'notification_settings': {'@type': 'chatNotificationSettings', 'mute_for': 0},
};

Map<String, Object?> _animation(int id) => {
  '@type': 'animation',
  'duration': 3,
  'width': 320,
  'height': 240,
  'file_name': 'gif$id.mp4',
  'mime_type': 'video/mp4',
  'has_stickers': false,
  'animation': _stickerFile(400 + id),
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

/// [_stickerFile] before any download was asked for.
Map<String, Object?> _idleFile(int id) => {
  ..._stickerFile(id),
  'local': {
    '@type': 'localFile',
    'path': '',
    'can_be_downloaded': true,
    'is_downloading_active': false,
    'is_downloading_completed': false,
  },
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

Map<String, Object?> _user(int id, String first, [String phone = '']) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': '',
  'phone_number': phone,
  'status': {'@type': 'userStatusRecently'},
  'type': {'@type': 'userTypeRegular'},
  'is_contact': true,
};
