import 'dart:convert';
import 'dart:typed_data';

/// Любой объект td_api: тип, обновление или функция.
abstract base class TdObject {
  const TdObject();

  /// Имя конструктора в схеме, значение поля `@type` в JSON.
  String get tdType;

  /// JSON в формате td_json, с полем `@type`.
  Map<String, Object?> toJson();

  @override
  String toString() => '$tdType${toJson()}';
}

/// Функция td_api, результат которой имеет тип [R].
abstract base class TdFunction<R extends TdObject> extends TdObject {
  const TdFunction();
}

/// Ответ TDLib не удалось разобрать: неизвестный `@type`, нет обязательного
/// поля или поле другого типа. Обычно значит, что схема и libtdjson разных
/// версий.
final class TdDecodeException implements Exception {
  const TdDecodeException(this.message);

  final String message;

  @override
  String toString() => 'TdDecodeException: $message';
}

// Помощники для сгенерированного кода. TDLib пропускает поля со значением
// null, а int64 передаёт строкой, поэтому чтение терпит и то и другое.

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
