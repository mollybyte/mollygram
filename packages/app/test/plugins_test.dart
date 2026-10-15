import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/chat/formatted_text.dart';
import 'package:mollygram/src/plugins/app_plugins.dart';
import 'package:mollygram/src/plugins/code_highlight.dart';
import 'package:mollygram/src/plugins/plugin_store.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:plugin_host/plugin_host.dart';

const _highlighter = '''
id: dev.mollygram.codehighlight
name: Code highlight
version: 1.0.0
runtime: js
sdk: ^1.0
hooks: [message.render.code]
''';

String _manifest(String version, {String permissions = ''}) =>
    '''
id: dev.example.stats
name: Chat statistics
version: $version
author: graphy
runtime: js
sdk: ^1.0
${permissions.isEmpty ? '' : 'permissions:\n$permissions'}
''';

/// Colors "final" as a keyword and leaves the rest plain; a [lie] answers
/// with text that is not the code.
final class _FakePlugin implements RunningPlugin {
  _FakePlugin({this.lie = false, this.disabledReason, this.fails = false});

  final bool lie;

  /// Throws from dispatch, as a dead isolate would.
  final bool fails;
  final dispatched = <Map<String, Object?>>[];
  final status = StreamController<PluginStatus>.broadcast();
  var stopped = false;

  void close() => unawaited(status.close());

  @override
  Future<EventOutcome> dispatch(PluginEvent e, Map<String, Object?> p) async {
    dispatched.add(p);
    if (fails) throw StateError('worker exited');
    final code = p['code']! as String;
    if (lie) {
      return EventHandled(
        payload: p,
        ui: const [
          {
            'type': 'code',
            'spans': [
              {'text': 'something else', 'token': 'plain'},
            ],
          },
        ],
      );
    }
    final spans = [
      for (final (i, word) in code.split(' ').indexed) ...[
        if (i > 0) {'text': ' ', 'token': 'plain'},
        {'text': word, 'token': word == 'final' ? 'keyword' : 'plain'},
      ],
    ];
    return EventHandled(
      payload: p,
      ui: [
        {'type': 'code', 'spans': spans},
      ],
    );
  }

  @override
  Future<void> updateSetting(String key, Object? value) async {}
  @override
  Stream<PluginStatus> get statusChanges => status.stream;
  @override
  String? disabledReason;
  @override
  void stop() => stopped = true;
}

void main() {
  late Directory temp;
  late MemoryPluginStore store;
  late List<_FakePlugin> launched;
  late bool lie;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('plugins_test');
    store = MemoryPluginStore();
    launched = [];
    lie = false;
  });
  tearDown(() => temp.delete(recursive: true));

  Future<Directory> bundle(String manifest) async {
    final dir = await Directory('${temp.path}/b${temp.listSync().length}')
        .create();
    await File('${dir.path}/manifest.yaml').writeAsString(manifest);
    await File('${dir.path}/index.js').writeAsString('// code');
    return dir;
  }

  File? manifestOf(Directory? dir) =>
      dir == null ? null : File('${dir.path}/manifest.yaml');

  Future<AppPlugins> load({
    Directory? picked,
    String? loadError,
    bool fails = false,
  }) => AppPlugins.load(
    store: store,
    builtin: [
      BuiltinPlugin(
        PluginEntry.parse(_highlighter, builtIn: true),
        'highlighter source',
      ),
    ],
    launch: (m, source, {required settings, required locale}) async {
      final p = _FakePlugin(lie: lie, disabledReason: loadError, fails: fails);
      addTearDown(p.close);
      launched.add(p);
      return p;
    },
    pick: () async => manifestOf(picked),
    locale: 'en',
  );

  group('AppPlugins', () {
    test('installs a picked folder after consent and keeps it', () async {
      final dir = await bundle(
        _manifest('1.0.0', permissions: '  storage: 1mb'),
      );
      final plugins = await load(picked: dir);
      final c = plugins.controller;

      await c.installFromFile();
      expect(c.consent?.entry.id, 'dev.example.stats');
      // Nothing is copied before the user allows it.
      expect(store.bundles, isEmpty);

      await c.allowConsent();
      await plugins.flush();
      expect(store.bundles['dev.example.stats']?.source, '// code');
      expect(store.states['dev.example.stats']?.enabled, isTrue);

      // The copy survives the original folder.
      await dir.delete(recursive: true);
      final again = await load();
      final entry = again.controller.entry('dev.example.stats')!;
      expect(entry.installed, isTrue);
      expect(entry.updatedAt, isNotNull);
    });

    test('an update that asks for more runs only once allowed', () async {
      final plugins = await load(picked: await bundle(_manifest('1.0.0')));
      final c = plugins.controller;
      await c.installFromFile();
      expect(c.entry('dev.example.stats')!.installed, isTrue);

      final next = await bundle(
        _manifest('1.1.0', permissions: '  net: [api.example.com]'),
      );
      final updated = await AppPlugins.load(
        store: store,
        builtin: const [],
        pick: () async => manifestOf(next),
      );
      final u = updated.controller;
      await u.installFromFile();
      expect(u.consent?.isUpdate, isTrue);
      expect(
        store.bundles['dev.example.stats']!.manifestSource,
        contains('1.0.0'),
      );

      await u.allowConsent();
      expect(
        store.bundles['dev.example.stats']!.manifestSource,
        contains('1.1.0'),
      );
    });

    test('settings and turning off are kept', () async {
      final plugins = await load();
      await plugins.controller.setEnabled('dev.mollygram.codehighlight', false);
      await plugins.flush();
      final again = await load();
      expect(
        again.controller.entry('dev.mollygram.codehighlight')!.active,
        isFalse,
      );
    });

    test('code is highlighted by a plugin started on first use', () async {
      final plugins = await load();
      expect(launched, isEmpty);
      final spans = await plugins.highlightCode('final x', 'dart');
      expect(spans, [
        (text: 'final', token: 'keyword'),
        (text: ' ', token: 'plain'),
        (text: 'x', token: 'plain'),
      ]);
      expect(launched.single.dispatched.single, {
        'code': 'final x',
        'language': 'dart',
      });

      // Answered from the cache the second time.
      await plugins.highlightCode('final x', 'dart');
      expect(launched.single.dispatched, hasLength(1));
    });

    test('a turned off plugin is stopped and not asked', () async {
      final plugins = await load();
      await plugins.highlightCode('final x', null);
      await plugins.controller.setEnabled('dev.mollygram.codehighlight', false);
      await Future<void>.delayed(Duration.zero);
      expect(launched.single.stopped, isTrue);
      expect(await plugins.highlightCode('final y', null), isNull);
      expect(launched, hasLength(1));
    });

    test('a plugin that fails to load is marked at once', () async {
      final plugins = await load(loadError: 'load error: SyntaxError');
      expect(await plugins.highlightCode('final x', null), isNull);
      final entry = plugins.controller.entry('dev.mollygram.codehighlight')!;
      expect(entry.disabledReason, 'load error: SyntaxError');
      expect(launched.single.stopped, isTrue);
    });

    test('a plugin that throws leaves the block plain', () async {
      final plugins = await load(fails: true);
      expect(await plugins.highlightCode('final x', null), isNull);
    });

    test('uninstalled and installed again, the same code is used', () async {
      final v1 = await bundle(_manifest('1.0.0'));
      final plugins = await load(picked: v1);
      final c = plugins.controller;
      await c.installFromFile();
      await c.uninstall('dev.example.stats');
      expect(store.bundles, isEmpty);
      expect(c.entry('dev.example.stats')!.installed, isFalse);

      c.requestInstall('dev.example.stats');
      expect(c.entry('dev.example.stats')!.installed, isTrue);
      expect(
        store.bundles['dev.example.stats']!.manifestSource,
        contains('1.0.0'),
      );
    });

    test('a bundle the user did not approve is never written', () async {
      final v1 = await bundle(_manifest('1.0.0'));
      final v2 = await bundle(
        _manifest('2.0.0', permissions: '  net: [api.example.com]'),
      );
      var picked = v1;
      final plugins = await AppPlugins.load(
        store: store,
        builtin: const [],
        pick: () async => manifestOf(picked),
      );
      final c = plugins.controller;
      await c.installFromFile();
      picked = v2;
      await c.installFromFile();
      c.cancelConsent();
      await c.uninstall('dev.example.stats');

      // Reinstalling asks for v1 and writes v1, not the declined v2.
      c.requestInstall('dev.example.stats');
      expect(
        store.bundles['dev.example.stats']!.manifestSource,
        contains('1.0.0'),
      );
    });

    test('a failed copy is reported and nothing is installed', () async {
      store.failWrites = true;
      final plugins = await load(picked: await bundle(_manifest('1.0.0')));
      final c = plugins.controller;
      await c.installFromFile();
      await Future<void>.delayed(Duration.zero);
      expect(c.entry('dev.example.stats')!.installed, isFalse);
      expect(c.installFailure?.problem, InstallProblem.notSaved);
    });

    test('only a manifest.yaml is accepted', () async {
      final dir = await bundle(_manifest('1.0.0'));
      final other = File('${dir.path}/plugin.yaml')..writeAsStringSync('x');
      final plugins = await AppPlugins.load(
        store: store,
        builtin: const [],
        pick: () async => other,
      );
      await plugins.controller.installFromFile();
      expect(
        plugins.controller.installFailure?.problem,
        InstallProblem.invalid,
      );
    });

    test('spans that change the code are ignored', () async {
      lie = true;
      final plugins = await load();
      expect(await plugins.highlightCode('final x', null), isNull);
    });

    test('a plugin the host disables is marked on its page', () async {
      final plugins = await load();
      await plugins.highlightCode('final x', null);
      launched.single
        ..disabledReason = '3 failures in a row'
        ..status.add(PluginStatus.disabled);
      await Future<void>.delayed(Duration.zero);
      final entry = plugins.controller.entry('dev.mollygram.codehighlight')!;
      expect(entry.disabledReason, '3 failures in a row');
      expect(launched.single.stopped, isTrue);
    });
  });

  group('FilePluginStore', () {
    test('replaces a copy and skips folders that hold another id', () async {
      final files = FilePluginStore(Directory('${temp.path}/store'));
      await files.writeBundle(
        StoredBundle(
          id: 'dev.example.stats',
          manifestSource: _manifest('1.0.0'),
          source: 'v1',
        ),
      );
      await files.writeBundle(
        StoredBundle(
          id: 'dev.example.stats',
          manifestSource: _manifest('1.1.0'),
          source: 'v2',
        ),
      );
      // A folder named after a built-in, holding something else.
      await files.writeBundle(
        StoredBundle(
          id: 'dev.mollygram.filters',
          manifestSource: _manifest('9.0.0'),
          source: 'x',
        ),
      );
      final bundles = await files.readBundles();
      expect(bundles.single.id, 'dev.example.stats');
      expect(bundles.single.source, 'v2');
    });

    test('keeps an unreadable state file aside', () async {
      final dir = await Directory('${temp.path}/store').create();
      File('${dir.path}/state.json').writeAsStringSync('{broken');
      final files = FilePluginStore(dir);
      expect(await files.readStates(), isEmpty);
      expect(File('${dir.path}/state.json.bak').readAsStringSync(), '{broken');
    });
  });

  testWidgets('code blocks in messages are colored', (tester) async {
    final plugins = await tester.runAsync(load);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appPluginsProvider.overrideWith((ref) async => plugins!)],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          home: const Material(
            child: FormattedTextView(
              text: td.FormattedText(
                text: 'Try: final x',
                entities: [
                  td.TextEntity(
                    offset: 5,
                    length: 7,
                    type: td.TextEntityTypePreCode(language: 'dart'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final pieces = <String, Color?>{};
    rich.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        pieces[span.text!] = span.style?.color;
      }
      return true;
    });
    expect(pieces['final'], codeTokenColor('keyword', MgColors.light));
    expect(pieces['x'], isNull);
    expect(pieces['Try: '], isNull);
  });
}
