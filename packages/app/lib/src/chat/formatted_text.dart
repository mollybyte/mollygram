import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart' show TelegramLinks;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../links/link_router.dart';
import '../plugins/code_highlight.dart';
import 'custom_emoji.dart';
import 'hashtag_results.dart';
import 'media_content.dart' show StickerContent;

/// A stretch of a message's text the user has selected, as a quote to
/// reply with: [position] is its offset in the text, in UTF-16 units as
/// TDLib counts them.
@immutable
final class QuoteSelection {
  const QuoteSelection({required this.text, required this.position});

  final String text;
  final int position;
}

/// Message text with its entities: bold, italic, code, links, mentions,
/// spoilers. A [trailing] span (the room for the time) goes after the last
/// line. Code blocks are colored by plugins, see [codeHighlightProvider].
class FormattedTextView extends ConsumerStatefulWidget {
  const FormattedTextView({
    super.key,
    required this.text,
    this.trailing,
    this.style,
    this.chatId,
    this.senderUserId,
    this.onSelection,
  });

  final td.FormattedText text;
  final InlineSpan? trailing;
  final TextStyle? style;

  /// The chat the text is a message of; its bot commands are sent there.
  /// Null outside a chat, where they are plain text.
  final int? chatId;

  /// The user who sent the message, for the bot a command in a group is
  /// meant for.
  final int? senderUserId;

  /// Called as the selection within this text changes, with null once
  /// nothing of it is selected. Needs a `SelectionArea` above.
  final void Function(QuoteSelection? quote)? onSelection;

  @override
  ConsumerState<FormattedTextView> createState() => _FormattedTextViewState();
}

class _FormattedTextViewState extends ConsumerState<FormattedTextView> {
  final _recognizers = <GestureRecognizer>[];
  final _selection = SelectionListenerNotifier();

  /// Spoilers the user has tapped open, by their offset.
  final _revealed = <int>{};

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelection);
  }

  @override
  void dispose() {
    _disposeRecognizers();
    _selection.dispose();
    super.dispose();
  }

  /// The offsets of the selection are those of the message's text, except
  /// that a custom emoji drawn as a sticker takes one position in place
  /// of its text; only [trailing] comes after it.
  void _onSelection() {
    final onSelection = widget.onSelection;
    if (onSelection == null || !_selection.registered) return;
    final range = _selection.selection.range;
    final s = widget.text.text;
    if (range == null) return onSelection(null);
    final start = _textOffset(math.min(range.startOffset, range.endOffset))
        .clamp(0, s.length);
    final end = _textOffset(math.max(range.startOffset, range.endOffset))
        .clamp(0, s.length);
    if (start >= end) return onSelection(null);
    onSelection(QuoteSelection(text: s.substring(start, end), position: start));
  }

  /// Custom emoji drawn as stickers in the last build, by offset in the
  /// text, with their length.
  final _drawn = <int, int>{};

  /// The offset in the message's text of [rendered], an offset among the
  /// spans as laid out.
  int _textOffset(int rendered) {
    var offset = rendered;
    var shift = 0;
    for (final at in _drawn.keys.toList()..sort()) {
      if (at - shift >= rendered) break;
      final extra = _drawn[at]! - 1;
      shift += extra;
      offset += extra;
    }
    return offset;
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final emoji = ref.watch(customEmojiProvider);
    return ListenableBuilder(
      listenable: emoji,
      builder: (context, _) => _build(context, emoji),
    );
  }

  Widget _build(BuildContext context, CustomEmojiCache emoji) {
    _disposeRecognizers();
    _drawn.clear();
    final c = MgColors.of(context);
    final fontSize =
        widget.style?.fontSize ??
        DefaultTextStyle.of(context).style.fontSize ??
        MgType.body;
    final spans = buildEntitySpans(
      widget.text,
      colors: c,
      revealed: _revealed,
      highlights: _highlights(),
      onCustomEmoji: (id, offset, length) {
        final sticker = emoji.lookup(id);
        if (sticker == null) return null;
        _drawn[offset] = length;
        final side = fontSize * 1.3;
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: StickerContent(
            sticker: sticker,
            side: side,
            animate: false,
            lazy: true,
          ),
        );
      },
      onLink: (url) {
        final r = TapGestureRecognizer()
          ..onTap = () => openLinkFrom(context, url);
        _recognizers.add(r);
        return r;
      },
      onHashtag: (hashtag) {
        final r = TapGestureRecognizer()
          ..onTap = () => unawaited(
            showHashtagResults(
              context,
              tag: hashtag,
              chatId: widget.chatId ?? 0,
            ),
          );
        _recognizers.add(r);
        return r;
      },
      onBotCommand: switch (widget.chatId) {
        null => null,
        final chatId => (command) {
          final r = TapGestureRecognizer()
            ..onTap = () => sendBotCommandFrom(
              context,
              command,
              chatId: chatId,
              senderUserId: widget.senderUserId,
            );
          _recognizers.add(r);
          return r;
        },
      },
      onCode: (code) {
        final r = TapGestureRecognizer()
          ..onTap = () {
            unawaited(Clipboard.setData(ClipboardData(text: code)));
            showMgToast(context, AppLocalizations.of(context).copied);
          };
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
    final text = Text.rich(
      TextSpan(style: widget.style, children: [...spans, ?widget.trailing]),
    );
    if (widget.onSelection == null) return text;
    return SelectionListener(selectionNotifier: _selection, child: text);
  }

  /// Colored pieces of the code blocks, by the block's offset.
  Map<int, List<CodeSpan>> _highlights() {
    final text = widget.text.text;
    final result = <int, List<CodeSpan>>{};
    for (final e in widget.text.entities) {
      final language = switch (e.type) {
        td.TextEntityTypePreCode(:final language) => language,
        td.TextEntityTypePre() => '',
        _ => null,
      };
      if (language == null || e.offset < 0) continue;
      if (e.offset + e.length > text.length) continue;
      final block = (
        code: text.substring(e.offset, e.offset + e.length),
        language: language.isEmpty ? null : language,
      );
      final spans = ref.watch(codeHighlightProvider(block)).value;
      if (spans != null) result[e.offset] = spans;
    }
    return result;
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
/// the entities that cover it; entities may nest. [highlights] colors the
/// code blocks starting at its offsets.
List<InlineSpan> buildEntitySpans(
  td.FormattedText text, {
  required MgColors colors,
  Set<int> revealed = const {},
  Map<int, List<CodeSpan>> highlights = const {},
  GestureRecognizer Function(String url)? onLink,
  GestureRecognizer Function(String hashtag)? onHashtag,
  GestureRecognizer Function(String command)? onBotCommand,
  GestureRecognizer Function(String code)? onCode,
  GestureRecognizer Function(int offset)? onSpoiler,
  InlineSpan? Function(int customEmojiId, int offset, int length)?
  onCustomEmoji,
}) {
  final s = text.text;
  final entities = [
    for (final e in text.entities)
      if (e.length > 0 && e.offset >= 0 && e.offset + e.length <= s.length) e,
  ];
  if (entities.isEmpty) return [TextSpan(text: s)];
  // A custom emoji drawn as a sticker replaces its text; the emoji text
  // stays when the sticker isn't known.
  final drawn = <int, InlineSpan>{};
  if (onCustomEmoji != null) {
    for (final e in entities) {
      if (e.type case td.TextEntityTypeCustomEmoji(:final customEmojiId)) {
        final span = onCustomEmoji(customEmojiId, e.offset, e.length);
        if (span != null) drawn[e.offset] = span;
      }
    }
  }
  final cuts = <int>{0, s.length};
  for (final e in entities) {
    cuts
      ..add(e.offset)
      ..add(e.offset + e.length);
  }
  // Colored code pieces as (start, end, color), cut like entities.
  final tokens = <(int, int, Color)>[];
  for (final MapEntry(key: start, value: spans) in highlights.entries) {
    var at = start;
    for (final span in spans) {
      final end = at + span.text.length;
      final color = codeTokenColor(span.token, colors);
      if (color != null && end <= s.length) {
        tokens.add((at, end, color));
        cuts
          ..add(at)
          ..add(end);
      }
      at = end;
    }
  }
  tokens.sort((a, b) => a.$1.compareTo(b.$1));
  var nextToken = 0;
  final points = cuts.toList()..sort();
  final spans = <InlineSpan>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final start = points[i];
    final end = points[i + 1];
    if (start == end) continue;
    if (drawn[start] case final span?) {
      // The entity's cuts fall on its ends, so one piece covers it.
      spans.add(span);
      continue;
    }
    final piece = s.substring(start, end);
    while (nextToken < tokens.length && tokens[nextToken].$2 <= start) {
      nextToken++;
    }
    final token = nextToken < tokens.length ? tokens[nextToken] : null;
    final covering = [
      for (final e in entities)
        if (e.offset <= start && e.offset + e.length >= end) e,
    ];
    var style = const TextStyle();
    GestureRecognizer? recognizer;
    MouseCursor? cursor;
    for (final e in covering) {
      // A link may be split by formatting nested in it; its target is the
      // whole entity, not this piece.
      final whole = s.substring(e.offset, e.offset + e.length);
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
            fontSize: MgType.small,
            // A colored block keeps its plain text in the text color.
            color: highlights.containsKey(e.offset) ? null : colors.accent,
          );
          if (token case (final from, _, final color) when from <= start) {
            style = style.copyWith(color: color);
          }
          // A tap copies it, as in the official client; a drag still
          // selects.
          recognizer = onCode?.call(whole);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeBlockQuote() ||
            td.TextEntityTypeExpandableBlockQuote():
          style = style.copyWith(fontStyle: FontStyle.italic);
        case td.TextEntityTypeUrl():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call(whole);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeTextUrl(:final url):
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call(url);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeEmailAddress():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('mailto:$whole');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypePhoneNumber():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('tel:$whole');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeMention():
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call('https://t.me/${whole.substring(1)}');
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeMentionName(:final userId):
          style = style.copyWith(color: colors.accent);
          recognizer = onLink?.call(TelegramLinks.userLink(userId).toString());
          cursor = SystemMouseCursors.click;
        // Known by their entity, not their text, so a link whose target
        // reads "/x" still opens as a link.
        case td.TextEntityTypeHashtag() || td.TextEntityTypeCashtag():
          style = style.copyWith(color: colors.accent);
          recognizer = onHashtag?.call(whole);
          cursor = SystemMouseCursors.click;
        case td.TextEntityTypeBotCommand():
          style = style.copyWith(color: colors.accent);
          if (onBotCommand != null) {
            recognizer = onBotCommand(whole);
            cursor = SystemMouseCursors.click;
          }
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
