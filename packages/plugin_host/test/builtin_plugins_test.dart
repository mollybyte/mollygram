import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

void main() {
  late FakeServices services;
  setUp(() => services = FakeServices());

  Future<PluginInstance> start(
    String name, {
    Map<String, Object?> settings = const {},
    String locale = 'en',
  }) async {
    final bundle = await PluginBundle.load(Directory('builtin/$name'));
    final p = PluginInstance(
      manifest: bundle.manifest,
      services: services,
      settings: settings,
      locale: locale,
    );
    addTearDown(p.stop);
    expect(p.start(bundle.source), isTrue, reason: p.disabledReason);
    return p;
  }

  Map<String, Object?> msg(String text, {bool outgoing = false}) => {
    'message': {
      'chatId': 10,
      'id': 7,
      'senderId': 2,
      'date': 0,
      'text': text,
      'outgoing': outgoing,
    },
  };

  group('Filters', () {
    Future<EventOutcome> check(
      PluginInstance p,
      String text, {
      bool outgoing = false,
    }) => p.dispatch(PluginEvent.messageFilter, msg(text, outgoing: outgoing));

    test('collapses posts with ad markers', () async {
      final p = await start('filters');
      for (final text in [
        'Лучший курс по Python!\n\nРеклама. ООО «Ромашка», ИНН 7700000000, erid: 2SDnjc4YtFm',
        'New VPN, 50% off #ad',
        'Скидки до конца недели #реклама',
        'Great deals\n\nSponsored',
      ]) {
        final r = await check(p, text);
        expect(r, isA<EventFiltered>(), reason: text);
        expect((r as EventFiltered).verdict, FilterVerdict.collapse);
        expect(r.reason, 'Advertising');
      }
    });

    test('leaves ordinary messages alone', () async {
      final p = await start('filters', settings: {'keywords': 'ad'});
      for (final text in [
        'I already read it',
        'Read the #adr-12 decision',
        'Перечитай рекламации от клиента',
      ]) {
        expect(await check(p, text), isA<EventHandled>(), reason: text);
      }
      expect(await check(p, 'The ad was fine'), isA<EventFiltered>());
    });

    test(
      'keywords match whole words in any script, case-insensitive',
      () async {
        final p = await start(
          'filters',
          settings: {'keywords': 'крипта, NFT', 'mode': 'hide'},
        );
        final r = await check(p, 'Заработок на КРИПТА за неделю');
        expect((r as EventFiltered).verdict, FilterVerdict.hide);
        expect(r.reason, 'Keyword: крипта');
        expect(await check(p, 'Криптография это наука'), isA<EventHandled>());
        expect(await check(p, 'Free nft drop'), isA<EventFiltered>());
      },
    );

    test('changing keywords applies at once', () async {
      final p = await start('filters');
      expect(await check(p, 'meeting at five'), isA<EventHandled>());
      await p.updateSetting('keywords', 'meeting');
      expect(await check(p, 'meeting at five'), isA<EventFiltered>());
    });

    test('ad filtering can be turned off', () async {
      final p = await start('filters', settings: {'ads': false});
      expect(await check(p, 'New VPN #ad'), isA<EventHandled>());
    });

    test('never filters your own messages', () async {
      final p = await start('filters', settings: {'keywords': 'secret'});
      expect(
        await check(p, 'the secret #ad', outgoing: true),
        isA<EventHandled>(),
      );
    });

    test('reasons follow the app language', () async {
      final p = await start('filters', locale: 'ru');
      final r = await check(p, 'Курс #реклама');
      expect((r as EventFiltered).reason, 'Реклама');
    });
  });

  group('Translate', () {
    const german = 'Guten Morgen, wie geht es dir heute?';

    Future<List<Map<String, Object?>>> render(
      PluginInstance p,
      String text,
    ) async => ((await p.dispatch(
      PluginEvent.messageRenderText,
      msg(text),
    )) as EventHandled).ui;

    test(
      'offers a translation for another language, sends nothing yet',
      () async {
        final p = await start('translate');
        final ui = await render(p, german);
        expect(ui.single['type'], 'button');
        expect(ui.single['label'], 'Translate from German');
        expect(services.calls, isNot(contains('messages.translate')));
      },
    );

    test('tap translates into the app language and caches it', () async {
      final p = await start('translate', locale: 'ru');
      final first = await render(p, german);
      expect(first.single['label'], 'Перевести с немецкого');

      final tapped = await p.dispatch(PluginEvent.uiAction, {
        'action': 'translate',
        'payload': first.single['payload'],
        ...msg(german),
      });
      final ui = (tapped as EventHandled).ui;
      expect(ui.first['text'], 'translated to ru');

      services.calls.clear();
      final again = await render(p, german);
      expect(again.first['text'], 'translated to ru');
      expect(services.calls, isNot(contains('messages.translate')));
    });

    test('an edited message is translated again', () async {
      final p = await start('translate', settings: {'auto': true});
      await render(p, german);
      services.calls.clear();
      await render(p, '$german Bis bald!');
      expect(services.calls, contains('messages.translate'));
    });

    test('skips its own language, skipped languages and short texts', () async {
      final p = await start('translate', settings: {'skip': 'uk, de'});
      expect(await render(p, german), isEmpty);
      services.detected = {'language': 'en', 'confidence': 0.99};
      expect(await render(p, 'Good morning, how are you today?'), isEmpty);
      services.detected = {'language': 'fr', 'confidence': 0.99};
      expect(await render(p, 'Merci!'), isEmpty);
      expect(await render(p, 'Bonjour, comment allez-vous ?'), isNotEmpty);
    });

    test('unsure detection shows nothing', () async {
      final p = await start('translate');
      services.detected = {'language': 'de', 'confidence': 0.3};
      expect(await render(p, german), isEmpty);
      services.detected = null;
      expect(await render(p, german), isEmpty);
    });

    test('a failed translation is shown, the plugin keeps running', () async {
      final p = await start('translate', settings: {'auto': true});
      services.failTranslate = true;
      final ui = await render(p, german);
      expect(ui.single['text'], 'Could not translate');
      expect(p.status, PluginStatus.running);
    });

    test('hide goes back to the button', () async {
      final p = await start('translate', settings: {'auto': true});
      expect((await render(p, german)).first['text'], 'translated to en');
      final hidden = await p.dispatch(PluginEvent.uiAction, {
        'action': 'hide',
        'payload': {'from': 'de'},
        ...msg(german),
      });
      expect(
        (hidden as EventHandled).ui.single['label'],
        'Translate from German',
      );
    });
  });

  group('Code highlight', () {
    Future<List<CodeSpan>?> highlight(
      PluginInstance p,
      String code, {
      String? language,
    }) async {
      final r = await p.dispatch(PluginEvent.messageRenderCode, {
        'code': code,
        'language': ?language,
      });
      if (r is! EventHandled) fail('$r');
      return codeSpansFor(r.ui, code);
    }

    String tokenOf(List<CodeSpan> spans, String text) =>
        spans.firstWhere((s) => s.text.trim() == text).token;

    test('asks for nothing', () async {
      final bundle = await PluginBundle.load(
        Directory('builtin/code_highlight'),
      );
      expect(
        bundle.manifest.permissions.escalationsFrom(PermissionSet.none),
        isEmpty,
      );
      expect(bundle.manifest.hooks, ['message.render.code']);
    });

    test('colors keywords, strings, numbers, comments and calls', () async {
      final p = await start('code_highlight');
      const code = 'final n = max(42, "a\\"b"); // done\nclass Box {}';
      final spans = (await highlight(p, code, language: 'dart'))!;
      expect(spans.map((s) => s.text).join(), code);
      expect(tokenOf(spans, 'final'), 'keyword');
      expect(tokenOf(spans, 'max'), 'function');
      expect(tokenOf(spans, '42'), 'number');
      expect(tokenOf(spans, '"a\\"b"'), 'string');
      expect(tokenOf(spans, '// done'), 'comment');
      expect(tokenOf(spans, 'Box'), 'type');
    });

    test('follows the language', () async {
      final p = await start('code_highlight');
      final python = (await highlight(p, 'def f(): # note', language: 'py'))!;
      expect(tokenOf(python, 'def'), 'keyword');
      expect(tokenOf(python, '# note'), 'comment');
      final sql = (await highlight(p, 'SELECT id FROM t', language: 'sql'))!;
      expect(tokenOf(sql, 'SELECT'), 'keyword');
      // Without a language the common keywords still stand out.
      final plain = (await highlight(p, 'return x'))!;
      expect(tokenOf(plain, 'return'), 'keyword');
    });

    test('keeps an unclosed string or comment to the end', () async {
      final p = await start('code_highlight');
      for (final code in ['x = "open', '/* never closed', "s = '''multi"]) {
        final spans = await highlight(p, code, language: 'js');
        expect(spans?.map((s) => s.text).join(), code, reason: code);
      }
    });

    test('a block that is one long comment stays valid', () async {
      final p = await start('code_highlight');
      for (final code in ['// ${'x' * 4090}', '/* ${'y' * 4092}']) {
        final spans = (await highlight(p, code, language: 'js'))!;
        expect(spans.map((s) => s.text).join(), code);
        expect(spans.every((s) => s.text.length <= 4000), isTrue);
      }
      expect(p.status, PluginStatus.running);
    });

    test('nested templates, lifetimes and # stay in their place', () async {
      final p = await start('code_highlight');
      final js = (await highlight(
        p,
        r'const s = `a ${f(`b ${c}`)} d`; x',
        language: 'ts',
      ))!;
      expect(tokenOf(js, r'`a ${f(`b ${c}`)} d`'), 'string');
      expect(js.last, (text: ' x', token: 'plain'));

      final rust = (await highlight(
        p,
        "fn f<'a>(s: &'a str) -> char { 'x' }",
        language: 'rust',
      ))!;
      expect(tokenOf(rust, "'x'"), 'string');
      // The lifetime is not the start of a string.
      expect(rust.where((s) => s.token == 'string').map((s) => s.text), [
        "'x'",
      ]);

      final c = (await highlight(p, '#include <stdio.h>\n# note'))!;
      expect(tokenOf(c, '#include'), 'plain');
      expect(tokenOf(c, '# note'), 'comment');
      final css = (await highlight(p, 'a { color: #fff; }', language: 'css'))!;
      expect(css.where((s) => s.token == 'comment'), isEmpty);
    });

    test('highlights the longest message within the time budget', () async {
      final p = await start('code_highlight');
      // A message holds at most 4096 characters.
      final code = List.filled(
        128,
        'if (a < 10) { call("x", 1.5); }',
      ).join('\n');
      expect(await highlight(p, code, language: 'js'), isNotNull);
      expect(p.status, PluginStatus.running);
    });
  });
}
