import 'dart:collection';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/home/workspace.dart';
import 'package:mollygram/src/profile/invite_links_sheet.dart';
import 'package:mollygram/src/profile/member_sheets.dart';
import 'package:mollygram/src/profile/new_chat_sheet.dart';
import 'package:mollygram/src/profile/peer_info_host.dart';
import 'package:mollygram/src/profile/peer_info_state.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));

  group('rights and links', () {
    test('a new administrator gets the usual rights', () {
      final on = rightsOf(
        adminRights({AdminRight.changeInfo, AdminRight.deleteMessages}),
      );
      expect(on, {AdminRight.changeInfo, AdminRight.deleteMessages});
      expect(AdminRight.of(channel: true), contains(AdminRight.postMessages));
      expect(
        AdminRight.of(channel: false),
        isNot(contains(AdminRight.postMessages)),
      );
    });

    test('restrictions keep media together', () {
      final p = memberPermissions({MemberPermission.sendMedia});
      expect(p.canSendPhotos && p.canSendVoiceNotes, isTrue);
      expect(p.canSendBasicMessages, isFalse);
      expect(permissionsOf(p), {MemberPermission.sendMedia});
    });

    test('a link says who joined and when it ends', () {
      final now = DateTime(2026, 10, 15);
      td.ChatInviteLink link({int limit = 0, int expires = 0}) =>
          td.ChatInviteLink.fromJson({
            '@type': 'chatInviteLink',
            'invite_link': 'https://t.me/+x',
            'member_count': 3,
            'member_limit': limit,
            'expiration_date': expires,
          });
      int at(DateTime time) => time.millisecondsSinceEpoch ~/ 1000;
      expect(describeLink(l10n, link(), now), '3 joined');
      expect(
        describeLink(
          l10n,
          link(limit: 10, expires: at(DateTime(2026, 10, 20))),
          now,
        ),
        '3 of 10 joined · expires Oct 20',
      );
      expect(
        describeLink(l10n, link(expires: at(DateTime(2026, 10, 1))), now),
        '3 joined · expired',
      );
    });

    test('the palette can start a group and a channel', () {
      final other = lookupAppLocalizations(const Locale('ru'));
      final commands = newChatCommands(() => throw StateError(''), l10n, other);
      expect(
        [for (final c in commands) c.id],
        ['app.newGroup', 'app.newChannel'],
      );
      expect(commands.first.keywords, ['Новая группа']);
    });
  });

  group('managing a group', () {
    late _FakeTdJson json;
    late TelegramSession session;
    late ProviderContainer container;

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

    /// Lets TDLib answer while animations run, then lets them finish. A
    /// busy button spins until its request is answered, so time moves
    /// with the answers.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    Future<void> pump(WidgetTester tester, {Widget? home}) async {
      tester.view
        ..physicalSize = const Size(1000, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
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
              child:
                  home ??
                  const PeerInfoHost(
                    chatId: 30,
                    child: Focus(autofocus: true, child: SizedBox.expand()),
                  ),
            ),
          ),
        ),
      );
      await settle(tester);
      if (home == null) {
        container.read(peerInfoPanelsProvider.notifier).open(30);
        await settle(tester);
      }
    }

    List<Map<String, Object?>> sent(String type) => [
      for (final r in json.sent)
        if (r['@type'] == type) r,
    ];

    testWidgets('an owner sees the tools, administrators first', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Invite links'), findsOneWidget);
      expect(find.text('Delete group'), findsOneWidget);
      final names = [
        for (final text in tester.widgetList<Text>(find.byType(Text)))
          if (const ['Me', 'Vera', 'Boris'].contains(text.data)) text.data,
      ];
      expect(names, ['Me', 'Vera', 'Boris']);
    });

    testWidgets('promotes a member from the context menu', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Boris'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      // Basic groups have no restrictions.
      expect(find.text('Restrict'), findsNothing);
      expect(find.text('Remove from group'), findsOneWidget);

      await tester.tap(find.text('Make admin'));
      await tester.pumpAndSettle();
      expect(find.text('What Boris can do'), findsOneWidget);
      await tester.tap(find.text('Add new admins'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);

      final request = sent('setChatMemberStatus').single;
      expect(request['member_id'], {
        '@type': 'messageSenderUser',
        'user_id': 6,
      });
      final status = request['status']! as Map;
      expect(status['@type'], 'chatMemberStatusAdministrator');
      final rights = status['rights']! as Map;
      expect(rights['can_promote_members'], isTrue);
      expect(rights['can_change_info'], isTrue);
      expect(rights['is_anonymous'], isFalse);
    });

    testWidgets('removes a member after asking', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Boris'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from group'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Boris?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(sent('banChatMember').single['chat_id'], 30);
    });

    testWidgets('edits the title and description', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit group'), findsOneWidget);

      final fields = find.descendant(
        of: find.byType(MgUnderlineField),
        matching: find.byType(EditableText),
      );
      await tester.enterText(fields.first, 'Flutter team');
      await tester.enterText(fields.last, 'Talk');
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(sent('setChatTitle').single['title'], 'Flutter team');
      expect(sent('setChatDescription').single['description'], 'Talk');
      expect(sent('setChatPhoto'), isEmpty);
      expect(find.text('Edit group'), findsNothing);
    });

    testWidgets('copies, lists and creates invite links', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Invite links'));
      await settle(tester);
      expect(find.text('t.me/+primary'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('2 joined'), findsOneWidget);

      await tester.tap(find.text('Create a new link'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 week'));
      await tester.tap(find.text('Approve new members'));
      await tester.pump();
      await tester.tap(find.text('Create'));
      await settle(tester);

      final request = sent('createChatInviteLink').single;
      expect(request['creates_join_request'], isTrue);
      expect(request['expiration_date'], greaterThan(0));
      expect(find.text('Create a new link'), findsOneWidget);
    });

    testWidgets('revokes the primary link by replacing it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Invite links'));
      await settle(tester);
      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await settle(tester);
      expect(sent('replacePrimaryChatInviteLink'), hasLength(1));
    });

    testWidgets('leaves the group after asking', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Leave group'));
      await tester.tap(find.text('Leave group'));
      await tester.pumpAndSettle();
      expect(find.text('Leave this group?'), findsOneWidget);
      await tester.tap(find.text('Leave'));
      await settle(tester);
      expect(sent('leaveChat').single['chat_id'], 30);
      expect(container.read(peerInfoPanelsProvider), isEmpty);
    });

    testWidgets('creates a group with picked contacts and opens it', (
      tester,
    ) async {
      await pump(
        tester,
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  newChatCommands(() => context, l10n, l10n).first.run(),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await settle(tester);
      expect(find.text('New group'), findsOneWidget);
      await tester.tap(find.text('Vera'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create'));
      await tester.pump();
      expect(find.text('Enter a name'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Trip');
      await tester.tap(find.text('Create'));
      await settle(tester);

      final request = sent('createNewBasicGroupChat').single;
      expect(request['user_ids'], [5]);
      expect(request['title'], 'Trip');
      expect(container.read(workspaceControllerProvider).value.focusedChat, 40);
      expect(find.text('New group'), findsNothing);
    });
  });
}

const _tick = Duration(milliseconds: 20);

Map<String, Object?> _chat(int id, String title, Map<String, Object?> type) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': title,
  'permissions': {'@type': 'chatPermissions'},
  'can_be_deleted_for_all_users': true,
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

Map<String, Object?> _user(int id, String name, {bool online = false}) => {
  '@type': 'user',
  'id': id,
  'first_name': name,
  'last_name': '',
  'phone_number': '',
  'is_contact': true,
  'status': online
      ? {'@type': 'userStatusOnline', 'expires': 1 << 40}
      : {'@type': 'userStatusRecently', 'by_my_privacy_settings': false},
  'type': {'@type': 'userTypeRegular'},
};

Map<String, Object?> _member(int id, Map<String, Object?> status) => {
  '@type': 'chatMember',
  'member_id': {'@type': 'messageSenderUser', 'user_id': id},
  'inviter_user_id': 7,
  'status': status,
};

Map<String, Object?> _link(String code, {String name = '', int joined = 0}) => {
  '@type': 'chatInviteLink',
  'invite_link': 'https://t.me/+$code',
  'name': name,
  'creator_user_id': 7,
  'member_count': joined,
  'is_primary': code == 'primary',
};

/// A basic group, 30, owned by the user (7) with Vera (5), an
/// administrator, and Boris (6).
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  final _users = {
    5: _user(5, 'Vera'),
    6: _user(6, 'Boris'),
    7: _user(7, 'Me', online: true),
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
    const creator = {'@type': 'chatMemberStatusCreator', 'is_member': true};
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getChat' => _chat(30, 'Flutter', {
        '@type': 'chatTypeBasicGroup',
        'basic_group_id': 3,
      }),
      'getUser' => _users[decoded['user_id']]!,
      'getMe' => _users[7]!,
      'getContacts' => {
        '@type': 'users',
        'total_count': 2,
        'user_ids': [5, 6],
      },
      'getScopeNotificationSettings' => {
        '@type': 'scopeNotificationSettings',
        'mute_for': 0,
      },
      'getBasicGroup' => {
        '@type': 'basicGroup',
        'id': 3,
        'member_count': 3,
        'status': creator,
        'is_active': true,
      },
      'getBasicGroupFullInfo' => {
        '@type': 'basicGroupFullInfo',
        'description': '',
        'creator_user_id': 7,
        'members': [
          _member(6, {'@type': 'chatMemberStatusMember'}),
          _member(5, {
            '@type': 'chatMemberStatusAdministrator',
            'can_be_edited': true,
            'rights': {'@type': 'chatAdministratorRights'},
          }),
          _member(7, creator),
        ],
        'bot_commands': <Object?>[],
      },
      'getChatInviteLinks' => {
        '@type': 'chatInviteLinks',
        'total_count': 2,
        'invite_links': [
          _link('f', name: 'Friends', joined: 2),
          _link('primary'),
        ],
      },
      'createChatInviteLink' => _link('new'),
      'replacePrimaryChatInviteLink' => _link('primary'),
      'createNewBasicGroupChat' => {
        '@type': 'createdBasicGroupChat',
        'chat_id': 40,
        'failed_to_add_members': {
          '@type': 'failedToAddMembers',
          'failed_to_add_members': <Object?>[],
        },
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
