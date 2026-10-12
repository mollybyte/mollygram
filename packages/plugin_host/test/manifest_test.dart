import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

void main() {
  test('parses the example manifest', () async {
    final m = PluginManifest.parse(
      await File('example/transcribe/manifest.yaml').readAsString(),
    );
    expect(m.id, 'dev.mollygram.transcribe');
    expect(m.permissions.mediaRead, {MediaKind.voice, MediaKind.round});
    expect(m.permissions.storageBytes, 1 << 20);
    expect(m.hooks, ['message.render.voice', 'message.render.round']);
    expect(m.settings.map((s) => s.key), ['auto', 'language']);
    expect(m.permissions.describe().map((d) => d.title), ['Storage', 'Media']);
  });

  test('parses the "Summary" manifest from the mockup', () {
    final m = PluginManifest.parse('''
id: dev.tgplug.summary
name: Summary
version: 2.3.0
runtime: js
sdk: ^1.0
permissions:
  messages.read: on_command
  net: [user_endpoint]
  storage: 5mb
commands:
  - { name: /summary, title: Summarize current chat, shortcut: cmd+shift+s }
''');
    expect(m.permissions.messagesRead, MessagesScope.onCommand);
    expect(m.permissions.net, {userEndpoint});
    expect(m.commands.single.name, '/summary');
  });

  ManifestException errorsOf(String yaml) {
    try {
      PluginManifest.parse(yaml);
    } on ManifestException catch (e) {
      return e;
    }
    fail('the manifest should have failed validation');
  }

  const base =
      'id: dev.test.x\nname: X\nversion: 1.0.0\nruntime: js\nsdk: ^1.0\n';

  test('native runtime is forbidden', () {
    final e = errorsOf(base.replaceFirst('runtime: js', 'runtime: native'));
    expect(e.errors.single, contains('native code'));
  });

  test('unknown permission and field are not silently ignored', () {
    final e = errorsOf('${base}permissions:\n  fs.write: true\nfoo: 1\n');
    expect(e.errors.join(), allOf(contains('fs.write'), contains('foo')));
  });

  test('a hook without the required permission is rejected', () {
    final e = errorsOf('${base}hooks: [message.incoming]\n');
    expect(e.errors.single, contains('messages.read'));
  });

  test('network access by host name only', () {
    final e = errorsOf(
      '${base}permissions:\n  net: ["*.evil.com", "10.0.0.1"]\n',
    );
    expect(e.errors, hasLength(1));
    expect(
      e.errors.single,
      allOf(contains('*.evil.com'), contains('10.0.0.1')),
    );
  });

  test('incompatible SDK version', () {
    final e = errorsOf(base.replaceFirst('^1.0', '^2.0'));
    expect(e.errors.single, contains('SDK'));
  });

  test('main cannot escape the plugin folder', () {
    final e = errorsOf('${base}main: ../../etc/x.js\n');
    expect(e.errors.single, contains('main'));
  });

  test('new permissions in an update require consent again', () {
    final old = PermissionSet.parse({
      'net': ['api.deepl.com'],
    });
    final next = PermissionSet.parse({
      'net': ['api.deepl.com', 'evil.example.com'],
      'messages.read': 'all',
    });
    expect(next.escalationsFrom(old), [
      'messages.read: all',
      'net: evil.example.com',
    ]);
    expect(old.escalationsFrom(next), isEmpty);
  });
}
