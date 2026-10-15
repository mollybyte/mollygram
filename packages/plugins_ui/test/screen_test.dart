import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';

import 'controller_test.dart' show RecordingDelegate;

Future<PluginsController> pumpScreen(
  WidgetTester tester, {
  String locale = 'en',
  Brightness brightness = Brightness.light,
  String? selected,
  PluginsDelegate? delegate,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final builtins = await tester.runAsync(loadBuiltinPlugins);
  final controller = PluginsController(
    [for (final b in builtins!) b.entry, ...mockPlugins(now: DateTime.now())],
    selected: selected,
    delegate: delegate,
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(1440, 900)),
        child: PluginsScreen(
          controller: controller,
          locale: locale,
          brightness: brightness,
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('lists installed and available plugins', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    // The selected plugin's name also shows as the pane title.
    expect(find.text('Filters'), findsNWidgets(2));
    expect(find.text('Code highlighting'), findsOneWidget);
    expect(find.text('Link cards'), findsOneWidget);
    // Quiet hours is installed but turned off.
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('built-in plugin: access, options, no uninstall', (tester) async {
    await pumpScreen(tester, selected: 'dev.mollygram.filters');
    expect(find.text('Built-in plugin · 1.0.0'), findsOneWidget);
    expect(find.text('All messages'), findsOneWidget);
    expect(find.text('Filter advertising'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);
    expect(find.text('Uninstall plugin…'), findsNothing);
  });

  testWidgets('picking a plugin shows its commands and manifest', (
    tester,
  ) async {
    final c = await pumpScreen(tester);
    await tester.tap(find.byKey(const ValueKey('item:dev.tgplug.summary')));
    await tester.pumpAndSettle();
    expect(c.selected?.id, 'dev.tgplug.summary');
    expect(find.text('/summary'), findsOneWidget);
    expect(find.text('⌘⇧S'), findsOneWidget);
    expect(find.text('Updated 3 days ago'), findsOneWidget);
    expect(find.text('Version 2.4.0 asks for more access'), findsOneWidget);
    expect(find.textContaining('id: dev.tgplug.summary'), findsNothing);
    await tester.tap(find.text('Manifest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('id: dev.tgplug.summary'), findsOneWidget);
  });

  testWidgets('a switch turns the plugin off', (tester) async {
    final c = await pumpScreen(tester, selected: 'dev.mollygram.filters');
    await tester.tap(find.bySemanticsLabel('Enable plugin'));
    await tester.pumpAndSettle();
    expect(c.entry('dev.mollygram.filters')!.active, isFalse);
    expect(find.text('off'), findsNWidgets(2));
  });

  testWidgets('select setting opens a menu and applies the choice', (
    tester,
  ) async {
    final c = await pumpScreen(tester, selected: 'dev.mollygram.filters');
    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hide').last);
    await tester.pumpAndSettle();
    expect(c.entry('dev.mollygram.filters')!.setting('mode'), 'hide');
    expect(find.text('Collapse'), findsNothing);
  });

  testWidgets('text setting is saved on Enter', (tester) async {
    final c = await pumpScreen(tester, selected: 'dev.mollygram.filters');
    final field = find.descendant(
      of: find.byKey(const ValueKey('setting:keywords')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field, 'crypto, nft');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      c.entry('dev.mollygram.filters')!.setting('keywords'),
      'crypto, nft',
    );
  });

  testWidgets('installing shows consent with a warning for all messages', (
    tester,
  ) async {
    final delegate = RecordingDelegate();
    final c = await pumpScreen(
      tester,
      selected: 'io.graphy.stats',
      delegate: delegate,
    );
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('Install “Chat statistics”?'), findsOneWidget);
    expect(find.textContaining('can read all your messages'), findsOneWidget);
    await tester.tap(find.text('Install').last);
    await tester.pumpAndSettle();
    expect(c.entry('io.graphy.stats')!.installed, isTrue);
    expect(delegate.calls, ['install io.graphy.stats']);
    expect(find.text('Uninstall plugin…'), findsOneWidget);
  });

  testWidgets('cancel leaves the plugin uninstalled', (tester) async {
    final c = await pumpScreen(tester, selected: 'dev.unfurl.cards');
    await tester.tap(find.text('Install'));
    await tester.pumpAndSettle();
    expect(find.text('github.com, figma.com, youtube.com'), findsNWidgets(2));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.consent, isNull);
    expect(c.entry('dev.unfurl.cards')!.installed, isFalse);
  });

  testWidgets('update review lists only the new access', (tester) async {
    await pumpScreen(tester, selected: 'dev.tgplug.summary');
    await tester.tap(find.text('Review…'));
    await tester.pumpAndSettle();
    expect(find.text('“Summary” 2.4.0 asks for more access'), findsOneWidget);
    expect(find.text('New access in this version:'), findsOneWidget);
    expect(find.text('Composer'), findsOneWidget);
    // Storage was already granted, so the sheet does not repeat it.
    expect(find.text('Up to 5 MB'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('search')),
        matching: find.byType(EditableText),
      ),
      'zzz',
    );
    await tester.pump();
    expect(find.text('No plugins found'), findsOneWidget);
  });

  testWidgets('Russian texts, including built-in plugins', (tester) async {
    await pumpScreen(tester, locale: 'ru', selected: 'dev.mollygram.filters');
    expect(find.text('Установленные'), findsOneWidget);
    expect(find.text('Фильтры'), findsNWidgets(2));
    expect(find.text('Подсветка кода'), findsOneWidget);
    expect(find.text('Встроенный плагин · 1.0.0'), findsOneWidget);
    expect(find.text('Все сообщения'), findsOneWidget);
    expect(find.text('Фильтровать рекламу'), findsOneWidget);
    expect(find.text('Сворачивать'), findsOneWidget);
  });

  testWidgets('switching the language updates the open screen', (tester) async {
    final c = await pumpScreen(tester);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: PluginsScreen(controller: c, locale: 'ru'),
      ),
    );
    expect(find.text('Установленные'), findsOneWidget);
  });

  testWidgets('dark theme renders', (tester) async {
    await pumpScreen(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
