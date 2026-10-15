import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'plugin_instance.dart';

/// The `storage` service: a JSON key-value store per plugin, one file each,
/// `<id>.json` in [folder].
///
/// A plugin's whole file must stay within the `storage` size from its
/// manifest, which the host passes as `quota` with each call. A write that
/// would go over it fails with `quota_exceeded` and changes nothing.
final class PluginStorage {
  PluginStorage(this.folder);

  final Directory folder;
  final _data = <String, Future<Map<String, Object?>>>{};
  final _writes = <String, Future<void>>{};

  /// Handles `storage.get`, `storage.set` and `storage.delete`.
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  ) async {
    final key = args['key']! as String;
    final data = await _load(pluginId);
    switch (method) {
      case 'storage.get':
        return data[key];
      case 'storage.delete':
        if (data.remove(key) != null) await _save(pluginId, data);
        return null;
      case 'storage.set':
        final value = args['value'];
        if (value == null) {
          if (data.remove(key) != null) await _save(pluginId, data);
          return null;
        }
        final quota = args['quota'] as int? ?? 0;
        final next = {...data, key: value};
        final size = utf8.encode(jsonEncode(next)).length;
        if (size > quota) {
          throw HostError(
            'quota_exceeded',
            'storage would take $size bytes, the limit is $quota',
          );
        }
        data[key] = value;
        await _save(pluginId, data);
        return null;
    }
    throw HostError('no_method', 'no method $method');
  }

  /// Forgets everything [pluginId] stored, when it is uninstalled.
  Future<void> clear(String pluginId) async {
    final data = await _load(pluginId);
    data.clear();
    await (_writes[pluginId] ?? Future<void>.value());
    final file = _file(pluginId);
    if (await file.exists()) await file.delete();
  }

  File _file(String id) => File('${folder.path}/$id.json');

  Future<Map<String, Object?>> _load(String id) => _data[id] ??= () async {
    try {
      final raw = jsonDecode(await _file(id).readAsString());
      if (raw is Map<String, Object?>) return raw;
    } on Object {
      // Missing or unreadable: the plugin starts over with nothing.
    }
    return <String, Object?>{};
  }();

  /// Writes in order, each one complete before the next, to a temporary
  /// file that replaces the old one, so a crash leaves either version.
  Future<void> _save(String id, Map<String, Object?> data) {
    final text = jsonEncode(data);
    final write = (_writes[id] ?? Future<void>.value()).then((_) async {
      await folder.create(recursive: true);
      final tmp = File('${_file(id).path}.tmp');
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(_file(id).path);
    });
    // A failed write is the caller's error; the next one still runs.
    _writes[id] = write.catchError((Object _) {});
    return write;
  }
}
