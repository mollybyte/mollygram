import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/contacts/people_sheet.dart';
import 'package:mollygram/src/contacts/presence.dart';
import 'package:mollygram/src/home/workspace.dart';
import 'package:mollygram/src/home/workspace_storage.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  group('formatPresence', () {
    setUpAll(initializeDateFormatting);
    final l10n = lookupAppLocalizations(const Locale('en'));
    final now = DateTime(2026, 10, 15, 12);

    String at(DateTime seen) => formatPresence(
      l10n,
      ContactUser(
        id: 1,
        firstName: 'Anna',
        presence: Presence(PresenceKind.offline, wasOnline: seen),
      ),
      locale: 'en',
      now: now,
    );

    test('says how long ago the user was online', () {
      expect(
        at(now.subtract(const Duration(seconds: 20))),
        'last seen just now',
      );
      expect(
        at(now.subtract(const Duration(minutes: 1))),
        'last seen 1 minute ago',
      );
      expect(
        at(now.subtract(const Duration(minutes: 42))),
        'last seen 42 minutes ago',
      );
      expect(at(DateTime(2026, 10, 15, 9, 5)), 'last seen today at 09:05');
      expect(
        at(DateTime(2026, 10, 14, 23, 50)),
        'last seen yesterday at 23:50',
      );
      expect(at(DateTime(2026, 9, 1, 10)), 'last seen 9/1/2026');
    });

    test('names the other statuses', () {
      String of(PresenceKind kind, {bool bot = false}) => formatPresence(
        l10n,
        ContactUser(
          id: 1,
          firstName: 'A',
          presence: Presence(kind),
          isBot: bot,
        ),
        locale: 'en',
      );
      expect(of(PresenceKind.online), 'online');
      expect(of(PresenceKind.recently), 'last seen recently');
      expect(of(PresenceKind.lastWeek), 'last seen within a week');
      expect(of(PresenceKind.lastMonth), 'last seen within a month');
      expect(of(PresenceKind.unknown), 'last seen a long time ago');
      expect(of(PresenceKind.online, bot: true), 'bot');
    });

    test('speaks Russian', () {
      final ru = lookupAppLocalizations(const Locale('ru'));
      String minutes(int n) => formatPresence(
        ru,
        ContactUser(
          id: 1,
          firstName: 'A',
          presence: Presence(
            PresenceKind.offline,
            wasOnline: now.subtract(Duration(minutes: n)),
          ),
        ),
        locale: 'ru',
        now: now,
      );
      expect(minutes(1), 'был(а) 1 минуту назад');
      expect(minutes(3), 'был(а) 3 минуты назад');
      expect(minutes(5), 'был(а) 5 минут назад');
    });
  });

  group('PeopleSheet', () {
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
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      PeopleSheetMode mode = PeopleSheetMode.newMessage,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramSessionProvider.overrideWith((ref) async => session),
            workspaceStorageProvider.overrideWithValue(
              MemoryWorkspaceStorage(),
            ),
            chatLoaderProvider.overrideWithValue((id) async => true),
          ],
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: _Host(mode: mode),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.text('open'));
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(_Host)));
    }

    testWidgets('lists contacts with their status', (tester) async {
      await pump(tester);

      expect(find.text('New message'), findsOneWidget);
      expect(find.text('Anna Petrova'), findsOneWidget);
      expect(find.text('Boris'), findsOneWidget);
      expect(find.text('online'), findsOneWidget);
      expect(find.text('last seen recently'), findsOneWidget);
    });

    testWidgets('arrows and Enter open the private chat', (tester) async {
      final container = await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);

      expect(json.sent.last['@type'], 'createPrivateChat');
      expect(json.sent.last['user_id'], 2);
      expect(find.text('New message'), findsNothing);
      expect(container.read(workspaceControllerProvider).value.focusedChat, 2);
    });

    testWidgets('typing searches contacts and usernames', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'dur');
      await settle(tester);

      expect(find.text('Anna Petrova'), findsNothing);
      expect(find.text('Global search'), findsOneWidget);
      expect(find.text('Pavel'), findsOneWidget);
      expect(
        json.sent.map((r) => r['@type']),
        containsAll(['searchContacts', 'searchPublicChats']),
      );
    });

    testWidgets('finds people with a chat who are not contacts', (
      tester,
    ) async {
      json.knownChats = [5];
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'gle');
      await settle(tester);

      expect(find.text('Gleb'), findsOneWidget);
    });

    testWidgets('a stale search does not replace a newer one', (tester) async {
      await pump(tester);
      json.holdPublic = true;
      await tester.enterText(find.byType(TextField), 'dur');
      await settle(tester);
      expect(find.text('Pavel'), findsNothing);

      await tester.enterText(find.byType(TextField), 'ann');
      await tester.pump();
      json.releasePublic();
      await settle(tester);

      expect(find.text('Anna Petrova'), findsOneWidget);
      expect(find.text('Pavel'), findsNothing);
    });

    testWidgets('results of the old query go as soon as it changes', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'dur');
      await settle(tester);
      expect(find.text('Pavel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'durx');
      await tester.pump();

      expect(find.text('Pavel'), findsNothing);
    });

    testWidgets('a recent chat with a contact is listed once', (tester) async {
      json.push({
        '@type': 'updateNewChat',
        'chat': {
          ..._chat(1, 'Anna Petrova'),
          'positions': [
            {
              '@type': 'chatPosition',
              'list': {'@type': 'chatListMain'},
              'order': '10',
              'is_pinned': false,
            },
          ],
        },
      });
      json.push({'@type': 'updateUser', 'user': json.users[1]});
      await pump(tester);

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Anna Petrova'), findsOneWidget);
      expect(find.text('Boris'), findsOneWidget);
    });

    testWidgets('loads the contacts again after a failed load', (tester) async {
      json.failContacts = true;
      await pump(tester, mode: PeopleSheetMode.contacts);
      expect(find.text('Anna Petrova'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      json.failContacts = false;
      await tester.tap(find.text('open'));
      await settle(tester);

      expect(find.text('Anna Petrova'), findsOneWidget);
    });

    testWidgets('Esc closes the sheet', (tester) async {
      await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);

      expect(find.text('New message'), findsNothing);
    });

    testWidgets('adds a contact, checking the form first', (tester) async {
      await pump(tester, mode: PeopleSheetMode.contacts);
      await tester.tap(find.text('Add contact'));
      await settle(tester);

      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(find.text('Enter a first name'), findsOneWidget);
      expect(find.text('Enter a phone number'), findsOneWidget);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Nobody');
      await tester.enterText(fields.at(2), '+1 000 000');
      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(find.text('This number is not on Telegram'), findsOneWidget);

      json.importedUserId = 3;
      await tester.enterText(fields.at(0), 'Vera');
      await tester.enterText(fields.at(2), '+7 999 000-11-22');
      await tester.tap(find.text('Add'));
      await settle(tester);

      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'importContacts',
      );
      expect((request['contacts']! as List).single, {
        '@type': 'importedContact',
        'phone_number': '+79990001122',
        'first_name': 'Vera',
        'last_name': '',
      });
      expect(find.text('Contacts'), findsOneWidget);
      expect(find.text('Vera'), findsOneWidget);
    });

    testWidgets('deletes a contact after confirming', (tester) async {
      await pump(tester, mode: PeopleSheetMode.contacts);

      // The first row is selected; its delete button shows.
      await tester.tap(find.byTooltip('Delete contact'));
      await settle(tester);
      expect(find.text('Delete Anna Petrova from contacts?'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await settle(tester);
      expect(json.sent.last['@type'], 'removeContacts');
      expect(find.text('Anna Petrova'), findsNothing);
    });
  });
}

class _Host extends ConsumerWidget {
  const _Host({required this.mode});

  final PeopleSheetMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: ref.watch(telegramSessionProvider).hasValue
        ? TextButton(
            onPressed: () => showPeopleSheet(context, mode: mode),
            child: const Text('open'),
          )
        : const SizedBox(),
  );
}

Map<String, Object?> _user(
  int id,
  String first, {
  String last = '',
  String status = 'userStatusRecently',
  bool contact = true,
}) => {
  '@type': 'user',
  'id': id,
  'first_name': first,
  'last_name': last,
  'phone_number': '',
  'status': {'@type': status},
  'type': {'@type': 'userTypeRegular'},
  'is_contact': contact,
};

Map<String, Object?> _chat(int id, String title) => {
  '@type': 'chat',
  'id': id,
  'type': {'@type': 'chatTypePrivate', 'user_id': id},
  'title': title,
  'permissions': {'@type': 'chatPermissions'},
  'positions': <Object?>[],
  'chat_lists': <Object?>[],
  'notification_settings': {'@type': 'chatNotificationSettings'},
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var importedUserId = 0;
  final users = {
    1: _user(1, 'Anna', last: 'Petrova', status: 'userStatusOnline'),
    2: _user(2, 'Boris'),
    3: _user(3, 'Vera'),
    5: _user(5, 'Gleb', contact: false),
  };
  final _contacts = [1, 2];

  /// Private chats searchChats finds.
  var knownChats = <int>[];
  var failContacts = false;

  /// Keeps searchPublicChats answers until [releasePublic].
  var holdPublic = false;
  final _heldPublic = <String>[];

  void releasePublic() {
    holdPublic = false;
    _queue.addAll(_heldPublic);
    _heldPublic.clear();
  }

  @override
  int createClientId() => 1;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final type = decoded['@type'];
    if (type != 'close') sent.add(decoded);
    final Map<String, Object?> response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getContacts' when failContacts => {
        '@type': 'error',
        'code': 500,
        'message': 'INTERNAL',
      },
      'getContacts' => {
        '@type': 'users',
        'total_count': _contacts.length,
        'user_ids': _contacts,
      },
      'getUser' => users[decoded['user_id']]!,
      'searchChats' => {
        '@type': 'chats',
        'total_count': knownChats.length,
        'chat_ids': knownChats,
      },
      'searchContacts' => {
        '@type': 'users',
        'total_count': 0,
        'user_ids': <int>[],
      },
      'searchPublicChats' => {
        '@type': 'chats',
        'total_count': 1,
        'chat_ids': [if ((decoded['query']! as String).startsWith('dur')) 77],
      },
      'createPrivateChat' => _chat(decoded['user_id']! as int, 'Boris'),
      'importContacts' => {
        '@type': 'importedContacts',
        'user_ids': [importedUserId],
        'importer_count': [0],
      },
      _ => {'@type': 'ok'},
    };
    if (type == 'searchPublicChats') {
      push({'@type': 'updateNewChat', 'chat': _chat(77, 'Pavel')});
    }
    if (type == 'removeContacts') _contacts.remove(1);
    final answer = jsonEncode({
      ...response,
      '@client_id': clientId,
      '@extra': decoded['@extra'],
    });
    if (type == 'searchPublicChats' && holdPublic) {
      _heldPublic.add(answer);
    } else {
      _queue.add(answer);
    }
    if (type == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
