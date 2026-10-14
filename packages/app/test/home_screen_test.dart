import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/home/home_screen.dart';
import 'package:mollygram/src/home/workspace.dart';
import 'package:mollygram/src/home/workspace_storage.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/plugins_page.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
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
    for (final (id, title) in [(1, 'Anna'), (2, 'Boris'), (3, 'Vera')]) {
      session.chatLists.store.upsert(
        ChatListEntry(
          id: id,
          title: title,
          unreadCount: 0,
          positions: [
            ChatListPosition(
              list: const ChatListLocation.main(),
              order: 100 - id,
              isPinned: false,
            ),
          ],
        ),
      );
    }
  });

  tearDown(() => session.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
  }

  late MemoryWorkspaceStorage storage;
  late Set<int> missingChats;

  setUp(() {
    storage = MemoryWorkspaceStorage();
    missingChats = {};
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Future<void>? beforeChatsLoad,
  }) async {
    tester.view
      ..physicalSize = const Size(1400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          workspaceStorageProvider.overrideWithValue(storage),
          chatLoaderProvider.overrideWithValue((id) async {
            await beforeChatsLoad;
            return !missingChats.contains(id);
          }),
          pluginsControllerProvider.overrideWith(
            (ref) => PluginsController(mockPlugins()),
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
    return ProviderScope.containerOf(tester.element(find.byType(_Host)));
  }

  Finder header(String title) => find.descendant(
    of: find.byType(ChatTitleCapsule),
    matching: find.text(title),
  );

  Finder row(String title) => find.descendant(
    of: find.byType(ChatListTile),
    matching: find.text(title),
  );

  testWidgets('a click opens the chat in the focused pane', (tester) async {
    final container = await pump(tester);
    expect(find.text('Select a chat to start messaging'), findsOneWidget);

    await tester.tap(row('Anna'));
    await settle(tester);
    expect(header('Anna'), findsOneWidget);

    await tester.tap(row('Boris'));
    await settle(tester);
    expect(header('Anna'), findsNothing);
    expect(header('Boris'), findsOneWidget);
    expect(container.read(workspaceControllerProvider).value.focusedChat, 2);
  });

  testWidgets('a primary-click opens the chat beside the current one', (
    tester,
  ) async {
    final container = await pump(tester);
    await tester.tap(row('Anna'));
    await settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(row('Boris'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);

    expect(header('Anna'), findsOneWidget);
    expect(header('Boris'), findsOneWidget);
    final tab = container.read(workspaceControllerProvider).value.activeTab;
    expect(tab.panes, [1, 2]);
  });

  testWidgets('an alt-click opens a tab and shows the tab strip', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(row('Anna'));
    await settle(tester);
    expect(find.byType(TabStrip), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.tap(row('Vera'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);

    expect(find.byType(TabStrip), findsOneWidget);
    expect(header('Vera'), findsOneWidget);
  });

  testWidgets('a draft survives switching tabs', (tester) async {
    final composer = find.descendant(
      of: find.byType(Composer),
      matching: find.byType(TextField),
    );
    await pump(tester);
    await tester.tap(row('Anna'));
    await settle(tester);
    await tester.enterText(composer, 'Half a thought');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.tap(row('Vera'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    expect(header('Vera'), findsOneWidget);

    await tester.tap(row('Anna'));
    await settle(tester);
    expect(header('Anna'), findsOneWidget);
    final field = tester.widget<TextField>(composer);
    expect(field.controller!.text, 'Half a thought');
  });

  testWidgets('the palette lists recent chats and opens one', (tester) async {
    final container = await pump(tester);
    await tester.tap(row('Boris'));
    await settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byType(CommandPalette), findsOneWidget);
    // The chat opened last comes first.
    final recent = find.descendant(
      of: find.byType(CommandPalette),
      matching: find.byType(MonogramAvatar),
    );
    expect(tester.widget<MonogramAvatar>(recent.first).name, 'Boris');

    await tester.tap(
      find.descendant(
        of: find.byType(CommandPalette),
        matching: find.text('Vera'),
      ),
    );
    await settle(tester);
    expect(find.byType(CommandPalette), findsNothing);
    expect(container.read(workspaceControllerProvider).value.focusedChat, 3);
  });

  testWidgets('the shortcut opens the plugins and Esc closes them', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(row('Anna'));
    await settle(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(tester);
    expect(find.byType(PluginsScreen), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byType(PluginsScreen), findsNothing);
    // The chat is still where it was.
    expect(header('Anna'), findsOneWidget);
  });

  testWidgets('saves the layout and restores it without lost chats', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(row('Anna'));
    await settle(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.tap(row('Vera'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await settle(tester);
    // Saves are batched.
    await tester.pump(const Duration(seconds: 1));
    final saved = Workspace.fromJson(storage.saved);
    expect(
      [for (final t in saved.tabs) t.panes],
      [
        [1],
        [3],
      ],
    );

    // Next launch: Vera's chat is gone.
    missingChats.add(3);
    await tester.pumpWidget(const SizedBox());
    final container = await pump(tester);
    final restored = container.read(workspaceControllerProvider).value;
    expect(
      [for (final t in restored.tabs) t.panes],
      [
        [1],
        [null],
      ],
    );
  });

  testWidgets('restores the saved layout on start', (tester) async {
    storage.saved = Workspace.initial().open(3).toJson();
    final container = await pump(tester);
    expect(container.read(workspaceControllerProvider).value.focusedChat, 3);
    expect(header('Vera'), findsOneWidget);
  });

  testWidgets('a chat opened before the layout loads wins', (tester) async {
    storage.saved = Workspace.initial().open(3).toJson();
    final loading = Completer<void>();
    final container = await pump(tester, beforeChatsLoad: loading.future);
    await tester.tap(row('Anna'));
    await settle(tester);
    loading.complete();
    await settle(tester);
    expect(container.read(workspaceControllerProvider).value.focusedChat, 1);
  });

  test('recent chats put the ones opened here first', () {
    final directory = TelegramChatDirectory(
      session.chatLists.store,
      session.search,
    )..noteOpened(3);
    expect(
      [for (final c in directory.recentChats()) c.title],
      ['Vera', 'Anna', 'Boris'],
    );
    expect(directory.chat(99), isNull);
  });
}

const _tick = Duration(milliseconds: 20);

/// Shows the window once the session is up, as the app does.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue
      ? const HomeScreen()
      : const SizedBox();
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  var _nextClientId = 0;

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
    final response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getChatHistory' => {
        '@type': 'messages',
        'total_count': 0,
        'messages': <Object?>[],
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
