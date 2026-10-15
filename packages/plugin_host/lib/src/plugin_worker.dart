import 'dart:async';
import 'dart:isolate';

import 'manifest.dart';
import 'permissions.dart';
import 'plugin_instance.dart';

/// A plugin in a separate isolate.
///
/// JS never runs in the UI isolate, so even a plugin that hits its time
/// budget on every event does not drop the frame rate. Services are called
/// in the app isolate: the worker forwards only calls that are already
/// authorized.
/// What the isolate sends when it exits; a plain string, as exit
/// messages must be.
const _exited = 'mg.worker.exited';

final class PluginWorker {
  PluginWorker._(this.manifest, this._services);

  final PluginManifest manifest;
  final PluginServices _services;

  late final Isolate _isolate;
  late final SendPort _send;
  final _receive = ReceivePort();
  final _replies = <int, Completer<Object?>>{};
  int _nextId = 1;

  PluginStatus _status = PluginStatus.stopped;
  String? _disabledReason;
  final _statusChanges = StreamController<PluginStatus>.broadcast();
  final _logs = <String>[];
  final _logLines = StreamController<String>.broadcast();

  /// The plugin's last [PluginInstance.maxLogLines] log lines.
  List<String> get logs => List.unmodifiable(_logs);

  /// Each line as the plugin logs it.
  Stream<String> get logLines => _logLines.stream;

  PluginStatus get status => _status;
  String? get disabledReason => _disabledReason;

  /// Reports when the plugin disables itself (failures, memory).
  Stream<PluginStatus> get statusChanges => _statusChanges.stream;

  static Future<PluginWorker> start({
    required PluginManifest manifest,
    required String source,
    required PluginServices services,
    PluginGrants grants = const PluginGrants(),
    PluginPolicy policy = const PluginPolicy(),
    String locale = 'en',
    Map<String, Object?> settings = const {},
  }) async {
    final w = PluginWorker._(manifest, services);
    final ready = Completer<SendPort>();
    w._receive.listen((msg) => w._onMessage(msg, ready));
    w._isolate = await Isolate.spawn(
      _workerMain,
      (
        port: w._receive.sendPort,
        manifest: manifest,
        source: source,
        grants: grants,
        policy: policy,
        locale: locale,
        settings: settings,
      ),
      debugName: 'plugin ${manifest.id}',
      errorsAreFatal: false,
    );
    // An isolate that dies (a crash in native code it survived, a kill)
    // must not leave callers waiting.
    w._isolate.addOnExitListener(w._receive.sendPort, response: _exited);
    w._send = await ready.future;
    await w._request((id) => ('start', id, null));
    return w;
  }

  Future<EventOutcome> dispatch(
    PluginEvent event,
    Map<String, Object?> payload,
  ) async {
    if (_status != PluginStatus.running) {
      return const EventSkipped('plugin is not running');
    }
    return await _request((id) => ('dispatch', id, (event, payload)))
        as EventOutcome;
  }

  Future<Object?> runCommand(String name, {int? chatId, Object? args}) =>
      _request((id) => ('command', id, (name, chatId, args)));

  Future<void> updateSetting(String key, Object? value) =>
      _request((id) => ('setting', id, (key, value)));

  var _stopped = false;

  void stop() {
    if (_stopped) return;
    _stopped = true;
    _send.send(('stop', 0, null));
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _receive.close();
    _failPending('plugin stopped');
    _setStatus(PluginStatus.stopped, null);
    unawaited(_statusChanges.close());
    unawaited(_logLines.close());
  }

  void _failPending(String why) {
    for (final c in _replies.values) {
      c.completeError(StateError(why));
    }
    _replies.clear();
  }

  Future<Object?> _request((String, int, Object?) Function(int id) build) {
    if (_stopped) return Future.error(StateError('plugin stopped'));
    final id = _nextId++;
    final c = _replies[id] = Completer<Object?>();
    _send.send(build(id));
    return c.future;
  }

  void _setStatus(PluginStatus s, String? reason) {
    if (s == _status || _statusChanges.isClosed) return;
    _status = s;
    _disabledReason = reason;
    _statusChanges.add(s);
  }

  void _onMessage(Object? msg, Completer<SendPort> ready) {
    switch (msg) {
      case final SendPort port:
        ready.complete(port);
      case _exited:
        if (_stopped) return;
        if (!ready.isCompleted) {
          ready.completeError(StateError('worker exited'));
        }
        _failPending('worker exited');
        _setStatus(PluginStatus.disabled, 'the plugin process exited');
      case ('reply', final int id, final Object? value, final Object? error):
        final c = _replies.remove(id);
        if (c == null) return;
        error == null ? c.complete(value) : c.completeError(error);
      case ('status', final PluginStatus s, final String? reason):
        _setStatus(s, reason);
      case ('log', final String line):
        _logs.add(line);
        if (_logs.length > PluginInstance.maxLogLines) _logs.removeAt(0);
        if (!_logLines.isClosed) _logLines.add(line);
      case (
        'service',
        final int id,
        final String method,
        final Map<String, Object?> args,
      ):
        _services
            .call(manifest.id, method, args)
            .then(
              (v) => _send.send(('service.done', id, v, null)),
              onError: (Object e) => _send.send((
                'service.done',
                id,
                null,
                e is HostError ? e : HostError('host_failure', '$e'),
              )),
            );
      case [final String error, final String? _]:
        // An unhandled error in the worker itself. Disable the plugin.
        _setStatus(PluginStatus.disabled, 'worker failure: $error');
    }
  }
}

typedef _WorkerArgs = ({
  SendPort port,
  PluginManifest manifest,
  String source,
  PluginGrants grants,
  PluginPolicy policy,
  String locale,
  Map<String, Object?> settings,
});

/// Services inside the worker: they forward calls to the app isolate.
final class _RemoteServices implements PluginServices {
  _RemoteServices(this._port);

  final SendPort _port;
  final _pending = <int, Completer<Object?>>{};
  int _next = 1;

  @override
  Future<Object?> call(String pluginId, String method, Map<String, Object?> a) {
    final id = _next++;
    final c = _pending[id] = Completer<Object?>();
    _port.send(('service', id, method, a));
    return c.future;
  }

  void complete(int id, Object? value, HostError? error) {
    final c = _pending.remove(id);
    if (c == null) return;
    error == null ? c.complete(value) : c.completeError(error);
  }
}

void _workerMain(_WorkerArgs args) {
  final port = args.port;
  final inbox = ReceivePort();
  final services = _RemoteServices(port);
  final plugin = PluginInstance(
    manifest: args.manifest,
    services: services,
    grants: args.grants,
    policy: args.policy,
    locale: args.locale,
    settings: args.settings,
    onLog: (line) => port.send(('log', line)),
  );
  var lastStatus = plugin.status;
  Isolate.current.addErrorListener(port);

  void reportStatus() {
    if (plugin.status == lastStatus) return;
    lastStatus = plugin.status;
    port.send(('status', plugin.status, plugin.disabledReason));
  }

  // The status is sent before the reply, so that by the time the reply
  // arrives the app already knows the plugin was disabled.
  Future<void> reply(int id, Future<Object?> Function() body) async {
    Object? value, error;
    try {
      value = await body();
    } on HostError catch (e) {
      error = e;
    } catch (e) {
      error = HostError('host_failure', '$e');
    }
    reportStatus();
    port.send(('reply', id, value, error));
  }

  inbox.listen((msg) {
    switch (msg) {
      case ('start', final int id, _):
        reply(id, () async => plugin.start(args.source));
      case (
        'dispatch',
        final int id,
        (final PluginEvent e, final Map<String, Object?> p),
      ):
        reply(id, () => plugin.dispatch(e, p));
      case (
        'command',
        final int id,
        (final String n, final int? chat, final Object? a),
      ):
        reply(id, () => plugin.runCommand(n, chatId: chat, args: a));
      case ('setting', final int id, (final String k, final Object? v)):
        reply(id, () => plugin.updateSetting(k, v));
      case ('service.done', final int id, final Object? v, final HostError? e):
        services.complete(id, v, e);
        // The service reply may have resumed a pending promise that disabled
        // the plugin.
        scheduleMicrotask(reportStatus);
      case ('stop', _, _):
        plugin.stop();
        inbox.close();
    }
  });
  port.send(inbox.sendPort);
}
