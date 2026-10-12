/// Разбор td_api.tl: типы, функции и документация из комментариев `//@`.
library;

final class TlSchema {
  TlSchema(this.abstractClasses, this.objects, this.functions);

  /// Абстрактные типы, объявленные через `//@class`.
  final Map<String, String> abstractClasses;
  final List<TlConstructor> objects;
  final List<TlConstructor> functions;
}

final class TlConstructor {
  TlConstructor({
    required this.name,
    required this.params,
    required this.resultType,
    required this.description,
  });

  final String name;
  final List<TlParam> params;
  final String resultType;
  final String description;
}

final class TlParam {
  TlParam(this.name, this.type, this.description);

  final String name;
  final TlType type;
  final String description;

  /// TDLib помечает необязательные объекты в описании, отдельного
  /// синтаксиса для этого в схеме нет.
  bool get mayBeNull =>
      !type.isPrimitive && !type.isVector && _nullable.hasMatch(description);

  static final _nullable = RegExp(
    r'may be null|pass null|or null|if null|null if|can be null',
    caseSensitive: false,
  );
}

final class TlType {
  TlType(this.name, [this.item]);

  /// `int32`, `string`, `vector`, имя типа и т.д.
  final String name;

  /// Тип элемента для `vector<T>`.
  final TlType? item;

  bool get isVector => name == 'vector';
  bool get isPrimitive => primitives.contains(name);

  static const primitives = {
    'int32',
    'int53',
    'int64',
    'double',
    'string',
    'bytes',
    'Bool',
  };

  static TlType parse(String s) {
    if (s.startsWith('vector<') && s.endsWith('>')) {
      return TlType('vector', parse(s.substring(7, s.length - 1)));
    }
    return TlType(s);
  }
}

/// Встроенные конструкторы в начале схемы, у них нет классов.
const _builtinResults = {
  'Double',
  'String',
  'Int32',
  'Int53',
  'Int64',
  'Bytes',
  'Bool',
  'Vector t',
};

TlSchema parseTlSchema(String source) {
  final abstractClasses = <String, String>{};
  final objects = <TlConstructor>[];
  final functions = <TlConstructor>[];
  var inFunctions = false;
  final doc = StringBuffer();

  for (final raw in source.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) {
      doc.clear();
      continue;
    }
    if (line == '---functions---') {
      inFunctions = true;
      doc.clear();
      continue;
    }
    if (line.startsWith('//-')) {
      doc.write(' ${line.substring(3).trim()}');
      continue;
    }
    if (line.startsWith('//')) {
      if (doc.isNotEmpty) doc.write(' ');
      doc.write(line.substring(2).trim());
      continue;
    }

    final tags = _parseDocTags(doc.toString());
    doc.clear();
    final declared = line.substring(line.lastIndexOf('=') + 1);
    if (_builtinResults.contains(declared.replaceAll(';', '').trim())) {
      continue;
    }
    final match = _constructor.firstMatch(line);
    if (match == null) {
      throw FormatException('Unexpected line in td_api.tl: $line');
    }
    final resultType = match.group(3)!.trim();

    final params = <TlParam>[];
    final paramSource = match.group(2)!.trim();
    if (paramSource.isNotEmpty) {
      for (final p in paramSource.split(RegExp(r'\s+'))) {
        final colon = p.indexOf(':');
        final name = p.substring(0, colon);
        params.add(
          TlParam(
            name,
            TlType.parse(p.substring(colon + 1)),
            tags[name == 'description' ? 'param_description' : name] ?? '',
          ),
        );
      }
    }
    (inFunctions ? functions : objects).add(
      TlConstructor(
        name: match.group(1)!,
        params: params,
        resultType: resultType,
        description: tags['description'] ?? '',
      ),
    );
  }

  // `//@class` стоит отдельным блоком перед своими конструкторами.
  for (final m in _classTag.allMatches(source)) {
    abstractClasses[m.group(1)!] = m.group(2)!.trim();
  }
  return TlSchema(abstractClasses, objects, functions);
}

final _constructor = RegExp(
  r'^([a-zA-Z0-9_]+)((?:\s+[a-z0-9_]+:\S+)*)\s*=\s*([^;]+);$',
);
final _classTag = RegExp(
  r'^//@class (\w+) @description (.*)$',
  multiLine: true,
);
final _tag = RegExp(r'(?:^|\s)@(\w+)\s');

Map<String, String> _parseDocTags(String doc) {
  final tags = <String, String>{};
  final matches = _tag.allMatches(doc).toList();
  for (var i = 0; i < matches.length; i++) {
    final end = i + 1 < matches.length ? matches[i + 1].start : doc.length;
    tags[matches[i].group(1)!] = doc.substring(matches[i].end, end).trim();
  }
  return tags;
}
