import 'dart:async';
import 'dart:convert';

import 'generated/td_api.dart';
import 'td_events.dart';
import 'td_json.dart';
import 'td_json_ffi.dart';
import 'td_object.dart';

/// An error returned by TDLib (an `error` object).
final class TdException implements Exception {
  const TdException(this.code, this.message);

  final int code;
  final String message;

  @override
  String toString() => 'TdException($code): $message';
}

/// Thrown when libtdjson has a different version than the schema the types
/// were generated from.
final class TdVersionMismatch implements Exception {
  const TdVersionMismatch(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() => 'TdVersionMismatch: libtdjson $actual, schema $expected';
}

/// Thrown when the client is closed and a request will never get a response.
final class TdClientClosed implements Exception {
  const TdClientClosed();

  @override
  String toString() => 'TdClientClosed';
}

/// An in-process TDLib instance: one libtdjson, one `td_receive` loop and any
/// number of clients (one per account).
final class Td {
  Td._(this._json, this._source) {
    _subscription = _source.events.listen(_dispatch, onError: _errors.add);
  }

  /// Starts TDLib with the receive loop in a background isolate.
  ///
  /// [libraryPath] sets the path to libtdjson; without it the library is
  /// looked up by its standard name. If [checkVersion] is true, the library
  /// version is checked against [tdlibVersion].
  ///
  /// [logVerbosity] sets TDLib's internal log level before anything else
  /// runs: 0 fatal, 1 errors, 2 warnings, 3 info, 4 debug, 5 verbose. TDLib's
  /// own default is 5, which writes every update to stderr. The default here
  /// is 1 and can be raised for a build with
  /// `--dart-define=TDLIB_LOG_VERBOSITY=<level>`.
  static Future<Td> start({
    String? libraryPath,
    bool checkVersion = true,
    int logVerbosity = defaultLogVerbosity,
  }) async {
    final json = TdJsonFfi.open(libraryPath);
    _execute(json, SetLogVerbosityLevel(newVerbosityLevel: logVerbosity));
    if (checkVersion) _checkVersion(json);
    final source = await IsolateTdEventSource.spawn(
      () => TdJsonFfi.open(libraryPath),
    );
    return Td._(json, source);
  }

  /// The log level [start] uses unless told otherwise.
  static const defaultLogVerbosity = int.fromEnvironment(
    'TDLIB_LOG_VERBOSITY',
    defaultValue: 1,
  );

  /// Creates a TDLib instance with the given [json] and [source].
  ///
  /// Intended for tests and custom loaders.
  factory Td.custom(TdJson json, TdEventSource source) => Td._(json, source);

  final TdJson _json;
  final TdEventSource _source;
  late final StreamSubscription<List<TdEvent>> _subscription;
  final _clients = <int, TdClient>{};
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _undecodable = StreamController<TdUndecodable>.broadcast(sync: true);
  var _nextRequestId = 0;
  var _closed = false;

  /// Responses and updates that could not be decoded.
  Stream<TdUndecodable> get undecodable => _undecodable.stream;

  /// Errors from the receive loop.
  Stream<Object> get errors => _errors.stream;

  /// Creates a client. TDLib starts it on the first request.
  TdClient createClient() {
    if (_closed) throw StateError('Td is closed');
    final client = TdClient._(this, _json.createClientId());
    _clients[client.id] = client;
    return client;
  }

  /// Executes a synchronous request that needs no client (`td_execute`).
  ///
  /// Works only for functions that the TDLib documentation marks as
  /// "can be called synchronously".
  R execute<R extends TdObject>(TdFunction<R> function) =>
      _execute(_json, function);

  /// Closes all clients and stops the receive loop.
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

/// A single TDLib client, usually one account.
final class TdClient {
  TdClient._(this._td, this.id);

  final Td _td;

  /// The TDLib `@client_id`.
  final int id;

  final _updates = StreamController<TdObject>.broadcast(sync: true);
  final _pending = <int, _Pending<TdObject>>{};
  Completer<void>? _closing;
  var _closed = false;

  /// Updates and other objects without `@extra`.
  Stream<TdObject> get updates => _updates.stream;

  /// Sends a request and waits for the response.
  ///
  /// A TDLib error arrives as a [TdException]; closing the client before the
  /// response arrives completes with a [TdClientClosed].
  Future<R> send<R extends TdObject>(TdFunction<R> function) {
    if (_closed) return Future.error(const TdClientClosed());
    final requestId = _td._requestId();
    final pending = _Pending<R>();
    _pending[requestId] = pending;
    final request = function.toJson()..['@extra'] = requestId;
    _td._json.send(id, jsonEncode(request));
    return pending.completer.future;
  }

  /// Closes the client by sending `close` and waiting for
  /// `authorizationStateClosed`.
  ///
  /// Repeated calls wait for the same result.
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
      // The client may never have started; then there is nothing to close.
      _finish();
    } on TdClientClosed {
      // authorizationStateClosed arrived before the response to close.
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
