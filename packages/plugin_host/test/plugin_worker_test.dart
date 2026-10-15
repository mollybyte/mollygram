import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

void main() {
  test(
    'the example runs in a separate isolate, services in the main one',
    () async {
      final bundle = await PluginBundle.load(Directory('example/transcribe'));
      final services = FakeServices();
      final w = await PluginWorker.start(
        manifest: bundle.manifest,
        source: bundle.source,
        services: services,
      );
      addTearDown(w.stop);
      expect(w.status, PluginStatus.running);

      final r = await w.dispatch(PluginEvent.uiAction, {
        'action': 'transcribe',
        'message': {
          'chatId': 1,
          'id': 2,
          'media': {'kind': 'voice', 'fileId': 'f'},
        },
      });
      expect(r, isA<EventHandled>(), reason: '$r ${w.disabledReason}');
      expect((r as EventHandled).ui.single['text'], services.transcript);
      expect(services.storage, {
        'dev.mollygram.transcribe/t:1:2': services.transcript,
      });
    },
  );

  test('a plugin disabled in the worker reports it', () async {
    final w = await PluginWorker.start(
      manifest: manifest(),
      source: 'mg.on("ui.action", () => { throw new Error("x") })',
      services: FakeServices(),
    );
    addTearDown(w.stop);
    final changes = w.statusChanges.first;
    for (var i = 0; i < 3; i++) {
      await w.dispatch(PluginEvent.uiAction, {});
    }
    expect(await changes, PluginStatus.disabled);
    expect(w.disabledReason, contains('failures in a row'));
    expect(w.disabledReason, contains('Error: x'));
  });

  test('a load error is known as soon as the worker starts', () async {
    final w = await PluginWorker.start(
      manifest: manifest(),
      source: 'throw new Error("broken")',
      services: FakeServices(),
    );
    addTearDown(w.stop);
    expect(w.status, PluginStatus.disabled);
    expect(w.disabledReason, contains('broken'));
  });

  test('stopping closes the status stream and refuses requests', () async {
    final w = await PluginWorker.start(
      manifest: manifest(),
      source: '',
      services: FakeServices(),
    );
    final done = w.statusChanges.toList();
    w.stop();
    expect(await done, [PluginStatus.stopped]);
    await expectLater(w.runCommand('/x'), throwsStateError);
  });

  test('a hung plugin does not block the main isolate', () async {
    final w = await PluginWorker.start(
      manifest: manifest(),
      source: 'mg.on("ui.action", () => { for (;;) {} })',
      services: FakeServices(),
      policy: const PluginPolicy(
        limits: JsLimits(callBudget: Duration(milliseconds: 300)),
      ),
    );
    addTearDown(w.stop);
    final sw = Stopwatch()..start();
    var ticks = 0;
    final pending = w.dispatch(PluginEvent.uiAction, {});
    while (sw.elapsedMilliseconds < 200) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      ticks++;
    }
    expect(ticks, greaterThan(5));
    expect(await pending, isA<EventSkipped>());
  });
}
