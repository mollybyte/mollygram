import 'dart:io';

import 'package:plugin_host/plugin_host.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('storage'));
  tearDown(() => dir.delete(recursive: true));

  Future<Object?> call(
    PluginStorage s,
    String method,
    String key, [
    Object? value,
  ]) => s.call('dev.a.b', method, {'key': key, 'value': value, 'quota': 200});

  test('keeps values per plugin in a JSON file', () async {
    final s = PluginStorage(dir);
    await call(s, 'storage.set', 'k', {'n': 1});
    await s.call('dev.other.plugin', 'storage.set', {
      'key': 'k',
      'value': 2,
      'quota': 100,
    });
    expect(await call(s, 'storage.get', 'k'), {'n': 1});

    // A new instance reads what the old one wrote.
    final again = PluginStorage(dir);
    expect(await call(again, 'storage.get', 'k'), {'n': 1});
    await call(again, 'storage.delete', 'k');
    expect(await call(PluginStorage(dir), 'storage.get', 'k'), isNull);
    expect(
      await PluginStorage(dir)
          .call('dev.other.plugin', 'storage.get', {'key': 'k'}),
      2,
    );
  });

  test('a write over the limit fails and changes nothing', () async {
    final s = PluginStorage(dir);
    await call(s, 'storage.set', 'a', 'x' * 100);
    await expectLater(
      call(s, 'storage.set', 'b', 'x' * 100),
      throwsA(isA<HostError>().having((e) => e.code, 'code', 'quota_exceeded')),
    );
    expect(await call(s, 'storage.get', 'b'), isNull);
    // Replacing a value counts only the new one.
    await call(s, 'storage.set', 'a', 'y' * 150);
    expect(await call(PluginStorage(dir), 'storage.get', 'a'), 'y' * 150);
  });

  test('writes close together all land, in order', () async {
    final s = PluginStorage(dir);
    await Future.wait([
      for (var i = 0; i < 20; i++) call(s, 'storage.set', 'k$i', i),
      call(s, 'storage.delete', 'k3'),
    ]);
    final again = PluginStorage(dir);
    expect(await call(again, 'storage.get', 'k19'), 19);
    expect(await call(again, 'storage.get', 'k3'), isNull);
  });

  test('an unreadable file starts over, clear forgets everything', () async {
    File('${dir.path}/dev.a.b.json').writeAsStringSync('{broken');
    final s = PluginStorage(dir);
    expect(await call(s, 'storage.get', 'k'), isNull);
    await call(s, 'storage.set', 'k', 1);
    await s.clear('dev.a.b');
    expect(File('${dir.path}/dev.a.b.json').existsSync(), isFalse);
    expect(await call(s, 'storage.get', 'k'), isNull);
  });
}
