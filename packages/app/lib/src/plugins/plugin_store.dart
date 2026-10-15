import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// What the user chose for one plugin: on or off, its settings and when it
/// was last installed or updated.
final class PluginState {
  const PluginState({
    this.enabled = true,
    this.settings = const {},
    this.updatedAt,
  });

  final bool enabled;
  final Map<String, Object?> settings;
  final DateTime? updatedAt;

  PluginState copyWith({
    bool? enabled,
    Map<String, Object?>? settings,
    DateTime? updatedAt,
  }) => PluginState(
    enabled: enabled ?? this.enabled,
    settings: settings ?? this.settings,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'settings': settings,
    if (updatedAt != null) 'updatedAt': updatedAt!.millisecondsSinceEpoch,
  };

  static PluginState fromJson(Object? json) {
    if (json is! Map) return const PluginState();
    final settings = json['settings'];
    final updated = json['updatedAt'];
    return PluginState(
      enabled: json['enabled'] != false,
      settings: settings is Map ? settings.cast<String, Object?>() : const {},
      updatedAt: updated is int
          ? DateTime.fromMillisecondsSinceEpoch(updated)
          : null,
    );
  }
}

/// A third-party plugin as installed: its manifest as written and its code.
final class StoredBundle {
  const StoredBundle({
    required this.id,
    required this.manifestSource,
    required this.source,
  });

  final String id;
  final String manifestSource;
  final String source;
}

/// Where installed plugins and their choices are kept.
abstract interface class PluginStore {
  Future<Map<String, PluginState>> readStates();
  Future<void> writeStates(Map<String, PluginState> states);
  Future<List<StoredBundle>> readBundles();
  Future<void> writeBundle(StoredBundle bundle);
  Future<void> deleteBundle(String id);
}

/// `plugins/` in the app support folder: `state.json` and a folder per
/// installed plugin with a copy of its `manifest.yaml` and code, so the
/// plugin keeps working after the file it came from is moved or deleted.
final class FilePluginStore implements PluginStore {
  FilePluginStore([this._root]);

  Directory? _root;

  Future<Directory> _dir() async => _root ??= Directory(
    '${(await getApplicationSupportDirectory()).path}/plugins',
  );

  // Plugin ids are reverse domain names (checked by the manifest), so they
  // are safe folder names.
  Future<Directory> _bundleDir(String id) async =>
      Directory('${(await _dir()).path}/bundles/$id');

  @override
  Future<Map<String, PluginState>> readStates() async {
    try {
      final file = File('${(await _dir()).path}/state.json');
      if (!await file.exists()) return {};
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return {};
      return {
        for (final MapEntry(:key, :value) in json.entries)
          '$key': PluginState.fromJson(value),
      };
    } on Object {
      return {};
    }
  }

  @override
  Future<void> writeStates(Map<String, PluginState> states) async {
    final dir = await _dir();
    await dir.create(recursive: true);
    final temp = File('${dir.path}/state.json.tmp');
    await temp.writeAsString(
      jsonEncode({for (final e in states.entries) e.key: e.value.toJson()}),
      flush: true,
    );
    await temp.rename('${dir.path}/state.json');
  }

  @override
  Future<List<StoredBundle>> readBundles() async {
    final root = Directory('${(await _dir()).path}/bundles');
    if (!await root.exists()) return [];
    final bundles = <StoredBundle>[];
    await for (final dir in root.list()) {
      if (dir is! Directory) continue;
      try {
        bundles.add(
          StoredBundle(
            id: dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
            manifestSource: await File('${dir.path}/manifest.yaml')
                .readAsString(),
            source: await File('${dir.path}/index.js').readAsString(),
          ),
        );
      } on FileSystemException {
        // A half-written copy: skipped, the user can install it again.
      }
    }
    return bundles;
  }

  @override
  Future<void> writeBundle(StoredBundle bundle) async {
    final dir = await _bundleDir(bundle.id);
    await dir.create(recursive: true);
    await File('${dir.path}/index.js')
        .writeAsString(bundle.source, flush: true);
    await File('${dir.path}/manifest.yaml')
        .writeAsString(bundle.manifestSource, flush: true);
  }

  @override
  Future<void> deleteBundle(String id) async {
    final dir = await _bundleDir(id);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// A [PluginStore] in memory, for tests.
final class MemoryPluginStore implements PluginStore {
  MemoryPluginStore({
    Map<String, PluginState>? states,
    List<StoredBundle>? bundles,
  }) : states = {...?states},
       bundles = {for (final b in bundles ?? <StoredBundle>[]) b.id: b};

  final Map<String, PluginState> states;
  final Map<String, StoredBundle> bundles;

  @override
  Future<Map<String, PluginState>> readStates() async => {...states};

  @override
  Future<void> writeStates(Map<String, PluginState> next) async {
    states
      ..clear()
      ..addAll(next);
  }

  @override
  Future<List<StoredBundle>> readBundles() async => [...bundles.values];

  @override
  Future<void> writeBundle(StoredBundle bundle) async =>
      bundles[bundle.id] = bundle;

  @override
  Future<void> deleteBundle(String id) async => bundles.remove(id);
}
