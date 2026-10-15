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

  group('message.render.code', () {
    const source = '''
      mg.on("message.render.code", ({message, code}) => [
        {type: "text", text: JSON.stringify(message ?? null)},
        {type: "code", spans: [{text: code, token: "plain"}]},
      ]);
    ''';
    final payload = {
      'message': {'chatId': 10, 'id': 7, 'text': 'secret words', 'senderId': 2},
      'language': 'dart',
      'code': 'main() {}',
    };

    test('needs no permission and sees only the ids', () async {
      final p = load(source, m: manifest(hooks: '  - message.render.code'));
      final r = await p.dispatch(PluginEvent.messageRenderCode, payload);
      final ui = (r as EventHandled).ui;
      expect(ui.first['text'], '{"chatId":10,"id":7}');
      expect(codeSpansFor(ui, 'main() {}'), [
        (text: 'main() {}', token: 'plain'),
      ]);
    });

    test('with messages.read the whole message is passed', () async {
      final p = load(
        source,
        m: manifest(
          permissions: '  messages.read: all',
          hooks: '  - message.render.code',
        ),
      );
      final r = await p.dispatch(PluginEvent.messageRenderCode, payload);
      expect((r as EventHandled).ui.first['text'], contains('secret words'));
    });

    test('spans that change the code are not used', () async {
      final p = load(
        'mg.on("message.render.code", () => '
        '[{type: "code", spans: [{text: "rm -rf /", token: "plain"}]}])',
        m: manifest(hooks: '  - message.render.code'),
      );
      final r = await p.dispatch(PluginEvent.messageRenderCode, payload);
      expect(codeSpansFor((r as EventHandled).ui, 'main() {}'), isNull);
    });

    test('too many spans are invalid UI', () async {
      final p = load(
        'mg.on("message.render.code", () => [{type: "code", spans: '
        'Array.from({length: ${maxCodeSpans + 1}}, () => ({text: "x"}))}])',
        m: manifest(hooks: '  - message.render.code'),
      );
      final r = await p.dispatch(PluginEvent.messageRenderCode, payload);
      expect(r, isA<EventSkipped>());
    });
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

  test('running out of memory in a promise job disables the plugin', () async {
    // The rejection is swallowed by a catch that itself needs memory.
    final p = load('''
      const a = [];
      mg.on("ui.action", async () => {
        await null;
        for (;;) a.push("x".repeat(4096));
      });
      ''', policy: const PluginPolicy(limits: JsLimits(memoryBytes: 8 << 20)));
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('memory'));
  });

  test('a caught out-of-memory error still disables the plugin', () async {
    final p = load(
      'mg.on("ui.action", () => { const a = []; '
      'try { for (;;) a.push("x".repeat(4096)) } catch (e) {} return null })',
      policy: const PluginPolicy(limits: JsLimits(memoryBytes: 8 << 20)),
    );
    expect(await p.dispatch(PluginEvent.uiAction, {}), isA<EventSkipped>());
    expect(p.status, PluginStatus.disabled);
    expect(p.disabledReason, contains('memory'));
  });

  test('a result after a caught out-of-memory error is discarded', () async {
    final p = load('''
      mg.on("ui.action", async () => {
        await null;
        let a = [];
        try { for (;;) a.push("x".repeat(4096)) } catch (e) {}
        a = null;
        return [{type: "text", text: "ok"}];
      });
      ''', policy: const PluginPolicy(limits: JsLimits(memoryBytes: 8 << 20)));
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

  group('SDK 1.1', () {
    PluginManifest m11(String scope, String hooks) => manifest(
      sdk: '^1.1',
      permissions: '  messages.read: $scope',
      hooks: hooks,
    );
    Map<String, Object?> msg(int chat, [String text = 'hi']) => {
      'message': {'chatId': chat, 'id': 1, 'text': text, 'outgoing': false},
    };

    test('message.filter: hide wins over collapse', () async {
      final p = load('''
        mg.on("message.filter", ({message}) =>
          message.text.includes("a") ? {filter: "collapse", reason: "A"} : undefined);
        mg.on("message.filter", ({message}) =>
          message.text.includes("b") ? {filter: "hide"} : undefined);
      ''', m: m11('all', '  - message.filter'));
      final a = await p.dispatch(PluginEvent.messageFilter, msg(1, 'a'));
      expect(a, isA<EventFiltered>());
      expect((a as EventFiltered).verdict, FilterVerdict.collapse);
      expect(a.reason, 'A');
      final ab = await p.dispatch(PluginEvent.messageFilter, msg(1, 'ab'));
      expect((ab as EventFiltered).verdict, FilterVerdict.hide);
      final none = await p.dispatch(PluginEvent.messageFilter, msg(1, 'c'));
      expect(none, isA<EventHandled>());
    });

    test('an invalid filter result is a strike', () async {
      final p = load(
        'mg.on("message.filter", () => ({filter: "explode"}))',
        m: m11('all', '  - message.filter'),
      );
      final r = await p.dispatch(PluginEvent.messageFilter, msg(1));
      expect(r, isA<EventSkipped>());
      expect(p.logs.last, contains('invalid filter result'));
    });

    test('chats[] plugins see only granted chats', () async {
      final p = load(
        'mg.on("message.render.text", () => [{type: "text", text: "seen"}])',
        m: m11('chats[]', '  - message.render.text'),
        grants: const PluginGrants(chats: {5}),
      );
      final granted = await p.dispatch(PluginEvent.messageRenderText, msg(5));
      expect((granted as EventHandled).ui.single['text'], 'seen');
      final other = await p.dispatch(PluginEvent.messageRenderText, msg(6));
      expect(other, isA<EventSkipped>());
    });

    test('translate follows messages.read, detection needs nothing', () async {
      final p = load(
        '''
        mg.command("/tr", async (chat) => {
          try { return (await mg.messages.translate(chat, 1, {to: "en"})).text; }
          catch (e) { return e.code; }
        });
        mg.command("/lang", async () =>
          (await mg.text.detectLanguage("Guten Morgen")).language + ":" + mg.app.locale());
      ''',
        m: manifest(
          sdk: '^1.1',
          permissions: '  messages.read: chats[]',
          extra:
              'commands:\n  - { name: /tr, title: Tr }\n'
              '  - { name: /lang, title: Lang }',
        ),
        grants: const PluginGrants(chats: {5}),
      );
      expect(await p.runCommand('/tr', args: 5), 'translated to en');
      expect(await p.runCommand('/tr', args: 6), 'permission_denied');
      expect(await p.runCommand('/lang'), 'de:en');
    });
  });
}
