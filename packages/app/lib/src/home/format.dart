import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';

/// Chat-list time: the hour today, the weekday this week, the date before.
String formatChatTime(int unixSeconds, String locale, {DateTime? now}) {
  if (unixSeconds == 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return DateFormat.Hm(locale).format(date);
  if (today.difference(day).inDays < 7) {
    return DateFormat.E(locale).format(date);
  }
  if (date.year == now.year) return DateFormat.MMMd(locale).format(date);
  return DateFormat.yMd(locale).format(date);
}

/// Message time inside a bubble.
String formatMessageTime(int unixSeconds, String locale) =>
    DateFormat.Hm(locale)
        .format(DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000));

/// The name of a kind of message, such as "Photo"; empty for text.
String kindLabel(AppLocalizations l10n, ChatPreviewKind kind) => switch (kind) {
  ChatPreviewKind.text => '',
  ChatPreviewKind.photo => l10n.previewPhoto,
  ChatPreviewKind.video => l10n.previewVideo,
  ChatPreviewKind.videoNote => l10n.previewVideoNote,
  ChatPreviewKind.voiceNote => l10n.previewVoiceNote,
  ChatPreviewKind.audio => l10n.previewAudio,
  ChatPreviewKind.document => l10n.previewDocument,
  ChatPreviewKind.sticker => l10n.previewSticker,
  ChatPreviewKind.animation => l10n.previewAnimation,
  ChatPreviewKind.other => l10n.previewOther,
};

/// The second line of a chat-list row.
String formatPreview(AppLocalizations l10n, ChatPreview? preview) {
  if (preview == null) return '';
  final label = kindLabel(l10n, preview.kind);
  final text = preview.text.replaceAll('\n', ' ');
  final body = switch ((label.isEmpty, text.isEmpty)) {
    (true, _) => text,
    (false, true) => label,
    (false, false) => '$label, $text',
  };
  return preview.isOutgoing ? l10n.previewYou(body) : body;
}
