import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/privacy/privacy_page.dart';
import 'package:mollygram/src/settings/settings_window.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('a setting with exceptions reads as TelegramSwift shows it', () {
    expect(
      privacySummary(
        l10n,
        const PrivacyChoice(
          audience: PrivacyAudience.contacts,
          alwaysUsers: [5],
          neverUsers: [6, 7],
        ),
      ),
      'My contacts (−2, +1)',
    );
    expect(
      privacySummary(
        l10n,
        const PrivacyChoice(
          audience: PrivacyAudience.everybody,
          alwaysUsers: [5],
        ),
      ),
      'Everybody',
    );
  });

  group('privacy and security', () {
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
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(_tick));
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1200, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramSessionProvider.overrideWith((ref) async => session),
            privacySettingsStorageProvider.overrideWithValue(
              MemoryPrivacySettingsStorage(),
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
      await settle(tester);
    }

    Map<String, Object?> lastSet() =>
        json.sent.lastWhere((r) => r['@type'] == 'setUserPrivacySettingRules');

    List<String> ruleTypes(Map<String, Object?> request) => [
      for (final rule in ((request['rules']! as Map)['rules']! as List))
        (rule as Map)['@type']! as String,
    ];

    testWidgets('lists every setting with who it is open to', (tester) async {
      await pump(tester);
      expect(find.text('Blocked users'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // blocked
      expect(find.text('Last seen and online'), findsOneWidget);
      expect(find.text('My contacts (−1)'), findsOneWidget);
      expect(find.text('Nobody'), findsOneWidget); // phone number
      expect(find.text('Everybody'), findsNWidgets(7));
    });

    testWidgets('changes the audience at once', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Last seen and online'));
      await settle(tester);
      expect(find.text('Who can see my last seen time?'), findsOneWidget);
      expect(find.text('Always allow'), findsOneWidget);
      expect(find.text('Never allow'), findsOneWidget);
      expect(find.text('1 person'), findsOneWidget);

      await tester.tap(find.text('Nobody'));
      await settle(tester);
      final request = lastSet();
      expect(request['setting'], {'@type': 'userPrivacySettingShowStatus'});
      // Nobody makes "never allow" moot, so Ivan isn't sent.
      expect(ruleTypes(request), ['userPrivacySettingRuleRestrictAll']);
      expect(find.text('Never allow'), findsNothing);
    });

    testWidgets('a failed save goes back and says so', (tester) async {
      json.failing.add('setUserPrivacySettingRules');
      await pump(tester);
      await tester.tap(find.text('Calls'));
      await settle(tester);
      await tester.tap(find.text('My contacts'));
      await settle(tester);
      expect(find.text("Couldn't save the change."), findsOneWidget);
      // Everybody is ticked again.
      final ticks = tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(
            const ValueKey((PrivacyRule.calls, PrivacyAudience.everybody)),
          ),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(ticks.single.opacity, 1);
    });

    testWidgets('a hidden number asks who can find it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Phone number'));
      await settle(tester);
      expect(find.text('Who can find me by my number?'), findsOneWidget);
      await tester.tap(find.text('Everybody').first);
      await settle(tester);
      expect(find.text('Who can find me by my number?'), findsNothing);
    });

    testWidgets('adds and removes exceptions', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Last seen and online'));
      await settle(tester);
      await tester.tap(find.text('Always allow'));
      await settle(tester);
      await tester.tap(find.text('Add people'));
      await settle(tester);
      // Ivan is in "never allow"; picking him moves him over.
      await tester.tap(find.text('Ivan'));
      await tester.pump();
      await tester.tap(find.text('Add'));
      await settle(tester);
      var request = lastSet();
      expect(ruleTypes(request).first, 'userPrivacySettingRuleAllowUsers');
      expect((request['rules']! as Map)['rules'], [
        {
          '@type': 'userPrivacySettingRuleAllowUsers',
          'user_ids': [6],
        },
        {'@type': 'userPrivacySettingRuleAllowContacts'},
        {'@type': 'userPrivacySettingRuleRestrictAll'},
      ]);
      expect(find.text('Ivan'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove'));
      await settle(tester);
      request = lastSet();
      expect(ruleTypes(request), [
        'userPrivacySettingRuleAllowContacts',
        'userPrivacySettingRuleRestrictAll',
      ]);
      expect(find.text('Ivan'), findsNothing);
    });

    List<(Object?, Object?)> pages() => [
      for (final r in json.sent)
        if (r['@type'] == 'getBlockedMessageSenders' && r['limit'] != 1)
          (r['offset'], r['limit']),
    ];

    testWidgets('pages through a long blocked list', (tester) async {
      json.blockMany(118); // 120 in all
      await pump(tester);
      // Tall enough for every row, so no scrolling is needed.
      tester.view.physicalSize = const Size(1200, 8000);
      await tester.tap(find.text('Blocked users'));
      await settle(tester);
      await settle(tester);
      expect(pages(), [(0, 50)]);
      expect(find.text('P1047'), findsOneWidget);
      expect(find.text('P1048'), findsNothing);

      await tester.tap(find.text('Show more'));
      await settle(tester);
      await settle(tester);
      expect(pages().last, (50, 50));
      expect(find.text('P1097'), findsOneWidget);

      // A change reloads all 100 shown, in one page of TDLib's most.
      json.sent.clear();
      await tester.tap(find.text('Unblock').first);
      await settle(tester);
      await settle(tester);
      expect(pages(), [(0, 100)]);
      expect(find.text('Spam bot'), findsNothing);
      // One fewer blocked: the next one moves up into the 100.
      expect(find.text('P1098'), findsOneWidget);
      expect(find.text('P1099'), findsNothing);
      await tester.tap(find.text('Show more'));
      await settle(tester);
      await settle(tester);
      expect(find.text('P1117'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('an unblock while a page loads leaves no duplicates', (
      tester,
    ) async {
      json.blockMany(60);
      await pump(tester);
      tester.view.physicalSize = const Size(1200, 8000);
      await tester.tap(find.text('Blocked users'));
      await settle(tester);
      await tester.tap(find.text('Show more'));
      await tester.tap(find.text('Unblock').first);
      await settle(tester);
      await settle(tester);
      // A duplicate row would have failed on its key already.
      expect(find.text('Spam bot'), findsNothing);
      expect(find.text('P1059'), findsOneWidget);
      expect(find.text('P1000'), findsOneWidget);
    });

    testWidgets('a failed unblock puts the row back', (tester) async {
      json.failing.add('setMessageSenderBlockList');
      await pump(tester);
      await tester.tap(find.text('Blocked users'));
      await settle(tester);
      await tester.tap(find.text('Unblock').first);
      await settle(tester);
      expect(find.text('Spam bot'), findsOneWidget);
      expect(find.text("Couldn't save the change."), findsOneWidget);
    });

    testWidgets('a change made elsewhere while picking is kept', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Last seen and online'));
      await settle(tester);
      await tester.tap(find.text('Always allow'));
      await settle(tester);
      await tester.tap(find.text('Add people'));
      await settle(tester);

      // Vera is always allowed from another device meanwhile.
      json.push({
        '@type': 'updateUserPrivacySettingRules',
        'setting': {'@type': 'userPrivacySettingShowStatus'},
        'rules': {
          '@type': 'userPrivacySettingRules',
          'rules': [
            {
              '@type': 'userPrivacySettingRuleAllowUsers',
              'user_ids': [5],
            },
            {'@type': 'userPrivacySettingRuleAllowContacts'},
          ],
        },
      });
      await tester.runAsync(() => session.security.blocked(limit: 1));
      await settle(tester);

      await tester.tap(find.text('Ivan').last);
      await tester.pump();
      await tester.tap(find.text('Add'));
      await settle(tester);
      expect((lastSet()['rules']! as Map)['rules'], [
        {
          '@type': 'userPrivacySettingRuleAllowUsers',
          'user_ids': [5, 6],
        },
        {'@type': 'userPrivacySettingRuleAllowContacts'},
        {'@type': 'userPrivacySettingRuleRestrictAll'},
      ]);
    });

    testWidgets('blocks and unblocks', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Blocked users'));
      await settle(tester);
      expect(find.text('Spam bot'), findsOneWidget);
      expect(find.text('Ivan'), findsOneWidget);

      await tester.tap(find.text('Unblock').first);
      await settle(tester);
      final unblock = json.sent.lastWhere(
        (r) => r['@type'] == 'setMessageSenderBlockList',
      );
      expect(unblock['block_list'], isNull);
      expect(find.text('Spam bot'), findsNothing);

      await tester.tap(find.text('Block someone'));
      await settle(tester);
      // Ivan is blocked already, so the picker leaves him out.
      expect(find.text('Ivan'), findsOneWidget);
      await tester.tap(find.text('Vera'));
      await tester.pump();
      await tester.tap(find.text('Block'));
      await settle(tester);
      final block = json.sent.lastWhere(
        (r) => r['@type'] == 'setMessageSenderBlockList',
      );
      expect(block['sender_id'], {'@type': 'messageSenderUser', 'user_id': 5});
      expect(find.text('Vera'), findsOneWidget);
    });
  });
}

const _tick = Duration(milliseconds: 20);

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(telegramSessionProvider).hasValue) {
      return const SizedBox.shrink();
    }
    return SettingsWindow(initialSection: 'privacy', onClose: () {});
  }
}

Map<String, Object?> _user(int id, String name, {bool bot = false}) => {
  '@type': 'user',
  'id': id,
  'first_name': name,
  'last_name': '',
  'phone_number': '',
  'is_contact': !bot,
  'status': {'@type': 'userStatusEmpty'},
  'type': bot
      ? {'@type': 'userTypeBot', 'inline_query_placeholder': ''}
      : {'@type': 'userTypeRegular'},
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final failing = <String>{};

  final _users = {
    5: _user(5, 'Vera'),
    6: _user(6, 'Ivan'),
    9: _user(9, 'Spam bot', bot: true),
  };

  /// The rules of each setting, by its type.
  final _rules = <String, List<Object?>>{
    'userPrivacySettingShowStatus': [
      {
        '@type': 'userPrivacySettingRuleRestrictUsers',
        'user_ids': [6],
      },
      {'@type': 'userPrivacySettingRuleAllowContacts'},
    ],
    'userPrivacySettingShowPhoneNumber': [
      {'@type': 'userPrivacySettingRuleRestrictAll'},
    ],
  };

  var _blocked = [9, 6];

  /// Blocks [count] more made-up people, for paging.
  void blockMany(int count) =>
      _blocked = [..._blocked, for (var i = 0; i < count; i++) 1000 + i];

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

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
    final extra = decoded.remove('@extra');
    final type = decoded['@type'];
    sent.add(decoded);
    String settingOf() => (decoded['setting']! as Map)['@type']! as String;
    if (failing.contains(type)) {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 400,
          'message': 'Failed',
          '@client_id': clientId,
          '@extra': extra,
        }),
      );
      return;
    }
    if (type == 'setUserPrivacySettingRules') {
      _rules[settingOf()] = (decoded['rules']! as Map)['rules']! as List;
    } else if (type == 'setMessageSenderBlockList') {
      final id = (decoded['sender_id']! as Map)['user_id']! as int;
      _blocked = decoded['block_list'] == null
          ? [..._blocked.where((b) => b != id)]
          : [id, ..._blocked];
    }
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getUserPrivacySettingRules' => {
        '@type': 'userPrivacySettingRules',
        'rules':
            _rules[settingOf()] ??
            [
              {'@type': 'userPrivacySettingRuleAllowAll'},
            ],
      },
      'getBlockedMessageSenders' => {
        '@type': 'messageSenders',
        'total_count': _blocked.length,
        'senders': [
          for (final id
              in _blocked
                  .skip(decoded['offset']! as int)
                  .take(decoded['limit']! as int))
            {'@type': 'messageSenderUser', 'user_id': id},
        ],
      },
      'getContacts' => {
        '@type': 'users',
        'total_count': 2,
        'user_ids': [5, 6],
      },
      'getUser' =>
        _users[decoded['user_id']] ??
            _user(decoded['user_id']! as int, 'P${decoded['user_id']}'),
      'getActiveSessions' => {
        '@type': 'sessions',
        'sessions': <Object?>[],
        'inactive_session_ttl_days': 180,
      },
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({...response, '@client_id': clientId, '@extra': extra}),
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
