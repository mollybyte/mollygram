import 'package:flutter/foundation.dart';

/// A kind of formatting the composer can put on text.
enum TextFormat {
  bold,
  italic,
  underline,
  strikethrough,

  /// Inline code, or a code block when it spans lines.
  monospace,
  spoiler,
  quote,

  /// A link behind the text; [FormatRange.url] is where it goes.
  link,

  /// A mention of a user without a username; [FormatRange.userId] is who.
  mention,

  /// A custom emoji standing on its fallback emoji; [FormatRange.emojiId]
  /// is which.
  customEmoji,
}

/// [format] over the UTF-16 code units `[start, end)` of the draft.
@immutable
final class FormatRange {
  const FormatRange(
    this.start,
    this.end,
    this.format, {
    this.url,
    this.userId,
    this.emojiId,
  }) : assert(start <= end);

  final int start;
  final int end;
  final TextFormat format;
  final String? url;
  final int? userId;
  final int? emojiId;

  int get length => end - start;

  FormatRange withBounds(int start, int end) => FormatRange(
    start,
    end,
    format,
    url: url,
    userId: userId,
    emojiId: emojiId,
  );

  /// Whether this and [other] can be one range when they touch.
  bool sameKind(FormatRange other) =>
      format == other.format &&
      url == other.url &&
      userId == other.userId &&
      emojiId == other.emojiId;

  @override
  bool operator ==(Object other) =>
      other is FormatRange &&
      other.start == start &&
      other.end == end &&
      other.format == format &&
      other.url == url &&
      other.userId == userId &&
      other.emojiId == emojiId;

  @override
  int get hashCode => Object.hash(start, end, format, url, userId, emojiId);

  @override
  String toString() =>
      'FormatRange($start, $end, ${format.name}'
      '${url == null ? '' : ', $url'}${userId == null ? '' : ', $userId'}${emojiId == null ? '' : ', emoji $emojiId'})';
}

/// Sorts [ranges], drops empty ones and joins those of the same kind that
/// overlap or touch. Mentions and custom emoji are never joined: each
/// names one person or one emoji.
List<FormatRange> normalizeRanges(Iterable<FormatRange> ranges) {
  final sorted = [
    for (final range in ranges)
      if (range.length > 0) range,
  ]..sort(_byStart);
  final result = <FormatRange>[];
  for (final range in sorted) {
    final index = result.lastIndexWhere(
      (r) =>
          r.sameKind(range) &&
          range.format != TextFormat.mention &&
          range.format != TextFormat.customEmoji &&
          r.end >= range.start,
    );
    if (index < 0) {
      result.add(range);
      continue;
    }
    final joined = result[index];
    if (range.end > joined.end) {
      result[index] = joined.withBounds(joined.start, range.end);
    }
  }
  return result..sort(_byStart);
}

int _byStart(FormatRange a, FormatRange b) {
  final byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;
  final byEnd = a.end.compareTo(b.end);
  return byEnd != 0 ? byEnd : a.format.index.compareTo(b.format.index);
}

/// Whether every code unit of `[start, end)` has [format].
bool hasFormat(
  List<FormatRange> ranges,
  TextFormat format,
  int start,
  int end,
) {
  if (end <= start) return false;
  final spans = [
    for (final r in ranges)
      if (r.format == format && r.end > start && r.start < end) r,
  ]..sort(_byStart);
  var covered = start;
  for (final range in spans) {
    if (range.start > covered) return false;
    if (range.end > covered) covered = range.end;
    if (covered >= end) return true;
  }
  return false;
}

/// Takes [format] off `[start, end)`, cutting the ranges that cross it.
List<FormatRange> removeFormat(
  List<FormatRange> ranges,
  TextFormat format,
  int start,
  int end,
) => normalizeRanges([
  for (final range in ranges)
    if (range.format != format || range.end <= start || range.start >= end)
      range
    else ...[
      if (range.start < start) range.withBounds(range.start, start),
      if (range.end > end) range.withBounds(end, range.end),
    ],
]);

/// Turns [format] off for `[start, end)` when all of it has it, otherwise
/// on, the way ⌘B works in a Mac text view. A link or a mention replaces
/// whatever link or mention was there.
List<FormatRange> toggleFormat(
  List<FormatRange> ranges,
  TextFormat format,
  int start,
  int end, {
  String? url,
  int? userId,
}) {
  if (end <= start) return ranges;
  if (format == TextFormat.link || format == TextFormat.mention) {
    final cleared = removeFormat(ranges, format, start, end);
    if (format == TextFormat.link && (url == null || url.isEmpty)) {
      return cleared;
    }
    return normalizeRanges([
      ...cleared,
      FormatRange(start, end, format, url: url, userId: userId),
    ]);
  }
  if (hasFormat(ranges, format, start, end)) {
    return removeFormat(ranges, format, start, end);
  }
  return normalizeRanges([...ranges, FormatRange(start, end, format)]);
}

/// Moves [ranges] of [before] onto [after], the same draft after one edit.
///
/// The edit is found as the part between the common start and end of the
/// two texts. Text typed inside a range joins it; text typed at its edges
/// does not, so typing after a bold word is plain again. Text typed over a
/// whole range takes its formatting. A mention that is edited inside is
/// dropped: it no longer names the person. [typing] formats go on the
/// inserted text, for ⌘B pressed with nothing selected.
List<FormatRange> shiftForEdit(
  List<FormatRange> ranges,
  String before,
  String after, {
  Set<TextFormat> typing = const {},
  (int, int)? selection,
}) {
  if (before == after) return ranges;
  // Typing and pasting go in at the caret; when the texts agree with
  // that, the edit is exactly there, even where the texts alone can't
  // tell (typing "a" before or after another "a").
  if (selection case (final start, final end)
      when start >= 0 &&
          start == end &&
          end <= before.length &&
          after.length - (before.length - end) >= start &&
          after.startsWith(before.substring(0, start)) &&
          after.endsWith(before.substring(end))) {
    final inserted = after.length - (before.length - end) - start;
    return _applyEdit(ranges, start, end, inserted, after.length, typing);
  }
  var p = 0;
  final shortest = before.length < after.length ? before.length : after.length;
  while (p < shortest && before.codeUnitAt(p) == after.codeUnitAt(p)) {
    p++;
  }
  // Never between the halves of an emoji: both texts share the high
  // surrogate, but the character it starts was changed.
  if (p > 0 && _isHighSurrogate(before.codeUnitAt(p - 1))) p--;
  var suffix = 0;
  while (suffix < before.length - p &&
      suffix < after.length - p &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
  }
  if (suffix > 0 && _isLowSurrogate(after.codeUnitAt(after.length - suffix))) {
    suffix--;
  }
  return _applyEdit(
    ranges,
    p,
    before.length - suffix,
    after.length - suffix - p,
    after.length,
    typing,
  );
}

bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Moves [index] back off the second half of a surrogate pair in [text],
/// so a cut there keeps the emoji whole.
int snapToCharacter(String text, int index) =>
    index > 0 &&
        index < text.length &&
        _isLowSurrogate(text.codeUnitAt(index)) &&
        _isHighSurrogate(text.codeUnitAt(index - 1))
    ? index - 1
    : index;

/// [ranges] after `[p, q)` of the old text was replaced by [inserted]
/// code units, giving a text [length] long.
List<FormatRange> _applyEdit(
  List<FormatRange> ranges,
  int p,
  int q,
  int inserted,
  int length, [
  Set<TextFormat> typing = const {},
]) {
  final delta = inserted - (q - p);

  int map(int i) => i <= p ? i : (i >= q ? i + delta : p + inserted);

  final shifted = <FormatRange>[];
  for (final range in ranges) {
    final touchesInside = range.start < q && range.end > p;
    final insideInsert = q == p && range.start < p && range.end > p;
    if ((range.format == TextFormat.mention ||
            range.format == TextFormat.customEmoji) &&
        (touchesInside || insideInsert)) {
      continue;
    }
    // An insertion right at the start of a range pushes it along.
    final start = range.start == p && q == p
        ? range.start + delta
        : map(range.start);
    shifted.add(range.withBounds(start, map(range.end)));
  }
  if (inserted > 0) {
    for (final format in typing) {
      shifted.add(FormatRange(p, p + inserted, format));
    }
  }
  return normalizeRanges([
    for (final range in shifted)
      if (range.end > range.start && range.end <= length) range,
  ]);
}

/// Markdown markers the composer turns into formatting on send, in the
/// order they are looked for: code first, so markers inside it stay text.
/// Each content starts and ends with something other than a space.
final _markdown = <(RegExp, TextFormat)>[
  (RegExp(r'```([^`][\s\S]*?)```'), TextFormat.monospace),
  // Double backticks hold code with backticks in it: `` `x` ``.
  (RegExp(r'``(?!`) ?([^ \n](?:[^\n]*?[^ \n])?) ?``'), TextFormat.monospace),
  (RegExp(r'`([^`\n]+)`'), TextFormat.monospace),
  (RegExp(r'\*\*([^*\s](?:[^\n]*?[^*\s])?)\*\*'), TextFormat.bold),
  (RegExp(r'__([^_\s](?:[^\n]*?[^_\s])?)__'), TextFormat.italic),
  (RegExp(r'~~([^~\s](?:[^\n]*?[^~\s])?)~~'), TextFormat.strikethrough),
  (RegExp(r'\|\|([^|\s](?:[^\n]*?[^|\s])?)\|\|'), TextFormat.spoiler),
];

/// The characters a backslash keeps from being a marker.
const _escapable = r'*_~|`\';

/// Where escaped characters wait while the markers are found: one code
/// unit each in the private use area, so offsets don't move.
const _escapeBase = 0xE000;

/// Replaces Markdown shortcuts in [text] with formatting: `**bold**`,
/// `__italic__`, `` `code` ``, ```` ```code block``` ````, `~~strike~~`
/// and `||spoiler||`. The markers are removed and [ranges] move with the
/// text; markers inside code are kept as they are. A backslash before a
/// marker character keeps it as text (`\_\_init\_\_`) and is removed.
(String, List<FormatRange>) applyMarkdown(
  String text,
  List<FormatRange> ranges,
) {
  var formats = normalizeRanges(ranges);
  final escaped = _escape(text, formats, (ranges) => formats = ranges);
  var current = escaped ?? text;
  for (final (pattern, format) in _markdown) {
    final matches = pattern.allMatches(current).toList();
    // From the end, so earlier matches keep their offsets.
    for (final match in matches.reversed) {
      final content = match.group(1)!;
      if (content.trim().isEmpty) continue;
      final whole = match.group(0)!;
      final open = whole.indexOf(content, 1);
      var contentStart = match.start + open;
      var contentEnd = contentStart + content.length;
      // A code block may start and end on lines of its own.
      if (whole.startsWith('```')) {
        if (current.codeUnitAt(contentStart) == 0x0A) contentStart++;
        if (contentEnd > contentStart &&
            current.codeUnitAt(contentEnd - 1) == 0x0A) {
          contentEnd--;
        }
      }
      if (contentEnd <= contentStart) continue;
      // Formats may wrap code, but their markers can't be inside it.
      bool inCode(int start, int end) => formats.any(
        (r) =>
            r.format == TextFormat.monospace && r.start < end && r.end > start,
      );
      if (inCode(match.start, contentStart) || inCode(contentEnd, match.end)) {
        continue;
      }
      current = current.replaceRange(contentEnd, match.end, '');
      formats = _applyEdit(formats, contentEnd, match.end, 0, current.length);
      current = current.replaceRange(match.start, contentStart, '');
      formats = _applyEdit(
        formats,
        match.start,
        contentStart,
        0,
        current.length,
      );
      formats = normalizeRanges([
        ...formats,
        FormatRange(
          match.start,
          match.start + (contentEnd - contentStart),
          format,
        ),
      ]);
    }
  }
  return (escaped == null ? current : _unescape(current), formats);
}

/// Takes the backslash off each escaped marker character of [text] and
/// hides the character from the patterns. Null when there is nothing to
/// escape, or when the text already uses the hiding place.
String? _escape(
  String text,
  List<FormatRange> ranges,
  void Function(List<FormatRange>) moved,
) {
  if (!text.contains(r'\')) return null;
  for (final unit in text.codeUnits) {
    if (unit >= _escapeBase && unit < _escapeBase + _escapable.length) {
      return null;
    }
  }
  // Code keeps its backslashes: find where it will be before escaping.
  final code = [
    for (final (pattern, _) in _markdown.take(3))
      for (final match in pattern.allMatches(text)) (match.start, match.end),
  ];
  final out = StringBuffer();
  var formats = ranges;
  var removed = 0;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    final next = i + 1 < text.length ? text[i + 1] : '';
    final kind = next.isEmpty ? -1 : _escapable.indexOf(next);
    final at = i - removed;
    final inCode =
        code.any((c) => c.$1 <= i && c.$2 > i) ||
        formats.any(
          (r) =>
              r.format == TextFormat.monospace && r.start <= at && r.end > at,
        );
    if (unit == 0x5C && kind >= 0 && !inCode) {
      formats = _applyEdit(formats, at, at + 1, 0, text.length - removed - 1);
      removed++;
      out.writeCharCode(_escapeBase + kind);
      i++;
    } else {
      out.writeCharCode(unit);
    }
  }
  if (removed == 0) return null;
  final escaped = out.toString();
  moved(formats);
  return escaped;
}

String _unescape(String text) => String.fromCharCodes([
  for (final unit in text.codeUnits)
    unit >= _escapeBase && unit < _escapeBase + _escapable.length
        ? _escapable.codeUnitAt(unit - _escapeBase)
        : unit,
]);
