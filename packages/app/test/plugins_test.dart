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
  _FakePlugin({this.lie = false});

  final bool lie;
  final dispatched = <Map<String, Object?>>[];
  final status = StreamController<PluginStatus>.broadcast();
  var stopped = false;

  void close() => unawaited(status.close());

  @override
  Future<EventOutcome> dispatch(PluginEvent e, Map<String, Object?> p) async {
    dispatched.add(p);
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
  String? get disabledReason => '3 failures in a row';
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

  Future<AppPlugins> load({Directory? picked}) => AppPlugins.load(
    store: store,
    builtin: [
      BuiltinPlugin(
        PluginEntry.parse(_highlighter, builtIn: true),
        'highlighter source',
      ),
    ],
    launch: (m, source, {required settings, required locale}) async {
      final p = _FakePlugin(lie: lie);
      addTearDown(p.close);
      launched.add(p);
      return p;
    },
    pick: () async => picked,
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
        pick: () async => next,
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

    test('spans that change the code are ignored', () async {
      lie = true;
      final plugins = await load();
      expect(await plugins.highlightCode('final x', null), isNull);
    });

    test('a plugin the host disables is marked on its page', () async {
      final plugins = await load();
      await plugins.highlightCode('final x', null);
      launched.single.status.add(PluginStatus.disabled);
      await Future<void>.delayed(Duration.zero);
      final entry = plugins.controller.entry('dev.mollygram.codehighlight')!;
      expect(entry.disabledReason, '3 failures in a row');
      expect(launched.single.stopped, isTrue);
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
