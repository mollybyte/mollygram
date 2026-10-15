import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/commands/command_registry.dart';
import 'package:mollygram/src/home/workspace.dart';
import 'package:mollygram/src/plugins/app_plugins.dart';
import 'package:mollygram/src/plugins/message_hooks.dart';
import 'package:mollygram/src/plugins/plugin_commands.dart';
import 'package:mollygram/src/plugins/plugin_store.dart';
import 'package:mollygram/src/settings/plugins_page.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:plugin_host/plugin_host.dart';

/// Our own plugin, as the app bundles it.
BuiltinPlugin _builtin(String dir) {
  final path = '../plugin_host/builtin/$dir';
  return BuiltinPlugin(
    PluginEntry.parse(
      File('$path/manifest.yaml').readAsStringSync(),
      builtIn: true,
    ),
    File('$path/index.js').readAsStringSync(),
  );
}

/// A plugin the user installed: [source] runs in a real worker.
StoredBundle _bundle(String source, {String extra = ''}) => StoredBundle(
  id: 'dev.example.hostile',
  manifestSource:
      '''
id: dev.example.hostile
name: Hostile
version: 1.0.0
runtime: js
sdk: ^1.1
permissions:
  messages.read: all
hooks:
  - message.filter
$extra'''
          .trim(),
  source: source,
);

PluginMessage _message(String text, {int id = 1, bool outgoing = false}) => (
  chatId: 7,
  id: id,
  senderId: 3,
  date: 1700000000,
  text: text,
  outgoing: outgoing,
);

ConversationMessage _conversationMessage(String text, {int id = 1}) =>
    ConversationMessage(
      td.Message.fromJson({
        '@type': 'message',
        'id': id,
        'sender_id': {'@type': 'messageSenderUser', 'user_id': 3},
        'chat_id': 7,
        'date': 1700000000,
        'content': {
          '@type': 'messageText',
          'text': {
            '@type': 'formattedText',
            'text': text,
            'entities': <Object?>[],
          },
        },
      }),
    );

const _ad = 'New course, sign up today. erid: 2VtzqwXyZ12';
const _german = 'Ich weiß nicht, ob wir heute auch mit dir kommen.';

void main() {
  late Directory temp;
  late MemoryPluginStore store;
  late List<(int, int, String)> translated;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugin_hooks');
    store = MemoryPluginStore(data: temp);
    translated = [];
  });
  tearDown(() => temp.delete(recursive: true));

  Future<AppPlugins> load({
    List<String> builtin = const ['filters', 'translate'],
    StoredBundle? installed,
    PluginLauncher? launch,
  }) async {
    if (installed != null) {
      store.bundles[installed.id] = installed;
    }
    final plugins = await AppPlugins.load(
      store: store,
      builtin: [for (final b in builtin) _builtin(b)],
      locale: 'en',
      launch: launch ?? launchInWorker,
      translate: (chat, message, to) async {
        translated.add((chat, message, to));
        return 'I do not know if we are coming with you today.';
      },
    );
    addTearDown(plugins.dispose);
    return plugins;
  }

  group('Filters', () {
    test('collapses advertising with the reason, shows the rest', () async {
      final plugins = await load();
      final verdict = await plugins.filterMessage(_message(_ad));
      expect(verdict?.verdict, FilterVerdict.collapse);
      expect(verdict?.reason, 'Advertising');
      expect(await plugins.filterMessage(_message('See you at 6')), isNull);
    });

    test('an edited message is asked about again', () async {
      final plugins = await load(builtin: ['filters']);
      expect(await plugins.filterMessage(_message(_ad)), isNotNull);
      expect(
        await plugins.filterMessage(_message('Course moved to 6')),
        isNull,
      );
    });

    test('hides instead when set so, and turning it off shows all', () async {
      final plugins = await load();
      await plugins.controller.setSetting(
        'dev.mollygram.filters',
        'mode',
        'hide',
      );
      final hidden = await plugins.filterMessage(_message(_ad));
      expect(hidden?.verdict, FilterVerdict.hide);

      await plugins.controller.setEnabled('dev.mollygram.filters', false);
      expect(await plugins.filterMessage(_message(_ad)), isNull);
    });
  });

  group('Translate', () {
    test(
      'offers a translation, translates on a click and remembers it',
      () async {
        final plugins = await load(builtin: ['translate']);
        final m = _message(_german);
        final blocks = await plugins.renderText(m);
        final button = blocks.single.ui.single;
        expect(button['label'], 'Translate from German');
        expect(translated, isEmpty);

        final ui = await plugins.action(
          blocks.single.pluginId,
          button['action']! as String,
          button['payload'],
          m,
        );
        expect(translated, [(7, 1, 'en')]);
        expect(
          ui!.first['text'],
          'I do not know if we are coming with you today.',
        );

        // Kept in the plugin's storage: shown at once next time.
        final again = await plugins.renderText(m);
        expect(again.single.ui.first['text'], ui.first['text']);
        expect(translated, hasLength(1));
        expect(
          File('${temp.path}/dev.mollygram.translate.json').existsSync(),
          isTrue,
        );
      },
    );

    test('leaves the app language and short texts alone', () async {
      final plugins = await load(builtin: ['translate']);
      expect(
        await plugins.renderText(_message('See you tomorrow at the station')),
        isEmpty,
      );
      expect(await plugins.renderText(_message('Danke!')), isEmpty);
    });
  });

  test('uninstalling deletes what the plugin stored', () async {
    final plugins = await load(builtin: const [], installed: _bundle(''));
    final file = File('${temp.path}/dev.example.hostile.json');
    await AppPluginServices(storage: PluginStorage(temp)).call(
      'dev.example.hostile',
      'storage.set',
      {'key': 'k', 'value': 1, 'quota': 1024},
    );
    expect(file.existsSync(), isTrue);
    await plugins.uninstall(plugins.controller.entry('dev.example.hostile')!);
    await pumpEventQueue();
    expect(file.existsSync(), isFalse);
  });

  group('hostile plugins', () {
    test(
      'one that cannot start is tried less often, then turned off',
      () async {
        var attempts = 0;
        final plugins = await load(
          builtin: const [],
          installed: _bundle(''),
          launch:
              (
                m,
                source, {
                required settings,
                required locale,
                required services,
              }) async {
                attempts++;
                throw StateError('no isolate');
              },
        );
        plugins.retryDelay = const Duration(milliseconds: 20);
        await plugins.filterMessage(_message('a', id: 1));
        // Within the wait it is not tried again.
        await plugins.filterMessage(_message('b', id: 2));
        expect(attempts, 1);
        for (var i = 3; attempts < 3 && i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          await plugins.filterMessage(_message('c', id: i));
        }
        expect(attempts, 3);
        final entry = plugins.controller.entry('dev.example.hostile')!;
        expect(entry.disabledReason, contains('no isolate'));
        await plugins.filterMessage(_message('d', id: 99));
        expect(attempts, 3);
      },
    );

    test('an endless loop is turned off with the reason shown', () async {
      final plugins = await load(
        builtin: const [],
        installed: _bundle('mg.on("message.filter", () => { for (;;) {} })'),
      );
      for (var i = 0; i < 3; i++) {
        expect(await plugins.filterMessage(_message('hi', id: i)), isNull);
      }
      await pumpEventQueue();
      final entry = plugins.controller.entry('dev.example.hostile')!;
      expect(entry.disabledReason, contains('exceeded the time limit'));
      expect(
        plugins.logsOf('dev.example.hostile').last,
        startsWith('disabled: 3 failures in a row'),
      );
      // It is not asked again.
      expect(await plugins.filterMessage(_message('hi', id: 9)), isNull);
    });

    test('a filter answering garbage is ignored', () async {
      final plugins = await load(
        builtin: const ['filters'],
        installed: _bundle('mg.on("message.filter", () => [1, {}, "hide"])'),
      );
      expect(await plugins.filterMessage(_message('hello there')), isNull);
      // Others still filter.
      expect(
        (await plugins.filterMessage(_message(_ad)))?.reason,
        'Advertising',
      );
      expect(
        plugins.logsOf('dev.example.hostile'),
        contains(startsWith('error: invalid filter result')),
      );
    });

    test('storage past the limit fails with quota_exceeded', () async {
      final services = AppPluginServices(storage: PluginStorage(temp));
      Future<Object?> set(String key, int size) => services.call(
        'dev.example.hostile',
        'storage.set',
        {'key': key, 'value': 'x' * size, 'quota': 1024},
      );
      await set('a', 500);
      await expectLater(
        set('b', 600),
        throwsA(
          isA<HostError>().having((e) => e.code, 'code', 'quota_exceeded'),
        ),
      );
    });
  });

  test('plugin commands are in the palette and run', () async {
    final plugins = await load(
      builtin: const [],
      installed: _bundle(
        'mg.command("/count", async () => { await mg.messages.history(7, {}); })',
        extra: 'commands:\n  - { name: /count, title: Count messages }',
      ),
    );
    final workspace = WorkspaceController();
    final container = ProviderContainer(
      overrides: [
        appPluginsProvider.overrideWith((ref) async => plugins),
        workspaceControllerProvider.overrideWithValue(workspace),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appPluginsProvider.future);
    final sub = container.listen(pluginCommandsProvider, (_, _) {});
    addTearDown(sub.close);

    final registry = container.read(commandRegistryProvider);
    final command = registry.commandsOf('plugins').single;
    expect(command.title, 'Count messages');
    expect(command.subtitle, 'Hostile');

    command.run();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // The command ran; history is not offered, so it says so in the log.
    expect(
      plugins.logsOf('dev.example.hostile').join('\n'),
      contains('/count'),
    );

    await plugins.controller.setEnabled('dev.example.hostile', false);
    expect(registry.commandsOf('plugins'), isEmpty);
  });

  testWidgets('a collapsed message shows its reason and opens on a click', (
    tester,
  ) async {
    final plugins = (await tester.runAsync(() => load(builtin: ['filters'])))!;
    // The verdict is known before the widget asks.
    await tester.runAsync(
      () => plugins.filterMessage(pluginMessageOf(_conversationMessage(_ad))!),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPluginsProvider.overrideWith((ref) async => plugins)],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Material(child: _Filtered()),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.text('Advertising'), findsOneWidget);
    expect(find.text('the message'), findsNothing);

    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(find.text('the message'), findsOneWidget);
  });

  testWidgets('Translate shows its button under a message and the result', (
    tester,
  ) async {
    final plugins = (await tester.runAsync(
      () => load(builtin: ['translate']),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPluginsProvider.overrideWith((ref) async => plugins)],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Material(
            child: PluginMessageExtras(message: _conversationMessage(_german)),
          ),
        ),
      ),
    );
    // Waits for the worker, up to a few seconds on a busy machine.
    Future<void> settle(Finder until) async {
      for (var i = 0; i < 200 && until.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
    }

    await settle(find.text('Translate from German'));
    await tester.tap(find.text('Translate from German'));
    await settle(find.text('I do not know if we are coming with you today.'));
    expect(
      find.text('I do not know if we are coming with you today.'),
      findsOneWidget,
    );
    expect(find.text('Translated from German'), findsOneWidget);
    expect(find.text('Hide translation'), findsOneWidget);
  });

  testWidgets('the log page lists what the plugin logged', (tester) async {
    final plugins = (await tester.runAsync(
      () => load(
        builtin: const [],
        installed: _bundle(
          'mg.on("message.filter", () => { console.warn("checked"); })',
        ),
      ),
    ))!;
    await tester.runAsync(() => plugins.filterMessage(_message('hello')));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPluginsProvider.overrideWith((ref) async => plugins)],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          home: const Material(child: PluginLogPage(id: 'dev.example.hostile')),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(find.text('warn: checked'), findsOneWidget);
    expect(find.byKey(const ValueKey('copyLog')), findsOneWidget);
  });

  testWidgets('hidden messages leave the list, unknown ones wait unseen', (
    tester,
  ) async {
    final plugins = (await tester.runAsync(() => load(builtin: ['filters'])))!;
    await tester.runAsync(
      () => plugins.controller.setSetting(
        'dev.mollygram.filters',
        'mode',
        'hide',
      ),
    );
    final messages = [
      _conversationMessage('Hello there, friend', id: 1),
      _conversationMessage(_ad, id: 2),
      _conversationMessage('See you at six', id: 3),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPluginsProvider.overrideWith((ref) async => plugins)],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Material(
            child: PluginVerdicts(
              child: Builder(
                builder: (context) => Column(
                  children: [
                    for (final m in PluginVerdicts.visible(context, messages))
                      PluginFilteredMessage(message: m, child: Text(m.text)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Asked, not answered yet: in place but not drawn.
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      findsWidgets,
    );
    final unseen = find.byWidgetPredicate(
      (w) => w is Opacity && w.opacity == 0,
    );
    for (var i = 0; i < 200 && unseen.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      // The answers are announced together, a frame later.
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text(_ad), findsNothing);
    expect(find.text('Hello there, friend'), findsOneWidget);
    expect(find.text('See you at six'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0),
      findsNothing,
    );
  });
}

class _Filtered extends StatelessWidget {
  const _Filtered();

  @override
  Widget build(BuildContext context) => PluginFilteredMessage(
    message: _conversationMessage(_ad),
    child: const Text('the message'),
  );
}
