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

  test('subscribes only to its own hooks', () {
    final p = start();
    expect(p.subscribedEvents, {
      'message.render.voice',
      'message.render.round',
      'ui.action',
    });
  });

  test('without auto shows a button, transcribes on tap and caches', () async {
    final p = start();
    final first = await p.dispatch(PluginEvent.messageRenderVoice, voice);
    expect((first as EventHandled).ui, [
      {'type': 'button', 'label': 'Transcribe', 'action': 'transcribe'},
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
  });

  test('with auto transcribes right away on render', () async {
    final p = start(settings: {'auto': true, 'language': 'ru'});
    final r = await p.dispatch(PluginEvent.messageRenderVoice, voice);
    expect((r as EventHandled).ui.single['text'], services.transcript);
  });

  test(
    'a recognition error is shown as text, the plugin keeps running',
    () async {
      final p = start();
      services.failWith = const HostError('unavailable', 'no model');
      final r = await p.dispatch(PluginEvent.uiAction, {
        'action': 'transcribe',
        ...voice,
      });
      expect((r as EventHandled).ui.single['text'], 'Transcription failed');
      expect(p.status, PluginStatus.running);
    },
  );

  test(
    'photos cannot be transcribed: no media.read: photo permission',
    () async {
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
      expect((r as EventHandled).ui.single['text'], 'Transcription failed');
      expect(services.calls, isNot(contains('media.transcribe')));
    },
  );
}
