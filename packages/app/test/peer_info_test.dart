import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/chat/message_tile.dart' show SenderAvatar;
import 'package:mollygram/src/profile/last_seen.dart';
import 'package:mollygram/src/profile/peer_info_host.dart';
import 'package:mollygram/src/profile/peer_info_state.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/shared_media/message_jump.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('status line', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 10, 15, 12);
    int seconds(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
    String describe(td.UserStatus status) =>
        describeUserStatus(l10n, status, now: now);

    test('says online until the status expires', () {
      expect(
        describe(td.UserStatusOnline(expires: seconds(now) + 60)),
        'online',
      );
      expect(
        describe(td.UserStatusOnline(expires: seconds(now) - 600)),
        'last seen 10 minutes ago',
      );
    });

    test('names the time of the last visit', () {
      String offline(DateTime time) =>
          describe(td.UserStatusOffline(wasOnline: seconds(time)));

      expect(
        offline(now.subtract(const Duration(seconds: 20))),
        'last seen just now',
      );
      expect(offline(DateTime(2026, 10, 15, 9, 5)), 'last seen today at 09:05');
      expect(
        offline(DateTime(2026, 10, 14, 23)),
        'last seen yesterday at 23:00',
      );
      expect(offline(DateTime(2026, 3, 2, 8)), 'last seen 3/2/2026');
    });

    test('keeps hidden times vague', () {
      expect(
        describe(const td.UserStatusRecently(byMyPrivacySettings: false)),
        'last seen recently',
      );
      expect(
        describe(const td.UserStatusLastMonth(byMyPrivacySettings: false)),
        'last seen within a month',
      );
    });

    test('formats a birthday with and without the year', () {
      expect(
        describeBirthdate(l10n, const td.Birthdate(day: 3, month: 9, year: 0)),
        'September 3',
      );
      expect(
        describeBirthdate(
          l10n,
          const td.Birthdate(day: 3, month: 9, year: 1990),
        ),
        'September 3, 1990',
      );
    });
  });

  group('panel', () {
    late _FakeTdJson json;
    late TelegramSession session;
    late ProviderContainer container;
    String? clipboard;

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

    /// Lets the panel slide in, TDLib answer and the answers show.
    Future<void> settle(WidgetTester tester) async {
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    /// Like [settle], for pages with a spinner that never settles while
    /// TDLib hasn't answered.
    Future<void> load(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump();
      }
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> pump(WidgetTester tester, {int chatId = 10}) async {
      tester.view
        ..physicalSize = const Size(900, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      clipboard = null;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      container = ProviderContainer(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
        ],
      );
      addTearDown(container.dispose);
      await container.read(telegramSessionProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(
              child: PeerInfoHost(
                chatId: chatId,
                child: const Focus(autofocus: true, child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    void open(int chatId) =>
        container.read(peerInfoPanelsProvider.notifier).open(chatId);

    testWidgets('shows a user and closes on Escape', (tester) async {
      await pump(tester);
      expect(find.text('Alina Petrova'), findsNothing);

      open(10);
      await settle(tester);

      expect(find.text('Alina Petrova'), findsOneWidget);
      expect(find.text('online'), findsOneWidget);
      expect(find.text('@alina'), findsOneWidget);
      expect(find.text('+7 900 123 4567'), findsOneWidget);
      expect(find.text('Designer'), findsOneWidget);
      expect(find.text('Mute'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('Alina Petrova'), findsNothing);
      expect(container.read(peerInfoPanelsProvider), isEmpty);
    });

    testWidgets('squeezes a wide pane and covers a narrow one', (tester) async {
      await pump(tester);
      final pane = find.byKey(const ValueKey('pane'));
      Widget child() => KeyedSubtree(
        key: const ValueKey('pane'),
        child: const Focus(autofocus: true, child: SizedBox.expand()),
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(child: PeerInfoHost(chatId: 10, child: child())),
          ),
        ),
      );
      await settle(tester);
      expect(tester.getSize(pane).width, 900);

      open(10);
      await settle(tester);
      // 900 - 340 leaves 560 for the chat, more than the minimum.
      expect(tester.getSize(pane).width, 900 - PeerInfoHost.width);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(tester.getSize(pane).width, 900);

      tester.view.physicalSize = const Size(800, 800);
      await settle(tester);
      open(10);
      await settle(tester);
      expect(tester.getSize(pane).width, 800);
      expect(find.text('Alina Petrova'), findsOneWidget);
    });

    testWidgets('copies the username', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(find.text('@alina'));
      await tester.pump();
      expect(clipboard, '@alina');
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('mutes the chat', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(find.text('Mute'));
      await tester.pumpAndSettle();
      expect(find.text('Until I turn it back on'), findsOneWidget);
      await tester.tap(find.text('For 8 hours'));
      await settle(tester);
      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'setChatNotificationSettings',
      );
      expect((request['notification_settings']! as Map)['mute_for'], 8 * 3600);
    });

    testWidgets('sets the auto-delete timer', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      expect(find.text('Auto-delete messages'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.text('Auto-delete messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 week'));
      await settle(tester);
      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'setChatMessageAutoDeleteTime',
      );
      expect(request['chat_id'], 10);
      expect(request['message_auto_delete_time'], 7 * 86400);

      // TDLib confirms with an update, and the row shows the new timer.
      json.push({
        '@type': 'updateChatMessageAutoDeleteTime',
        'chat_id': 10,
        'message_auto_delete_time': 7 * 86400,
      });
      await settle(tester);
      expect(find.text('1 week'), findsOneWidget);
      expect(find.text('Off'), findsNothing);
    });

    testWidgets('blocks only after confirmation', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(find.text('Block user'));
      await tester.pumpAndSettle();
      expect(find.text('Block Alina Petrova?'), findsOneWidget);
      expect(json.types, isNot(contains('setMessageSenderBlockList')));

      await tester.tap(find.text('Block').last);
      await settle(tester);
      expect(json.types, contains('setMessageSenderBlockList'));
      expect(find.text('Unblock user'), findsOneWidget);
    });

    testWidgets('reports the chat and offers to share the contact', (
      tester,
    ) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(find.text('Report'));
      await settle(tester);
      final report = json.sent.lastWhere((r) => r['@type'] == 'reportChat');
      expect(report['chat_id'], 10);
      expect(report['message_ids'], isEmpty);
      expect(find.text('Thank you, the report is on its way.'), findsOneWidget);

      await tester.tap(find.text('Share contact'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Forward to chat'), findsOneWidget);
    });

    testWidgets('closes when no pane shows the chat any more', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(container.read(peerInfoPanelsProvider), isEmpty);
    });

    testWidgets('offers no mute or block in Saved Messages', (tester) async {
      json.push({
        '@type': 'updateOption',
        'name': 'my_id',
        'value': {'@type': 'optionValueInteger', 'value': '5'},
      });
      await pump(tester);
      open(10);
      await settle(tester);

      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Mute'), findsNothing);
      expect(find.text('Block user'), findsNothing);
    });

    testWidgets('lists group members and opens one', (tester) async {
      await pump(tester, chatId: 20);
      open(20);
      await settle(tester);

      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('2 members'), findsNWidgets(2));
      expect(find.text('t.me/+abc'), findsOneWidget);
      expect(find.text('owner'), findsOneWidget);

      await tester.tap(find.text('Alina Petrova'));
      await settle(tester);
      expect(find.text('@alina'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Flutter'), findsOneWidget);
    });

    testWidgets('shows shared media with a way back to the info', (
      tester,
    ) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(find.text('Shared media'));
      await load(tester);
      expect(find.text('Alina Petrova'), findsNothing);
      expect(find.text('No photos or videos yet'), findsOneWidget);
      expect(
        json.sent.lastWhere((r) => r['@type'] == 'searchChatMessages'),
        containsPair('chat_id', 10),
      );

      await tester.tap(find.text('Links'));
      await load(tester);
      expect(find.text('Example'), findsOneWidget);

      await tester.tap(find.byTooltip('Show in chat'));
      await tester.pump();
      expect(container.read(messageJumpProvider)[10]?.messageId, 40);
      // The pane's own chat: the panel stays to go on browsing.
      expect(find.text('Example'), findsOneWidget);

      await tester.tap(find.text('GIFs'));
      await load(tester);
      expect(find.text('No GIFs yet'), findsOneWidget);
      expect(
        (json.sent.lastWhere(
              (r) => r['@type'] == 'searchChatMessages',
            )['filter']!
            as Map)['@type'],
        'searchMessagesFilterAnimation',
      );

      // A user's info also lists the groups in common.
      await tester.tap(find.text('Groups'));
      await load(tester);
      expect(
        json.sent.lastWhere((r) => r['@type'] == 'getGroupsInCommon'),
        containsPair('user_id', 5),
      );
      expect(find.text('Flutter'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await settle(tester);
      expect(find.text('Alina Petrova'), findsOneWidget);
      expect(find.byTooltip('Back'), findsNothing);
    });

    testWidgets('opens the profile photos from the big photo', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);

      await tester.tap(
        find.byWidgetPredicate((w) => w is SenderAvatar && w.size == 88),
      );
      await settle(tester);

      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'getUserProfilePhotos',
      );
      expect(request['user_id'], 5);
      // The viewer: the newest photo first, the name on top, a counter.
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Alina Petrova'), findsNWidgets(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.text('1 of 2'), findsNothing);
      expect(find.text('2 of 2'), findsNothing);
      expect(find.text('Alina Petrova'), findsOneWidget);
    });

    testWidgets('opens the info, not the media, the next time', (tester) async {
      await pump(tester);
      open(10);
      await settle(tester);
      await tester.tap(find.text('Shared media'));
      await load(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      open(10);
      await settle(tester);
      expect(find.text('Alina Petrova'), findsOneWidget);
      expect(find.text('Shared media'), findsOneWidget);
    });
  });

  group('message jumps', () {
    test('are taken once, and a repeat counts again', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final jumps = container.read(messageJumpProvider.notifier);

      jumps.request(10, 40);
      final first = container.read(messageJumpProvider)[10];
      jumps.request(10, 40);
      expect(container.read(messageJumpProvider)[10], isNot(first));

      expect(jumps.take(10), 40);
      expect(jumps.take(10), isNull);
      expect(container.read(messageJumpProvider), isEmpty);
    });

    test('expire when the chat does not open in time', () {
      var now = DateTime(2026);
      final container = ProviderContainer(
        overrides: [
          messageJumpProvider.overrideWith(
            () => MessageJumps(clock: () => now),
          ),
        ],
      );
      addTearDown(container.dispose);
      final jumps = container.read(messageJumpProvider.notifier)
        ..request(10, 40);
      now = now.add(MessageJumps.maxWait + const Duration(seconds: 1));
      expect(jumps.take(10), isNull);
      expect(container.read(messageJumpProvider), isEmpty);
    });
  });
}

const _tick = Duration(milliseconds: 20);

Map<String, Object?> _linkMessage(int chatId, int id) => {
  '@type': 'message',
  'id': id,
  'sender_id': {'@type': 'messageSenderUser', 'user_id': 5},
  'chat_id': chatId,
  'date': _now - 60,
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

int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Map<String, Object?> _chat(int id, String title, Map<String, Object?> type) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': title,
  'permissions': {'@type': 'chatPermissions'},
  'notification_settings': {
    '@type': 'chatNotificationSettings',
    'use_default_mute_for': true,
  },
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
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
    'is_downloading_completed': false,
  },
  'remote': {'@type': 'remoteFile', 'id': 'r$id', 'unique_id': 'u$id'},
};

/// A profile photo with one 640 px size and when it was set.
Map<String, Object?> _chatPhoto(int id, int addedDate) => {
  '@type': 'chatPhoto',
  'id': id,
  'added_date': addedDate,
  'sizes': [
    {
      '@type': 'photoSize',
      'type': 'x',
      'photo': _file(id),
      'width': 640,
      'height': 640,
      'progressive_sizes': <int>[],
    },
  ],
};

Map<String, Object?> _user(
  int id,
  String first,
  String last, {
  Map<String, Object?>? status,
  String phone = '',
  String username = '',
}) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': last,
  'phone_number': phone,
  'status': status ?? {'@type': 'userStatusOnline', 'expires': _now + 600},
  'type': {'@type': 'userTypeRegular'},
  if (id == 5)
    'profile_photo': {
      '@type': 'profilePhoto',
      'id': 1,
      'small': _file(901),
      'big': _file(902),
      'has_animation': false,
      'is_personal': false,
    },
  if (username.isNotEmpty)
    'usernames': {
      '@type': 'usernames',
      'active_usernames': [username],
      'editable_username': username,
    },
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  Iterable<Object?> get types => sent.map((r) => r['@type']);

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

  final _chats = {
    10: _chat(10, 'Alina Petrova', {'@type': 'chatTypePrivate', 'user_id': 5}),
    11: _chat(11, 'Boris', {'@type': 'chatTypePrivate', 'user_id': 6}),
    20: _chat(20, 'Flutter', {
      '@type': 'chatTypeBasicGroup',
      'basic_group_id': 3,
    }),
  };

  final _users = {
    5: _user(5, 'Alina', 'Petrova', phone: '79001234567', username: 'alina'),
    6: _user(
      6,
      'Boris',
      '',
      status: {'@type': 'userStatusRecently', 'by_my_privacy_settings': false},
    ),
  };

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
      'getChat' => _chats[decoded['chat_id']]!,
      'getUser' => _users[decoded['user_id']]!,
      'getMe' => _user(7, 'Me', ''),
      'createPrivateChat' => _chats[decoded['user_id'] == 5 ? 10 : 11]!,
      'getUserFullInfo' => {
        '@type': 'userFullInfo',
        'bio': {
          '@type': 'formattedText',
          'text': decoded['user_id'] == 5 ? 'Designer' : '',
          'entities': <Object?>[],
        },
        'gift_settings': {
          '@type': 'giftSettings',
          'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
        },
      },
      'searchChatMessages' => {
        '@type': 'foundChatMessages',
        'total_count': 0,
        'messages': [
          if ((decoded['filter'] as Map?)?['@type'] ==
              'searchMessagesFilterUrl')
            _linkMessage(decoded['chat_id']! as int, 40),
        ],
        'next_from_message_id': 0,
      },
      'reportChat' => {'@type': 'reportChatResultOk'},
      'getGroupsInCommon' => {
        '@type': 'chats',
        'total_count': 1,
        'chat_ids': [20],
      },
      'getUserProfilePhotos' => {
        '@type': 'chatPhotos',
        'total_count': 2,
        'photos': [_chatPhoto(910, 1760000000), _chatPhoto(911, 1750000000)],
      },
      'getPhoneNumberInfo' => {
        '@type': 'phoneNumberInfo',
        'country_calling_code': '7',
        'formatted_phone_number': '900 123 4567',
      },
      'getScopeNotificationSettings' => {
        '@type': 'scopeNotificationSettings',
        'mute_for': 0,
      },
      'getBasicGroup' => {
        '@type': 'basicGroup',
        'id': 3,
        'member_count': 2,
        'status': {'@type': 'chatMemberStatusMember'},
        'is_active': true,
      },
      'getBasicGroupFullInfo' => {
        '@type': 'basicGroupFullInfo',
        'description': '',
        'creator_user_id': 6,
        'invite_link': {
          '@type': 'chatInviteLink',
          'invite_link': 'https://t.me/+abc',
          'is_primary': true,
        },
        'members': [
          for (final (id, status) in [
            (5, 'chatMemberStatusMember'),
            (6, 'chatMemberStatusCreator'),
          ])
            {
              '@type': 'chatMember',
              'member_id': {'@type': 'messageSenderUser', 'user_id': id},
              'status': {'@type': status},
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
