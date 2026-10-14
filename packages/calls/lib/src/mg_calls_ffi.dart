import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _Int32C = Int32 Function();
typedef _Int32 = int Function();
typedef _StringC = Pointer<Utf8> Function();

/// The C API version this binding is written for (`MG_CALLS_API_VERSION`).
const int mgCallsApiVersion = 1;

/// Thrown when the loaded libmgcalls speaks a different C API version.
final class MgCallsVersionMismatch implements Exception {
  const MgCallsVersionMismatch(this.actual);

  final int actual;

  @override
  String toString() =>
      'libmgcalls has C API version $actual, expected $mgCallsApiVersion';
}

/// libmgcalls loaded via dart:ffi.
final class MgCalls {
  MgCalls(DynamicLibrary library)
    : _apiVersion = library.lookupFunction<_Int32C, _Int32>(
        'mg_calls_api_version',
      ),
      _versionsJson = library.lookupFunction<_StringC, _StringC>(
        'mg_calls_versions_json',
      ),
      _maxLayer = library.lookupFunction<_Int32C, _Int32>(
        'mg_calls_max_layer',
      ) {
    final actual = _apiVersion();
    if (actual != mgCallsApiVersion) throw MgCallsVersionMismatch(actual);
  }

  /// Opens libmgcalls at [path], or by the standard name for the OS.
  factory MgCalls.open([String? path]) =>
      MgCalls(DynamicLibrary.open(path ?? defaultLibraryName));

  /// The library name the OS loader looks up when no path is given.
  static String get defaultLibraryName {
    if (Platform.isMacOS) return 'libmgcalls.dylib';
    if (Platform.isWindows) return 'mgcalls.dll';
    return 'libmgcalls.so';
  }

  final _Int32 _apiVersion;
  final _StringC _versionsJson;
  final _Int32 _maxLayer;

  /// tgcalls versions the library can connect with, newest first
  /// (`callProtocol.library_versions`).
  List<String> get versions =>
      (jsonDecode(_versionsJson().toDartString()) as List).cast<String>();

  /// Highest API layer the library supports (`callProtocol.max_layer`).
  int get maxLayer => _maxLayer();
}
