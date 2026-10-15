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
/// "14 October 2025 at 12:05", for tooltips.
String formatFullDate(int unixSeconds, String locale) {
  final date = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return '${DateFormat.yMMMMd(locale).format(date)}, '
      '${DateFormat.Hm(locale).format(date)}';
}

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

/// The last message as a chat-list row shows it. A message with a
/// thumbnail drops the kind before its caption, the picture says it.
/// [you] puts "You:" before the user's own message; a group's row names
/// the sender on a line of its own instead. [sender] puts their name
/// before someone else's message, as in a forum, where the topic takes
/// that line.
String formatPreview(
  AppLocalizations l10n,
  ChatPreview? preview, {
  bool you = true,
  String sender = '',
}) {
  if (preview == null) return '';
  // A file or a song is named by what it is called, not "File".
  final label = preview.fileName.isNotEmpty
      ? preview.fileName
      : preview.thumbnail != null && preview.text.isNotEmpty
      ? ''
      : kindLabel(l10n, preview.kind);
  final text = preview.text.replaceAll('\n', ' ');
  final body = switch ((label.isEmpty, text.isEmpty)) {
    (true, _) => text,
    (false, true) => label,
    (false, false) => '$label, $text',
  };
  if (you && preview.isOutgoing) return l10n.previewYou(body);
  return sender.isEmpty || preview.isOutgoing ? body : '$sender: $body';
}

/// What a chat-list row shows for an unsent draft: its text, or the kind of
/// the draft when it is not text, such as a voice note.
String draftText(AppLocalizations l10n, ChatDraft draft) {
  final text = draft.text.replaceAll('\n', ' ');
  final label = kindLabel(l10n, draft.kind);
  return switch ((label.isEmpty, text.isEmpty)) {
    (true, _) => text,
    (false, true) => label,
    (false, false) => '$label, $text',
  };
}
