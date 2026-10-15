import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/home/workspace_storage.dart';
import 'package:mollygram/src/privacy/ghost_mode_capsule.dart';
import 'package:mollygram/src/privacy/message_store.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram/src/settings/privacy_extras_page.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  group('persistence', () {
    late MemoryPrivacySettingsStorage storage;
    late List<_FakeTdJson> clients;

    /// [gate] holds TDLib's start until it completes.
    ProviderContainer create(Object? saved, {Future<void>? gate}) {
      storage = MemoryPrivacySettingsStorage(saved);
      clients = [];
      final container = ProviderContainer(
        overrides: [
          privacySettingsStorageProvider.overrideWithValue(storage),
          messageStoreOpenerProvider.overrideWithValue(
            () => MessageStore.memory(),
          ),
          telegramApiConfigProvider.overrideWithValue(
            const TelegramApiConfig(
              apiId: 12345,
              apiHash: '0123456789abcdef0123456789abcdef',
            ),
          ),
          workspaceStorageProvider.overrideWithValue(MemoryWorkspaceStorage()),
          telegramSessionLauncherProvider.overrideWithValue(
            TelegramSessionLauncher(
              startTdlib: (_) async {
                await gate;
                final json = _FakeTdJson();
                clients.add(json);
                return td.Td.custom(json, td.InlineTdEventSource(json));
              },
              loadParameters: _parameters,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('the session starts with the saved switches', () async {
      final container = create(const PrivacySettings.ghost().toJson());
      final subscription = container.listen(telegramSessionProvider, (_, _) {});
      addTearDown(subscription.close);

      final session = await container.read(telegramSessionProvider.future);

      expect(session.privacy.settings, const PrivacySettings.ghost());
      expect(clients, hasLength(1));
    });

    test('a switch flipped while the session starts is not lost', () async {
      final release = Completer<void>();
      final container = create(null, gate: release.future);
      final subscription = container.listen(telegramSessionProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(privacySettingsProvider.notifier).loaded;
      await Future<void>.delayed(Duration.zero);

      container.read(privacySettingsProvider.notifier).setGhost(true);
      release.complete();
      final session = await container.read(telegramSessionProvider.future);

      expect(session.privacy.settings.isGhost, isTrue);
    });

    test('the keep switches reach the capture', () async {
      final container = create(
        const PrivacySettings(keepDeletedMessages: true).toJson(),
      );
      final subscription = container.listen(telegramSessionProvider, (_, _) {});
      addTearDown(subscription.close);
      final session = await container.read(telegramSessionProvider.future);
      expect(session.capture.keepDeleted, isTrue);
      expect(session.capture.keepEdits, isFalse);
      expect(session.capture.store, isNotNull);

      container
          .read(privacySettingsProvider.notifier)
          .update((s) => s.copyWith(keepEditHistory: true));
      expect(session.capture.keepEdits, isTrue);
    });

    test('a change reaches the running session and is saved', () async {
      final container = create(null);
      final subscription = container.listen(telegramSessionProvider, (_, _) {});
      addTearDown(subscription.close);
      final session = await container.read(telegramSessionProvider.future);
      expect(session.privacy.settings, const PrivacySettings());

      container
          .read(privacySettingsProvider.notifier)
          .update((s) => s.copyWith(stayOffline: true));
      await Future<void>.delayed(Duration.zero);

      expect(session.privacy.settings.stayOffline, isTrue);
      expect(
        PrivacySettings.fromJson(storage.saved),
        const PrivacySettings(stayOffline: true),
      );
    });

    test('reading a chat silently is remembered per chat', () async {
      final container = create(null);
      final notifier = container.read(privacySettingsProvider.notifier);
      await notifier.loaded;

      notifier.setSilentRead(7, true);
      await Future<void>.delayed(Duration.zero);
      expect(PrivacySettings.fromJson(storage.saved).silentReadChats, {7});

      notifier.setSilentRead(7, false);
      await Future<void>.delayed(Duration.zero);
      expect(PrivacySettings.fromJson(storage.saved).silentReadChats, isEmpty);
    });

    test('a broken file reads as every switch off', () async {
      final container = create('not a map');
      await container.read(privacySettingsProvider.notifier).loaded;
      expect(container.read(privacySettingsProvider), const PrivacySettings());
    });
  });

  group('page and capsule', () {
    late MemoryPrivacySettingsStorage storage;
    var storedSize = 0;
    var cleared = 0;

    setUp(() {
      storedSize = 0;
      cleared = 0;
    });

    Future<ProviderContainer> pump(WidgetTester tester, Widget child) async {
      storage = MemoryPrivacySettingsStorage();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privacySettingsStorageProvider.overrideWithValue(storage),
            // No session: the switches only go to disk.
            telegramSessionProvider.overrideWith(
              (ref) => Completer<TelegramSession>().future,
            ),
            storedMessagesSizeProvider.overrideWith((ref) async => storedSize),
            clearStoredMessagesProvider.overrideWithValue(() async {
              cleared++;
              storedSize = 0;
            }),
          ],
          child: MaterialApp(
            theme: buildMgTheme(MgColors.light),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Material(child: child),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byWidget(child)));
    }

    bool switchOn(WidgetTester tester, String title) {
      final row = find.ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.toggled != null,
        ),
      );
      return (tester.widget<Semantics>(row.first)).properties.toggled!;
    }

    const titles = [
      "Don't send read receipts",
      "Don't show typing",
      'Stay offline',
      "Don't mark voice and video messages as played",
    ];

    testWidgets('every switch starts off', (tester) async {
      await pump(tester, const PrivacyExtrasPage());

      expect(switchOn(tester, 'Ghost mode'), isFalse);
      for (final title in titles) {
        expect(switchOn(tester, title), isFalse, reason: title);
      }
    });

    testWidgets('ghost mode flips every switch', (tester) async {
      final container = await pump(tester, const PrivacyExtrasPage());

      await tester.tap(find.text('Ghost mode'));
      await tester.pumpAndSettle();
      for (final title in titles) {
        expect(switchOn(tester, title), isTrue, reason: title);
      }
      expect(container.read(privacySettingsProvider).isGhost, isTrue);
      expect(PrivacySettings.fromJson(storage.saved).isGhost, isTrue);

      // One switch off is no longer ghost mode.
      await tester.tap(find.text('Stay offline'));
      await tester.pumpAndSettle();
      expect(switchOn(tester, 'Ghost mode'), isFalse);
      final mixed = container.read(privacySettingsProvider);
      expect(mixed.stayOffline, isFalse);
      expect(mixed.hideReadReceipts && mixed.hideTyping, isTrue);

      await tester.tap(find.text('Stay offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghost mode'));
      await tester.pumpAndSettle();
      expect(container.read(privacySettingsProvider), const PrivacySettings());
    });

    testWidgets('ghost mode off brings back the earlier mix', (tester) async {
      final container = await pump(tester, const PrivacyExtrasPage());

      await tester.tap(find.text("Don't show typing"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghost mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghost mode'));
      await tester.pumpAndSettle();

      final settings = container.read(privacySettingsProvider);
      expect(settings.hideTyping, isTrue);
      expect(settings.hideReadReceipts, isFalse);
      expect(settings.stayOffline, isFalse);
      expect(settings.hideContentOpened, isFalse);
      expect(switchOn(tester, "Don't show typing"), isTrue);
    });

    testWidgets('keeping messages is off by default and not ghost mode', (
      tester,
    ) async {
      final container = await pump(tester, const PrivacyExtrasPage());
      expect(switchOn(tester, 'Keep deleted messages'), isFalse);
      expect(switchOn(tester, 'Keep edit history'), isFalse);

      await tester.tap(find.text('Ghost mode'));
      await tester.pumpAndSettle();
      expect(switchOn(tester, 'Keep deleted messages'), isFalse);

      await tester.ensureVisible(find.text('Keep edit history'));
      await tester.tap(find.text('Keep edit history'));
      await tester.pumpAndSettle();
      final settings = container.read(privacySettingsProvider);
      expect(settings.keepEditHistory, isTrue);
      expect(settings.isGhost, isTrue);
      expect(PrivacySettings.fromJson(storage.saved).keepEditHistory, isTrue);
    });

    testWidgets('clears the stored data after asking', (tester) async {
      storedSize = 4200;
      await pump(tester, const PrivacyExtrasPage());
      final row = find.byKey(const ValueKey('clearStoredData'));
      await tester.ensureVisible(row);
      expect(find.text('4.2 KB'), findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Clear the deleted messages and edit history kept on this Mac?',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(cleared, 1);
    });

    testWidgets('each switch turns on only itself', (tester) async {
      final container = await pump(tester, const PrivacyExtrasPage());

      await tester.tap(find.text("Don't show typing"));
      await tester.pumpAndSettle();

      expect(
        container.read(privacySettingsProvider),
        const PrivacySettings(hideTyping: true),
      );
    });

    testWidgets('the capsule shows while any extra is on', (tester) async {
      var taps = 0;
      final capsule = GhostModeCapsule(onTap: () => taps++);
      final container = await pump(tester, Center(child: capsule));
      double opacity() => tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity;

      expect(opacity(), 0);
      expect(find.bySemanticsLabel('Ghost mode is on'), findsNothing);
      await tester.tap(find.byType(GhostModeCapsule), warnIfMissed: false);
      expect(taps, 0);

      // One extra on: the ghost shows, dimmed.
      container
          .read(privacySettingsProvider.notifier)
          .update((s) => s.copyWith(hideTyping: true));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(
        find.bySemanticsLabel('Some privacy extras are on'),
        findsOneWidget,
      );

      container.read(privacySettingsProvider.notifier).setGhost(true);
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      expect(find.bySemanticsLabel('Ghost mode is on'), findsOneWidget);
      await tester.tap(find.byType(GhostModeCapsule));
      expect(taps, 1);
    });
  });
}

Future<TdlibParameters> _parameters(TelegramApiConfig api) async =>
    TdlibParameters(
      api: api,
      databaseDirectory: '/tmp/mollygram/database',
      filesDirectory: '/tmp/mollygram/files',
      databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
      systemLanguageCode: 'en',
      deviceModel: 'Mac',
      applicationVersion: '0.1.0',
    );

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();

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
    final response = decoded['@type'] == 'getAuthorizationState'
        ? {'@type': 'authorizationStateWaitPhoneNumber'}
        : {'@type': 'ok'};
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
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
