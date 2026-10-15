import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

void main() {
  late WorkspaceController controller;
  final directory = MockChatDirectory();

  setUp(() => controller = WorkspaceController());
  tearDown(() => controller.dispose());

  Widget app({
    List<PaletteCommand> commands = const [],
    ShortcutResolver? shortcuts,
  }) {
    return WidgetsApp(
      color: const Color(0xFF0071E3),
      debugShowCheckedModeBanner: false,
      builder: (context, _) => DefaultTextStyle(
        style: const TextStyle(fontSize: 13, color: Color(0xFF000000)),
        child: WorkspaceShell(
          controller: controller,
          directory: directory,
          strings: ShellStrings.en,
          commands: commands,
          shortcuts: shortcuts,
          sidebarWidth: 320,
          sidebar: const SizedBox.expand(key: Key('sidebar')),
          paneBuilder: (context, chat, focused) => chat == null
              ? const EmptyPane(strings: ShellStrings.en)
              : Center(
                  child: Text(
                    'chat $chat${focused ? ' focused' : ''}',
                    key: ValueKey('chat $chat'),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> primary(WidgetTester tester, LogicalKeyboardKey key) async {
    final mod = usesCommandKey
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(mod);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(mod);
    await tester.pump();
  }

  Future<void> openPalette(WidgetTester tester) async {
    await primary(tester, LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(find.byType(CommandPalette), findsOneWidget);
  }

  Future<void> setUpWindow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pump();
  }

  testWidgets('starts with one empty pane and no tab strip', (tester) async {
    await setUpWindow(tester);
    expect(find.text('Select a chat'), findsOneWidget);
    expect(find.byType(TabStrip), findsNothing);
  });

  testWidgets('⌘K opens the palette without animation; Esc closes it', (
    tester,
  ) async {
    await setUpWindow(tester);
    await openPalette(tester);
    expect(find.text('Recent'), findsOneWidget);
    expect(
      find.textContaining('Anna Morris', findRichText: true),
      findsOneWidget,
    );
    // Opened on the first frame: nothing is scheduled.
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(CommandPalette), findsNothing);
  });

  testWidgets('⏎ opens the selected chat in the focused pane', (tester) async {
    await setUpWindow(tester);
    await openPalette(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.byType(CommandPalette), findsNothing);
    expect(controller.value.focusedChat, 2);
    expect(find.text('chat 2 focused'), findsOneWidget);
  });

  testWidgets('⌘⏎ opens in split view, ⌥⏎ in a new tab', (tester) async {
    await setUpWindow(tester);
    controller.open(1);
    await tester.pump();

    await openPalette(tester);
    await tester.enterText(find.byType(EditableText), '@vicky');
    await tester.pump();
    await tester.pump();
    final mod = usesCommandKey
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(mod);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(mod);
    await tester.pump();
    expect(controller.value.activeTab.panes, [1, 6]);
    expect(find.text('chat 1'), findsOneWidget);
    expect(find.text('chat 6 focused'), findsOneWidget);

    await openPalette(tester);
    await tester.enterText(find.byType(EditableText), 'adam');
    await tester.pump();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(controller.value.tabs, hasLength(2));
    expect(controller.value.focusedChat, 5);
    expect(find.byType(TabStrip), findsOneWidget);
    expect(find.text('Anna Morris · Vicky Stone'), findsOneWidget);
    expect(find.text('Adam Lewis'), findsOneWidget, reason: 'tab title');
  });

  testWidgets('> runs a command; app commands come first', (tester) async {
    var ran = false;
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        commands: [
          PaletteCommand(
            id: 'app.ghost',
            title: 'Ghost mode',
            run: () => ran = true,
          ),
        ],
      ),
    );
    await openPalette(tester);
    await tester.enterText(find.byType(EditableText), '>');
    await tester.pump();
    await tester.pump();
    expect(find.text('Ghost mode'), findsOneWidget);
    expect(find.text('Open second chat in split view'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(ran, isTrue);

    await openPalette(tester);
    await tester.enterText(find.byType(EditableText), '>split');
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(controller.value.activeTab.isSplit, isTrue);
  });

  testWidgets('nothing found', (tester) async {
    await setUpWindow(tester);
    await openPalette(tester);
    await tester.enterText(find.byType(EditableText), 'zzzz');
    await tester.pump();
    await tester.pump();
    expect(find.text('Nothing found'), findsOneWidget);
  });

  testWidgets('a click outside closes the palette', (tester) async {
    await setUpWindow(tester);
    await openPalette(tester);
    await tester.tapAt(const Offset(100, 800));
    await tester.pump();
    expect(find.byType(CommandPalette), findsNothing);
  });

  testWidgets('clicking a row opens it', (tester) async {
    await setUpWindow(tester);
    await openPalette(tester);
    await tester.tap(find.text('Dad'));
    await tester.pump();
    expect(controller.value.focusedChat, 3);
  });

  testWidgets('tab shortcuts', (tester) async {
    await setUpWindow(tester);
    controller
      ..open(1)
      ..open(2, target: OpenTarget.newTab)
      ..open(3, target: OpenTarget.newTab);
    await tester.pump();

    await primary(tester, LogicalKeyboardKey.digit1);
    expect(controller.value.active, 0);
    await primary(tester, LogicalKeyboardKey.digit9);
    expect(controller.value.active, 2);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(controller.value.active, 0);

    await primary(tester, LogicalKeyboardKey.keyT);
    expect(controller.value.tabs, hasLength(4));
    expect(controller.value.active, 1);

    await primary(tester, LogicalKeyboardKey.keyW);
    expect(controller.value.tabs, hasLength(3));

    await primary(tester, LogicalKeyboardKey.backslash);
    // Closing the new tab activated its right neighbour, chat 2.
    expect(controller.value.activeTab.panes, [2, null]);
    await primary(tester, LogicalKeyboardKey.keyW);
    expect(controller.value.activeTab.panes, [2]);
  });

  testWidgets('takes its keys from a resolver', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final keys = {
      for (final action in shellShortcutActions(ShellStrings.en))
        action.id: action.shortcut,
      // New tab moves to J; go to tab 1 has no key.
      'shell.newTab': primaryShortcut(LogicalKeyboardKey.keyJ),
      'shell.tab.1': null,
    };
    await tester.pumpWidget(app(shortcuts: (id) => keys[id]));
    await tester.pump();

    await primary(tester, LogicalKeyboardKey.keyT);
    expect(controller.value.tabs, hasLength(1));
    await primary(tester, LogicalKeyboardKey.keyJ);
    expect(controller.value.tabs, hasLength(2));
    expect(controller.value.active, 1);
    // Go to tab 1 has no key now; go to tab 2 keeps ⌘2.
    await primary(tester, LogicalKeyboardKey.digit1);
    expect(controller.value.active, 1);
    controller.selectTabByNumber(1);
    await tester.pump();
    expect(controller.value.active, 0);
    await primary(tester, LogicalKeyboardKey.digit2);
    expect(controller.value.active, 1);
  });

  test('lists every action that takes a key', () {
    final actions = shellShortcutActions(ShellStrings.ru);
    expect(
      actions.map((a) => a.id),
      containsAll(['shell.palette', 'shell.tab.9']),
    );
    expect(actions.first.keywords, [ShellStrings.en.palette]);
    expect(ShellStrings.ru.cmdTab(3), 'Перейти на вкладку 3');
    expect(shortcutKeyLabel(LogicalKeyboardKey.escape), isNotEmpty);
    // A key this version doesn't know still shows something.
    expect(
      shortcutKeyLabel(const LogicalKeyboardKey(0x1f0000ffff)),
      isNotEmpty,
    );
  });

  testWidgets('the tab strip selects and closes tabs', (tester) async {
    await setUpWindow(tester);
    controller
      ..open(1)
      ..open(2, target: OpenTarget.newTab);
    await tester.pump();

    await tester.tap(find.text('Anna Morris'));
    await tester.pump();
    expect(controller.value.active, 0);

    await tester.tap(find.bySemanticsLabel('Close tab').first);
    await tester.pump();
    expect(controller.value.tabs, hasLength(1));
    expect(controller.value.focusedChat, 2);
    expect(find.byType(TabStrip), findsNothing);

    await tester.pump();
  });

  testWidgets('dragging the divider resizes the split', (tester) async {
    await setUpWindow(tester);
    controller
      ..open(1)
      ..open(2, target: OpenTarget.split);
    await tester.pump();

    // Content is 1440 - 320 = 1120 wide; the divider sits in the middle.
    final divider = find.bySemanticsLabel('Split view divider');
    expect(divider, findsOneWidget);
    await tester.drag(divider, const Offset(-200, 0));
    await tester.pump();
    expect(controller.value.activeTab.split, lessThan(0.4));

    // A click in a pane focuses it.
    await tester.tap(find.byKey(const ValueKey('chat 1')));
    await tester.pump();
    expect(controller.value.activeTab.focus, 0);
    // Let the divider's double-tap timer run out.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shortcut labels follow the platform', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(shortcutLabel(ShellShortcuts.split), r'⌘\');
    expect(shortcutLabel(ShellShortcuts.nextTab), '⌃⇥');
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(shortcutLabel(ShellShortcuts.newTab), 'Ctrl+T');
    expect(shortcutLabel(ShellShortcuts.previousTab), 'Ctrl+Shift+Tab');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Russian strings', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF0071E3),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        builder: (context, _) => WorkspaceShell(
          controller: controller,
          directory: directory,
          paneBuilder: (context, chat, focused) =>
              const EmptyPane(strings: ShellStrings.ru),
        ),
      ),
    );
    await openPalette(tester);
    expect(find.text('Недавние'), findsOneWidget);
    expect(find.text('Команды'), findsOneWidget);
    expect(find.text('Открыть второй чат в сплите'), findsOneWidget);
  });

  testWidgets('hidden tabs keep their panes alive with tickers off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final created = <int>[];
    final visible = <int, bool>{};
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF0071E3),
        builder: (context, _) => WorkspaceShell(
          controller: controller,
          directory: directory,
          strings: ShellStrings.en,
          paneBuilder: (context, chat, focused) => chat == null
              ? const SizedBox()
              : _ProbePane(chat: chat, created: created, visible: visible),
        ),
      ),
    );
    controller
      ..open(1)
      ..open(2, target: OpenTarget.newTab);
    await tester.pump();
    expect(visible, {1: false, 2: true});

    controller.selectTab(0);
    await tester.pump();
    controller.selectTab(1);
    await tester.pump();
    // Each chat was built once: switching tabs did not recreate it.
    expect(created, [1, 2]);
    expect(visible, {1: false, 2: true});
  });

  testWidgets('tab titles follow a listenable directory', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final names = _RenamingDirectory();
    addTearDown(names.dispose);
    controller
      ..open(1)
      ..open(2, target: OpenTarget.newTab);
    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF0071E3),
        builder: (context, _) => WorkspaceShell(
          controller: controller,
          directory: names,
          strings: ShellStrings.en,
          paneBuilder: (context, chat, focused) => const SizedBox(),
        ),
      ),
    );
    expect(find.text('Anna Morris'), findsOneWidget);

    names.rename(1, 'Anna');
    await tester.pump();
    expect(find.text('Anna Morris'), findsNothing);
    expect(find.text('Anna'), findsOneWidget);
  });
}

class _ProbePane extends StatefulWidget {
  const _ProbePane({
    required this.chat,
    required this.created,
    required this.visible,
  });

  final int chat;
  final List<int> created;
  final Map<int, bool> visible;

  @override
  State<_ProbePane> createState() => _ProbePaneState();
}

class _ProbePaneState extends State<_ProbePane> {
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.chat);
  }

  @override
  Widget build(BuildContext context) {
    widget.visible[widget.chat] = TickerMode.valuesOf(context).enabled;
    return Text('chat ${widget.chat}');
  }
}

class _RenamingDirectory extends ChangeNotifier implements ChatDirectory {
  final _inner = MockChatDirectory();
  final _names = <int, String>{};

  void rename(int id, String title) {
    _names[id] = title;
    notifyListeners();
  }

  @override
  ChatSummary? chat(ChatId id) => switch (_inner.chat(id)) {
    final c? => ChatSummary(id: c.id, title: _names[id] ?? c.title),
    null => null,
  };

  @override
  List<ChatSummary> recentChats({int limit = 5}) =>
      _inner.recentChats(limit: limit);

  @override
  Future<List<ChatSummary>> searchChats(String query, {int limit = 8}) =>
      _inner.searchChats(query, limit: limit);

  @override
  Future<List<MessageHit>> searchMessages(String query, {int limit = 8}) =>
      _inner.searchMessages(query, limit: limit);
}
