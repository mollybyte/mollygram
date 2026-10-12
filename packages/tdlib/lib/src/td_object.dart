import 'dart:convert';
import 'dart:typed_data';

/// Any td_api object: a type, an update or a function.
abstract base class TdObject {
  const TdObject();

  /// The constructor name in the schema; the value of the `@type` JSON field.
  String get tdType;

  /// JSON in td_json format, with the `@type` field.
  Map<String, Object?> toJson();

  @override
  String toString() => '$tdType${toJson()}';
}

/// A td_api function whose result has type [R].
abstract base class TdFunction<R extends TdObject> extends TdObject {
  const TdFunction();
}

/// Thrown when a TDLib response cannot be decoded.
///
/// Causes include an unknown `@type`, a missing required field, or a field of
/// the wrong type. Usually this means the schema and libtdjson have different
/// versions.
final class TdDecodeException implements Exception {
  const TdDecodeException(this.message);

  final String message;

  @override
  String toString() => 'TdDecodeException: $message';
}

// Helpers for the generated code. TDLib omits fields whose value is null and
// sends int64 as a string, so the readers tolerate both.

int tdInt(Object? v) => v == null ? 0 : (v as num).toInt();

int tdInt64(Object? v) => switch (v) {
  null => 0,
  final String s => int.parse(s),
  final num n => n.toInt(),
  _ => throw TdDecodeException('int64 expected, got ${v.runtimeType}'),
};

double tdDouble(Object? v) => v == null ? 0 : (v as num).toDouble();

String tdString(Object? v) => v == null ? '' : v as String;

bool tdBool(Object? v) => v == null ? false : v as bool;

Uint8List tdBytes(Object? v) =>
    v == null ? Uint8List(0) : base64.decode(v as String);

List<T> tdList<T>(Object? v, T Function(Object?) item) =>
    v == null ? <T>[] : [for (final e in v as List<Object?>) item(e)];

T? tdObjectOrNull<T extends TdObject>(
  Object? v,
  TdObject Function(Map<String, Object?>) decode,
) {
  if (v == null) return null;
  final object = decode(v as Map<String, Object?>);
  if (object is! T) {
    throw TdDecodeException('$T expected, got ${object.tdType}');
  }
  return object;
}

T tdObject<T extends TdObject>(
  Object? v,
  TdObject Function(Map<String, Object?>) decode,
) =>
    tdObjectOrNull<T>(v, decode) ??
    (throw TdDecodeException('$T expected, got null'));
