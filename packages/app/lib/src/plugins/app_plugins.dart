import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:plugin_host/plugin_host.dart';

import 'plugin_store.dart';

/// The events the app delivers to plugins so far. A plugin that hooks none
/// of them is never started. Spec: docs/plugins.md, "Running in the app".
const deliveredEvents = {PluginEvent.messageRenderCode};

/// A plugin running in the sandbox, as the app uses it.
abstract interface class RunningPlugin {
  Future<EventOutcome> dispatch(
    PluginEvent event,
    Map<String, Object?> payload,
  );
  Future<void> updateSetting(String key, Object? value);

  /// Reports when the host turns the plugin off after failures.
  Stream<PluginStatus> get statusChanges;
  String? get disabledReason;
  void stop();
}

typedef PluginLauncher = Future<RunningPlugin> Function(
  PluginManifest manifest,
  String source, {
  required Map<String, Object?> settings,
  required String locale,
});

/// Starts a plugin in its own isolate (see `PluginWorker`).
Future<RunningPlugin> launchInWorker(
  PluginManifest manifest,
  String source, {
  required Map<String, Object?> settings,
  required String locale,
}) async => _WorkerPlugin(
  await PluginWorker.start(
    manifest: manifest,
    source: source,
    services: const AppPluginServices(),
    settings: settings,
    locale: locale,
  ),
);

final class _WorkerPlugin implements RunningPlugin {
  _WorkerPlugin(this._worker);

  final PluginWorker _worker;

  @override
  Future<EventOutcome> dispatch(PluginEvent e, Map<String, Object?> p) =>
      _worker.dispatch(e, p);
  @override
  Future<void> updateSetting(String key, Object? value) =>
      _worker.updateSetting(key, value);
  @override
  Stream<PluginStatus> get statusChanges => _worker.statusChanges;
  @override
  String? get disabledReason => _worker.disabledReason;
  @override
  void stop() => _worker.stop();
}

/// The host services the app offers plugins so far: none of the delivered
/// events needs one. Everything else fails with a code the plugin can read.
final class AppPluginServices implements PluginServices {
  const AppPluginServices();

  @override
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  ) async => switch (method) {
    'ui.toast' || 'text.detectLanguage' => null,
    _ => throw HostError('unavailable', '$method is not available yet'),
  };
}

/// Asks for a plugin's `manifest.yaml`; its folder is the plugin.
Future<Directory?> pickPluginBundle() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Plugin manifest', extensions: ['yaml', 'yml']),
    ],
  );
  return file == null ? null : File(file.path).parent;
}

/// The plugins of this app: the built-in ones and those the user installed,
/// their settings, and the ones running.
///
/// Implements the settings screen's [PluginsDelegate]: installing copies
/// the bundle into the app's own folder, and a plugin starts the first
/// time the app has an event for it.
final class AppPlugins implements PluginsDelegate {
  AppPlugins._(
    this._store,
    this._launch,
    this._pick,
    this._locale,
    this._states,
    this._sources,
  );

  final PluginStore _store;
  final PluginLauncher _launch;
  final Future<Directory?> Function() _pick;
  final String _locale;
  final Map<String, PluginState> _states;

  /// Code of every known plugin, by id.
  final Map<String, String> _sources;

  /// Picked bundles waiting for the user's consent, by id.
  final _pending = <String, StoredBundle>{};
  final _running = <String, Future<RunningPlugin?>>{};
  final _subscriptions = <String, StreamSubscription<PluginStatus>>{};
  Future<void> _writes = Future.value();
  final _cache = <(String, String?), List<CodeSpan>?>{};

  late final PluginsController controller;

  /// Bumped whenever what renders a message may have changed: a plugin
  /// turned on or off, updated, or a setting changed.
  final revision = ValueNotifier(0);

  static Future<AppPlugins> load({
    required PluginStore store,
    PluginLauncher launch = launchInWorker,
    Future<Directory?> Function() pick = pickPluginBundle,
    List<BuiltinPlugin>? builtin,
    String? locale,
  }) async {
    final own = builtin ?? await loadBuiltinPlugins();
    final states = await store.readStates();
    final entries = <PluginEntry>[];
    final sources = <String, String>{};
    for (final p in own) {
      final s = states[p.entry.id];
      entries.add(
        s == null
            ? p.entry
            : p.entry.copyWith(enabled: s.enabled, settings: s.settings),
      );
      sources[p.entry.id] = p.source;
    }
    for (final b in await store.readBundles()) {
      if (sources.containsKey(b.id)) continue;
      final s = states[b.id] ?? const PluginState();
      try {
        entries.add(
          PluginEntry.parse(
            b.manifestSource,
            installed: true,
            enabled: s.enabled,
            settings: s.settings,
            updatedAt: s.updatedAt,
          ),
        );
        sources[b.id] = b.source;
      } on ManifestException {
        // Written for an SDK this version no longer accepts: left out.
      }
    }
    final lang = locale ?? PlatformDispatcher.instance.locale.languageCode;
    final plugins = AppPlugins._(
      store,
      launch,
      pick,
      lang == 'ru' ? 'ru' : 'en',
      states,
      sources,
    );
    plugins.controller = PluginsController(entries, delegate: plugins);
    return plugins;
  }

  /// Colors a code block with the first plugin that answers, in install
  /// order. Null when none does: the block stays plain.
  Future<List<CodeSpan>?> highlightCode(String code, String? language) async {
    final key = (code, language);
    if (_cache.containsKey(key)) return _cache[key];
    final at = revision.value;
    List<CodeSpan>? result;
    for (final e in controller.entries) {
      if (!e.manifest.hooks.contains(PluginEvent.messageRenderCode.id)) {
        continue;
      }
      final plugin = await _plugin(e.id);
      if (plugin == null) continue;
      final outcome = await plugin.dispatch(PluginEvent.messageRenderCode, {
        'code': code,
        'language': ?language,
      });
      if (outcome is EventHandled) {
        result = codeSpansFor(outcome.ui, code);
        if (result != null) break;
      }
    }
    // A change while this ran makes the answer stale: not kept.
    if (at == revision.value) {
      if (_cache.length >= 300) _cache.remove(_cache.keys.first);
      _cache[key] = result;
    }
    return result;
  }

  /// The running plugin, started now if it should run and is not yet.
  Future<RunningPlugin?> _plugin(String id) {
    final e = controller.entry(id);
    final source = _sources[id];
    if (e == null || source == null || !e.active || !_delivered(e)) {
      return Future.value();
    }
    return _running[id] ??= () async {
      try {
        final p = await _launch(
          e.manifest,
          source,
          settings: e.settings,
          locale: _locale,
        );
        _subscriptions[id] = p.statusChanges.listen((s) {
          if (s != PluginStatus.disabled) return;
          controller.markDisabled(id, p.disabledReason ?? '');
          _stop(id);
        });
        return p;
      } on Object {
        // Could not start: tried again with the next event.
        unawaited(_running.remove(id));
        return null;
      }
    }();
  }

  static bool _delivered(PluginEntry e) =>
      deliveredEvents.any((ev) => e.manifest.hooks.contains(ev.id));

  void _stop(String id) {
    unawaited(_subscriptions.remove(id)?.cancel());
    final running = _running.remove(id);
    unawaited(running?.then((p) => p?.stop()));
    _changed();
  }

  void _changed() {
    _cache.clear();
    revision.value++;
  }

  void _save() {
    final snapshot = {..._states};
    _writes = _writes
        .then((_) => _store.writeStates(snapshot))
        .catchError((Object _) {});
  }

  @override
  Future<PluginEntry?> pickFile() async {
    final dir = await _pick();
    if (dir == null) return null;
    final PluginBundle bundle;
    final String manifestSource;
    try {
      bundle = await PluginBundle.load(dir);
      manifestSource = await File('${dir.path}/manifest.yaml').readAsString();
    } on FileSystemException catch (e) {
      throw ManifestException([e.message]);
    }
    final id = bundle.manifest.id;
    _pending[id] = StoredBundle(
      id: id,
      manifestSource: manifestSource,
      source: bundle.source,
    );
    return PluginEntry.parse(manifestSource);
  }

  @override
  Future<void> install(PluginEntry entry) async {
    final bundle = _pending.remove(entry.id);
    if (bundle == null) return;
    await _store.writeBundle(bundle);
    _sources[entry.id] = bundle.source;
    _states[entry.id] = PluginState(updatedAt: DateTime.now());
    _save();
    _changed();
  }

  @override
  Future<void> applyUpdate(PluginEntry entry, PluginUpdate update) async {
    final bundle = _pending.remove(entry.id);
    if (bundle == null) return;
    await _store.writeBundle(bundle);
    _sources[entry.id] = bundle.source;
    _states[entry.id] = (_states[entry.id] ?? const PluginState()).copyWith(
      updatedAt: DateTime.now(),
    );
    _save();
    // The next event starts the new version.
    _stop(entry.id);
  }

  @override
  Future<void> uninstall(PluginEntry entry) async {
    _stop(entry.id);
    _sources.remove(entry.id);
    _states.remove(entry.id);
    _save();
    await _store.deleteBundle(entry.id);
  }

  @override
  Future<void> setEnabled(PluginEntry entry, bool enabled) async {
    _states[entry.id] = (_states[entry.id] ?? const PluginState()).copyWith(
      enabled: enabled,
    );
    _save();
    // Off stops it; on starts it with the next event, failures forgotten.
    _stop(entry.id);
  }

  @override
  Future<void> setSetting(PluginEntry entry, String key, Object? value) async {
    final state = _states[entry.id] ?? const PluginState();
    _states[entry.id] = state.copyWith(
      settings: {...state.settings, key: value},
    );
    _save();
    final running = await _running[entry.id];
    await running?.updateSetting(key, value);
    _changed();
  }

  /// Waits for settings still being written, for tests and quitting.
  Future<void> flush() => _writes;

  void dispose() {
    for (final id in [..._running.keys]) {
      _stop(id);
    }
    controller.dispose();
    revision.dispose();
  }
}

final pluginStoreProvider = Provider<PluginStore>((ref) => FilePluginStore());
final pluginLauncherProvider = Provider<PluginLauncher>(
  (ref) => launchInWorker,
);
final pluginBundlePickerProvider = Provider<Future<Directory?> Function()>(
  (ref) => pickPluginBundle,
);

final appPluginsProvider = FutureProvider<AppPlugins>((ref) async {
  final plugins = await AppPlugins.load(
    store: ref.watch(pluginStoreProvider),
    launch: ref.watch(pluginLauncherProvider),
    pick: ref.watch(pluginBundlePickerProvider),
  );
  ref.onDispose(plugins.dispose);
  return plugins;
});
