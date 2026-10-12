import 'dart:async';
import 'dart:convert';

import 'js_vm.dart';
import 'manifest.dart';
import 'permissions.dart';
import 'prelude.dart';
import 'ui.dart';

/// Ошибка, которую хост возвращает плагину. Код виден в JS как `e.code`.
final class HostError implements Exception {
  const HostError(this.code, this.message);

  final String code;
  final String message;

  static HostError denied(String what) =>
      HostError('permission_denied', 'нет права: $what');

  @override
  String toString() => 'HostError($code): $message';
}

/// Внешний мир для плагинов: TDLib, хранилище, сеть, распознавание речи.
/// Реализует приложение. К моменту вызова права уже проверены хостом,
/// поэтому реализация занимается только делом.
abstract interface class PluginServices {
  /// [method] один из: `storage.get`, `storage.set`, `storage.delete`,
  /// `messages.get`, `messages.history`, `composer.insert`,
  /// `media.transcribe`, `net.fetch`, `ui.toast`, `log`.
  /// Ошибки бросать как [HostError].
  Future<Object?> call(
    String pluginId,
    String method,
    Map<String, Object?> args,
  );
}

/// Что пользователь разрешил сверх манифеста.
final class PluginGrants {
  const PluginGrants({this.chats = const {}, this.userEndpoints = const {}});

  /// Чаты для `messages.read: chats[]`.
  final Set<int> chats;

  /// Хосты, которые пользователь вписал для `net: [user_endpoint]`.
  final Set<String> userEndpoints;
}

/// Как хост обращается с плагином, который ведёт себя плохо.
final class PluginPolicy {
  const PluginPolicy({
    this.limits = const JsLimits(),
    this.eventTimeout = const Duration(seconds: 5),
    this.actionTimeout = const Duration(seconds: 60),
    this.maxStrikes = 3,
  });

  final JsLimits limits;

  /// Сколько ждать асинхронный обработчик события, включая ожидание хоста.
  final Duration eventTimeout;

  /// Сколько ждать команду или нажатие кнопки: там бывает долгая работа
  /// вроде распознавания речи.
  final Duration actionTimeout;

  /// После стольких сбоев подряд (исключение, тайм-аут) плагин выключается.
  final int maxStrikes;
}

enum PluginStatus { stopped, running, disabled }

/// Результат события для приложения.
sealed class EventOutcome {
  const EventOutcome();
}

/// Плагин не подписан или упал: действуем как без плагина.
final class EventSkipped extends EventOutcome {
  const EventSkipped([this.reason]);
  final String? reason;

  @override
  String toString() => 'EventSkipped($reason)';
}

final class EventCancelled extends EventOutcome {
  const EventCancelled();
}

final class EventHandled extends EventOutcome {
  const EventHandled({required this.payload, this.ui = const []});

  /// Данные после перехватчиков (для `intercept`), иначе исходные.
  final Object? payload;

  /// Узлы декларативного UI (для `render`), уже проверенные.
  final List<Map<String, Object?>> ui;
}

/// Один загруженный плагин в своей VM. Падение, зависание или нехватка
/// памяти в плагине превращаются в [EventSkipped] и страйк, а не в
/// исключение у вызывающего.
final class PluginInstance {
  PluginInstance({
    required this.manifest,
    required this._services,
    this.grants = const PluginGrants(),
    this.policy = const PluginPolicy(),
    Map<String, Object?> settings = const {},
  }) : _settings = {
         for (final s in manifest.settings) s.key: s.defaultValue,
         ...settings,
       };

  final PluginManifest manifest;
  final PluginGrants grants;
  final PluginPolicy policy;
  final PluginServices _services;
  final Map<String, Object?> _settings;

  JsVm? _vm;
  PluginStatus _status = PluginStatus.stopped;
  String? _disabledReason;
  int _strikes = 0;
  var _events = <String>{};
  var _commands = <String>{};

  int _nextPending = 1;
  final _runs = <int, Completer<Object?>>{};

  /// Чат, в котором сейчас идёт команда. Для `messages.read: on_command`.
  int? _commandChat;

  final _logs = <String>[];

  PluginStatus get status => _status;
  String? get disabledReason => _disabledReason;
  Set<String> get subscribedEvents => _events;
  Set<String> get registeredCommands => _commands;
  List<String> get logs => List.unmodifiable(_logs);
  int get memoryUsed => _vm?.memoryUsed ?? 0;

  /// Загружает код плагина. Ошибка загрузки выключает плагин и
  /// возвращает false.
  bool start(String source) {
    if (_status != PluginStatus.stopped) {
      throw StateError('плагин ${manifest.id} уже запущен');
    }
    final vm = _vm = JsVm(host: _onHost, limits: policy.limits);
    final boot = vm.eval(prelude, filename: '<mg>');
    if (!boot.isOk) throw StateError('prelude: $boot');
    final r = vm.eval(source, filename: manifest.main);
    if (!r.isOk) {
      _disable('ошибка при загрузке: ${_firstLine(r.raw)}', r.status);
      return false;
    }
    final ready = vm.call('__mg_dispatch', {'kind': 'ready'});
    if (!ready.isOk) {
      _disable('ошибка при загрузке: ${_firstLine(ready.raw)}', ready.status);
      return false;
    }
    final value = (ready.value as Map)['value'] as Map;
    _events = {...(value['events'] as List).cast<String>()};
    _commands = {...(value['commands'] as List).cast<String>()};
    _status = PluginStatus.running;
    _drain();
    return _status == PluginStatus.running;
  }

  /// Отправляет событие. Для `render` результат проверяется как UI.
  Future<EventOutcome> dispatch(
    PluginEvent event,
    Map<String, Object?> payload,
  ) async {
    if (_status != PluginStatus.running) {
      return const EventSkipped('плагин не запущен');
    }
    if (!_events.contains(event.id)) return const EventSkipped();
    final timeout = event == PluginEvent.uiAction
        ? policy.actionTimeout
        : policy.eventTimeout;
    final Object? value;
    try {
      value = await _run({
        'kind': 'event',
        'event': event.id,
        'payload': payload,
      }, timeout);
    } on _PluginFailure catch (e) {
      return EventSkipped(e.message);
    }
    if (value is! Map) return EventSkipped('плагин вернул не объект');
    if (value['cancel'] == true) {
      return event.kind == EventKind.intercept
          ? const EventCancelled()
          : EventHandled(payload: payload);
    }
    if (event.kind == EventKind.render) {
      try {
        final ui = [
          for (final r in value['results'] as List)
            ...validateUi(r is List ? r : [r]),
        ];
        _strikes = 0;
        return EventHandled(payload: payload, ui: ui);
      } on UiException catch (e) {
        _strike('некорректный UI: ${e.message}');
        return EventSkipped(e.message);
      }
    }
    _strikes = 0;
    return EventHandled(
      payload: event.kind == EventKind.intercept ? value['payload'] : payload,
    );
  }

  /// Запускает команду из палитры. [chatId] — текущий чат.
  Future<Object?> runCommand(String name, {int? chatId, Object? args}) async {
    if (_status != PluginStatus.running || !_commands.contains(name)) {
      throw HostError('no_command', 'команда $name недоступна');
    }
    _commandChat = chatId;
    try {
      return await _run({
        'kind': 'command',
        'name': name,
        'args': args,
      }, policy.actionTimeout);
    } on _PluginFailure catch (e) {
      throw HostError('plugin_failed', e.message);
    } finally {
      _commandChat = null;
    }
  }

  /// Пользователь поменял параметр на экране плагина.
  Future<void> updateSetting(String key, Object? value) async {
    if (!_settings.containsKey(key)) throw ArgumentError('нет параметра $key');
    _settings[key] = value;
    await dispatch(PluginEvent.settingsChanged, {'key': key, 'value': value});
  }

  void stop() {
    _vm?.dispose();
    _vm = null;
    for (final c in _runs.values) {
      c.completeError(_PluginFailure('плагин остановлен'));
    }
    _runs.clear();
    if (_status == PluginStatus.running) _status = PluginStatus.stopped;
  }

  // --- исполнение ---

  Future<Object?> _run(Map<String, Object?> msg, Duration timeout) async {
    final vm = _vm!;
    final r = vm.call('__mg_dispatch', msg);
    if (!r.isOk) {
      _fail(r);
      throw _PluginFailure(_firstLine(r.raw));
    }
    final v = r.value as Map;
    if (v['done'] == true) {
      _drain();
      return v['value'];
    }
    final id = v['id'] as int;
    final done = _runs[id] = Completer<Object?>();
    _drain();
    try {
      return await done.future.timeout(timeout);
    } on TimeoutException {
      _runs.remove(id);
      _strike('не ответил за ${timeout.inSeconds} с');
      throw _PluginFailure('тайм-аут');
    }
  }

  /// Прогоняет продолжения промисов после каждого захода в VM.
  void _drain() {
    final vm = _vm;
    if (vm == null) return;
    final r = vm.runJobs();
    if (!r.isOk) _fail(r);
  }

  void _settle(int id, {Object? value, HostError? error}) {
    final vm = _vm;
    if (vm == null) return;
    final r = vm.call('__mg_dispatch', {
      'kind': 'settle',
      'id': id,
      if (error != null)
        'error': {'code': error.code, 'message': error.message}
      else
        'value': value,
    });
    if (!r.isOk) {
      _fail(r);
      return;
    }
    _drain();
  }

  void _fail(JsResult r) {
    if (r.status == JsStatus.outOfMemory) {
      _disable('превысил лимит памяти', r.status);
    } else if (r.status == JsStatus.timeout) {
      _strike('превысил лимит времени');
    } else {
      _strike(_firstLine(r.raw));
    }
  }

  void _strike(String reason) {
    _logs.add('error: $reason');
    if (++_strikes >= policy.maxStrikes) {
      _disable('$_strikes сбоя подряд, последний: $reason', null);
    }
  }

  void _disable(String reason, JsStatus? status) {
    _status = PluginStatus.disabled;
    _disabledReason = reason;
    _logs.add('disabled: $reason');
    // Отложенно: _disable бывает вызван изнутри колбэка из той же VM.
    final vm = _vm;
    _vm = null;
    if (vm != null) scheduleMicrotask(vm.dispose);
    for (final c in _runs.values) {
      if (!c.isCompleted) c.completeError(_PluginFailure(reason));
    }
    _runs.clear();
  }

  bool get _nearMemoryLimit =>
      (_vm?.memoryUsed ?? 0) > policy.limits.memoryBytes ~/ 10 * 9;

  static String _firstLine(String s) => s.split('\n').first;

  // --- вызовы из JS ---

  String? _onHost(String method, String argsJson) {
    final args = (jsonDecode(argsJson) as Map?)?.cast<String, Object?>() ?? {};
    try {
      switch (method) {
        case 'run.done':
          final c = _runs.remove(args['id']);
          if (c != null && !c.isCompleted) {
            if (args.containsKey('error')) {
              // Нехватка памяти внутри async-обработчика приходит сюда как
              // обычный отказ промиса, поэтому смотрим на заполненность кучи.
              if (_nearMemoryLimit) {
                _disable('превысил лимит памяти', JsStatus.outOfMemory);
                c.completeError(_PluginFailure('превысил лимит памяти'));
                return null;
              }
              _strike(_firstLine('${args['error']}'));
              c.completeError(_PluginFailure(_firstLine('${args['error']}')));
            } else {
              c.complete(args['value']);
            }
          }
          return null;
        case 'hooks.check':
          final event = PluginEvent.byName[args['event']];
          if (event == null || !manifest.hooks.contains(event.id)) {
            if (event != PluginEvent.uiAction &&
                event != PluginEvent.settingsChanged &&
                event != PluginEvent.appReady) {
              throw HostError(
                'undeclared_hook',
                'хук "${args['event']}" не объявлен в манифесте',
              );
            }
          }
          return _ok(null);
        case 'commands.check':
          if (!manifest.commands.any((c) => c.name == args['name'])) {
            throw HostError(
              'undeclared_command',
              'команда "${args['name']}" не объявлена в манифесте',
            );
          }
          return _ok(null);
        case 'settings.get':
          if (!_settings.containsKey(args['key'])) {
            throw HostError('no_setting', 'нет параметра ${args['key']}');
          }
          return _ok(_settings[args['key']]);
        case 'log':
          _logs.add('${args['level']}: ${args['text']}');
          if (_logs.length > 200) _logs.removeRange(0, _logs.length - 200);
          return null;
      }
      _authorize(method, args);
      return _async(method, args);
    } on HostError catch (e) {
      return jsonEncode({
        'error': {'code': e.code, 'message': e.message},
      });
    }
  }

  void _authorize(String method, Map<String, Object?> args) {
    final p = manifest.permissions;
    switch (method) {
      case 'storage.get' || 'storage.set' || 'storage.delete':
        if (p.storageBytes == 0) throw HostError.denied('storage');
        final key = args['key'];
        if (key is! String || key.isEmpty || key.length > 128) {
          throw const HostError('bad_argument', 'ключ: строка до 128 символов');
        }
        args['quota'] = p.storageBytes;
      case 'messages.get' || 'messages.history':
        final chat = args['chatId'];
        final allowed = switch (p.messagesRead) {
          MessagesScope.none => false,
          MessagesScope.onCommand => chat != null && chat == _commandChat,
          MessagesScope.chats => grants.chats.contains(chat),
          MessagesScope.all => true,
        };
        if (!allowed) throw HostError.denied('messages.read для чата $chat');
      case 'composer.insert':
        if (!p.composerWrite) throw HostError.denied('composer.write');
      case 'media.transcribe':
        final kind = MediaKind.values
            .asNameMap()[(args['media'] as Map?)?['kind']];
        if (kind == null || !p.mediaRead.contains(kind)) {
          throw HostError.denied('media.read: ${kind?.name ?? '?'}');
        }
      case 'net.fetch':
        final url = Uri.tryParse('${args['url']}');
        if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty) {
          throw const HostError('bad_argument', 'нужен https-адрес');
        }
        final ok =
            p.net.contains(url.host) ||
            (p.net.contains(userEndpoint) &&
                grants.userEndpoints.contains(url.host));
        if (!ok) throw HostError.denied('net: ${url.host}');
      case 'ui.toast':
        break;
      default:
        throw HostError('no_method', 'нет метода $method');
    }
  }

  String _async(String method, Map<String, Object?> args) {
    final id = _nextPending++;
    final vm = _vm;
    Future(() => _services.call(manifest.id, method, args)).then(
      (v) {
        if (identical(vm, _vm)) _settle(id, value: v);
      },
      onError: (Object e) {
        if (!identical(vm, _vm)) return;
        _settle(
          id,
          error: e is HostError ? e : HostError('host_failure', '$e'),
        );
      },
    );
    return jsonEncode({'pending': id});
  }

  static String _ok(Object? v) => jsonEncode({'ok': v});
}

final class _PluginFailure implements Exception {
  _PluginFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
