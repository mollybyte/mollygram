import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/privacy/passcode.dart';
import 'package:mollygram/src/settings/privacy/privacy_page.dart';
import 'package:mollygram/src/settings/privacy/two_step_page.dart';
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

    late MemoryPasscodeStorage passcodes;
    setUp(() {
      passcodes = MemoryPasscodeStorage();
      PasscodeHash.defaultIterations = 100;
    });

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
            passcodeStorageProvider.overrideWithValue(passcodes),
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

    Future<void> fill(WidgetTester tester, List<String> values) async {
      final fields = find.descendant(
        of: find.byType(MgUnderlineField),
        matching: find.byType(EditableText),
      );
      for (var i = 0; i < values.length; i++) {
        await tester.enterText(fields.at(i), values[i]);
      }
      await tester.pump();
    }

    testWidgets('sets a two-step password and confirms the email', (
      tester,
    ) async {
      await pump(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('twoStep')),
          matching: find.text('Off'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Two-step verification'));
      await settle(tester);
      await tester.tap(find.text('Set password'));
      await settle(tester);

      await fill(tester, ['secret', 'secreT', 'cat', 'a@mail.com']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text("The passwords don't match."), findsOneWidget);
      expect(json.sent.where((r) => r['@type'] == 'setPassword'), isEmpty);

      await fill(tester, ['secret', 'secret', 'cat', 'a@mail.com']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      final request = json.sent.lastWhere((r) => r['@type'] == 'setPassword');
      expect(request['new_hint'], 'cat');
      expect(request['new_recovery_email_address'], 'a@mail.com');

      // Until the code is in, TDLib holds the password back: the page
      // says so rather than "on", and asks for the code right away.
      expect(find.text('Telegram sent a code to a***@mail.com.'), findsWidgets);
      expect(
        find.text(
          'Enter the code from the email to turn on two-step verification.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Two-step verification turns on once you enter the code sent to '
          'the recovery email.',
        ),
        findsOneWidget,
      );
      expect(find.text('Change password'), findsNothing);

      // A code of the length TDLib gave goes in without a click.
      await fill(tester, ['11111']);
      await settle(tester);
      expect(find.text('Invalid code'), findsOneWidget);

      await fill(tester, ['12345']);
      await settle(tester);
      expect(find.text('The recovery email is confirmed.'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Change recovery email'), findsOneWidget);
    });

    testWidgets('a forgotten password is reset through the email', (
      tester,
    ) async {
      json
        ..password = 'old'
        ..hasEmail = true;
      await pump(tester);
      await tester.tap(find.text('Two-step verification'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('turnOff')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('formSheetAside')));
      await settle(tester);
      expect(
        find.text('Enter the code sent to a***@mail.com and a new password.'),
        findsOneWidget,
      );

      await fill(tester, ['000000', 'fresh', 'fresh', '']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Invalid code'), findsOneWidget);

      await fill(tester, ['777777', 'fresh', 'fresh', '']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(json.password, 'fresh');
      expect(find.text('The password is changed.'), findsOneWidget);
    });

    test('says what Telegram turned a password down for', () {
      String says(String message) =>
          twoStepError(l10n, td.TdException(400, message));
      expect(
        says('PASSWORD_TOO_FRESH_86400'),
        'The password was changed recently. Try again later.',
      );
      expect(
        says('SESSION_TOO_FRESH_86400'),
        'This device signed in recently. Try again later.',
      );
      expect(says('NEW_PASSWORD_BAD'), l10n.twoStepPasswordRejected);
      expect(says('NEW_SALT_INVALID'), l10n.twoStepPasswordRejected);
      expect(says('PASSWORD_MISSING'), l10n.saveFailed);
    });

    testWidgets('changes how long an unused account lives', (tester) async {
      await pump(tester);
      expect(find.text('6 months'), findsOneWidget);
      await tester.tap(find.text('If away for'));
      await settle(tester);
      await tester.tap(find.text('1 year'));
      await settle(tester);
      expect(json.sent.lastWhere((r) => r['@type'] == 'setAccountTtl')['ttl'], {
        '@type': 'accountTtl',
        'days': 365,
      });
    });

    testWidgets('turns the passcode on and picks when it locks', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Passcode lock'));
      await settle(tester);
      await tester.tap(find.text('Turn passcode on'));
      await settle(tester);
      await fill(tester, ['12', '12']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Use at least 4 characters.'), findsOneWidget);

      await fill(tester, ['2580', '2580']);
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(PasscodeSettings.fromJson(passcodes.saved).enabled, isTrue);
      expect(find.text('Change passcode'), findsOneWidget);

      await tester.tap(find.text('If away for 15 minutes'));
      await settle(tester);
      expect(PasscodeSettings.fromJson(passcodes.saved).autoLockMinutes, 15);

      await tester.tap(find.text('Turn passcode off'));
      await settle(tester);
      await fill(tester, ['0000']);
      await tester.tap(find.text('Turn off'));
      await settle(tester);
      expect(find.text('Wrong passcode'), findsOneWidget);
      await fill(tester, ['2580']);
      await tester.tap(find.text('Turn off'));
      await settle(tester);
      final off = PasscodeSettings.fromJson(passcodes.saved);
      expect(off.enabled, isFalse);
      // The away time stays for the next passcode.
      expect(off.autoLockMinutes, 15);
      expect(find.text('Turn passcode on'), findsOneWidget);
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

  var password = '';
  var pendingEmail = false;
  var hasEmail = false;
  var ttl = 180;

  Map<String, Object?> _password() => {
    '@type': 'passwordState',
    // TDLib keeps a password with a new email until its code is in.
    'has_password': password.isNotEmpty && !pendingEmail,
    'password_hint': '',
    'has_recovery_email_address': hasEmail,
    'has_passport_data': false,
    'recovery_email_address_code_info': pendingEmail
        ? {
            '@type': 'emailAddressAuthenticationCodeInfo',
            'email_address_pattern': 'a***@mail.com',
            'length': 5,
          }
        : null,
    'login_email_address_pattern': '',
    'pending_reset_date': 0,
  };

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
      'getPasswordState' => _password(),
      'setPassword' => () {
        password = decoded['new_password']! as String;
        pendingEmail = decoded['set_recovery_email_address'] == true;
        return _password();
      }(),
      'checkRecoveryEmailAddressCode' when decoded['code'] == '12345' => () {
        pendingEmail = false;
        hasEmail = true;
        return _password();
      }(),
      'requestPasswordRecovery' => {
        '@type': 'emailAddressAuthenticationCodeInfo',
        'email_address_pattern': 'a***@mail.com',
        'length': 6,
      },
      'recoverPassword' when decoded['recovery_code'] == '777777' => () {
        password = decoded['new_password']! as String;
        return _password();
      }(),
      'recoverPassword' => {
        '@type': 'error',
        'code': 400,
        'message': 'PASSWORD_RECOVERY_CODE_INVALID',
      },
      'checkRecoveryEmailAddressCode' => {
        '@type': 'error',
        'code': 400,
        'message': 'EMAIL_CODE_INVALID',
      },
      'getAccountTtl' => {'@type': 'accountTtl', 'days': ttl},
      'setAccountTtl' => () {
        ttl = (decoded['ttl']! as Map)['days']! as int;
        return {'@type': 'ok'};
      }(),
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
