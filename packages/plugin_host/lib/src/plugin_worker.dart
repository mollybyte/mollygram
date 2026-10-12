import 'dart:async';
import 'dart:isolate';

import 'manifest.dart';
import 'permissions.dart';
import 'plugin_instance.dart';

/// Плагин в отдельном изоляте. JS никогда не выполняется в UI-изоляте,
/// поэтому даже плагин, который упирается в бюджет времени на каждом
/// событии, не роняет частоту кадров. Сервисы вызываются в изоляте
/// приложения: воркер пересылает только уже разрешённые вызовы.
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

  PluginStatus get status => _status;
  String? get disabledReason => _disabledReason;

  /// Сообщает, когда плагин выключился сам (сбои, память).
  Stream<PluginStatus> get statusChanges => _statusChanges.stream;

  static Future<PluginWorker> start({
    required PluginManifest manifest,
    required String source,
    required PluginServices services,
    PluginGrants grants = const PluginGrants(),
    PluginPolicy policy = const PluginPolicy(),
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
        settings: settings,
      ),
      debugName: 'plugin ${manifest.id}',
      errorsAreFatal: false,
    );
    w._send = await ready.future;
    await w._request((id) => ('start', id, null));
    return w;
  }

  Future<EventOutcome> dispatch(
    PluginEvent event,
    Map<String, Object?> payload,
  ) async {
    if (_status != PluginStatus.running) {
      return const EventSkipped('плагин не запущен');
    }
    return await _request((id) => ('dispatch', id, (event, payload)))
        as EventOutcome;
  }

  Future<Object?> runCommand(String name, {int? chatId, Object? args}) =>
      _request((id) => ('command', id, (name, chatId, args)));

  Future<void> updateSetting(String key, Object? value) =>
      _request((id) => ('setting', id, (key, value)));

  void stop() {
    _send.send(('stop', 0, null));
    _isolate.kill(priority: Isolate.beforeNextEvent);
    _receive.close();
    for (final c in _replies.values) {
      c.completeError(StateError('плагин остановлен'));
    }
    _replies.clear();
    _setStatus(PluginStatus.stopped, null);
  }

  Future<Object?> _request((String, int, Object?) Function(int id) build) {
    final id = _nextId++;
    final c = _replies[id] = Completer<Object?>();
    _send.send(build(id));
    return c.future;
  }

  void _setStatus(PluginStatus s, String? reason) {
    if (s == _status) return;
    _status = s;
    _disabledReason = reason;
    _statusChanges.add(s);
  }

  void _onMessage(Object? msg, Completer<SendPort> ready) {
    switch (msg) {
      case SendPort port:
        ready.complete(port);
      case ('reply', int id, Object? value, Object? error):
        final c = _replies.remove(id);
        if (c == null) return;
        error == null ? c.complete(value) : c.completeError(error);
      case ('status', PluginStatus s, String? reason):
        _setStatus(s, reason);
      case ('service', int id, String method, Map<String, Object?> args):
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
        // Необработанная ошибка в самом воркере. Плагин выключаем.
        _setStatus(PluginStatus.disabled, 'сбой воркера: $error');
    }
  }
}

typedef _WorkerArgs = ({
  SendPort port,
  PluginManifest manifest,
  String source,
  PluginGrants grants,
  PluginPolicy policy,
  Map<String, Object?> settings,
});

/// Сервисы внутри воркера: пересылают вызов в изолят приложения.
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
    settings: args.settings,
  );
  var lastStatus = plugin.status;
  Isolate.current.addErrorListener(port);

  void reportStatus() {
    if (plugin.status == lastStatus) return;
    lastStatus = plugin.status;
    port.send(('status', plugin.status, plugin.disabledReason));
  }

  // Статус уходит раньше ответа, чтобы к моменту ответа приложение уже
  // знало, что плагин выключился.
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
      case ('start', int id, _):
        reply(id, () async => plugin.start(args.source));
      case ('dispatch', int id, (PluginEvent e, Map<String, Object?> p)):
        reply(id, () => plugin.dispatch(e, p));
      case ('command', int id, (String n, int? chat, Object? a)):
        reply(id, () => plugin.runCommand(n, chatId: chat, args: a));
      case ('setting', int id, (String k, Object? v)):
        reply(id, () => plugin.updateSetting(k, v));
      case ('service.done', int id, Object? v, HostError? e):
        services.complete(id, v, e);
        // Ответ сервиса мог доиграть отложенный промис и выключить плагин.
        scheduleMicrotask(reportStatus);
      case ('stop', _, _):
        plugin.stop();
        inbox.close();
    }
  });
  port.send(inbox.sendPort);
}
