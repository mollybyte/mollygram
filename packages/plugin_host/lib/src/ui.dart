/// Декларативный UI плагинов. Плагин не рисует сам: он возвращает дерево
/// из фиксированного набора узлов, а приложение рисует его своими виджетами
/// в своём стиле. Так плагин не может подделать системный интерфейс или
/// выбиться из дизайна.
library;

final class UiException implements Exception {
  UiException(this.message);
  final String message;
  @override
  String toString() => 'UiException: $message';
}

const _maxNodes = 200;
const _maxDepth = 8;
const _maxText = 4000;

/// Цвета только из темы приложения, без произвольных hex.
const codeTokens = {
  'plain',
  'keyword',
  'string',
  'number',
  'comment',
  'function',
  'type',
  'punctuation',
};

/// Проверяет и нормализует дерево узлов, которое вернул плагин.
/// Лишние поля отбрасываются, неизвестный узел или превышение лимитов
/// дают [UiException].
List<Map<String, Object?>> validateUi(Object? raw) {
  var count = 0;

  String text(Map m, String key, {bool required = true}) {
    final v = m[key];
    if (v == null && !required) return '';
    if (v is! String) throw UiException('"$key" должно быть строкой');
    if (v.length > _maxText) throw UiException('"$key" длиннее $_maxText');
    return v;
  }

  late Map<String, Object?> Function(Object?, int) node;

  List<Map<String, Object?>> nodes(Object? list, int depth) {
    if (list == null) return const [];
    if (list is! List) throw UiException('ожидался список узлов');
    if (depth > _maxDepth) throw UiException('вложенность больше $_maxDepth');
    return [for (final n in list) node(n, depth)];
  }

  node = (Object? n, int depth) {
    if (++count > _maxNodes) throw UiException('больше $_maxNodes узлов');
    if (n is! Map) throw UiException('узел должен быть объектом');
    final type = n['type'];
    return switch (type) {
      'text' => {
        'type': 'text',
        'text': text(n, 'text'),
        'style': switch (n['style']) {
          null || 'body' => 'body',
          'secondary' => 'secondary',
          'mono' => 'mono',
          final s => throw UiException('неизвестный стиль текста "$s"'),
        },
      },
      'button' => {
        'type': 'button',
        'label': text(n, 'label'),
        'action': text(n, 'action'),
        if (n['payload'] != null) 'payload': n['payload'],
      },
      'toggle' => {
        'type': 'toggle',
        'label': text(n, 'label'),
        'action': text(n, 'action'),
        'value': n['value'] == true,
      },
      'progress' => {
        'type': 'progress',
        'label': text(n, 'label', required: false),
      },
      'row' ||
      'column' => {'type': type, 'children': nodes(n['children'], depth + 1)},
      'code' => {
        'type': 'code',
        'language': text(n, 'language', required: false),
        'spans': [
          for (final s in (n['spans'] as List? ?? const []))
            if (s is Map && codeTokens.contains(s['token'] ?? 'plain'))
              {'text': text(s, 'text'), 'token': s['token'] ?? 'plain'}
            else
              throw UiException('span: нужен text и token из темы'),
        ],
      },
      _ => throw UiException('неизвестный узел "$type"'),
    };
  };

  return nodes(raw, 0);
}
