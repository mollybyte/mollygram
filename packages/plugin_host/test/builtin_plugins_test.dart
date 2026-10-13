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
}
