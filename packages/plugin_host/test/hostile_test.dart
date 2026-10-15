import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

/// Plugins that misbehave on purpose: none of them may take the app down,
/// and each ends up with a reason the user can read.
void main() {
  final filterManifest = manifest(
    sdk: '^1.1',
    permissions: '  messages.read: all',
    hooks: '  - message.filter',
  );
  const message = {
    'message': {'chatId': 1, 'id': 2, 'text': 'hello', 'outgoing': false},
  };

  test('an endless loop hits the CPU budget until the plugin is turned off '
      'with the reason', () async {
    final w = await PluginWorker.start(
      manifest: filterManifest,
      source: 'mg.on("message.filter", () => { for (;;) {} })',
      services: FakeServices(),
    );
    addTearDown(w.stop);
    final lines = <String>[];
    w.logLines.listen(lines.add);
    final disabled = w.statusChanges.firstWhere(
      (s) => s == PluginStatus.disabled,
    );
    for (var i = 0; i < 3; i++) {
      expect(
        await w.dispatch(PluginEvent.messageFilter, message),
        isA<EventSkipped>(),
      );
    }
    await disabled;
    expect(w.disabledReason, contains('exceeded the time limit'));
    expect(w.logs.last, startsWith('disabled: 3 failures in a row'));
    expect(lines, w.logs);
    // Once off, it is not asked again.
    expect(
      await w.dispatch(PluginEvent.messageFilter, message),
      isA<EventSkipped>(),
    );
  });

  test('writing past the storage limit fails in the plugin', () async {
    final dir = await Directory.systemTemp.createTemp('hostile');
    addTearDown(() => dir.delete(recursive: true));
    final storage = PluginStorage(dir);
    final p = PluginInstance(
      manifest: manifest(permissions: '  storage: 1kb'),
      services: _Storage(storage),
    );
    addTearDown(p.stop);
    p.start('''
      mg.on("ui.action", async () => {
        await mg.storage.set("small", "x".repeat(100));
        try {
          await mg.storage.set("big", "x".repeat(4000));
          return [{type: "text", text: "stored"}];
        } catch (e) {
          return [{type: "text", text: e.code}];
        }
      });
    ''');
    final r = await p.dispatch(PluginEvent.uiAction, {});
    expect((r as EventHandled).ui.single['text'], 'quota_exceeded');
    expect(p.status, PluginStatus.running);
    // What fit is kept, what did not is not.
    final saved = File('${dir.path}/dev.test.plugin.json').readAsStringSync();
    expect(saved, contains('small'));
    expect(saved, isNot(contains('big')));
  });

  test('a filter answering garbage is ignored: the message stays', () async {
    for (final garbage in [
      '42',
      '"hide"',
      '[1, 2]',
      '({filter: "hide", reason: 7})',
      '({filter: "hide", reason: "x".repeat(500)})',
      '({filter: {}})',
    ]) {
      final p = PluginInstance(
        manifest: filterManifest,
        services: FakeServices(),
      );
      addTearDown(p.stop);
      p.start('mg.on("message.filter", () => $garbage)');
      final r = await p.dispatch(PluginEvent.messageFilter, message);
      expect(r, isA<EventSkipped>(), reason: garbage);
      expect(p.logs.last, contains('invalid filter result'), reason: garbage);
    }
  });
}

final class _Storage implements PluginServices {
  _Storage(this.storage);
  final PluginStorage storage;

  @override
  Future<Object?> call(String id, String method, Map<String, Object?> args) =>
      storage.call(id, method, args);
}
