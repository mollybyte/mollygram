import 'dart:async';
import 'dart:convert';

import 'generated/td_api.dart';
import 'td_events.dart';
import 'td_json.dart';
import 'td_json_ffi.dart';
import 'td_object.dart';

/// Ошибка, которую вернул TDLib (объект `error`).
final class TdException implements Exception {
  const TdException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TdException($code): $message';
}

/// libtdjson другой версии, чем схема, из которой сгенерированы типы.
final class TdVersionMismatch implements Exception {
  const TdVersionMismatch(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => 'TdVersionMismatch: libtdjson $actual, schema $expected';
}

/// Клиент закрыт, ответа на запрос уже не будет.
final class TdClientClosed implements Exception {
  const TdClientClosed();

  @override
  String toString() => 'TdClientClosed';
}

/// Экземпляр TDLib в процессе: одна libtdjson, один цикл `td_receive`
/// и сколько угодно клиентов (по одному на аккаунт).
final class Td {
  Td._(this._json, this._source) {
    _subscription = _source.events.listen(_dispatch, onError: _errors.add);
  }

  /// Запускает TDLib с циклом приёма в фоновом изоляте.
  ///
  /// [libraryPath] задаёт путь к libtdjson; без него библиотека ищется по
  /// стандартному имени. Если [checkVersion], версия библиотеки сверяется
  /// с [tdlibVersion].
  static Future<Td> start({
    String? libraryPath,
    bool checkVersion = true,
  }) async {
    final json = TdJsonFfi.open(libraryPath);
    if (checkVersion) _checkVersion(json);
    final source = await IsolateTdEventSource.spawn(
      () => TdJsonFfi.open(libraryPath),
    );
    return Td._(json, source);
  }

  /// TDLib с заданными [json] и [source]. Для тестов и нестандартных
  /// загрузчиков.
  factory Td.custom(TdJson json, TdEventSource source) => Td._(json, source);

  final TdJson _json;
  final TdEventSource _source;
  late final StreamSubscription<List<TdEvent>> _subscription;
  final _clients = <int, TdClient>{};
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _undecodable = StreamController<TdUndecodable>.broadcast(sync: true);
  var _nextRequestId = 0;
  var _closed = false;

  /// Ответы и обновления, которые не удалось разобрать.
  Stream<TdUndecodable> get undecodable => _undecodable.stream;

  /// Ошибки цикла приёма.
  Stream<Object> get errors => _errors.stream;

  /// Создаёт клиента. TDLib запускает его при первом запросе.
  TdClient createClient() {
    if (_closed) throw StateError('Td is closed');
    final client = TdClient._(this, _json.createClientId());
    _clients[client.id] = client;
    return client;
  }

  /// Синхронный запрос, не требующий клиента (`td_execute`). Работает
  /// только для функций, которые в документации TDLib помечены как
  /// «can be called synchronously».
  R execute<R extends TdObject>(TdFunction<R> function) =>
      _execute(_json, function);

  /// Закрывает всех клиентов и останавливает цикл приёма.
  Future<void> close() async {
    if (_closed) return;
    await Future.wait([for (final c in _clients.values.toList()) c.close()]);
    _closed = true;
    await _source.close();
    await _subscription.cancel();
    await _errors.close();
    await _undecodable.close();
  }

  int _requestId() => ++_nextRequestId;

  void _dispatch(List<TdEvent> batch) {
    for (final event in batch) {
      if (event is TdUndecodable) _undecodable.add(event);
      _clients[event.clientId]?._handle(event);
    }
  }

  static R _execute<R extends TdObject>(TdJson json, TdFunction<R> function) {
    final raw = json.execute(jsonEncode(function.toJson()));
    if (raw == null) {
      throw TdDecodeException('td_execute returned null for $function');
    }
    final result = tdFromJson(jsonDecode(raw) as Map<String, Object?>);
    if (result is TdError) throw TdException(result.code, result.message);
    if (result is! R) {
      throw TdDecodeException('$R expected, got ${result.tdType}');
    }
    return result;
  }

  static void _checkVersion(TdJson json) {
    final version = _execute(json, const GetOption(name: 'version'));
    final actual = version is OptionValueString ? version.value : '$version';
    if (actual != tdlibVersion) throw TdVersionMismatch(tdlibVersion, actual);
  }
}

/// Один клиент TDLib, обычно один аккаунт.
final class TdClient {
  TdClient._(this._td, this.id);

  final Td _td;

  /// `@client_id` в TDLib.
  final int id;

  final _updates = StreamController<TdObject>.broadcast(sync: true);
  final _pending = <int, _Pending<TdObject>>{};
  Completer<void>? _closing;
  var _closed = false;

  /// Обновления и прочие объекты без `@extra`.
  Stream<TdObject> get updates => _updates.stream;

  /// Отправляет запрос и ждёт ответа. Ошибка TDLib приходит как
  /// [TdException], закрытие клиента до ответа как [TdClientClosed].
  Future<R> send<R extends TdObject>(TdFunction<R> function) {
    if (_closed) return Future.error(const TdClientClosed());
    final requestId = _td._requestId();
    final pending = _Pending<R>();
    _pending[requestId] = pending;
    final request = function.toJson()..['@extra'] = requestId;
    _td._json.send(id, jsonEncode(request));
    return pending.completer.future;
  }

  /// Закрывает клиента: отправляет `close` и ждёт
  /// `authorizationStateClosed`. Повторные вызовы ждут того же.
  Future<void> close() async {
    if (_closing != null) return _closing!.future;
    final closing = _closing = Completer<void>();
    if (_closed) {
      closing.complete();
      return;
    }
    try {
      await send(const Close());
    } on TdException {
      // Клиент мог и не стартовать, тогда закрывать нечего.
      _finish();
    } on TdClientClosed {
      // authorizationStateClosed пришёл раньше ответа на close.
    }
    return closing.future;
  }

  void _handle(TdEvent event) {
    final requestId = event.requestId;
    if (requestId != null) {
      _pending.remove(requestId)?.complete(event);
      return;
    }
    if (event is! TdReceived) return;
    final object = event.object;
    _updates.add(object);
    if (object is UpdateAuthorizationState &&
        object.authorizationState is AuthorizationStateClosed) {
      _finish();
    }
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    _td._clients.remove(id);
    for (final pending in _pending.values) {
      pending.completer.completeError(const TdClientClosed());
    }
    _pending.clear();
    unawaited(_updates.close());
    (_closing ??= Completer<void>()).complete();
  }
}

final class _Pending<R extends TdObject> {
  final completer = Completer<R>();

  void complete(TdEvent event) => switch (event) {
    TdReceived(object: final TdError e) => completer.completeError(
      TdException(e.code, e.message),
    ),
    TdReceived(object: final R result) => completer.complete(result),
    TdReceived(:final object) => completer.completeError(
      TdDecodeException('$R expected, got ${object.tdType}'),
    ),
    TdUndecodable(:final error) => completer.completeError(
      TdDecodeException(error),
    ),
  };
}
