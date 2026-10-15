/// Declarative UI for plugins.
///
/// A plugin does not draw anything itself: it returns a tree built from a
/// fixed set of nodes, and the app renders it with its own widgets in its own
/// style. This way a plugin cannot spoof system UI or break the design.
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

/// Spans in one `code` node: enough for a long block, bounded for memory.
const maxCodeSpans = 8000;

/// Colors come only from the app theme, never arbitrary hex values.
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

/// Validates and normalizes the node tree a plugin returned.
///
/// Extra fields are dropped; an unknown node or exceeding a limit throws
/// [UiException].
List<Map<String, Object?>> validateUi(Object? raw) {
  var count = 0;

  String text(Map<Object?, Object?> m, String key, {bool required = true}) {
    final v = m[key];
    if (v == null && !required) return '';
    if (v is! String) throw UiException('"$key" must be a string');
    if (v.length > _maxText) {
      throw UiException('"$key" is longer than $_maxText');
    }
    return v;
  }

  late Map<String, Object?> Function(Object?, int) node;

  List<Map<String, Object?>> nodes(Object? list, int depth) {
    if (list == null) return const [];
    if (list is! List) throw UiException('expected a list of nodes');
    if (depth > _maxDepth) throw UiException('nesting deeper than $_maxDepth');
    return [for (final n in list) node(n, depth)];
  }

  node = (Object? n, int depth) {
    if (++count > _maxNodes) throw UiException('more than $_maxNodes nodes');
    if (n is! Map) throw UiException('a node must be an object');
    final type = n['type'];
    return switch (type) {
      'text' => {
        'type': 'text',
        'text': text(n, 'text'),
        'style': switch (n['style']) {
          null || 'body' => 'body',
          'secondary' => 'secondary',
          'mono' => 'mono',
          final s => throw UiException('unknown text style "$s"'),
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
      'code' when (n['spans'] as List? ?? const []).length > maxCodeSpans =>
        throw UiException('more than $maxCodeSpans code spans'),
      'code' => {
        'type': 'code',
        'language': text(n, 'language', required: false),
        'spans': [
          for (final s in (n['spans'] as List? ?? const []))
            if (s is Map && codeTokens.contains(s['token'] ?? 'plain'))
              {'text': text(s, 'text'), 'token': s['token'] ?? 'plain'}
            else
              throw UiException('span: needs text and a theme token'),
        ],
      },
      _ => throw UiException('unknown node "$type"'),
    };
  };

  return nodes(raw, 0);
}

/// A piece of a highlighted code block.
typedef CodeSpan = ({String text, String token});

/// The spans of the first `code` node in [ui], when they spell exactly
/// [code]: a plugin colors a block, it cannot change what it says.
List<CodeSpan>? codeSpansFor(List<Map<String, Object?>> ui, String code) {
  for (final node in ui) {
    if (node['type'] != 'code') continue;
    final spans = [
      for (final s in node['spans']! as List)
        (text: (s as Map)['text'] as String, token: s['token'] as String),
    ];
    return spans.map((s) => s.text).join() == code ? spans : null;
  }
  return null;
}
