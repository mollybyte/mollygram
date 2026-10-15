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
        icon: isVideo ? MgIcons.video : MgIcons.call,
        tint: switch (discardReason) {
          td.CallDiscardReasonMissed() ||
          td.CallDiscardReasonDeclined() => _missedCall,
          _ => _answeredCall,
        },
        title: _callTitle(l10n, isOutgoing, isVideo, discardReason),
        subtitle: duration > 0 ? _callLength(l10n, duration) : null,
      ),
    td.MessageGame(:final game) => _Labeled(
      icon: _gameIcon,
      title: game.title,
      subtitle: game.description,
    ),
    td.MessageInvoice(:final productInfo) => _Labeled(
      icon: _receiptIcon,
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
    td.MessageStory() => _Labeled(icon: _storyIcon, title: l10n.contentStory),
    td.MessageGiveaway() || td.MessageGiveawayWinners() => _Labeled(
      icon: _giftIcon,
      title: l10n.contentGiveaway,
    ),
    td.MessagePaidMedia() => _Labeled(
      icon: _starIcon,
      title: l10n.contentPaidMedia,
    ),
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

/// Call rows: green for a call that took place, red for one that didn't.
const _answeredCall = Color(0xFF34C759);
const _missedCall = Color(0xFFFF3B30);

// Line icons for the rows, in the style of the design's set.
const _gameIcon = MgIconData(
  'game',
  '<rect x="3" y="7" width="18" height="11" rx="5.5"/>'
      '<path d="M7.5 11v3M6 12.5h3M15.5 12h.01M18 13.5h.01"/>',
);
const _receiptIcon = MgIconData(
  'receipt',
  '<path d="M6 3h12v18l-3-2-3 2-3-2-3 2zM9 8h6M9 12h6M9 16h4"/>',
);
const _storyIcon = MgIconData(
  'story',
  '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.5"/>',
);
const _giftIcon = MgIconData(
  'gift',
  '<rect x="3" y="8" width="18" height="4"/>'
      '<path d="M5 12v8h14v-8M12 8v12M12 8c-1.5-3-5-3-5-1s3 1 5 1'
      'c2 0 5 1 5-1s-3.5-2-5 1"/>',
);
const _starIcon = MgIconData(
  'star',
  '<path d="M12 3.5l2.6 5.6 6.1.7-4.5 4.2 1.2 6-5.4-3-5.4 3 1.2-6'
      'L3.3 9.8l6.1-.7z"/>',
);

/// A row with a round tinted tile holding a line icon, a title and a
/// line under it, for contents that have no media of their own.
class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.icon,
    required this.title,
    this.subtitle,
    this.tint,
  });

  final MgIconData icon;
  final String title;
  final String? subtitle;

  /// The tile's colour; the accent unless given.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final subtitle = this.subtitle;
    final tint = this.tint ?? c.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: MgIcon(icon, size: 18, color: tint)),
          ),
        ),
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
