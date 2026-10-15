import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../links/link_router.dart';
import 'checklist_content.dart';
import 'location_content.dart';
import 'poll_content.dart';

/// The text lines of contents that have no media of their own: places,
/// contacts, polls, calls, games, invoices. Null for anything else.
/// [isOutgoing] tells a call the user made from one they received;
/// [onPollVote] lets a poll be voted in, [onPollVoters] lists who voted
/// for an option and [recentVoters] shows the latest voters' avatars;
/// [onChecklistToggle] marks a checklist's task done or not done and
/// [completerAvatar] draws who did it, and the [sender] of a live
/// location in its pin; [chatId] is the chat a map is drawn for.
Widget? otherContent(
  BuildContext context,
  td.MessageContent content, {
  bool isOutgoing = false,
  int chatId = 0,
  td.MessageSender? sender,
  void Function(List<int> optionIds)? onPollVote,
  void Function(int optionIndex, Offset position)? onPollVoters,
  Widget? recentVoters,
  void Function(int taskId, bool done)? onChecklistToggle,
  Widget Function(td.MessageSender sender, double size)? completerAvatar,
}) {
  final l10n = AppLocalizations.of(context);
  return switch (content) {
    td.MessageLocation(:final location) => LocationContent(
      location: location,
      chatId: chatId,
    ),
    td.MessageLiveLocation(:final location) && final live => LocationContent(
      location: location.location,
      live: live,
      avatar: sender == null ? null : completerAvatar?.call(sender, 22),
      chatId: chatId,
    ),
    td.MessageVenue(:final venue) => LocationContent(
      location: venue.location,
      venue: venue,
      chatId: chatId,
    ),
    td.MessageContact(:final contact) => _ContactCard(contact),
    td.MessagePoll(:final poll, :final description) => PollContent(
      poll: poll,
      description: description,
      onVote: onPollVote,
      onShowVoters: onPollVoters,
      recentVoters: recentVoters,
    ),
    td.MessageCall(:final isVideo, :final discardReason, :final duration) =>
      _Labeled(
        icon: isVideo ? '📹' : '📞',
        title: _callTitle(l10n, isOutgoing, isVideo, discardReason),
        subtitle: duration > 0 ? _callLength(l10n, duration) : null,
      ),
    td.MessageGame(:final game) => _Labeled(
      icon: '🎮',
      title: game.title,
      subtitle: game.description,
    ),
    td.MessageInvoice(:final productInfo) => _Labeled(
      icon: '🧾',
      title: productInfo.title.isEmpty
          ? l10n.contentInvoice
          : productInfo.title,
      subtitle: productInfo.description.text,
    ),
    td.MessageChecklist(:final list) => ChecklistContent(
      list: list,
      onToggle: onChecklistToggle,
      completerAvatar: completerAvatar,
    ),
    td.MessageStory() => _Labeled(icon: '◎', title: l10n.contentStory),
    td.MessageGiveaway() || td.MessageGiveawayWinners() => _Labeled(
      icon: '🎁',
      title: l10n.contentGiveaway,
    ),
    td.MessagePaidMedia() => _Labeled(icon: '⭐', title: l10n.contentPaidMedia),
    td.MessageExpiredPhoto() => _Muted(l10n.contentExpiredPhoto),
    td.MessageExpiredVideo() => _Muted(l10n.contentExpiredVideo),
    td.MessageExpiredVideoNote() => _Muted(l10n.contentExpiredVideoNote),
    td.MessageExpiredVoiceNote() => _Muted(l10n.contentExpiredVoiceNote),
    td.MessageUnsupported() ||
    td.MessageRichMessage() => _Muted(l10n.contentUnsupported),
    _ => null,
  };
}

String _callTitle(
  AppLocalizations l10n,
  bool isOutgoing,
  bool isVideo,
  td.CallDiscardReason reason,
) => switch (reason) {
  // A call the other side didn't pick up was cancelled by the caller.
  td.CallDiscardReasonMissed() when isOutgoing => l10n.callCancelled,
  td.CallDiscardReasonMissed() => l10n.callMissed,
  td.CallDiscardReasonDeclined() => l10n.callDeclined,
  _ when isOutgoing => isVideo ? l10n.callVideoOutgoing : l10n.callOutgoing,
  _ => isVideo ? l10n.callVideoIncoming : l10n.callIncoming,
};

String _callLength(AppLocalizations l10n, int seconds) => seconds < 60
    ? l10n.durationSeconds(seconds)
    : l10n.durationMinutes(seconds ~/ 60);

class _Labeled extends StatelessWidget {
  const _Labeled({required this.icon, required this.title, this.subtitle});

  final String icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final subtitle = this.subtitle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mgTextStyle(c, weight: FontWeight.w500),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MessageMeta.styleOf(c),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A shared contact: the monogram, the name and the phone number. A tap
/// opens the person when they are on Telegram.
class _ContactCard extends StatelessWidget {
  const _ContactCard(this.contact);

  final td.Contact contact;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final name = [
      contact.firstName,
      contact.lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final body = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MonogramAvatar(name: name, size: 36),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mgTextStyle(c, weight: FontWeight.w500),
              ),
              if (contact.phoneNumber.isNotEmpty)
                Text(
                  '+${contact.phoneNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, color: c.accent),
                ),
            ],
          ),
        ),
      ],
    );
    if (contact.userId == 0) return body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => openLinkFrom(context, 'tg://user?id=${contact.userId}'),
        child: body,
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Text(
      text,
      style: mgTextStyle(c, color: c.fg2, weight: FontWeight.w400),
    );
  }
}
