import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'td_json.dart';

typedef _CreateClientIdC = Int32 Function();
typedef _CreateClientId = int Function();
typedef _SendC = Void Function(Int32, Pointer<Utf8>);
typedef _Send = void Function(int, Pointer<Utf8>);
typedef _ReceiveC = Pointer<Utf8> Function(Double);
typedef _Receive = Pointer<Utf8> Function(double);
typedef _ExecuteC = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Execute = Pointer<Utf8> Function(Pointer<Utf8>);

/// [TdJson] поверх libtdjson через dart:ffi.
///
/// Строки, которые возвращают `td_receive` и `td_execute`, принадлежат
/// TDLib и живут до следующего вызова той же функции в том же потоке,
/// поэтому копируются в Dart сразу.
final class TdJsonFfi implements TdJson {
  TdJsonFfi(DynamicLibrary library)
    : _createClientId = library
          .lookupFunction<_CreateClientIdC, _CreateClientId>(
            'td_create_client_id',
          ),
      _send = library.lookupFunction<_SendC, _Send>('td_send'),
      _receive = library.lookupFunction<_ReceiveC, _Receive>('td_receive'),
      _execute = library.lookupFunction<_ExecuteC, _Execute>('td_execute');

  /// Открывает libtdjson по [path] или по стандартному имени для ОС.
  factory TdJsonFfi.open([String? path]) =>
      TdJsonFfi(DynamicLibrary.open(path ?? defaultLibraryName));

  /// Имя библиотеки, которое ищет загрузчик ОС, если путь не задан.
  static String get defaultLibraryName {
    if (Platform.isMacOS) return 'libtdjson.dylib';
    if (Platform.isWindows) return 'tdjson.dll';
    return 'libtdjson.so';
  }

  final _CreateClientId _createClientId;
  final _Send _send;
  final _Receive _receive;
  final _Execute _execute;

  @override
  int createClientId() => _createClientId();

  @override
  void send(int clientId, String request) {
    final native = request.toNativeUtf8();
    try {
      _send(clientId, native);
    } finally {
      malloc.free(native);
    }
  }

  @override
  String? receive(double timeout) => _read(_receive(timeout));

  @override
  String? execute(String request) {
    final native = request.toNativeUtf8();
    try {
      return _read(_execute(native));
    } finally {
      malloc.free(native);
    }
  }

  static String? _read(Pointer<Utf8> result) =>
      result == nullptr ? null : result.toDartString();
}
