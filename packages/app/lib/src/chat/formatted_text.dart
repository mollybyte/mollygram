import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Message text with its entities: bold, italic, code, links, mentions,
/// spoilers. A [trailing] span (the room for the time) goes after the last
/// line.
class FormattedTextView extends StatefulWidget {
  const FormattedTextView({
    super.key,
    required this.text,
    this.trailing,
    this.style,
  });

  final td.FormattedText text;
  final InlineSpan? trailing;
  final TextStyle? style;

  @override
  State<FormattedTextView> createState() => _FormattedTextViewState();
}

class _FormattedTextViewState extends State<FormattedTextView> {
  final _recognizers = <GestureRecognizer>[];

  /// Spoilers the user has tapped open, by their offset.
  final _revealed = <int>{};

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final c = MgColors.of(context);
    final spans = buildEntitySpans(
      widget.text,
      colors: c,
      revealed: _revealed,
      onLink: (url) {
        final r = TapGestureRecognizer()..onTap = () => openLink(url);
        _recognizers.add(r);
        return r;
      },
      onSpoiler: (offset) {
        final r = TapGestureRecognizer()
          ..onTap = () => setState(() => _revealed.add(offset));
        _recognizers.add(r);
        return r;
      },
    );
    return Text.rich(
      TextSpan(style: widget.style, children: [...spans, ?widget.trailing]),
    );
  }
}

/// Opens a link from a message in the browser. A link without a scheme
/// ("example.com") gets https.
Future<void> openLink(String url) async {
  var uri = Uri.tryParse(url.trim());
  if (uri == null) return;
  if (!uri.hasScheme) uri = Uri.tryParse('https://${url.trim()}');
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Splits [text] at every entity boundary and styles each piece with all
/// the entities that cover it; entities may nest.
List<InlineSpan> buildEntitySpans(
  td.FormattedText text, {
  required MgColors colors,
  Set<int> revealed = const {},
  GestureRecognizer Function(String url)? onLink,
  GestureRecognizer Function(int offset)? onSpoiler,
}) {
  final s = text.text;
  final entities = [
    for (final e in text.entities)
      if (e.length > 0 && e.offset >= 0 && e.offset + e.length <= s.length) e,
  ];
  if (entities.isEmpty) return [TextSpan(text: s)];
  final cuts = <int>{0, s.length};
  for (final e in entities) {
    cuts
      ..add(e.offset)
      ..add(e.offset + e.length);
  }
  final points = cuts.toList()..sort();
  final spans = <InlineSpan>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final start = points[i];
    final end = points[i + 1];
    if (start == end) continue;
    final piece = s.substring(start, end);
    final covering = [
      for (final e in entities)
        if (e.offset <= start && e.offset + e.length >= end) e,
    ];
    var style = const TextStyle();
    GestureRecognizer? recognizer;
    MouseCursor? cursor;
    for (final e in covering) {
      switch (e.type) {
        case td.TextEntityTypeBold():
          style = style.copyWith(fontWeight: FontWeight.w600);
        case td.TextEntityTypeItalic():
          style = style.copyWith(fontStyle: FontStyle.italic);
        case td.TextEntityTypeUnderline():
          style = style.merge(
            const TextStyle(decoration: TextDecoration.underline),
          );
        case td.TextEntityTypeStrikethrough():
          style = style.merge(
            const TextStyle(decoration: TextDecoration.lineThrough),
          );
        case td.TextEntityTypeCode() ||
            td.TextEntityTypePre() ||
            td.TextEntityTypePreCode():
          style = style.copyWith(
            fontFamily: 'Menlo',
            fontFamilyFallback: const ['Consolas', 'monospace'],
            fontSize: MgType.body - 0.5,
            color: colors.accent,
          );
        case td.TextEntityTypeBlockQuote() ||
            td.TextEntityTypeExpandableBlockQuote():
          style = style.copyWith(fontStyle: FontStyle.italic);
        case td.TextEntityTypeUrl():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call(piece);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeTextUrl(:final url):
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call(url);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeEmailAddress():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('mailto:$piece');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypePhoneNumber():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('tel:$piece');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeMention():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('https://t.me/${piece.substring(1)}');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeMentionName() ||
            td.TextEntityTypeHashtag() ||
            td.TextEntityTypeCashtag() ||
            td.TextEntityTypeBotCommand():
          style = style.copyWith(color: colors.accent);
        case td.TextEntityTypeSpoiler():
          if (!revealed.contains(e.offset)) {
            style = style.copyWith(
              color: const Color(0x00000000),
              background: Paint()..color = colors.fg2.withValues(alpha: 0.35),
            );
            recognizer = onSpoiler?.call(e.offset);
            cursor = SystemMouseCursors.click;
          }
        default:
          break;
      }
    }
    spans.add(
      TextSpan(
        text: piece,
        style: style,
        recognizer: recognizer,
        mouseCursor: cursor,
      ),
    );
  }
  return spans;
}
