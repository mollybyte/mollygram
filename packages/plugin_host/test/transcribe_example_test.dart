import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

void main() {
  late FakeServices services;
  late PluginBundle bundle;

  setUpAll(() async {
    bundle = await PluginBundle.load(Directory('example/transcribe'));
  });
  setUp(() => services = FakeServices());

  PluginInstance start({Map<String, Object?> settings = const {}}) {
    final p = PluginInstance(
      manifest: bundle.manifest,
      services: services,
      settings: settings,
    );
    addTearDown(p.stop);
    expect(p.start(bundle.source), isTrue, reason: p.disabledReason);
    return p;
  }

  final voice = {
    'message': {
      'chatId': 10,
      'id': 5,
      'senderId': 1,
      'date': 0,
      'outgoing': false,
      'media': {'kind': 'voice', 'fileId': 'f1', 'duration': 4},
    },
  };

  test('подписывается только на свои хуки', () {
    final p = start();
    expect(p.subscribedEvents, {
      'message.render.voice',
      'message.render.round',
      'ui.action',
    });
  });

  test(
    'без авто показывает кнопку, по нажатию расшифровывает и кэширует',
    () async {
      final p = start();
      final first = await p.dispatch(PluginEvent.messageRenderVoice, voice);
      expect((first as EventHandled).ui, [
        {'type': 'button', 'label': 'Расшифровать', 'action': 'transcribe'},
      ]);

      final action = await p.dispatch(PluginEvent.uiAction, {
        'action': 'transcribe',
        ...voice,
      });
      expect((action as EventHandled).ui.single['text'], services.transcript);
      expect(services.calls, contains('media.transcribe'));

      services.calls.clear();
      final again = await p.dispatch(PluginEvent.messageRenderVoice, voice);
      expect((again as EventHandled).ui.single['text'], services.transcript);
      expect(services.calls, isNot(contains('media.transcribe')));
    },
  );

  test('с авто расшифровывает сразу при отрисовке', () async {
    final p = start(settings: {'auto': true, 'language': 'ru'});
    final r = await p.dispatch(PluginEvent.messageRenderVoice, voice);
    expect((r as EventHandled).ui.single['text'], services.transcript);
  });

  test('ошибка распознавания показывается текстом, плагин живёт', () async {
    final p = start();
    services.failWith = const HostError('unavailable', 'нет модели');
    final r = await p.dispatch(PluginEvent.uiAction, {
      'action': 'transcribe',
      ...voice,
    });
    expect((r as EventHandled).ui.single['text'], 'Не удалось расшифровать');
    expect(p.status, PluginStatus.running);
  });

  test('фото расшифровать нельзя: нет права media.read: photo', () async {
    final p = start();
    services.calls.clear();
    final photo = {
      'action': 'transcribe',
      'message': {
        ...voice['message']!,
        'media': {'kind': 'photo', 'fileId': 'p'},
      },
    };
    final r = await p.dispatch(PluginEvent.uiAction, photo);
    expect((r as EventHandled).ui.single['text'], 'Не удалось расшифровать');
    expect(services.calls, isNot(contains('media.transcribe')));
  });
}
