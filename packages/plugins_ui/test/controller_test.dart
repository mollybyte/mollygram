import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:plugin_host/plugin_host.dart';

final class RecordingDelegate implements PluginsDelegate {
  final calls = <String>[];
  PluginEntry? file;

  var failInstall = false;

  @override
  Future<void> install(PluginEntry e) async {
    if (failInstall) throw 'disk full';
    calls.add('install ${e.id}');
  }

  @override
  Future<void> uninstall(PluginEntry e) async => calls.add('uninstall ${e.id}');
  @override
  Future<void> setEnabled(PluginEntry e, bool v) async =>
      calls.add('enabled ${e.id} $v');
  @override
  Future<void> setSetting(PluginEntry e, String k, Object? v) async =>
      calls.add('setting ${e.id} $k=$v');
  @override
  Future<void> applyUpdate(PluginEntry e, PluginUpdate u) async =>
      calls.add('update ${e.id} ${u.manifest.version}');
  @override
  void discard(PluginEntry e) => calls.add('discard ${e.id}');
  @override
  Future<PluginEntry?> pickFile() async {
    if (invalid != null) throw ManifestException(invalid!);
    return file;
  }

  List<String>? invalid;
}

PluginEntry plugin(
  String id, {
  String permissions = '',
  bool installed = false,
  String version = '1.0.0',
  String extra = '',
}) => PluginEntry.parse('''
id: $id
name: ${id.split('.').last}
version: $version
author: someone
runtime: js
sdk: ^1.0
${permissions.isEmpty ? '' : 'permissions:\n$permissions'}
$extra
''', installed: installed);

void main() {
  late RecordingDelegate delegate;
  setUp(() => delegate = RecordingDelegate());

  test('mock manifests parse and split into groups', () {
    final c = PluginsController(mockPlugins());
    final g = c.groups((e) => e.manifest.name);
    expect(g.installed.map((e) => e.manifest.name), [
      'Summary',
      'Transcribe',
      'Quiet hours',
      'Code highlighting',
    ]);
    expect(g.available.map((e) => e.manifest.name), [
      'Link cards',
      'Chat statistics',
    ]);
  });

  test('search matches the shown name and the author', () {
    final c = PluginsController(mockPlugins());
    c.query = 'unfurl';
    expect(
      c.groups((e) => e.manifest.name).available.single.id,
      'dev.unfurl.cards',
    );
    c.query = 'перевод';
    final g = c.groups(
      (e) => e.id == 'dev.tgplug.summary' ? 'Перевод' : e.manifest.name,
    );
    expect(g.installed.single.id, 'dev.tgplug.summary');
  });

  test('installing asks for consent first', () async {
    final c = PluginsController([
      plugin('dev.a.net', permissions: '  net: [api.deepl.com]'),
    ], delegate: delegate);
    c.requestInstall('dev.a.net');
    expect(c.consent?.permissions.net, {'api.deepl.com'});
    expect(c.entry('dev.a.net')!.installed, isFalse);

    c.cancelConsent();
    expect(c.consent, isNull);
    expect(delegate.calls, ['discard dev.a.net']);

    c.requestInstall('dev.a.net');
    await c.allowConsent();
    expect(c.entry('dev.a.net')!.installed, isTrue);
    expect(delegate.calls.last, 'install dev.a.net');
  });

  test('a plugin that asks for nothing installs at once', () async {
    final c = PluginsController([plugin('dev.a.plain')], delegate: delegate);
    c.requestInstall('dev.a.plain');
    expect(c.consent, isNull);
    expect(c.entry('dev.a.plain')!.installed, isTrue);
  });

  test('an update shows only the new access', () async {
    final c = PluginsController(mockPlugins(), delegate: delegate);
    final summary = c.entry('dev.tgplug.summary')!;
    expect(summary.update?.manifest.version, '2.4.0');
    c.requestUpdate(summary.id);
    final p = c.consent!.permissions;
    expect(p.composerWrite, isTrue);
    expect(p.net, isEmpty);
    expect(p.storageBytes, 0);
    expect(p.messagesRead, MessagesScope.none);

    await c.allowConsent();
    final updated = c.entry(summary.id)!;
    expect(updated.manifest.version, '2.4.0');
    expect(updated.update, isNull);
    expect(updated.manifestSource, contains('composer.write: true'));
    expect(delegate.calls, ['update dev.tgplug.summary 2.4.0']);
  });

  test('built-in plugins cannot be uninstalled, only turned off', () async {
    final builtin = PluginEntry(
      manifest: plugin('dev.mollygram.x').manifest,
      manifestSource: '',
      builtIn: true,
      installed: true,
    );
    final c = PluginsController([builtin], delegate: delegate);
    await c.uninstall(builtin.id);
    expect(c.entry(builtin.id)!.installed, isTrue);
    await c.setEnabled(builtin.id, false);
    expect(c.entry(builtin.id)!.active, isFalse);
    expect(delegate.calls, ['enabled dev.mollygram.x false']);
  });

  test(
    'settings fall back to manifest defaults and reach the delegate',
    () async {
      final c = PluginsController(mockPlugins(), delegate: delegate);
      const id = 'dev.mollygram.transcribe';
      expect(c.entry(id)!.setting('language'), 'auto');
      await c.setSetting(id, 'language', 'ru');
      expect(c.entry(id)!.setting('language'), 'ru');
      await c.setSetting(id, 'nope', 1);
      expect(delegate.calls, ['setting dev.mollygram.transcribe language=ru']);
    },
  );

  test('turning a failed plugin back on clears the failure', () async {
    final c = PluginsController(mockPlugins());
    const id = 'tg.shiki.code';
    c.markDisabled(id, '3 failures in a row');
    expect(c.entry(id)!.active, isFalse);
    await c.setEnabled(id, true);
    expect(c.entry(id)!.active, isTrue);
  });

  test('install from file: new plugin asks for consent', () async {
    final c = PluginsController(mockPlugins(), delegate: delegate);
    delegate.file = plugin('dev.new.one', permissions: '  storage: 1mb');
    await c.installFromFile();
    expect(c.selected?.id, 'dev.new.one');
    expect(c.consent?.entry.id, 'dev.new.one');
  });

  test('install from file over an installed plugin is an update', () async {
    final c = PluginsController([
      plugin('dev.a.b', installed: true, permissions: '  storage: 1mb'),
    ], delegate: delegate);
    delegate.file = plugin(
      'dev.a.b',
      version: '1.1.0',
      permissions: '  storage: 1mb',
    );
    await c.installFromFile();
    expect(c.consent, isNull);
    expect(c.entry('dev.a.b')!.manifest.version, '1.1.0');

    delegate.file = plugin(
      'dev.a.b',
      version: '1.2.0',
      permissions: '  storage: 1mb\n  net: [x.example.com]',
    );
    await c.installFromFile();
    expect(c.consent?.isUpdate, isTrue);
    expect(c.consent?.permissions.net, {'x.example.com'});
  });

  test('an update keeps the old version until its access is allowed', () async {
    final c = PluginsController([
      plugin('dev.a.b', installed: true),
    ], delegate: delegate);
    delegate.file = plugin(
      'dev.a.b',
      version: '2.0.0',
      permissions: '  net: [api.example.com]',
    );
    await c.installFromFile();
    expect(c.entry('dev.a.b')!.manifest.version, '1.0.0');
    expect(c.entry('dev.a.b')!.update?.manifest.version, '2.0.0');
    expect(c.consent?.permissions.net, {'api.example.com'});

    // Declined: the update waits on the plugin's page.
    c.cancelConsent();
    expect(delegate.calls, isEmpty);
    c.requestUpdate('dev.a.b');
    await c.allowConsent();
    expect(c.entry('dev.a.b')!.manifest.version, '2.0.0');
    expect(c.entry('dev.a.b')!.update, isNull);
    expect(delegate.calls, ['update dev.a.b 2.0.0']);
  });

  test('refuses an older version, a built-in id and a broken bundle', () async {
    final c = PluginsController([
      plugin('dev.a.b', installed: true, version: '1.2.0'),
      PluginEntry.parse(
        'id: dev.mollygram.filters\nname: Filters\nversion: 1.0.0\n'
        'runtime: js\nsdk: ^1.0',
        builtIn: true,
      ),
    ], delegate: delegate);
    delegate.file = plugin('dev.a.b', version: '1.1.0');
    await c.installFromFile();
    expect(c.installFailure?.problem, InstallProblem.older);
    expect(c.entry('dev.a.b')!.manifest.version, '1.2.0');

    delegate.file = plugin('dev.mollygram.filters', version: '9.0.0');
    await c.installFromFile();
    expect(c.installFailure?.problem, InstallProblem.builtIn);

    delegate.invalid = ['unknown permission "camera"'];
    await c.installFromFile();
    expect(c.installFailure?.problem, InstallProblem.invalid);
    expect(c.installFailure?.details, ['unknown permission "camera"']);
    c.dismissInstallFailure();
    expect(c.installFailure, isNull);
    // Refused files are forgotten.
    expect(delegate.calls, [
      'discard dev.a.b',
      'discard dev.mollygram.filters',
    ]);

    delegate
      ..invalid = null
      ..file = plugin('dev.a.b', version: '1.2.0');
    await c.installFromFile();
    expect(c.installFailure?.problem, InstallProblem.sameVersion);
  });

  test('a declined install is forgotten, a failed one undone', () async {
    final c = PluginsController([], delegate: delegate);
    delegate.file = plugin('dev.new.one', permissions: '  storage: 1mb');
    await c.installFromFile();
    c.cancelConsent();
    expect(delegate.calls, ['discard dev.new.one']);

    delegate.failInstall = true;
    c.requestInstall('dev.new.one');
    await c.allowConsent();
    expect(c.entry('dev.new.one')!.installed, isFalse);
    expect(c.installFailure?.problem, InstallProblem.notSaved);
    expect(c.installFailure?.details, ['disk full']);
  });

  test('escalation matches the host rule', () {
    final old = PermissionSet.parse({
      'messages.read': 'chats[]',
      'storage': '1mb',
    });
    final next = PermissionSet.parse({
      'messages.read': 'all',
      'storage': '1mb',
      'media.read': ['voice'],
    });
    final e = escalation(next, old);
    expect(e.messagesRead, MessagesScope.all);
    expect(e.storageBytes, 0);
    expect(e.mediaRead, {MediaKind.voice});
    expect(next.escalationsFrom(old), hasLength(2));
  });

  test('relative dates in both languages', () {
    final now = DateTime(2026, 10, 13, 12);
    String en(int d) =>
        PluginsStrings.en.ago(now.subtract(Duration(days: d)), now);
    String ru(int d) =>
        PluginsStrings.ru.ago(now.subtract(Duration(days: d)), now);
    expect(
      [en(0), en(1), en(3), en(14), en(31)],
      ['today', 'yesterday', '3 days ago', '2 weeks ago', 'a month ago'],
    );
    expect(
      [ru(1), ru(3), ru(5), ru(14), ru(31)],
      ['вчера', '3 дня назад', '5 дней назад', '2 нед. назад', 'месяц назад'],
    );
  });
}
