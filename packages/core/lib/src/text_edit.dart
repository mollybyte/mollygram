import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Moves the formatting of [before] onto [after], an edited version of
/// the same text, so that fixing a typo keeps the bold, links and
/// mentions around it.
///
/// The texts are compared character by character; every character the
/// edit kept carries its formatting along, and text typed inside an
/// entity or right after its end joins it. Entities TDLib finds by
/// itself (plain URLs, @mentions, hashtags) are left out: it detects them
/// again, and refuses them in an edit. Offsets are in UTF-16 code units,
/// as in TDLib and Dart strings.
List<td.TextEntity> carryEntities(
  String before,
  String after,
  List<td.TextEntity> entities,
) {
  final manual = [
    for (final entity in entities)
      if (_isManual(entity.type)) entity,
  ];
  if (manual.isEmpty || before == after) return manual;
  final kept = _keptPositions(before, after);

  // The new position of the first kept character at or after [index].
  int endAt(int index) {
    for (var i = index; i < before.length; i++) {
      if (kept[i] >= 0) return kept[i];
    }
    return after.length;
  }

  final carried = <td.TextEntity>[];
  for (final entity in manual) {
    final start = entity.offset;
    final end = entity.offset + entity.length;
    // An entity starts at its first character the edit kept; one whose
    // every character was deleted goes with them.
    int? newStart;
    for (var i = start; i < end && i < before.length; i++) {
      if (kept[i] >= 0) {
        newStart = kept[i];
        break;
      }
    }
    if (newStart == null) continue;
    final newEnd = endAt(end);
    if (newEnd > newStart) {
      carried.add(
        td.TextEntity(
          offset: newStart,
          length: newEnd - newStart,
          type: entity.type,
        ),
      );
    }
  }
  return carried;
}

/// [fresh], the formatting the composer gives [after], plus what it can't
/// show of [old], the entities of the earlier version [before]: custom
/// emoji and dates are carried over, and a code block keeps its language
/// and a quote stays expandable where the composer's entity covers the
/// same text.
List<td.TextEntity> keepHiddenEntities(
  String before,
  String after,
  List<td.TextEntity> old,
  List<td.TextEntity> fresh,
) {
  final hidden = [
    for (final entity in old)
      if (entity.type
          case td.TextEntityTypeCustomEmoji() ||
              td.TextEntityTypeDateTime() ||
              td.TextEntityTypePreCode() ||
              td.TextEntityTypeExpandableBlockQuote())
        entity,
  ];
  if (hidden.isEmpty) return fresh;
  final carried = carryEntities(before, after, hidden);

  bool richer(td.TextEntityType kept, td.TextEntityType plain) => switch ((
    kept,
    plain,
  )) {
    (
      td.TextEntityTypePreCode(),
      td.TextEntityTypePre() || td.TextEntityTypeCode(),
    ) =>
      true,
    (td.TextEntityTypeExpandableBlockQuote(), td.TextEntityTypeBlockQuote()) =>
      true,
    _ => false,
  };

  final result = [
    for (final entity in fresh)
      carried
              .where(
                (c) =>
                    c.offset == entity.offset &&
                    c.length == entity.length &&
                    richer(c.type, entity.type),
              )
              .firstOrNull ??
          entity,
    for (final entity in carried)
      if (entity.type
          case td.TextEntityTypeCustomEmoji() || td.TextEntityTypeDateTime())
        entity,
  ]..sort((a, b) => a.offset.compareTo(b.offset));
  return result;
}

/// Formatting the user sets, as opposed to what TDLib detects by itself.
bool _isManual(td.TextEntityType type) => switch (type) {
  td.TextEntityTypeBold() ||
  td.TextEntityTypeItalic() ||
  td.TextEntityTypeUnderline() ||
  td.TextEntityTypeStrikethrough() ||
  td.TextEntityTypeSpoiler() ||
  td.TextEntityTypeCode() ||
  td.TextEntityTypePre() ||
  td.TextEntityTypePreCode() ||
  td.TextEntityTypeBlockQuote() ||
  td.TextEntityTypeExpandableBlockQuote() ||
  td.TextEntityTypeTextUrl() ||
  td.TextEntityTypeMentionName() ||
  td.TextEntityTypeCustomEmoji() ||
  td.TextEntityTypeDateTime() => true,
  _ => false,
};

/// For each code unit of [before], its index in [after] when the edit
/// kept it, otherwise -1. Uses Myers' diff; a rewrite too large for it is
/// treated as one change between the common start and end.
List<int> _keptPositions(String before, String after) {
  final n = before.length;
  final m = after.length;
  final kept = List.filled(n, -1);
  var prefix = 0;
  while (prefix < n &&
      prefix < m &&
      before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    kept[prefix] = prefix;
    prefix++;
  }
  var suffix = 0;
  while (suffix < n - prefix &&
      suffix < m - prefix &&
      before.codeUnitAt(n - 1 - suffix) == after.codeUnitAt(m - 1 - suffix)) {
    kept[n - 1 - suffix] = m - 1 - suffix;
    suffix++;
  }
  final a = before.substring(prefix, n - suffix);
  final b = after.substring(prefix, m - suffix);
  for (final (i, j) in _myers(a, b, maxEdits: 400)) {
    kept[prefix + i] = prefix + j;
  }
  return kept;
}

/// The matching pairs (index in [a], index in [b]) of a shortest edit
/// from [a] to [b], or none when it takes more than [maxEdits] edits.
List<(int, int)> _myers(String a, String b, {required int maxEdits}) {
  final n = a.length;
  final m = b.length;
  if (n == 0 || m == 0) return const [];
  final max = n + m;
  final limit = maxEdits < max ? maxEdits : max;
  final offset = limit + 1;
  final v = List.filled(2 * limit + 3, 0);
  final trace = <List<int>>[];
  for (var d = 0; d <= limit; d++) {
    trace.add(List.of(v));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
          ? v[offset + k + 1]
          : v[offset + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && a.codeUnitAt(x) == b.codeUnitAt(y)) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) return _backtrack(trace, d, n, m, offset);
    }
  }
  return const [];
}

List<(int, int)> _backtrack(
  List<List<int>> trace,
  int depth,
  int n,
  int m,
  int offset,
) {
  final pairs = <(int, int)>[];
  var x = n;
  var y = m;
  for (var d = depth; d > 0; d--) {
    final v = trace[d];
    final k = x - y;
    final previousK =
        (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
        ? k + 1
        : k - 1;
    final previousX = v[offset + previousK];
    final previousY = previousX - previousK;
    while (x > previousX && y > previousY) {
      x--;
      y--;
      pairs.add((x, y));
    }
    x = previousX;
    y = previousY;
  }
  while (x > 0 && y > 0) {
    x--;
    y--;
    pairs.add((x, y));
  }
  return pairs;
}
