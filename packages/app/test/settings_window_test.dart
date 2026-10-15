import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/account_page.dart';
import 'package:mollygram/src/settings/plugins_page.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/settings_window.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  var closed = 0;
  var loggedOut = 0;
  late MemoryPreferencesStorage preferences;
  var logOutFails = false;

  Future<void> pump(WidgetTester tester, {String section = 'account'}) async {
    closed = 0;
    loggedOut = 0;
    preferences = MemoryPreferencesStorage();
    logOutFails = false;
    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          pluginsControllerProvider.overrideWith(
            (ref) => PluginsController(mockPlugins()),
          ),
          preferencesStorageProvider.overrideWithValue(preferences),
          logOutProvider.overrideWithValue(() async {
            if (logOutFails) throw StateError('offline');
            loggedOut++;
          }),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: _Host(section: section, onClose: () => closed++),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('opens on my profile with the account card on top', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Anna Petrova'), findsNWidgets(2));
    expect(find.text('+79991234567'), findsNWidgets(2));
    expect(find.text('Privacy and security'), findsOneWidget);
    expect(find.text('Plugins'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(closed, 1);
  });

  testWidgets('search narrows the sections in both languages', (tester) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byType(MgSearchField),
        matching: find.byType(TextField),
      ),
      'сеанс',
    );
    await tester.pump();
    expect(find.text('Privacy and security'), findsOneWidget);
    expect(find.text('Plugins'), findsNothing);
    expect(find.byType(AccountCard), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Active sessions'), findsOneWidget);
  });

  testWidgets('lists sessions and terminates one after confirming', (
    tester,
  ) async {
    await pump(tester, section: 'privacy');
    await tester.tap(find.byKey(const ValueKey('activeSessions')));
    await settle(tester);

    expect(find.text('Mollygram 0.1.0'), findsOneWidget);
    expect(find.text('Telegram iOS 11.2'), findsOneWidget);
    expect(find.text('Telegram Web 2.0'), findsOneWidget);
    // This device comes first.
    expect(
      tester.getTopLeft(find.text('Mollygram 0.1.0')).dy,
      lessThan(tester.getTopLeft(find.text('Telegram iOS 11.2')).dy),
    );

    await tester.tap(find.text('Telegram iOS 11.2'));
    await settle(tester);
    expect(find.text('Terminate this session?'), findsOneWidget);
    await tester.tap(find.text('Terminate').last);
    await settle(tester);

    expect(
      json.sent,
      contains(equals({'@type': 'terminateSession', 'session_id': '2'})),
    );
    expect(find.text('Telegram iOS 11.2'), findsNothing);
    expect(find.text('Telegram Web 2.0'), findsOneWidget);

    // Esc goes back to Privacy and security before closing.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const ValueKey('activeSessions')), findsOneWidget);
    expect(closed, 0);
  });

  testWidgets('terminates all other sessions', (tester) async {
    await pump(tester, section: 'privacy');
    await tester.tap(find.byKey(const ValueKey('activeSessions')));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('terminateOthers')));
    await settle(tester);
    await tester.tap(find.text('Terminate').last);
    await settle(tester);

    expect(json.sent, contains(equals({'@type': 'terminateAllOtherSessions'})));
    expect(find.text("You're signed in on this device only."), findsOneWidget);
  });

  testWidgets('checks a username while it is typed and saves it', (
    tester,
  ) async {
    await pump(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('username')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'ab');
    await tester.pump();
    expect(
      find.text('A username must have at least 5 characters.'),
      findsOneWidget,
    );

    await tester.enterText(field, 'anna_new');
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.text('@anna_new is available.'), findsOneWidget);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(
      json.sent,
      contains(equals({'@type': 'setUsername', 'username': 'anna_new'})),
    );
  });

  testWidgets('drops a username check answered after the text changed', (
    tester,
  ) async {
    await pump(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('username')),
      matching: find.byType(TextField),
    );
    json.hold.add('checkChatUsername');
    await tester.enterText(field, 'anna_new');
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      json.sent,
      contains(
        equals({
          '@type': 'checkChatUsername',
          'chat_id': 42,
          'username': 'anna_new',
        }),
      ),
    );

    // Back to the current username while the check is still out.
    await tester.enterText(field, 'anna');
    await tester.pump();
    json.release();
    await settle(tester);

    expect(find.text('@anna_new is available.'), findsNothing);
    expect(
      find.textContaining('People can find you by this username'),
      findsOneWidget,
    );
  });

  testWidgets('refuses an empty first name', (tester) async {
    await pump(tester);
    final field = find.descendant(
      of: find.byKey(const ValueKey('firstName')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('A first name is required.'), findsOneWidget);
    expect(json.sent.where((r) => r['@type'] == 'setName'), isEmpty);

    await tester.enterText(field, 'Anya');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(
      json.sent,
      contains(
        equals({
          '@type': 'setName',
          'first_name': 'Anya',
          'last_name': 'Petrova',
        }),
      ),
    );
  });

  testWidgets('an edit left in a field is saved when the page changes', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('bio')),
        matching: find.byType(TextField),
      ),
      'Hello there',
    );
    await tester.tap(find.text('Privacy and security'));
    await settle(tester);
    expect(
      json.sent,
      contains(equals({'@type': 'setBio', 'bio': 'Hello there'})),
    );
  });

  testWidgets('logs out only after confirming', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Log out…'));
    await tester.tap(find.text('Log out…'));
    await settle(tester);
    expect(find.text('Log out of Telegram?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(loggedOut, 0);

    await tester.tap(find.text('Log out…'));
    await settle(tester);
    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(loggedOut, 1);
  });

  testWidgets('a failed log out says so and can be tried again', (
    tester,
  ) async {
    await pump(tester);
    logOutFails = true;
    await tester.ensureVisible(find.text('Log out…'));
    await tester.tap(find.text('Log out…'));
    await settle(tester);
    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(
      find.text("Couldn't log out. Check the connection and try again."),
      findsOneWidget,
    );

    logOutFails = false;
    await tester.tap(find.text('Log out…'));
    await settle(tester);
    await tester.tap(find.text('Log out'));
    await settle(tester);
    expect(loggedOut, 1);
  });

  testWidgets('first and last name edits both reach Telegram', (tester) async {
    await pump(tester);
    Finder field(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.enterText(field('firstName'), 'Anya');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.enterText(field('lastName'), 'Smirnova');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(json.sent.where((r) => r['@type'] == 'setName').last, {
      '@type': 'setName',
      'first_name': 'Anya',
      'last_name': 'Smirnova',
    });
  });

  testWidgets('a username typed just before leaving is checked and saved', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('username')),
        matching: find.byType(TextField),
      ),
      'anna_new',
    );
    await tester.tap(find.text('Privacy and security'));
    await settle(tester);
    expect(
      json.sent,
      contains(equals({'@type': 'setUsername', 'username': 'anna_new'})),
    );
  });

  testWidgets('the back button returns from a nested page', (tester) async {
    await pump(tester, section: 'privacy');
    await tester.tap(find.byKey(const ValueKey('activeSessions')));
    await settle(tester);
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.byKey(const ValueKey('activeSessions')), findsOneWidget);
  });

  testWidgets('shows the connected business bot and disconnects it', (
    tester,
  ) async {
    json.bot = true;
    await pump(tester, section: 'privacy');
    await tester.tap(find.byKey(const ValueKey('activeSessions')));
    await settle(tester);
    expect(find.text('Shop bot'), findsOneWidget);
    await tester.tap(find.text('Disconnect'));
    await settle(tester);
    await tester.tap(find.text('Disconnect').last);
    await settle(tester);
    expect(
      json.sent,
      contains(
        equals({'@type': 'deleteBusinessConnectedBot', 'bot_user_id': 7}),
      ),
    );
    expect(find.text('Shop bot'), findsNothing);
  });

  testWidgets('says when the connected bot cannot be loaded', (tester) async {
    json.botFails = true;
    await pump(tester, section: 'privacy');
    await tester.tap(find.byKey(const ValueKey('activeSessions')));
    await settle(tester);
    expect(find.text("Couldn't load the connected bot"), findsOneWidget);

    json
      ..botFails = false
      ..bot = true;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Shop bot'), findsOneWidget);
  });

  testWidgets('appearance choices apply and are saved', (tester) async {
    await pump(tester, section: 'appearance');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsWindow)),
    );
    await tester.tap(find.byKey(const ValueKey('theme.dark')));
    await tester.tap(find.byKey(const ValueKey('accent.teal')));
    await tester.tap(find.byKey(const ValueKey('wallpaper')));
    await tester.tap(find.byKey(const ValueKey('reduceMotion')));
    await settle(tester);
    final p = container.read(preferencesProvider);
    expect(p.theme, ThemeMode.dark);
    expect(p.accent, AccentChoice.teal);
    expect(p.wallpaper, isFalse);
    expect(p.reduceMotion, isTrue);

    // Dragging the slider to its right end picks 17 pt.
    final slider = find.byKey(const ValueKey('textSize'));
    await tester.tapAt(
      tester.getCenter(slider) +
          Offset(tester.getSize(slider).width / 2 - 2, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(container.read(preferencesProvider).textSize, 17);
    expect((preferences.saved! as Map)['textSize'], 17);
    expect((preferences.saved! as Map)['theme'], 'dark');
  });

  testWidgets('shows the storage by kind and clears the chosen kinds', (
    tester,
  ) async {
    await pump(tester, section: 'data');
    expect(find.text('42 MB of media and files'), findsOneWidget);
    expect(find.text('4.2 MB'), findsOneWidget);
    expect(find.text('38 MB'), findsOneWidget);
    expect(find.text('12 MB'), findsOneWidget);

    // Untick videos: only photos are cleared.
    await tester.tap(find.byKey(const ValueKey('storage.videos')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('clearCache')));
    await settle(tester);
    expect(find.text('Clear 4.2 MB from this computer?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await settle(tester);

    final request = json.sent.lastWhere((r) => r['@type'] == 'optimizeStorage');
    expect(request['file_types'], [
      {'@type': 'fileTypePhoto'},
      {'@type': 'fileTypePhotoStory'},
    ]);
    expect(find.text('38 MB of media and files'), findsOneWidget);
  });

  testWidgets('auto-download switches are kept per network', (tester) async {
    await pump(tester, section: 'data');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SettingsWindow)),
    );
    await tester.tap(find.byKey(const ValueKey('autoDownload.files.wifi')));
    await tester.pump();
    final files = container
        .read(preferencesProvider)
        .autoDownloadOf(AutoDownloadKind.files);
    expect(files, const AutoDownload(wifi: true, other: false));
    expect(
      container.read(autoDownloadProvider(AutoDownloadKind.files)),
      isTrue,
    );
  });

  testWidgets('plugins open their page and install after consent', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Plugins'));
    await settle(tester);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);

    await tester.tap(find.text('Chat statistics'));
    await settle(tester);
    expect(find.text('graphy · 0.6.1'), findsOneWidget);
    expect(find.text('/stats'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('install')));
    await settle(tester);
    expect(find.byType(ConsentSheet), findsOneWidget);
    expect(find.text('Install “Chat statistics”?'), findsOneWidget);
    expect(
      find.textContaining('This plugin can read all your messages'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('consent.allow')));
    await settle(tester);
    expect(find.byType(ConsentSheet), findsNothing);
    expect(find.byKey(const ValueKey('enabled')), findsOneWidget);
    expect(find.byKey(const ValueKey('uninstall')), findsOneWidget);
  });

  testWidgets('an update asking for more shows only the new access', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Plugins'));
    await settle(tester);
    await tester.tap(find.text('Summary'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('review')));
    await settle(tester);
    expect(find.text('New access in this version:'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ConsentSheet),
        matching: find.text('Storage'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('consent.allow')));
    await settle(tester);
    expect(find.byKey(const ValueKey('review')), findsNothing);
  });

  testWidgets('a plugin is turned off from its page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Plugins'));
    await settle(tester);
    await tester.tap(find.text('Summary'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('enabled')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('manifest')));
    await settle(tester);
    expect(find.textContaining('id: dev.tgplug.summary'), findsOneWidget);

    // Back on the list the plugin reads as off.
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('plugin:dev.tgplug.summary')),
        matching: find.text('off'),
      ),
      findsOneWidget,
    );
  });
}

const _tick = Duration(milliseconds: 20);

class _Host extends ConsumerWidget {
  const _Host({required this.section, required this.onClose});

  final String section;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(telegramSessionProvider).hasValue) {
      return const SizedBox.shrink();
    }
    return SettingsWindow(initialSection: section, onClose: onClose);
  }
}

Map<String, Object?> _session(
  int id,
  String app,
  String version, {
  bool current = false,
  int lastActive = 0,
}) => {
  '@type': 'session',
  'id': '$id',
  'is_current': current,
  'device_type': {'@type': 'sessionDeviceTypeMac'},
  'application_name': app,
  'application_version': version,
  'device_model': 'Device $id',
  'platform': 'OS',
  'system_version': '1',
  'last_active_date': lastActive,
  'location': 'Berlin, Germany',
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// Whether a business bot is connected.
  var bot = false;

  /// Whether loading the business bot fails with a server error.
  var botFails = false;

  /// Whether the photo cache was cleared.
  var cleared = false;

  /// Request types whose answers wait for [release].
  final hold = <String>{};
  final _held = <String>[];

  void release() {
    _queue.addAll(_held);
    _held.clear();
  }

  var _sessions = [
    _session(2, 'Telegram iOS', '11.2', lastActive: 1700000000),
    _session(1, 'Mollygram', '0.1.0', current: true),
    _session(3, 'Telegram Web', '2.0', lastActive: 1600000000),
  ];

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
    if (type == 'terminateSession') {
      _sessions = [
        for (final s in _sessions)
          if (s['id'] != decoded['session_id']) s,
      ];
    } else if (type == 'optimizeStorage') {
      cleared = true;
    } else if (type == 'deleteBusinessConnectedBot') {
      bot = false;
    } else if (type == 'terminateAllOtherSessions') {
      _sessions = [
        for (final s in _sessions)
          if (s['is_current'] == true) s,
      ];
    }
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getMe' => {
        '@type': 'user',
        'id': 42,
        'first_name': 'Anna',
        'last_name': 'Petrova',
        'usernames': {'@type': 'usernames', 'editable_username': 'anna'},
        'phone_number': '79991234567',
        'status': {'@type': 'userStatusEmpty'},
        'type': {'@type': 'userTypeRegular'},
      },
      'getUserFullInfo' => {
        '@type': 'userFullInfo',
        'bio': {'@type': 'formattedText', 'text': 'Hi', 'entities': <Object>[]},
        'gift_settings': {
          '@type': 'giftSettings',
          'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
        },
      },
      'getActiveSessions' => {
        '@type': 'sessions',
        'sessions': _sessions,
        'inactive_session_ttl_days': 180,
      },
      'checkChatUsername' => {'@type': 'checkChatUsernameResultOk'},
      'getOption' => {'@type': 'optionValueEmpty'},
      'getStorageStatistics' => {
        '@type': 'storageStatistics',
        'by_chat': [
          {
            '@type': 'storageStatisticsByChat',
            'by_file_type': [
              if (!cleared)
                {
                  '@type': 'storageStatisticsByFileType',
                  'file_type': {'@type': 'fileTypePhoto'},
                  'size': 4200000,
                },
              {
                '@type': 'storageStatisticsByFileType',
                'file_type': {'@type': 'fileTypeVideo'},
                'size': 38000000,
              },
            ],
          },
        ],
      },
      'optimizeStorage' => {'@type': 'storageStatistics'},
      'getStorageStatisticsFast' => {
        '@type': 'storageStatisticsFast',
        'database_size': 12000000,
      },
      'getBusinessConnectedBot' when botFails => {
        '@type': 'error',
        'code': 500,
        'message': 'Internal',
      },
      'getBusinessConnectedBot' when bot => {
        '@type': 'businessConnectedBotInfo',
        'bot': {
          '@type': 'businessConnectedBot',
          'bot_user_id': 7,
          'recipients': {'@type': 'businessRecipients'},
          'rights': {'@type': 'businessBotRights'},
        },
      },
      'getBusinessConnectedBot' => {
        '@type': 'error',
        'code': 404,
        'message': 'Not Found',
      },
      'getUser' => {
        '@type': 'user',
        'id': 7,
        'first_name': 'Shop bot',
        'status': {'@type': 'userStatusEmpty'},
        'type': {'@type': 'userTypeBot'},
      },
      _ => {'@type': 'ok'},
    };
    final answer = jsonEncode({
      ...response,
      '@client_id': clientId,
      '@extra': extra,
    });
    hold.contains(type) ? _held.add(answer) : _queue.add(answer);
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
