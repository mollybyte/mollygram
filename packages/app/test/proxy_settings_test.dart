import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/app.dart';
import 'package:mollygram/src/proxy/proxy_editor.dart';
import 'package:mollygram/src/proxy/sign_in_proxy_button.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/language_page.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/privacy/passcode.dart';
import 'package:mollygram/src/settings/proxy_page.dart';
import 'package:mollygram/src/settings/selection_check.dart';
import 'package:mollygram/src/settings/settings_style.dart';
import 'package:mollygram/src/settings/settings_window.dart';
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
  });

  tearDown(() => session.dispose());

  /// Lets TDLib answer and the answers show. Spinners never settle, so
  /// frames are pumped by time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(900, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: _WhenSignedIn(child: child)),
        ),
      ),
    );
    await settle(tester);
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  Map<String, Object?> typeOf(Map<String, Object?> request) =>
      (request['proxy']! as Map<String, Object?>)['type']!
          as Map<String, Object?>;

  test('both sections are in the settings', () {
    final ids = [for (final s in settingsSections) s.id];
    expect(ids, containsAll(['proxy', 'language']));
  });

  group('proxy page', () {
    testWidgets('lists proxies with their ping and the one in use', (
      tester,
    ) async {
      json.proxies = [
        _added(1, 'a.example', 1080, enabled: true),
        _added(2, 'b.example', 443, mtproto: true),
      ];
      json.pings = {'a.example': 0.042};
      await pump(tester, const ProxyPage());

      expect(find.text('a.example:1080'), findsOneWidget);
      expect(find.text('b.example:443'), findsOneWidget);
      expect(find.text('SOCKS5'), findsOneWidget);
      expect(find.text('MTProto'), findsOneWidget);
      final quick = tester.widget<Text>(find.text('42 ms'));
      expect(quick.style?.color, pingColor(const Duration(milliseconds: 42)));
      final down = tester.widget<Text>(find.text('Unavailable'));
      expect(down.style?.color, MgDestructive.color);
      expect(
        tester
            .widgetList<SelectionCheck>(find.byType(SelectionCheck))
            .map((c) => c.checked),
        [true, false],
      );
      final use = tester.widget<SettingsSwitchRow>(
        find.byKey(const ValueKey('useProxy')),
      );
      expect(use.value, isTrue);
    });

    testWidgets('connects through a proxy on a click', (tester) async {
      json.proxies = [
        _added(1, 'a.example', 1080, enabled: true),
        _added(2, 'b.example', 443),
      ];
      await pump(tester, const ProxyPage());

      await tester.tap(find.text('b.example:443'));
      await settle(tester);
      expect(sent('enableProxy')['proxy_id'], 2);
      expect(
        tester
            .widget<SettingsSwitchRow>(find.byKey(const ValueKey('useProxy')))
            .value,
        isTrue,
      );
    });

    testWidgets('"Use proxy" turns the last used one on and off', (
      tester,
    ) async {
      json.proxies = [
        _added(1, 'a.example', 1080, lastUsed: 10),
        _added(2, 'b.example', 443, lastUsed: 90),
      ];
      await pump(tester, const ProxyPage());

      await tester.tap(find.byType(SettingsSwitch));
      await settle(tester);
      expect(sent('enableProxy')['proxy_id'], 2);

      await tester.tap(find.byType(SettingsSwitch));
      await settle(tester);
      expect(sent('disableProxy'), isNotNull);
      expect(
        tester
            .widget<SettingsSwitchRow>(find.byKey(const ValueKey('useProxy')))
            .value,
        isFalse,
      );
    });

    testWidgets('the switch is off with nothing saved', (tester) async {
      await pump(tester, const ProxyPage());
      expect(find.text('No proxies yet'), findsOneWidget);
      expect(
        tester
            .widget<SettingsSwitchRow>(find.byKey(const ValueKey('useProxy')))
            .onChanged,
        isNull,
      );
    });

    testWidgets('adds an MTProto proxy', (tester) async {
      await pump(tester, const ProxyPage());
      await tester.tap(find.text('Add proxy'));
      await settle(tester);
      expect(find.byType(ProxyEditor), findsOneWidget);

      await tester.tap(find.text('MTProto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('server')), 'mt.ex');
      await tester.enterText(find.byKey(const ValueKey('port')), '443x');
      await tester.enterText(find.byKey(const ValueKey('secret')), _secret);
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await settle(tester);

      final request = sent('addProxy');
      expect(request['enable'], isTrue);
      expect((request['proxy']! as Map)['server'], 'mt.ex');
      expect((request['proxy']! as Map)['port'], 443);
      expect(typeOf(request), {'@type': 'proxyTypeMtproto', 'secret': _secret});
      expect(find.byType(ProxyEditor), findsNothing);
      expect(find.text('mt.ex:443'), findsOneWidget);
    });

    testWidgets('checks a proxy before saving it', (tester) async {
      json.pings = {'s.ex': 0.1};
      await pump(tester, const ProxyPage());
      await tester.tap(find.text('Add proxy'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('server')), 's.ex');
      await tester.enterText(find.byKey(const ValueKey('port')), '1080');
      await tester.pump();
      await tester.tap(find.text('Check'));
      await settle(tester);
      expect(find.text('100 ms'), findsOneWidget);
      expect(json.sent.any((r) => r['@type'] == 'addProxy'), isFalse);
    });

    testWidgets('edits and removes a proxy', (tester) async {
      json.proxies = [_added(1, 'a.example', 1080, enabled: true)];
      await pump(tester, const ProxyPage());

      await tester.tap(find.byKey(const ValueKey(('editProxy', 1))));
      await settle(tester);
      expect(find.text('Edit proxy'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('password')), 'new');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      final edit = sent('editProxy');
      expect(edit['proxy_id'], 1);
      expect(edit['enable'], isTrue);
      expect(typeOf(edit)['password'], 'new');

      await tester.tap(find.byKey(const ValueKey(('editProxy', 1))));
      await settle(tester);
      await tester.tap(find.text('Remove proxy'));
      await settle(tester);
      expect(find.text('Remove a.example:1080?'), findsOneWidget);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(sent('removeProxy')['proxy_id'], 1);
      expect(find.text('a.example:1080'), findsNothing);
    });

    testWidgets('says when a secret is not valid', (tester) async {
      await pump(tester, const ProxyPage());
      await tester.tap(find.text('Add proxy'));
      await settle(tester);
      await tester.tap(find.text('MTProto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byKey(const ValueKey('server')), 'mt.ex');
      await tester.enterText(find.byKey(const ValueKey('port')), '443');
      await tester.enterText(find.byKey(const ValueKey('secret')), 'ee00');
      await tester.pump();
      expect(find.text('Invalid secret'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      await settle(tester);
      expect(json.sent.any((r) => r['@type'] == 'addProxy'), isFalse);

      TextField secretField() => tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('secret')),
          matching: find.byType(TextField),
        ),
      );
      expect(secretField().obscureText, isTrue);
      await tester.tap(find.byKey(const ValueKey('revealSecret')));
      await tester.pump();
      expect(secretField().obscureText, isFalse);

      await tester.enterText(find.byKey(const ValueKey('secret')), _secret);
      await tester.pump();
      expect(find.text('Invalid secret'), findsNothing);
    });

    testWidgets('pings again after switching proxies', (tester) async {
      json.proxies = [
        _added(1, 'a.example', 1080, enabled: true),
        _added(2, 'b.example', 443),
      ];
      await pump(tester, const ProxyPage());
      int pings() => json.sent.where((r) => r['@type'] == 'pingProxy').length;
      final before = pings();
      expect(before, 2);

      await tester.tap(find.text('b.example:443'));
      await settle(tester);
      expect(pings(), before + 2);
    });

    testWidgets('says when the proxies could not be read', (tester) async {
      json.failing.add('getProxies');
      await pump(tester, const ProxyPage());
      expect(find.text("Couldn't load the proxies."), findsOneWidget);
      expect(find.text('No proxies yet'), findsNothing);
    });

    testWidgets('a failed save keeps the sheet open', (tester) async {
      json.failing.add('addProxy');
      await pump(tester, const ProxyPage());
      await tester.tap(find.text('Add proxy'));
      await settle(tester);
      await tester.enterText(find.byKey(const ValueKey('server')), 's.ex');
      await tester.enterText(find.byKey(const ValueKey('port')), '1080');
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await settle(tester);
      expect(find.byType(ProxyEditor), findsOneWidget);
      expect(find.text("Couldn't save the change."), findsOneWidget);
    });

    testWidgets('a proxy link asks and checks the proxy first', (tester) async {
      json.pings = {'mt.ex': 0.05};
      await pump(
        tester,
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showProxyEditor(
                context,
                initial: const ProxySettings(
                  server: 'mt.ex',
                  port: 443,
                  kind: ProxyKind.mtproto,
                  secret: _secret,
                ),
                fromLink: true,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(
        find.text('Add this proxy and connect through it?'),
        findsOneWidget,
      );
      expect(find.text('50 ms'), findsOneWidget);
      // Nothing has focus in a sheet from a link, and Enter still adds.
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await settle(tester);
      expect(typeOf(sent('addProxy'))['secret'], _secret);
      expect(find.byType(ProxyEditor), findsNothing);
    });
  });

  group('sign-in', () {
    testWidgets('connects through the proxy used last', (tester) async {
      json.proxies = [
        _added(1, 'a.example', 1080, lastUsed: 10),
        _added(2, 'b.example', 1080, lastUsed: 90),
      ];
      await pump(tester, const Center(child: SignInProxyButton()));
      expect(find.text('Proxy'), findsOneWidget);

      await tester.tap(find.text('Proxy'));
      await settle(tester);
      expect(find.text('Edit proxy'), findsOneWidget);
      await tester.tap(find.text('Connect'));
      await settle(tester);
      expect(sent('editProxy')['proxy_id'], 2);
      expect(sent('editProxy')['enable'], isTrue);
      expect(find.text('Proxy: b.example'), findsOneWidget);
    });

    testWidgets('adds a proxy when none is saved', (tester) async {
      await pump(tester, const Center(child: SignInProxyButton()));
      await tester.tap(find.text('Proxy'));
      await settle(tester);
      expect(find.text('Add proxy'), findsOneWidget);
    });
  });

  group('language', () {
    testWidgets('a choice applies to the whole app at once', (tester) async {
      tester.view
        ..physicalSize = const Size(1200, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final storage = MemoryPreferencesStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramApiConfigProvider.overrideWithValue(
              const TelegramApiConfig(apiId: 0, apiHash: ''),
            ),
            preferencesStorageProvider.overrideWithValue(storage),
            // The keychain never answers under flutter test; without a
            // storage the passcode gate would hide the window.
            passcodeStorageProvider.overrideWithValue(MemoryPasscodeStorage()),
          ],
          child: const MollygramApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Telegram API keys are missing'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.text('Telegram API keys are missing')),
      );
      container
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(language: AppLanguage.russian));
      await tester.pumpAndSettle();
      expect(find.text('Нет ключей Telegram API'), findsOneWidget);
      await container.read(preferencesProvider.notifier).flush();
      expect((storage.saved! as Map)['language'], 'russian');
    });

    testWidgets('a saved choice applies from the start', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            telegramApiConfigProvider.overrideWithValue(
              const TelegramApiConfig(apiId: 0, apiHash: ''),
            ),
            preferencesStorageProvider.overrideWithValue(
              MemoryPreferencesStorage(),
            ),
            initialPreferencesProvider.overrideWithValue(
              Preferences.fromJson({'language': 'russian'}),
            ),
            passcodeStorageProvider.overrideWithValue(MemoryPasscodeStorage()),
          ],
          child: const MollygramApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Нет ключей Telegram API'), findsOneWidget);
    });

    testWidgets('lists the languages and marks the current one', (
      tester,
    ) async {
      await pump(tester, const LanguagePage());
      expect(find.text('System'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Русский'), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(LanguagePage)),
      );
      expect(container.read(preferencesProvider).language, AppLanguage.english);
      expect(
        tester
            .widget<SettingsRow>(
              find.byKey(const ValueKey(('language', 'english'))),
            )
            .onTap,
        isNull,
      );
    });

    test('is saved with the preferences', () {
      final restored = Preferences.fromJson(
        const Preferences().copyWith(language: AppLanguage.russian).toJson(),
      );
      expect(restored.language, AppLanguage.russian);
      expect(
        Preferences.fromJson({'language': 'klingon'}).language,
        AppLanguage.system,
      );
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.russian.locale, const Locale('ru'));
    });
  });
}

const _tick = Duration(milliseconds: 20);

/// A plain MTProto secret: 16 bytes in hex.
const _secret = '000102030405060708090a0b0c0d0e0f';

class _WhenSignedIn extends ConsumerWidget {
  const _WhenSignedIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue ? child : const SizedBox();
}

Map<String, Object?> _added(
  int id,
  String server,
  int port, {
  bool enabled = false,
  bool mtproto = false,
  int lastUsed = 0,
}) => {
  '@type': 'addedProxy',
  'id': id,
  'last_used_date': lastUsed,
  'is_enabled': enabled,
  'comment': '',
  'proxy': {
    '@type': 'proxy',
    'server': server,
    'port': port,
    'type': mtproto
        ? {'@type': 'proxyTypeMtproto', 'secret': 'dd00'}
        : {'@type': 'proxyTypeSocks5', 'username': '', 'password': ''},
  },
};

/// TDLib's proxy list, kept the way TDLib keeps it: one enabled at most.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final failing = <String>{};

  List<Map<String, Object?>> proxies = [];

  /// Round trips in seconds by server; the others can't be reached.
  Map<String, double> pings = {};
  var _nextId = 10;
  var _nextClientId = 0;

  void _enable(int? id) {
    proxies = [
      for (final p in proxies) {...p, 'is_enabled': p['id'] == id},
    ];
  }

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
    final type = decoded['@type']! as String;
    if (type != 'getAuthorizationState' && type != 'loadChats') {
      sent.add(decoded);
    }
    final Map<String, Object?> response = failing.contains(type)
        ? _error
        : switch (type) {
            'getAuthorizationState' => {'@type': 'authorizationStateReady'},
            'getProxies' => {'@type': 'addedProxies', 'proxies': proxies},
            'addProxy' => _save(decoded, _nextId++),
            'editProxy' => _save(decoded, decoded['proxy_id']! as int),
            'enableProxy' => _ok(() => _enable(decoded['proxy_id'] as int?)),
            'disableProxy' => _ok(() => _enable(null)),
            'removeProxy' => _ok(
              () => proxies = [
                for (final p in proxies)
                  if (p['id'] != decoded['proxy_id']) p,
              ],
            ),
            'pingProxy' => switch (pings[(decoded['proxy']!
                as Map)['server']]) {
              final seconds? => {'@type': 'seconds', 'seconds': seconds},
              null => _error,
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
          '@client_id': 1,
        }),
      );
    }
  }

  Map<String, Object?> _ok(void Function() change) {
    change();
    return {'@type': 'ok'};
  }

  Map<String, Object?> _save(Map<String, Object?> request, int id) {
    final enable = request['enable'] == true;
    final existing = proxies.where((p) => p['id'] == id).firstOrNull;
    final saved = {
      '@type': 'addedProxy',
      'id': id,
      'last_used_date': 0,
      'is_enabled': (existing?['is_enabled'] ?? false) == true || enable,
      'comment': '',
      'proxy': request['proxy'],
    };
    proxies = [
      for (final p in proxies)
        if (p['id'] == id) saved else p,
      if (existing == null) saved,
    ];
    if (enable) _enable(id);
    return saved;
  }
}

const _error = {'@type': 'error', 'code': 400, 'message': 'Failed'};
