import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

void main() {
  late FakeServices services;
  setUp(() => services = FakeServices());

  PluginInstance load(
    String source, {
    PluginManifest? m,
    PluginGrants grants = const PluginGrants(),
    PluginPolicy policy = const PluginPolicy(),
  }) {
    final p = PluginInstance(
      manifest: m ?? manifest(),
      services: services,
      grants: grants,
      policy: policy,
    );
    addTearDown(p.stop);
    p.start(source);
    return p;
  }

  test('a load error disables the plugin, not the app', () {
    final p = load('throw new Error("broken")');
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('broken'));
  });

  test('a hang during load is interrupted', () {
    final p = load('for (;;) {}');
    expect(p.status, PluginStatus.disabled);
  });

  test('cannot subscribe to a hook missing from the manifest', () {
    final p = load('mg.on("message.render.code", () => [])');
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('is not declared'));
  });

  test('mg cannot be replaced', () {
    final p = load('mg.storage = 1; globalThis.mg = 2;');
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('read-only'));
  });

  test('without storage permission the call is rejected in JS', () async {
    final p = load('''
      mg.on("ui.action", async () => {
        try { await mg.storage.set("a", 1); return [{type: "text", text: "ok"}]; }
        catch (e) { return [{type: "text", text: e.code}]; }
      });
    ''');
    final r = await p.dispatch(PluginEvent.uiAction, {'action': 'x'});
    expect((r as EventHandled).ui.single['text'], 'permission_denied');
    expect(services.calls, isEmpty);
  });

  test('network only to declared hosts', () async {
    final p = load(
      '''
      mg.command("/go", async (url) => {
        try { return (await mg.net.fetch(url)).status; } catch (e) { return e.code; }
      });
    ''',
      m: manifest(
        permissions: '  net: [api.deepl.com, user_endpoint]',
        extra: 'commands:\n  - { name: /go, title: Go }',
      ),
      grants: const PluginGrants(userEndpoints: {'llm.home.lan'}),
    );
    expect(await p.runCommand('/go', args: 'https://api.deepl.com/v2'), 200);
    expect(await p.runCommand('/go', args: 'https://llm.home.lan/v1'), 200);
    expect(
      await p.runCommand('/go', args: 'https://evil.com/'),
      'permission_denied',
    );
    expect(
      await p.runCommand('/go', args: 'http://api.deepl.com/'),
      'bad_argument',
    );
  });

  test(
    'messages.read: on_command allows only the current command chat',
    () async {
      final p = load(
        '''
      mg.command("/peek", async (chat) => {
        try { return (await mg.messages.get(chat, 1)).text; } catch (e) { return e.code; }
      });
    ''',
        m: manifest(
          permissions: '  messages.read: on_command',
          extra: 'commands:\n  - { name: /peek, title: Peek }',
        ),
      );
      expect(await p.runCommand('/peek', chatId: 7, args: 7), 'x');
      expect(
        await p.runCommand('/peek', chatId: 7, args: 8),
        'permission_denied',
      );
    },
  );

  test('send interception: modify and cancel', () async {
    final p = load(
      '''
      mg.on("message.sending", (d) => d.text === "stop" ? {cancel: true} : {modify: {...d, text: d.text + "!"}});
      mg.on("message.sending", (d) => ({modify: {...d, text: d.text.toUpperCase()}}));
    ''',
      m: manifest(
        permissions: '  composer.write: true',
        hooks: '  - message.sending',
      ),
    );
    final r = await p.dispatch(PluginEvent.messageSending, {
      'chatId': 1,
      'text': 'hello',
    });
    expect((r as EventHandled).payload, {'chatId': 1, 'text': 'HELLO!'});
    expect(
      await p.dispatch(PluginEvent.messageSending, {
        'chatId': 1,
        'text': 'stop',
      }),
      isA<EventCancelled>(),
    );
  });

  test('invalid UI never reaches the app', () async {
    final p = load('mg.on("ui.action", () => [{type: "iframe", src: "x"}])');
    final r = await p.dispatch(PluginEvent.uiAction, {'action': 'x'});
    expect(r, isA<EventSkipped>());
  });

  test('three failures in a row disable the plugin', () async {
    final p = load('mg.on("ui.action", () => { throw new Error("no") })');
    for (var i = 0; i < 3; i++) {
      expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
    }
    expect(p.status, PluginStatus.disabled);
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
  });

  test('a synchronous hang in a handler is interrupted', () async {
    final p = load('mg.on("ui.action", () => { for (;;) {} })');
    final sw = Stopwatch()..start();
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(p.status, PluginStatus.running);
  });

  test('a promise that never settles is cut off by a timeout', () async {
    final p = load(
      'mg.on("ui.action", () => new Promise(() => {}))',
      policy: const PluginPolicy(actionTimeout: Duration(milliseconds: 100)),
    );
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
  });

  test('running out of memory disables the plugin immediately', () async {
    final p = load(
      'const a = []; mg.on("ui.action", () => { for (;;) a.push("x".repeat(4096)) })',
      policy: const PluginPolicy(limits: JsLimits(memoryBytes: 8 << 20)),
    );
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('memory'));
  });

  test('a service error reaches JS as an exception with a code', () async {
    services.failWith = const HostError('busy', 'busy');
    final p = load('''
      mg.on("ui.action", async () => {
        try { await mg.storage.get("k"); } catch (e) { return [{type: "text", text: e.code}]; }
      });
    ''', m: manifest(permissions: '  storage: 1kb'));
    final r = await p.dispatch(PluginEvent.uiAction, {});
    expect((r as EventHandled).ui.single['text'], 'busy');
  });

  test('console.log writes to the plugin log', () {
    final p = load('console.log("loaded", {v: 1})');
    expect(p.logs, ['info: loaded {"v":1}']);
  });
}
