import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Moves the formatting of [before] onto [after], an edited version of
/// the same text, so that fixing a typo keeps the bold, links and
/// mentions around it.
///
/// The edit is taken as one changed span between the common start and the
/// common end of both texts. Entities before it stay, entities after it
/// shift by the change in length, an entity around it grows or shrinks
/// with it, and one that overlaps it is cut at its edge. Offsets are in
/// UTF-16 code units, as in TDLib and Dart strings.
List<td.TextEntity> carryEntities(
  String before,
  String after,
  List<td.TextEntity> entities,
) {
  if (entities.isEmpty || before == after) return entities;
  final shortest = before.length < after.length ? before.length : after.length;
  var prefix = 0;
  while (prefix < shortest &&
      before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
    prefix++;
  }
  var suffix = 0;
  while (suffix < shortest - prefix &&
      before.codeUnitAt(before.length - 1 - suffix) ==
          after.codeUnitAt(after.length - 1 - suffix)) {
    suffix++;
  }
  // The changed span: [prefix, oldEnd) before, [prefix, newEnd) after.
  final oldEnd = before.length - suffix;
  final newEnd = after.length - suffix;
  final delta = after.length - before.length;

  final carried = <td.TextEntity>[];
  for (final entity in entities) {
    var start = entity.offset;
    var end = entity.offset + entity.length;
    if (end <= prefix) {
      // Before the change.
    } else if (start >= oldEnd) {
      start += delta;
      end += delta;
    } else if (start <= prefix && end >= oldEnd) {
      end += delta;
    } else if (start < prefix) {
      end = prefix;
    } else {
      start = newEnd;
      end = end <= oldEnd ? newEnd : end + delta;
    }
    if (end > start) {
      carried.add(
        td.TextEntity(offset: start, length: end - start, type: entity.type),
      );
    }
  }
  return carried;
}
