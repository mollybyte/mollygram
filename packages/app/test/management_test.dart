import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/profile/admin_log_sheet.dart';
import 'package:mollygram/src/profile/peer_info_host.dart';
import 'package:mollygram/src/profile/peer_info_state.dart';
import 'package:mollygram/src/profile/permissions_sheet.dart';
import 'package:mollygram/src/profile/removed_users_sheet.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final l10n = lookupAppLocalizations(const Locale('en'));

  group('descriptions', () {
    test('slow mode in short units', () {
      expect(describeSlowMode(l10n, 0), 'Off');
      expect(describeSlowMode(l10n, 30), '30s');
      expect(describeSlowMode(l10n, 300), '5m');
      expect(describeSlowMode(l10n, 3600), '1h');
    });

    test('a removed user says what and until when', () {
      final now = DateTime(2026, 10, 15);
      final until = DateTime(2026, 10, 20).millisecondsSinceEpoch ~/ 1000;
      expect(
        describeRemoved(
          l10n,
          RemovedMember(
            userId: 1,
            name: 'Zed',
            isBanned: true,
            until: DateTime.fromMillisecondsSinceEpoch(until * 1000),
          ),
          now,
        ),
        'Banned until Oct 20',
      );
      expect(
        describeRemoved(
          l10n,
          RemovedMember(
            userId: 1,
            name: 'Zed',
            isBanned: false,
            permissions: td.ChatPermissions.fromJson({
              '@type': 'chatPermissions',
              'can_send_basic_messages': true,
              'can_send_polls': true,
              'can_send_other_messages': true,
              'can_add_link_previews': true,
              'can_invite_users': true,
              'can_pin_messages': true,
              'can_change_info': true,
            }),
          ),
          now,
        ),
        "Can't send media",
      );
    });

    test('an action reads as one line', () {
      AdminLogEntry entry(td.ChatEventAction action, {String? subject}) =>
          AdminLogEntry(
            id: 1,
            date: DateTime(2026),
            actorName: 'Me',
            action: action,
            subjectName: subject,
          );
      expect(
        describeAction(
          l10n,
          entry(
            const td.ChatEventTitleChanged(oldTitle: 'A', newTitle: 'Team'),
          ),
        ),
        'renamed the chat to Team',
      );
      expect(
        describeAction(
          l10n,
          entry(
            const td.ChatEventMemberRestricted(
              memberId: td.MessageSenderUser(userId: 2),
              oldStatus: td.ChatMemberStatusMember(memberUntilDate: 0),
              newStatus: td.ChatMemberStatusBanned(bannedUntilDate: 0),
            ),
            subject: 'Zed',
          ),
        ),
        'banned Zed',
      );
      expect(
        describeAction(
          l10n,
          entry(
            const td.ChatEventSlowModeDelayChanged(
              oldSlowModeDelay: 0,
              newSlowModeDelay: 60,
            ),
          ),
        ),
        'set slow mode to 1m',
      );
    });
  });

  group('managing a supergroup', () {
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

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1000, 1100)
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
            home: const Material(
              child: PeerInfoHost(
                chatId: 50,
                child: Focus(autofocus: true, child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      container.read(peerInfoPanelsProvider.notifier).open(50);
      await settle(tester);
    }

    List<Map<String, Object?>> sent(String type) => [
      for (final r in json.sent)
        if (r['@type'] == type) r,
    ];

    Future<void> scrollTo(WidgetTester tester, String text) async {
      await tester.scrollUntilVisible(
        find.text(text),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the owner sees the management rows', (tester) async {
      await pump(tester);
      for (final row in [
        'Group type',
        'Permissions',
        'Reactions',
        'Invite links',
        'Join requests',
        'Removed users',
        'Recent actions',
        'Show history to new members',
        'Topics',
        'Add members',
      ]) {
        await scrollTo(tester, row);
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('Private'), findsOneWidget);
      // One banned and one restricted user.
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('sets permissions and slow mode', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Permissions');
      await tester.tap(find.text('Permissions'));
      await settle(tester);
      await tester.tap(find.text('Send polls'));
      await tester.tap(find.text('30s'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await settle(tester);

      final permissions =
          sent('setChatPermissions').single['permissions']! as Map;
      expect(permissions['can_send_polls'], isTrue);
      expect(permissions['can_send_basic_messages'], isTrue);
      expect(sent('setChatSlowModeDelay').single['slow_mode_delay'], 30);
    });

    testWidgets('lets a banned user back in', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Removed users');
      await tester.tap(find.text('Removed users'));
      await settle(tester);
      expect(find.text('Zed'), findsOneWidget);
      expect(find.text('Banned'), findsOneWidget);
      expect(find.text('Yan'), findsOneWidget);
      await tester.tap(find.text('Unban'));
      await settle(tester);
      final status = sent('setChatMemberStatus').single;
      expect(status['member_id'], {'@type': 'messageSenderUser', 'user_id': 8});
      expect((status['status']! as Map)['@type'], 'chatMemberStatusLeft');
      expect(find.text('Zed'), findsNothing);
    });

    testWidgets('approves a join request', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Join requests');
      await tester.tap(find.text('Join requests'));
      await settle(tester);
      expect(find.text('Nina'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await settle(tester);
      final request = sent('processChatJoinRequest').single;
      expect(request['user_id'], 10);
      expect(request['approve'], isTrue);
      expect(find.text('Nobody is waiting to join.'), findsOneWidget);
    });

    testWidgets('shows the recent actions by day', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Recent actions');
      await tester.tap(find.text('Recent actions'));
      await settle(tester);
      expect(find.textContaining('renamed the chat to Team'), findsOneWidget);
      expect(find.textContaining('banned Zed'), findsOneWidget);
      expect(sent('getChatEventLog').single['chat_id'], 50);
    });

    testWidgets('makes the group public after checking the link', (
      tester,
    ) async {
      await pump(tester);
      await scrollTo(tester, 'Group type');
      await tester.tap(find.text('Group type'));
      await settle(tester);
      await tester.tap(find.text('Public'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'flutterteam');
      await settle(tester);
      expect(sent('checkChatUsername').single['username'], 'flutterteam');
      expect(find.text('This link is available.'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final request = sent('setSupergroupUsername').single;
      expect(request['supergroup_id'], 9);
      expect(request['username'], 'flutterteam');
    });

    testWidgets('adds a contact to the group', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Add members');
      await tester.tap(find.text('Add members'));
      await settle(tester);
      // The sheet's row, not the one in the members list behind it.
      await tester.tap(find.text('Vera').last);
      await tester.pump();
      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(sent('addChatMembers').single['user_ids'], [5]);
    });

    testWidgets('hides the history with a switch', (tester) async {
      await pump(tester);
      await scrollTo(tester, 'Show history to new members');
      await tester.tap(find.text('Show history to new members'));
      await settle(tester);
      final request = sent('toggleSupergroupIsAllHistoryAvailable').single;
      expect(request['is_all_history_available'], isFalse);
    });
  });
}

const _tick = Duration(milliseconds: 20);

Map<String, Object?> _user(int id, String name) => {
  '@type': 'user',
  'id': id,
  'first_name': name,
  'last_name': '',
  'phone_number': '',
  'is_contact': true,
  'status': {'@type': 'userStatusRecently', 'by_my_privacy_settings': false},
  'type': {'@type': 'userTypeRegular'},
};

Map<String, Object?> _member(int id, Map<String, Object?> status) => {
  '@type': 'chatMember',
  'member_id': {'@type': 'messageSenderUser', 'user_id': id},
  'inviter_user_id': 7,
  'status': status,
};

const _allowed = {
  '@type': 'chatPermissions',
  'can_send_basic_messages': true,
  'can_send_audios': true,
  'can_send_documents': true,
  'can_send_photos': true,
  'can_send_videos': true,
  'can_send_video_notes': true,
  'can_send_voice_notes': true,
  'can_send_other_messages': true,
  'can_add_link_previews': true,
  'can_invite_users': true,
  'can_pin_messages': true,
  'can_change_info': true,
};

/// A private supergroup, 50 (supergroup 9), owned by the user (7), with
/// Zed (8) banned, Yan (11) restricted and Nina (10) asking to join.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  final _users = {
    5: _user(5, 'Vera'),
    7: _user(7, 'Me'),
    8: _user(8, 'Zed'),
    10: _user(10, 'Nina'),
    11: _user(11, 'Yan'),
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
      'getChat' => {
        '@type': 'chat',
        'id': 50,
        'type': {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': 9,
          'is_channel': false,
        },
        'title': 'Flutter',
        'permissions': _allowed,
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
      },
      'getUser' => _users[decoded['user_id']]!,
      'getMe' => _users[7]!,
      'getContacts' => {
        '@type': 'users',
        'total_count': 1,
        'user_ids': [5],
      },
      'getScopeNotificationSettings' => {
        '@type': 'scopeNotificationSettings',
        'mute_for': 0,
      },
      'getSupergroup' => {
        '@type': 'supergroup',
        'id': 9,
        'member_count': 2,
        'status': creator,
      },
      'getSupergroupFullInfo' => {
        '@type': 'supergroupFullInfo',
        'description': '',
        'member_count': 2,
        'banned_count': 1,
        'restricted_count': 1,
        'is_all_history_available': true,
        'can_get_members': true,
        'bot_commands': <Object?>[],
      },
      'getSupergroupMembers' => switch ((decoded['filter']! as Map)['@type']) {
        'supergroupMembersFilterBanned' => _members([
          _member(8, {
            '@type': 'chatMemberStatusBanned',
            'banned_until_date': 0,
          }),
        ]),
        'supergroupMembersFilterRestricted' => _members([
          _member(11, {
            '@type': 'chatMemberStatusRestricted',
            'is_member': true,
            'restricted_until_date': 0,
            'permissions': {'@type': 'chatPermissions'},
          }),
        ]),
        'supergroupMembersFilterAdministrators' => _members([
          _member(7, creator),
        ]),
        _ => _members([
          _member(7, creator),
          _member(5, {
            '@type': 'chatMemberStatusMember',
            'member_until_date': 0,
          }),
        ]),
      },
      'getChatAdministrators' => {
        '@type': 'chatAdministrators',
        'administrators': [
          {
            '@type': 'chatAdministrator',
            'user_id': 7,
            'custom_title': '',
            'is_owner': true,
          },
        ],
      },
      'getChatJoinRequests' => {
        '@type': 'chatJoinRequests',
        'total_count': 1,
        'requests': [
          {
            '@type': 'chatJoinRequest',
            'user_id': 10,
            'date': 1760000000,
            'bio': 'Dart fan',
          },
        ],
      },
      'getChatEventLog' => {
        '@type': 'chatEvents',
        'events': [
          {
            '@type': 'chatEvent',
            'id': 2,
            'date': 1760000000,
            'member_id': {'@type': 'messageSenderUser', 'user_id': 7},
            'action': {
              '@type': 'chatEventTitleChanged',
              'old_title': 'Flutter',
              'new_title': 'Team',
            },
          },
          {
            '@type': 'chatEvent',
            'id': 1,
            'date': 1759900000,
            'member_id': {'@type': 'messageSenderUser', 'user_id': 7},
            'action': {
              '@type': 'chatEventMemberRestricted',
              'member_id': {'@type': 'messageSenderUser', 'user_id': 8},
              'old_status': {
                '@type': 'chatMemberStatusMember',
                'member_until_date': 0,
              },
              'new_status': {
                '@type': 'chatMemberStatusBanned',
                'banned_until_date': 0,
              },
            },
          },
        ],
      },
      'checkChatUsername' => {'@type': 'checkChatUsernameResultOk'},
      'addChatMembers' => {
        '@type': 'failedToAddMembers',
        'failed_to_add_members': <Object?>[],
      },
      'getChatInviteLinks' => {
        '@type': 'chatInviteLinks',
        'total_count': 0,
        'invite_links': <Object?>[],
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

Map<String, Object?> _members(List<Map<String, Object?>> list) => {
  '@type': 'chatMembers',
  'total_count': list.length,
  'members': list,
};
