import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

import 'fake_services.dart';

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

  test('SDK 1.1 hooks need sdk ^1.1 and messages.read', () {
    final old = errorsOf(
      '${base}permissions:\n  messages.read: all\nhooks: [message.filter]\n',
    );
    expect(old.errors.single, contains('^1.1'));
    final noRead = errorsOf(
      '${base.replaceFirst('^1.0', '^1.1')}hooks: [message.render.text]\n',
    );
    expect(noRead.errors.single, contains('messages.read'));
    final ok = PluginManifest.parse(
      '${base.replaceFirst('^1.0', '^1.1')}'
      'permissions:\n  messages.read: chats[]\n'
      'hooks: [message.filter, message.render.text]\n',
    );
    expect(ok.hooks, ['message.filter', 'message.render.text']);
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

  test('orders versions by semver', () {
    expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
    expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0.0+build.7'), 0);
    expect(compareVersions('1.0.0-beta', '1.0.0'), lessThan(0));
    expect(compareVersions('1.0.0-alpha', '1.0.0-beta'), lessThan(0));
    // Pre-release parts compare one by one, numbers as numbers.
    expect(compareVersions('1.0.0-beta.2', '1.0.0-beta.11'), lessThan(0));
    expect(compareVersions('1.0.0-1', '1.0.0-alpha'), lessThan(0));
    expect(compareVersions('1.0.0-alpha', '1.0.0-alpha.1'), lessThan(0));
  });

  test('refuses ids Windows cannot use as folder names', () {
    for (final id in ['dev.con.plugin', 'dev.example.nul', 'com1.a.b']) {
      expect(
        () => PluginManifest.parse(
          'id: $id\nname: X\nversion: 1.0.0\nruntime: js\nsdk: ^1.0',
        ),
        throwsA(isA<ManifestException>()),
        reason: id,
      );
    }
  });

  test('code blocks with network access need messages.read: all', () {
    expect(
      () => manifest(
        permissions: '  net: [paste.example.com]',
        hooks: '  - message.render.code',
      ),
      throwsA(
        isA<ManifestException>().having(
          (e) => e.errors.single,
          'error',
          contains('messages.read: all'),
        ),
      ),
    );
    expect(
      manifest(
        permissions: '  net: [paste.example.com]\n  messages.read: all',
        hooks: '  - message.render.code',
      ).hooks,
      ['message.render.code'],
    );
  });
}
