import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:plugin_host/plugin_host.dart';

import '../session/providers.dart';
import 'plugin_store.dart';

/// The events the app delivers to plugins so far. A plugin that hooks none
/// of them and has no commands is never started. Spec: docs/plugins.md,
/// "Running in the app".
const deliveredEvents = {
  PluginEvent.messageRenderCode,
  PluginEvent.messageRenderText,
  PluginEvent.messageFilter,
};

/// A message as plugins see it (`Mg.Message` in the SDK).
typedef PluginMessage = ({
  int chatId,
  int id,
  int senderId,
  int date,
  String text,
  bool outgoing,
});

Map<String, Object?> _payloadOf(PluginMessage m) => {
  'chatId': m.chatId,
  'id': m.id,
  'senderId': m.senderId,
  'date': m.date,
  'text': m.text,
  'outgoing': m.outgoing,
};

/// What one plugin rendered under a message (`message.render.text`).
typedef PluginBlock = ({String pluginId, List<Map<String, Object?>> ui});

/// A plugin's command, as the ⌘K palette lists it.
typedef PluginCommandEntry = ({PluginEntry plugin, PluginCommand command});

/// A plugin running in the sandbox, as the app uses it.
abstract interface class RunningPlugin {
  Future<EventOutcome> dispatch(
    PluginEvent event,
    Map<String, Object?> payload,
  );
  Future<void> updateSetting(String key, Object? value);
  Future<Object?> runCommand(String name, {int? chatId});

  /// Each line the plugin logs, including why the host turned it off.
  Stream<String> get logLines;

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
  required PluginServices services,
});

/// Starts a plugin in its own isolate (see `PluginWorker`).
Future<RunningPlugin> launchInWorker(
  PluginManifest manifest,
  String source, {
  required Map<String, Object?> settings,
  required String locale,
  required PluginServices services,
}) async => _WorkerPlugin(
  await PluginWorker.start(
    manifest: manifest,
    source: source,
    services: services,
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
  Future<Object?> runCommand(String name, {int? chatId}) =>
      _worker.runCommand(name, chatId: chatId);
  @override
  Stream<String> get logLines => _worker.logLines;
  @override
  Stream<PluginStatus> get statusChanges => _worker.statusChanges;
  @override
  String? get disabledReason => _worker.disabledReason;
  @override
  void stop() => _worker.stop();
}

/// Translates a message with Telegram (`messages.translate`).
typedef MessageTranslator = Future<String> Function(
  int chatId,
  int messageId,
  String to,
);

/// The host services the app offers plugins: `storage`, on-device
/// language detection and Telegram's translation. The host has checked
/// permissions already. Everything else fails with a code the plugin can
/// read.
final class AppPluginServices implements PluginServices {
  AppPluginServices({required this.storage, this.translate});

  final PluginStorage storage;
  final MessageTranslator? translate;

  @override
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  ) async {
    switch (method) {
      case 'storage.get' || 'storage.set' || 'storage.delete':
        return storage.call(pluginId, method, args);
      case 'text.detectLanguage':
        final found = detectLanguage(args['text']! as String);
        return found == null
            ? null
            : {'language': found.language, 'confidence': found.confidence};
      case 'messages.translate':
        final translate = this.translate;
        final chat = args['chatId'], message = args['messageId'];
        if (translate == null || chat is! int || message is! int) break;
        try {
          return {
            'text': await translate(chat, message, args['to']! as String),
          };
        } on Object catch (e) {
          throw HostError('translation_failed', '$e');
        }
      case 'ui.toast':
        return null;
    }
    throw HostError('unavailable', '$method is not available');
  }
}

/// Asks for a plugin's `manifest.yaml`; its folder is the plugin.
Future<File?> pickPluginManifest() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Plugin manifest', extensions: ['yaml']),
    ],
  );
  return file == null ? null : File(file.path);
}

/// How long the app waits for a plugin to start or to answer an event
/// before giving up on it; the host's own limits are shorter.
const launchTimeout = Duration(seconds: 10);
const eventTimeout = Duration(seconds: 6);

/// A plugin that fails to start is tried again after [launchRetry] times
/// 2, 4, … and turned off after [maxLaunchFailures] failures in a row.
const launchRetry = Duration(seconds: 5);
const maxLaunchFailures = 3;

/// An approved plugin that could not be installed.
final class PluginInstallError implements Exception {
  const PluginInstallError(this.message);

  final String message;

  @override
  String toString() => message;
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
    this._services,
  );

  final PluginStore _store;
  final PluginLauncher _launch;
  final Future<File?> Function() _pick;
  final String _locale;
  final Map<String, PluginState> _states;

  /// Code of every known plugin, by id.
  final Map<String, String> _sources;
  final AppPluginServices _services;

  /// Picked bundles waiting for the user's consent, by id.
  final _pending = <String, StoredBundle>{};
  final _running = <String, Future<RunningPlugin?>>{};
  final _subscriptions = <String, StreamSubscription<PluginStatus>>{};
  Future<void> _writes = Future.value();
  final _cache = <(String, String?), List<CodeSpan>?>{};
  final _verdicts = <PluginMessage, EventFiltered?>{};
  final _asking = <PluginMessage, Future<EventFiltered?>>{};
  final _blocks = <PluginMessage, List<PluginBlock>>{};
  final _revealed = <(int, int)>{};
  final _logs = <String, ListQueue<String>>{};
  final _launchFailures = <String, int>{};
  final _retryAt = <String, DateTime>{};
  final _logSubscriptions = <String, StreamSubscription<String>>{};

  late final PluginsController controller;

  /// Bumped whenever what renders a message may have changed: a plugin
  /// turned on or off, updated, or a setting changed.
  final revision = ValueNotifier(0);

  /// Bumped, at most a few times a second, when a plugin's log grows.
  final logRevision = ValueNotifier(0);

  /// Bumped, once a frame at most, when filter answers arrive.
  final verdictRevision = ValueNotifier(0);

  /// The last lines a plugin logged in this run of the app, oldest first.
  List<String> logsOf(String id) => List.unmodifiable(_logs[id] ?? const []);

  void _log(String id, String line) {
    final lines = _logs.putIfAbsent(id, ListQueue.new);
    lines.add(line);
    if (lines.length > PluginInstance.maxLogLines) lines.removeFirst();
    _logBump ??= Timer(const Duration(milliseconds: 250), () {
      _logBump = null;
      logRevision.value++;
    });
  }

  Timer? _logBump;
  Timer? _verdictBump;

  /// See [launchRetry]; shorter in tests.
  @visibleForTesting
  Duration retryDelay = launchRetry;

  static Future<AppPlugins> load({
    required PluginStore store,
    PluginLauncher launch = launchInWorker,
    Future<File?> Function() pick = pickPluginManifest,
    List<BuiltinPlugin>? builtin,
    String? locale,
    MessageTranslator? translate,
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
      AppPluginServices(
        storage: PluginStorage(await store.dataFolder()),
        translate: translate,
      ),
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
      try {
        final plugin = await _plugin(e.id);
        if (plugin == null) continue;
        final outcome = await plugin
            .dispatch(PluginEvent.messageRenderCode, {
              'code': code,
              'language': ?language,
            })
            .timeout(eventTimeout);
        if (outcome is EventHandled) {
          result = codeSpansFor(outcome.ui, code);
          if (result != null) break;
        }
      } on Object {
        // One plugin failing leaves the block to the next one.
      }
    }
    // A change while this ran makes the answer stale: not kept.
    if (at == revision.value) {
      if (_cache.length >= 300) _cache.remove(_cache.keys.first);
      _cache[key] = result;
    }
    return result;
  }

  /// Asks each running plugin that hooks [event] in turn, in install order.
  /// A plugin that fails or does not answer in time is left out.
  Stream<(String, EventOutcome)> _ask(
    PluginEvent event,
    Map<String, Object?> payload,
  ) async* {
    for (final e in [...controller.entries]) {
      if (!e.manifest.hooks.contains(event.id)) continue;
      final EventOutcome outcome;
      try {
        final plugin = await _plugin(e.id);
        if (plugin == null) continue;
        outcome = await plugin.dispatch(event, payload).timeout(eventTimeout);
      } on Object {
        continue;
      }
      yield (e.id, outcome);
    }
  }

  /// Whether any plugin that is on filters messages.
  bool get filters => controller.entries.any(
    (e) => e.active && e.manifest.hooks.contains(PluginEvent.messageFilter.id),
  );

  /// The answer for [m] if it is known now; otherwise it is asked for, and
  /// [verdictRevision] moves when it arrives. Without filter plugins the
  /// answer is always known: shown.
  ({bool known, EventFiltered? verdict}) verdictNow(PluginMessage m) {
    if (_verdicts.containsKey(m)) return (known: true, verdict: _verdicts[m]);
    if (!filters) return (known: true, verdict: null);
    unawaited(
      filterMessage(m).then((_) {
        _verdictBump ??= Timer(const Duration(milliseconds: 16), () {
          _verdictBump = null;
          verdictRevision.value++;
        });
      }),
    );
    return (known: false, verdict: null);
  }

  /// Whether the user chose to see the filtered message [m] anyway.
  bool isRevealed(PluginMessage m) => _revealed.contains((m.chatId, m.id));

  void reveal(PluginMessage m) => _revealed.add((m.chatId, m.id));

  /// Whether `message.filter` plugins collapse or hide [m]; null to show it.
  /// The strongest answer wins, and an invalid one counts as none.
  Future<EventFiltered?> filterMessage(PluginMessage m) async {
    if (_verdicts.containsKey(m)) return _verdicts[m];
    return _asking[m] ??= _filter(m).whenComplete(() {
      // A block: the removed future is this one, not to be waited for.
      _asking.remove(m);
    });
  }

  Future<EventFiltered?> _filter(PluginMessage m) async {
    final at = revision.value;
    EventFiltered? verdict;
    await for (final (_, outcome) in _ask(PluginEvent.messageFilter, {
      'message': _payloadOf(m),
    })) {
      if (outcome is EventFiltered &&
          (verdict == null || outcome.verdict.index > verdict.verdict.index)) {
        verdict = outcome;
      }
    }
    if (at == revision.value) {
      if (_verdicts.length >= 1000) _verdicts.remove(_verdicts.keys.first);
      _verdicts[m] = verdict;
    }
    return verdict;
  }

  /// What `message.render.text` plugins showed under [m] last, if known.
  List<PluginBlock>? cachedBlocks(PluginMessage m) => _blocks[m];

  /// What `message.render.text` plugins show under [m].
  Future<List<PluginBlock>> renderText(PluginMessage m) async {
    final known = _blocks[m];
    if (known != null) return known;
    final at = revision.value;
    final blocks = [
      await for (final (id, outcome) in _ask(PluginEvent.messageRenderText, {
        'message': _payloadOf(m),
      }))
        if (outcome is EventHandled && outcome.ui.isNotEmpty)
          (pluginId: id, ui: outcome.ui),
    ];
    if (at == revision.value) _remember(m, blocks);
    return blocks;
  }

  void _remember(PluginMessage m, List<PluginBlock> blocks) {
    _blocks.remove(m);
    if (_blocks.length >= 300) _blocks.remove(_blocks.keys.first);
    _blocks[m] = blocks;
  }

  /// Passes a tap on a plugin's button under [m] to that plugin. Returns
  /// what to show instead, or null to keep what is shown.
  Future<List<Map<String, Object?>>?> action(
    String pluginId,
    String action,
    Object? payload,
    PluginMessage m,
  ) async {
    final plugin = await _plugin(pluginId);
    if (plugin == null) return null;
    try {
      final at = revision.value;
      final outcome = await plugin.dispatch(PluginEvent.uiAction, {
        'action': action,
        'payload': ?payload,
        'message': _payloadOf(m),
      });
      if (outcome is! EventHandled) return null;
      // The answer stays when the message scrolls away and back.
      final shown = _blocks[m];
      if (shown != null && at == revision.value) {
        _remember(m, [
          for (final b in shown)
            b.pluginId == pluginId ? (pluginId: pluginId, ui: outcome.ui) : b,
        ]);
      }
      return outcome.ui;
    } on Object {
      return null;
    }
  }

  /// The commands of the plugins that are on, for the ⌘K palette.
  List<PluginCommandEntry> get commands => [
    for (final e in controller.entries)
      if (e.active)
        for (final c in e.manifest.commands) (plugin: e, command: c),
  ];

  /// Runs a plugin's command in [chatId], the chat in front. A failure is
  /// written to the plugin's log.
  Future<void> runCommand(String pluginId, String name, {int? chatId}) async {
    try {
      final plugin = await _plugin(pluginId);
      await plugin?.runCommand(name, chatId: chatId);
    } on Object catch (e) {
      _log(pluginId, 'error: $name: $e');
    }
  }

  /// The running plugin, started now if it should run and is not yet.
  Future<RunningPlugin?> _plugin(String id) {
    final e = controller.entry(id);
    final source = _sources[id];
    if (e == null || source == null || !e.active || !_delivered(e)) {
      return Future.value();
    }
    final retryAt = _retryAt[id];
    if (retryAt != null && DateTime.now().isBefore(retryAt)) {
      return Future.value();
    }
    late final Future<RunningPlugin?> starting;
    starting = _running[id] ??= () async {
      // Lets `starting` be set before anything below can look at it.
      await Future<void>.value();
      final RunningPlugin p;
      try {
        p = await _launch(
          e.manifest,
          source,
          settings: e.settings,
          locale: _locale,
          services: _services,
        ).timeout(launchTimeout);
      } on Object catch (error) {
        _log(id, 'error: could not start: $error');
        if (identical(_running[id], starting)) unawaited(_running.remove(id));
        // Tried again later, each time waiting longer; after a few
        // failures in a row the plugin is turned off with the reason.
        final failures = _launchFailures[id] = (_launchFailures[id] ?? 0) + 1;
        if (failures >= maxLaunchFailures) {
          _launchFailures.remove(id);
          _retryAt.remove(id);
          controller.markDisabled(id, 'could not start: $error');
          _changed();
        } else {
          _retryAt[id] = DateTime.now().add(retryDelay * (1 << failures));
        }
        return null;
      }
      _launchFailures.remove(id);
      _retryAt.remove(id);
      // Turned off, updated or uninstalled while it was starting.
      if (!identical(_running[id], starting)) {
        p.stop();
        return null;
      }
      void disabled() {
        controller.markDisabled(id, p.disabledReason ?? '');
        _stop(id);
      }

      // A load error is reported before anyone could listen.
      if (p.disabledReason != null) {
        _log(id, 'disabled: ${p.disabledReason}');
        p.stop();
        disabled();
        return null;
      }
      _logSubscriptions[id] = p.logLines.listen((line) => _log(id, line));
      _subscriptions[id] = p.statusChanges.listen((s) {
        if (s == PluginStatus.disabled) disabled();
      });
      return p;
    }();
    return starting;
  }

  static bool _delivered(PluginEntry e) =>
      e.manifest.commands.isNotEmpty ||
      deliveredEvents.any((ev) => e.manifest.hooks.contains(ev.id));

  void _stop(String id) {
    unawaited(_subscriptions.remove(id)?.cancel());
    unawaited(_logSubscriptions.remove(id)?.cancel());
    final running = _running.remove(id);
    unawaited(running?.then((p) => p?.stop()));
    _changed();
  }

  void _changed() {
    _cache.clear();
    _verdicts.clear();
    _blocks.clear();
    _retryAt.clear();
    revision.value++;
    verdictRevision.value++;
  }

  void _save() {
    final snapshot = {..._states};
    _writes = _writes
        .then((_) => _store.writeStates(snapshot))
        .catchError((Object _) {});
  }

  @override
  Future<PluginEntry?> pickFile() async {
    final file = await _pick();
    if (file == null) return null;
    if (file.uri.pathSegments.last != 'manifest.yaml') {
      throw ManifestException(["choose the plugin's manifest.yaml"]);
    }
    final PluginBundle bundle;
    try {
      bundle = await PluginBundle.load(file.parent);
    } on FileSystemException catch (e) {
      throw ManifestException([e.message]);
    }
    final id = bundle.manifest.id;
    _pending[id] = StoredBundle(
      id: id,
      manifestSource: bundle.manifestSource,
      source: bundle.source,
    );
    return PluginEntry.parse(bundle.manifestSource);
  }

  @override
  void discard(PluginEntry entry) => _pending.remove(entry.id);

  /// The picked bundle for [manifestSource], the text the user approved.
  StoredBundle _approved(String id, String manifestSource) {
    final bundle = _pending[id];
    if (bundle == null ||
        bundle.manifestSource.trim() != manifestSource.trim()) {
      throw const PluginInstallError('pick the plugin file again');
    }
    return bundle;
  }

  @override
  Future<void> install(PluginEntry entry) async {
    final bundle = _approved(entry.id, entry.manifestSource);
    await _store.writeBundle(bundle);
    _pending.remove(entry.id);
    _sources[entry.id] = bundle.source;
    _states[entry.id] = PluginState(updatedAt: DateTime.now());
    _save();
    _changed();
  }

  @override
  Future<void> applyUpdate(PluginEntry entry, PluginUpdate update) async {
    final bundle = _approved(entry.id, update.source);
    await _store.writeBundle(bundle);
    _pending.remove(entry.id);
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
    await _store.deleteBundle(entry.id);
    final source = _sources.remove(entry.id);
    _states.remove(entry.id);
    _logs.remove(entry.id);
    unawaited(_services.storage.clear(entry.id).catchError((Object _) {}));
    _save();
    // It stays under Available: installing it again asks again, for this
    // very code, and anything picked earlier is forgotten.
    _pending.remove(entry.id);
    if (source != null) {
      _pending[entry.id] = StoredBundle(
        id: entry.id,
        manifestSource: entry.manifestSource,
        source: source,
      );
    }
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
    _logBump?.cancel();
    _verdictBump?.cancel();
    controller.dispose();
    revision.dispose();
    logRevision.dispose();
    verdictRevision.dispose();
  }
}

final pluginStoreProvider = Provider<PluginStore>((ref) => FilePluginStore());
final pluginLauncherProvider = Provider<PluginLauncher>(
  (ref) => launchInWorker,
);
final pluginManifestPickerProvider = Provider<Future<File?> Function()>(
  (ref) => pickPluginManifest,
);

/// Telegram's translation in the signed-in session.
final pluginTranslatorProvider = Provider<MessageTranslator>(
  (ref) => (chatId, messageId, to) async {
    final session = await ref.read(telegramSessionProvider.future);
    return session.conversations.translate(chatId, messageId, to);
  },
);

final appPluginsProvider = FutureProvider<AppPlugins>((ref) async {
  final plugins = await AppPlugins.load(
    store: ref.watch(pluginStoreProvider),
    launch: ref.watch(pluginLauncherProvider),
    pick: ref.watch(pluginManifestPickerProvider),
    translate: ref.watch(pluginTranslatorProvider),
  );
  ref.onDispose(plugins.dispose);
  return plugins;
});
