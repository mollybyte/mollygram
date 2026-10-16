import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';
import 'formatting.dart';

/// A text controller that keeps formatting on the draft and shows it as
/// the user types: bold, italic, underline, strikethrough, monospace,
/// spoiler shading, quotes, links and mentions.
///
/// [ranges] follow every edit (see [shiftForEdit]). Toggling a format with
/// nothing selected applies it to what is typed next at the caret.
class RichTextEditingController extends TextEditingController {
  RichTextEditingController({super.text});

  List<FormatRange> _ranges = const [];

  /// Formats waiting for the next typed text, and the caret they wait at.
  final Set<TextFormat> _typing = {};
  int _typingAt = -1;

  /// The formatting of the draft, sorted and joined.
  List<FormatRange> get ranges => _ranges;

  /// Formats ⌘B and the like set for the text typed next at the caret.
  Set<TextFormat> get typingFormats => Set.unmodifiable(_typing);

  /// The drafts before recent changes, newest last, so undo and redo
  /// bring their formatting back with the text.
  final List<(String, List<FormatRange>)> _history = [];
  static const _historyLimit = 100;

  /// Set by [prepareUndo] for the text change undo or redo makes next.
  var _undoing = false;

  void _remember(String text, List<FormatRange> ranges) {
    if (_history.isNotEmpty &&
        _history.last.$1 == text &&
        identical(_history.last.$2, ranges)) {
      return;
    }
    _history.add((text, ranges));
    if (_history.length > _historyLimit) _history.removeAt(0);
  }

  /// ⌘Z or ⇧⌘Z is about to change the text. When the last change only
  /// formatted the text, an undo takes that back here and returns true;
  /// otherwise the field's own undo runs, and the formatting the text had
  /// at that point comes back with it.
  bool prepareUndo({bool redo = false}) {
    if (!redo &&
        _history.isNotEmpty &&
        _history.last.$1 == text &&
        !identical(_history.last.$2, _ranges)) {
      _ranges = _history.removeLast().$2;
      notifyListeners();
      return true;
    }
    _undoing = true;
    // Undo changes the text at once; whatever comes later is typing.
    scheduleMicrotask(() => _undoing = false);
    return false;
  }

  @override
  set value(TextEditingValue newValue) {
    final old = super.value;
    if (newValue.text != old.text) {
      final typing =
          _typingAt >= 0 &&
              old.selection.isCollapsed &&
              old.selection.baseOffset == _typingAt
          ? _typing
          : const <TextFormat>{};
      final restored = _undoing
          ? _history.lastIndexWhere((entry) => entry.$1 == newValue.text)
          : -1;
      _undoing = false;
      if (restored >= 0) {
        // Back to that point: what came after it is undone.
        _ranges = _history[restored].$2;
        _history.removeRange(restored, _history.length);
      } else {
        _remember(old.text, _ranges);
        _ranges = shiftForEdit(
          _ranges,
          old.text,
          newValue.text,
          typing: typing,
          selection: old.selection.isValid
              ? (old.selection.start, old.selection.end)
              : null,
        );
      }
      final caret = newValue.selection;
      if (typing.isNotEmpty && caret.isCollapsed) {
        _typingAt = caret.baseOffset;
      } else {
        _clearTyping();
      }
    } else if (newValue.selection != old.selection &&
        !(newValue.selection.isCollapsed &&
            newValue.selection.baseOffset == _typingAt)) {
      _clearTyping();
    }
    super.value = newValue;
  }

  void _clearTyping() {
    _typing.clear();
    _typingAt = -1;
  }

  /// Replaces the draft with [text] and its [ranges], such as a message
  /// being edited, with the caret at the end.
  void setFormatted(String text, List<FormatRange> ranges) {
    _clearTyping();
    // The value setter would move the old ranges onto the new text.
    _ranges = const [];
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _ranges = normalizeRanges([
      for (final range in ranges)
        if (range.start >= 0 && range.end <= text.length) range,
    ]);
    notifyListeners();
  }

  /// Whether the whole selection has [format]; with nothing selected,
  /// whether it is waiting for the next typed text.
  bool isActive(TextFormat format) {
    final selection = value.selection;
    if (!selection.isValid) return false;
    if (selection.isCollapsed) return _typing.contains(format);
    return hasFormat(_ranges, format, selection.start, selection.end);
  }

  /// ⌘B and friends: toggles [format] on the selection, or for the text
  /// typed next when nothing is selected.
  void toggle(TextFormat format) {
    final selection = value.selection;
    if (!selection.isValid) return;
    if (selection.isCollapsed) {
      if (format == TextFormat.link ||
          format == TextFormat.mention ||
          format == TextFormat.customEmoji) {
        return;
      }
      if (_typingAt != selection.baseOffset) _typing.clear();
      _typingAt = selection.baseOffset;
      if (!_typing.remove(format)) _typing.add(format);
      notifyListeners();
      return;
    }
    _remember(text, _ranges);
    _ranges = toggleFormat(_ranges, format, selection.start, selection.end);
    notifyListeners();
  }

  /// Puts a link to [url] on the selection, or takes it off when [url] is
  /// empty.
  void setLink(String url) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _remember(text, _ranges);
    _ranges = toggleFormat(
      _ranges,
      TextFormat.link,
      selection.start,
      selection.end,
      url: url,
    );
    notifyListeners();
  }

  /// Removes every format from the selection.
  void clearFormatting() {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    var ranges = _ranges;
    for (final format in TextFormat.values) {
      // A custom emoji is content, not styling.
      if (format == TextFormat.customEmoji) continue;
      ranges = removeFormat(ranges, format, selection.start, selection.end);
    }
    _remember(text, _ranges);
    _ranges = ranges;
    notifyListeners();
  }

  /// The link on the selection, if one covers all of it.
  String? get selectedLink {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return null;
    for (final range in _ranges) {
      if (range.format == TextFormat.link &&
          range.start <= selection.start &&
          range.end >= selection.end) {
        return range.url;
      }
    }
    return null;
  }

  /// The word being typed after an @ right before the caret, without the
  /// @; null when the caret is not in such a word.
  String? get mentionQuery {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final caret = selection.baseOffset;
    final before = text.substring(0, caret);
    final at = before.lastIndexOf('@');
    if (at < 0) return null;
    // The @ starts a word, and the word has no spaces yet.
    if (at > 0 && !_isSpace(before.codeUnitAt(at - 1))) return null;
    final query = before.substring(at + 1);
    if (query.length > 32 || query.contains(RegExp(r'[\s@]'))) return null;
    return query;
  }

  /// The `:word` the caret is in, without the colon: at least two
  /// letters right after a colon that starts a word, for emoji
  /// suggestions. Null otherwise.
  String? get emojiQuery {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final caret = selection.baseOffset;
    final before = text.substring(0, caret);
    final colon = before.lastIndexOf(':');
    if (colon < 0) return null;
    if (colon > 0 && !_isSpace(before.codeUnitAt(colon - 1))) return null;
    final query = before.substring(colon + 1);
    if (query.length < 2 || query.length > 32) return null;
    if (!RegExp(r'^[\p{L}\p{N}_]+$', unicode: true).hasMatch(query)) {
      return null;
    }
    return query;
  }

  /// The bot command being typed: the draft starts with a slash, the
  /// caret is in that first word, and nothing else was written. Without
  /// the slash; empty right after it. Null otherwise.
  String? get commandQuery {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    if (!text.startsWith('/')) return null;
    final caret = selection.baseOffset;
    if (caret != text.length || text.length > 33) return null;
    final query = text.substring(1);
    return RegExp(r'^[A-Za-z0-9_]*$').hasMatch(query) ? query : null;
  }

  /// Replaces the `:word` at the caret with [emoji].
  void insertEmoji(String emoji) {
    final query = emojiQuery;
    if (query == null) return;
    final caret = value.selection.baseOffset;
    final start = caret - query.length - 1;
    value = TextEditingValue(
      text: text.replaceRange(start, caret, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  /// Replaces the @word at the caret with `@username ` when the user has
  /// a username, otherwise with their [name] linked to [userId].
  void insertMention({required String name, String? username, int? userId}) {
    final query = mentionQuery;
    if (query == null) return;
    final caret = value.selection.baseOffset;
    final start = caret - query.length - 1;
    final inserted = username != null && username.isNotEmpty
        ? '@$username'
        : name;
    final newText = text.replaceRange(start, caret, '$inserted ');
    value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + inserted.length + 1),
    );
    if ((username == null || username.isEmpty) && userId != null) {
      _ranges = normalizeRanges([
        ..._ranges,
        FormatRange(
          start,
          start + inserted.length,
          TextFormat.mention,
          userId: userId,
        ),
      ]);
      notifyListeners();
    }
  }

  /// Puts custom emoji [id], standing on [emoji] (its fallback), at the
  /// caret or over the selection.
  void insertCustomEmoji(String emoji, int id) {
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    final start = selection.start;
    value = TextEditingValue(
      text: text.replaceRange(start, selection.end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    _ranges = normalizeRanges([
      ..._ranges,
      FormatRange(
        start,
        start + emoji.length,
        TextFormat.customEmoji,
        emojiId: id,
      ),
    ]);
    notifyListeners();
  }

  static bool _isSpace(int unit) =>
      unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0xA0;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    // An input method's marked text is underlined over the formatting.
    final marked =
        withComposing &&
        composing.isValid &&
        !composing.isCollapsed &&
        composing.end <= text.length;
    if (_ranges.isEmpty && !marked) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final colors = MgColors.of(context);
    final cuts = <int>{0, text.length};
    for (final range in _ranges) {
      if (range.end > text.length) continue;
      cuts
        ..add(snapToCharacter(text, range.start))
        ..add(snapToCharacter(text, range.end));
    }
    if (marked) {
      cuts
        ..add(composing.start)
        ..add(composing.end);
    }
    final points = cuts.toList()..sort();
    final children = <TextSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start == end) continue;
      var piece = styleFor({
        for (final range in _ranges)
          if (snapToCharacter(text, range.start) <= start &&
              snapToCharacter(text, range.end) >= end)
            range.format,
      }, colors);
      if (marked && start >= composing.start && end <= composing.end) {
        piece = piece.copyWith(
          decoration: TextDecoration.combine([
            ?piece.decoration,
            TextDecoration.underline,
          ]),
        );
      }
      children.add(TextSpan(text: text.substring(start, end), style: piece));
    }
    return TextSpan(style: style, children: children);
  }

  /// How a piece of the draft with [formats] looks.
  static TextStyle styleFor(Set<TextFormat> formats, MgColors colors) {
    var style = const TextStyle();
    final decorations = <TextDecoration>[];
    for (final format in formats) {
      switch (format) {
        case TextFormat.bold:
          style = style.copyWith(fontWeight: FontWeight.w600);
        case TextFormat.italic:
          style = style.copyWith(fontStyle: FontStyle.italic);
        case TextFormat.underline:
          decorations.add(TextDecoration.underline);
        case TextFormat.strikethrough:
          decorations.add(TextDecoration.lineThrough);
        case TextFormat.monospace:
          style = style.copyWith(
            fontFamily: 'Menlo',
            fontFamilyFallback: const ['Consolas', 'monospace'],
            fontSize: MgType.small,
            color: colors.accent,
          );
        case TextFormat.spoiler:
          style = style.copyWith(
            background: Paint()..color = colors.fg2.withValues(alpha: 0.22),
          );
        case TextFormat.quote:
          style = style.copyWith(
            fontStyle: FontStyle.italic,
            color: colors.fg2,
          );
        case TextFormat.link || TextFormat.mention:
          style = style.copyWith(color: colors.accent);
        case TextFormat.customEmoji:
          break;
      }
    }
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return style;
  }
}
