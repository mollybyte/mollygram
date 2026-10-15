import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:plugin_host/plugin_host.dart';

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
    final file = File('${(await _dir()).path}/state.json');
    final String text;
    try {
      if (!await file.exists()) return {};
      text = await file.readAsString();
    } on FileSystemException {
      return {};
    }
    try {
      final json = jsonDecode(text);
      if (json is! Map) throw const FormatException('not an object');
      return {
        for (final MapEntry(:key, :value) in json.entries)
          '$key': PluginState.fromJson(value),
      };
    } on FormatException {
      // Unreadable: kept aside rather than overwritten by the next save.
      try {
        await file.copy('${file.path}.bak');
      } on FileSystemException {
        // Nothing more to do.
      }
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
      final name = dir.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      // Copies still being written or replaced.
      if (name.endsWith('.tmp') || name.endsWith('.old')) continue;
      try {
        final manifestSource = await File('${dir.path}/manifest.yaml')
            .readAsString();
        // The folder must hold the plugin it is named after.
        if (PluginManifest.parse(manifestSource).id != name) continue;
        bundles.add(
          StoredBundle(
            id: name,
            manifestSource: manifestSource,
            source: await File('${dir.path}/index.js').readAsString(),
          ),
        );
      } on FileSystemException {
        // A damaged copy: skipped, the user can install it again.
      } on ManifestException {
        // Same.
      }
    }
    return bundles;
  }

  /// Writes the copy next to the old one and swaps them, so a failure
  /// halfway leaves the installed version as it was.
  @override
  Future<void> writeBundle(StoredBundle bundle) async {
    final dir = await _bundleDir(bundle.id);
    final temp = Directory('${dir.path}.tmp');
    final old = Directory('${dir.path}.old');
    for (final d in [temp, old]) {
      if (await d.exists()) await d.delete(recursive: true);
    }
    await temp.create(recursive: true);
    await File('${temp.path}/index.js')
        .writeAsString(bundle.source, flush: true);
    await File('${temp.path}/manifest.yaml')
        .writeAsString(bundle.manifestSource, flush: true);
    if (await dir.exists()) await dir.rename(old.path);
    await temp.rename(dir.path);
    if (await old.exists()) await old.delete(recursive: true);
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

  /// Makes [writeBundle] fail, as a full disk would.
  var failWrites = false;

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
  Future<void> writeBundle(StoredBundle bundle) async {
    if (failWrites) throw const FileSystemException('disk full');
    bundles[bundle.id] = bundle;
  }

  @override
  Future<void> deleteBundle(String id) async => bundles.remove(id);
}
