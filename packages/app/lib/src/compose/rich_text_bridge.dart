import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// The draft as TDLib takes it: Markdown shortcuts applied on top of the
/// formatting set in the field, then each range as a TDLib entity.
td.FormattedText formattedDraft(String text, List<FormatRange> ranges) {
  var (converted, formats) = applyMarkdown(text, ranges);
  // Markers around nothing but spaces leave nothing worth sending.
  if (converted.trim().isEmpty) (converted, formats) = ('', const []);
  return td.FormattedText(
    text: converted,
    entities: [
      for (final range in formats)
        // A mention whose user is unknown would name nobody.
        if ((range.format != TextFormat.mention || range.userId != null) &&
            (range.format != TextFormat.customEmoji || range.emojiId != null))
          td.TextEntity(
            offset: range.start,
            length: range.length,
            type: switch (range.format) {
              TextFormat.bold => const td.TextEntityTypeBold(),
              TextFormat.italic => const td.TextEntityTypeItalic(),
              TextFormat.underline => const td.TextEntityTypeUnderline(),
              TextFormat.strikethrough =>
                const td.TextEntityTypeStrikethrough(),
              TextFormat.spoiler => const td.TextEntityTypeSpoiler(),
              TextFormat.quote => const td.TextEntityTypeBlockQuote(),
              TextFormat.monospace =>
                converted.substring(range.start, range.end).contains('\n')
                    ? const td.TextEntityTypePre()
                    : const td.TextEntityTypeCode(),
              TextFormat.link => td.TextEntityTypeTextUrl(url: range.url ?? ''),
              TextFormat.mention => td.TextEntityTypeMentionName(
                userId: range.userId!,
              ),
              TextFormat.customEmoji => td.TextEntityTypeCustomEmoji(
                customEmojiId: range.emojiId!,
              ),
            },
          ),
    ],
  );
}

/// Whether [a] and [b] read and look the same, ignoring what TDLib
/// detects by itself.
bool sameDraft(td.FormattedText a, td.FormattedText b) {
  if (a.text != b.text) return false;
  final x = draftRanges(a);
  final y = draftRanges(b);
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}

/// The formatting of a sent message as the composer shows it, for
/// editing. What TDLib finds by itself (plain links, @usernames,
/// hashtags) is left out; it is found again on save.
List<FormatRange> draftRanges(td.FormattedText text) => normalizeRanges([
  for (final entity in text.entities)
    if (_formatOf(entity.type) case (
      final format,
      final url,
      final userId,
      final emojiId,
    ))
      FormatRange(
        entity.offset,
        entity.offset + entity.length,
        format,
        url: url,
        userId: userId,
        emojiId: emojiId,
      ),
]);

(TextFormat, String?, int?, int?)? _formatOf(
  td.TextEntityType type,
) => switch (type) {
  td.TextEntityTypeBold() => (TextFormat.bold, null, null, null),
  td.TextEntityTypeItalic() => (TextFormat.italic, null, null, null),
  td.TextEntityTypeUnderline() => (TextFormat.underline, null, null, null),
  td.TextEntityTypeStrikethrough() => (
    TextFormat.strikethrough,
    null,
    null,
    null,
  ),
  td.TextEntityTypeSpoiler() => (TextFormat.spoiler, null, null, null),
  td.TextEntityTypeCode() ||
  td.TextEntityTypePre() ||
  td.TextEntityTypePreCode() => (TextFormat.monospace, null, null, null),
  td.TextEntityTypeBlockQuote() || td.TextEntityTypeExpandableBlockQuote() => (
    TextFormat.quote,
    null,
    null,
    null,
  ),
  td.TextEntityTypeTextUrl(:final url) => (TextFormat.link, url, null, null),
  td.TextEntityTypeMentionName(:final userId) => (
    TextFormat.mention,
    null,
    userId,
    null,
  ),
  td.TextEntityTypeCustomEmoji(:final customEmojiId) => (
    TextFormat.customEmoji,
    null,
    null,
    customEmojiId,
  ),
  _ => null,
};

/// The composer's formatting menu and link sheet in the user's language.
FormatLabels formatLabelsOf(AppLocalizations l10n) => FormatLabels(
  bold: l10n.formatBold,
  italic: l10n.formatItalic,
  underline: l10n.formatUnderline,
  strikethrough: l10n.formatStrikethrough,
  monospace: l10n.formatMonospace,
  spoiler: l10n.formatSpoiler,
  quote: l10n.formatQuote,
  link: l10n.formatLink,
  plain: l10n.formatPlain,
  linkTitle: l10n.linkTitle,
  linkHint: l10n.linkHint,
  apply: l10n.linkApply,
  cancel: l10n.cancel,
);
