import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'plugin_instance.dart';

/// The `storage` service: a JSON key-value store per plugin, one file each,
/// `<id>.json` in [folder].
///
/// A plugin's whole file must stay within the `storage` size from its
/// manifest, which the host passes as `quota` with each call. A write that
/// would go over it fails with `quota_exceeded` and changes nothing.
///
/// The size is kept per key, so a write encodes only its own value. Files
/// are encoded and written in a background isolate, and writes that come
/// while one is waiting are folded into it.
final class PluginStorage {
  PluginStorage(this.folder);

  final Directory folder;
  final _data = <String, Future<_Store>>{};
  final _writes = <String, Future<void>>{};

  /// A write that has not started yet: later changes ride along with it.
  final _queued = <String, Future<void>>{};

  /// Handles `storage.get`, `storage.set` and `storage.delete`.
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  ) async {
    final key = args['key']! as String;
    final store = await _load(pluginId);
    switch (method) {
      case 'storage.get':
        return store.values[key];
      case 'storage.delete':
        if (store.remove(key)) await _save(pluginId, store);
        return null;
      case 'storage.set':
        final value = args['value'];
        if (value == null) {
          if (store.remove(key)) await _save(pluginId, store);
          return null;
        }
        final quota = args['quota'] as int? ?? 0;
        final entry = _Store.sizeOf(key, value);
        final size = store.bytes - (store.sizes[key] ?? 0) + entry;
        if (size > quota) {
          throw HostError(
            'quota_exceeded',
            'storage would take $size bytes, the limit is $quota',
          );
        }
        store.put(key, value, entry);
        await _save(pluginId, store);
        return null;
    }
    throw HostError('no_method', 'no method $method');
  }

  /// Forgets everything [pluginId] stored, when it is uninstalled.
  Future<void> clear(String pluginId) async {
    final store = await _load(pluginId);
    store.clear();
    await (_writes[pluginId] ?? Future<void>.value());
    final file = _file(pluginId);
    if (await file.exists()) await file.delete();
  }

  File _file(String id) => File('${folder.path}/$id.json');

  Future<_Store> _load(String id) => _data[id] ??= () async {
    try {
      final raw = jsonDecode(await _file(id).readAsString());
      if (raw is Map<String, Object?>) return _Store(raw);
    } on Object {
      // Missing or unreadable: the plugin starts over with nothing.
    }
    return _Store({});
  }();

  /// Writes after the previous write, to a temporary file that replaces
  /// the old one, so a crash leaves either version.
  Future<void> _save(String id, _Store store) {
    final queued = _queued[id];
    if (queued != null) return queued;
    final path = _file(id).path;
    final write = (_writes[id] ?? Future<void>.value()).then((_) async {
      unawaited(_queued.remove(id));
      final snapshot = Map<String, Object?>.of(store.values);
      await Isolate.run(_writer(path, snapshot));
    });
    _queued[id] = write;
    // A failed write is the caller's error; the next one still runs.
    _writes[id] = write.catchError((Object _) {});
    return write;
  }
}

/// The write for [Isolate.run], holding nothing but its arguments.
Future<void> Function() _writer(String path, Map<String, Object?> data) =>
    () => _write(path, data);

Future<void> _write(String path, Map<String, Object?> data) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final tmp = File('$path.tmp');
  await tmp.writeAsString(jsonEncode(data), flush: true);
  await tmp.rename(path);
}

/// One plugin's values and the bytes each takes in the file.
final class _Store {
  _Store(this.values) {
    for (final MapEntry(:key, :value) in values.entries) {
      final size = sizeOf(key, value);
      sizes[key] = size;
      bytes += size;
    }
  }

  final Map<String, Object?> values;
  final sizes = <String, int>{};

  /// The file's size, give or take the braces.
  var bytes = 0;

  /// `"key":value,` in UTF-8.
  static int sizeOf(String key, Object? value) =>
      utf8.encode(jsonEncode(key)).length +
      utf8.encode(jsonEncode(value)).length +
      2;

  void put(String key, Object? value, int size) {
    bytes += size - (sizes[key] ?? 0);
    sizes[key] = size;
    values[key] = value;
  }

  bool remove(String key) {
    if (!values.containsKey(key)) return false;
    values.remove(key);
    bytes -= sizes.remove(key) ?? 0;
    return true;
  }

  void clear() {
    values.clear();
    sizes.clear();
    bytes = 0;
  }
}
