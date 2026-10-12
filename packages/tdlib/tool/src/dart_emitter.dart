/// Генерация Dart-классов из [TlSchema].
library;

import 'tl_schema.dart';

/// Имена из dart:core, с которыми совпадают типы td_api. Таким классам
/// добавляется префикс `Td`, чтобы не путать, например, `Error` из схемы
/// с `Error` из Dart.
const _reserved = {
  'BigInt',
  'Comparable',
  'DateTime',
  'Duration',
  'Enum',
  'Error',
  'Exception',
  'Expando',
  'Function',
  'Future',
  'Invocation',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'Match',
  'Never',
  'Null',
  'Object',
  'Pattern',
  'Record',
  'RegExp',
  'Runes',
  'Set',
  'Sink',
  'StackTrace',
  'Stopwatch',
  'Stream',
  'String',
  'Symbol',
  'Type',
  'Uri',
};

String className(String tlName) {
  final name = tlName[0].toUpperCase() + tlName.substring(1);
  return _reserved.contains(name) ? 'Td$name' : name;
}

String fieldName(String tlName) {
  final parts = tlName.split('_');
  return parts.first +
      parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
}

String emitLibrary(
  TlSchema schema, {
  required String version,
  required String commit,
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln('// Сгенерировано tool/generate.dart из schema/td_api.tl.')
    ..writeln('// TDLib $version ($commit).')
    ..writeln()
    ..writeln('// ignore_for_file: unintended_html_in_doc_comment')
    ..writeln()
    ..writeln("import 'dart:convert';")
    ..writeln("import 'dart:typed_data';")
    ..writeln()
    ..writeln("import '../td_object.dart';")
    ..writeln()
    ..writeln('/// Версия TDLib, из схемы которой сгенерирован этот файл.')
    ..writeln("const String tdlibVersion = '$version';")
    ..writeln()
    ..writeln('/// Коммит TDLib, из схемы которого сгенерирован этот файл.')
    ..writeln("const String tdlibCommit = '$commit';")
    ..writeln();

  final names = <String>{};
  void claim(String name) {
    if (!names.add(name)) throw StateError('Duplicate class name $name');
  }

  for (final entry in schema.abstractClasses.entries) {
    final name = className(entry.key);
    claim(name);
    _doc(out, entry.value, '');
    out
      ..writeln('sealed class $name extends TdObject {')
      ..writeln('  const $name();')
      ..writeln()
      ..writeln('  static $name fromJson(Map<String, Object?> json) =>')
      ..writeln('      tdObject<$name>(json, tdFromJson);')
      ..writeln('}')
      ..writeln();
  }

  for (final c in schema.objects) {
    final name = className(c.name);
    claim(name);
    final parent = schema.abstractClasses.containsKey(c.resultType)
        ? className(c.resultType)
        : 'TdObject';
    _emitClass(out, c, name, parent, isFunction: false);
  }

  for (final c in schema.functions) {
    final name = className(c.name);
    claim(name);
    _emitClass(
      out,
      c,
      name,
      'TdFunction<${className(c.resultType)}>',
      isFunction: true,
    );
  }

  out
    ..writeln('/// Разбирает объект td_api по полю `@type`.')
    ..writeln('TdObject tdFromJson(Map<String, Object?> json) {')
    ..writeln("  final type = json['@type'];")
    ..writeln('  final decode = _decoders[type];')
    ..writeln('  if (decode == null) {')
    ..writeln("    throw TdDecodeException('Unknown @type: \$type');")
    ..writeln('  }')
    ..writeln('  return decode(json);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      'const Map<String, TdObject Function(Map<String, Object?>)> _decoders = {',
    );
  for (final c in schema.objects) {
    out.writeln("  '${c.name}': ${className(c.name)}.fromJson,");
  }
  out.writeln('};');
  return out.toString();
}

void _emitClass(
  StringBuffer out,
  TlConstructor c,
  String name,
  String parent, {
  required bool isFunction,
}) {
  _doc(out, c.description, '');
  if (isFunction) {
    out
      ..writeln('///')
      ..writeln('/// Returns [${className(c.resultType)}].');
  }
  out.writeln('final class $name extends $parent {');

  // Конструктор.
  if (c.params.isEmpty) {
    out.writeln('  const $name();');
  } else {
    out.writeln('  const $name({');
    for (final p in c.params) {
      out.writeln(
        '    ${p.mayBeNull ? '' : 'required '}this.${fieldName(p.name)},',
      );
    }
    out.writeln('  });');
  }
  out.writeln();

  // Разбор из JSON. Функции TDLib не присылает, им он не нужен.
  if (!isFunction) {
    final arg = c.params.isEmpty ? '_' : 'json';
    out.write('  factory $name.fromJson(Map<String, Object?> $arg) => $name(');
    if (c.params.isNotEmpty) {
      out.writeln();
      for (final p in c.params) {
        out.writeln(
          "    ${fieldName(p.name)}: ${_decode(p.type, "json['${p.name}']", nullable: p.mayBeNull)},",
        );
      }
      out.write('  ');
    }
    out
      ..writeln(');')
      ..writeln();
  }

  out
    ..writeln("  static const String constructor = '${c.name}';")
    ..writeln();

  for (final p in c.params) {
    _doc(out, p.description, '  ');
    out
      ..writeln(
        '  final ${_dartType(p.type)}${p.mayBeNull ? '?' : ''} ${fieldName(p.name)};',
      )
      ..writeln();
  }

  out
    ..writeln('  @override')
    ..writeln('  String get tdType => constructor;')
    ..writeln()
    ..writeln('  @override')
    ..writeln('  Map<String, Object?> toJson() => {')
    ..writeln("    '@type': constructor,");
  for (final p in c.params) {
    final f = fieldName(p.name);
    if (p.mayBeNull) {
      out.writeln(
        "    if ($f != null) '${p.name}': ${_encode(p.type, '$f!')},",
      );
    } else {
      out.writeln("    '${p.name}': ${_encode(p.type, f)},");
    }
  }
  out
    ..writeln('  };')
    ..writeln('}')
    ..writeln();
}

String _dartType(TlType t) => switch (t.name) {
  'int32' || 'int53' || 'int64' => 'int',
  'double' => 'double',
  'string' => 'String',
  'bytes' => 'Uint8List',
  'Bool' => 'bool',
  'vector' => 'List<${_dartType(t.item!)}>',
  _ => className(t.name),
};

String _decode(TlType t, String v, {bool nullable = false}) => switch (t.name) {
  'int32' || 'int53' => 'tdInt($v)',
  'int64' => 'tdInt64($v)',
  'double' => 'tdDouble($v)',
  'string' => 'tdString($v)',
  'bytes' => 'tdBytes($v)',
  'Bool' => 'tdBool($v)',
  'vector' => 'tdList($v, (e) => ${_decode(t.item!, 'e')})',
  _ =>
    nullable
        ? 'tdObjectOrNull<${className(t.name)}>($v, tdFromJson)'
        : 'tdObject<${className(t.name)}>($v, tdFromJson)',
};

String _encode(TlType t, String v) => switch (t.name) {
  'int64' => '$v.toString()',
  'bytes' => 'base64.encode($v)',
  'vector' =>
    _isIdentity(t.item!) ? v : '[for (final e in $v) ${_encode(t.item!, 'e')}]',
  'int32' || 'int53' || 'double' || 'string' || 'Bool' => v,
  _ => '$v.toJson()',
};

bool _isIdentity(TlType t) =>
    const {'int32', 'int53', 'double', 'string', 'Bool'}.contains(t.name);

void _doc(StringBuffer out, String text, String indent) {
  if (text.isEmpty) return;
  // Квадратные скобки dartdoc принял бы за ссылки.
  final escaped = text.replaceAll('[', r'\[').replaceAll(']', r'\]');
  out.writeln('$indent/// $escaped');
}
