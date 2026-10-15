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
}

/// [format] over the UTF-16 code units `[start, end)` of the draft.
@immutable
final class FormatRange {
  const FormatRange(this.start, this.end, this.format, {this.url, this.userId})
    : assert(start <= end);

  final int start;
  final int end;
  final TextFormat format;
  final String? url;
  final int? userId;

  int get length => end - start;

  FormatRange withBounds(int start, int end) =>
      FormatRange(start, end, format, url: url, userId: userId);

  /// Whether this and [other] can be one range when they touch.
  bool sameKind(FormatRange other) =>
      format == other.format && url == other.url && userId == other.userId;

  @override
  bool operator ==(Object other) =>
      other is FormatRange &&
      other.start == start &&
      other.end == end &&
      other.format == format &&
      other.url == url &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(start, end, format, url, userId);

  @override
  String toString() =>
      'FormatRange($start, $end, ${format.name}'
      '${url == null ? '' : ', $url'}${userId == null ? '' : ', $userId'})';
}

/// Sorts [ranges], drops empty ones and joins those of the same kind that
/// overlap or touch. Mentions are never joined: each names one person.
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
}) {
  if (before == after) return ranges;
  var p = 0;
  final shortest = before.length < after.length ? before.length : after.length;
  while (p < shortest && before.codeUnitAt(p) == after.codeUnitAt(p)) {
    p++;
  }
  var suffix = 0;
  while (suffix < before.length - p &&
      suffix < after.length - p &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
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
    if (range.format == TextFormat.mention && (touchesInside || insideInsert)) {
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
final _markdown = <(RegExp, TextFormat)>[
  (RegExp(r'```([^`][\s\S]*?)```'), TextFormat.monospace),
  (RegExp(r'`([^`\n]+)`'), TextFormat.monospace),
  (RegExp(r'\*\*([^*\s](?:[^\n]*?[^*\s])?)\*\*'), TextFormat.bold),
  (RegExp(r'__([^_\s](?:[^\n]*?[^_\s])?)__'), TextFormat.italic),
  (RegExp(r'~~([^~\s](?:[^\n]*?[^~\s])?)~~'), TextFormat.strikethrough),
  (RegExp(r'\|\|([^|\s](?:[^\n]*?[^|\s])?)\|\|'), TextFormat.spoiler),
];

/// Replaces Markdown shortcuts in [text] with formatting: `**bold**`,
/// `__italic__`, `` `code` ``, ```` ```code block``` ````, `~~strike~~`
/// and `||spoiler||`. The markers are removed and [ranges] move with the
/// text; markers inside code are kept as they are.
(String, List<FormatRange>) applyMarkdown(
  String text,
  List<FormatRange> ranges,
) {
  var current = text;
  var formats = normalizeRanges(ranges);
  for (final (pattern, format) in _markdown) {
    final matches = pattern.allMatches(current).toList();
    // From the end, so earlier matches keep their offsets.
    for (final match in matches.reversed) {
      final inCode = formats.any(
        (r) =>
            r.format == TextFormat.monospace &&
            r.start < match.end &&
            r.end > match.start,
      );
      if (inCode) continue;
      final marker = (match.end - match.start - match.group(1)!.length) ~/ 2;
      var contentStart = match.start + marker;
      var contentEnd = match.end - marker;
      // A code block may start and end on lines of its own.
      var cutStart = marker;
      var cutEnd = marker;
      if (marker == 3) {
        if (current.codeUnitAt(contentStart) == 0x0A) {
          contentStart++;
          cutStart++;
        }
        if (contentEnd > contentStart &&
            current.codeUnitAt(contentEnd - 1) == 0x0A) {
          contentEnd--;
          cutEnd++;
        }
      }
      if (contentEnd <= contentStart) continue;
      current = current.replaceRange(contentEnd, contentEnd + cutEnd, '');
      formats = _applyEdit(
        formats,
        contentEnd,
        contentEnd + cutEnd,
        0,
        current.length,
      );
      current = current.replaceRange(match.start, match.start + cutStart, '');
      formats = _applyEdit(
        formats,
        match.start,
        match.start + cutStart,
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
  return (current, formats);
}
