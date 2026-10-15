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
      _ranges = shiftForEdit(_ranges, old.text, newValue.text, typing: typing);
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
      if (format == TextFormat.link || format == TextFormat.mention) return;
      if (_typingAt != selection.baseOffset) _typing.clear();
      _typingAt = selection.baseOffset;
      if (!_typing.remove(format)) _typing.add(format);
      notifyListeners();
      return;
    }
    _ranges = toggleFormat(_ranges, format, selection.start, selection.end);
    notifyListeners();
  }

  /// Puts a link to [url] on the selection, or takes it off when [url] is
  /// empty.
  void setLink(String url) {
    final selection = value.selection;
    if (!selection.isValid || selection.isCollapsed) return;
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
      ranges = removeFormat(ranges, format, selection.start, selection.end);
    }
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

  static bool _isSpace(int unit) =>
      unit == 0x20 || unit == 0x0A || unit == 0x09 || unit == 0xA0;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    // While an input method is composing, its underline matters more.
    if (_ranges.isEmpty ||
        (withComposing && composing.isValid && !composing.isCollapsed)) {
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
        ..add(range.start)
        ..add(range.end);
    }
    final points = cuts.toList()..sort();
    final children = <TextSpan>[];
    for (var i = 0; i + 1 < points.length; i++) {
      final start = points[i];
      final end = points[i + 1];
      if (start == end) continue;
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: styleFor({
            for (final range in _ranges)
              if (range.start <= start && range.end >= end) range.format,
          }, colors),
        ),
      );
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
            fontSize: MgType.body - 0.5,
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
      }
    }
    if (decorations.isNotEmpty) {
      style = style.copyWith(decoration: TextDecoration.combine(decorations));
    }
    return style;
  }
}
