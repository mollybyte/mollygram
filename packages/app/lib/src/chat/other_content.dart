import 'package:flutter/widgets.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'formatted_text.dart';

/// The text lines of contents that have no media of their own: places,
/// contacts, polls, calls, games, invoices. Null for anything else.
Widget? otherContent(BuildContext context, td.MessageContent content) {
  final l10n = AppLocalizations.of(context);
  return switch (content) {
    td.MessageLocation(:final location) => _Labeled(
      icon: '📍',
      title: l10n.contentLocation,
      onTap: () => openLink(_mapUrl(location)),
    ),
    td.MessageLiveLocation(:final location) => _Labeled(
      icon: '📍',
      title: l10n.contentLiveLocation,
      onTap: () => openLink(_mapUrl(location.location)),
    ),
    td.MessageVenue(:final venue) => _Labeled(
      icon: '📍',
      title: venue.title,
      subtitle: venue.address,
      onTap: () => openLink(_mapUrl(venue.location)),
    ),
    td.MessageContact(:final contact) => _Labeled(
      icon: '👤',
      title: [
        contact.firstName,
        contact.lastName,
      ].where((s) => s.isNotEmpty).join(' '),
      subtitle: contact.phoneNumber,
    ),
    td.MessagePoll(:final poll) => _Poll(poll),
    td.MessageCall(:final isVideo, :final discardReason, :final duration) =>
      _Labeled(
        icon: isVideo ? '📹' : '📞',
        title: _callTitle(l10n, content, isVideo, discardReason),
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
    td.MessageChecklist(:final list) => _Checklist(list),
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

String _mapUrl(td.Location l) =>
    'https://maps.apple.com/?ll=${l.latitude},${l.longitude}&q=${l.latitude},${l.longitude}';

String _callTitle(
  AppLocalizations l10n,
  td.MessageContent content,
  bool isVideo,
  td.CallDiscardReason reason,
) => switch (reason) {
  td.CallDiscardReasonMissed() => l10n.callMissed,
  td.CallDiscardReasonDeclined() => l10n.callDeclined,
  _ => isVideo ? l10n.callVideoOutgoing : l10n.callOutgoing,
};

String _callLength(AppLocalizations l10n, int seconds) => seconds < 60
    ? l10n.durationSeconds(seconds)
    : l10n.durationMinutes(seconds ~/ 60);

class _Labeled extends StatelessWidget {
  const _Labeled({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final subtitle = this.subtitle;
    final body = Row(
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
    if (onTap == null) return body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: body),
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

/// The question, then each option with its share of the votes. Voting
/// arrives with the message actions.
class _Poll extends StatelessWidget {
  const _Poll(this.poll);

  final td.Poll poll;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final showResults = poll.canSeeResults || poll.isClosed;
    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            poll.question.text,
            style: mgTextStyle(c, weight: FontWeight.w600),
          ),
          Text(
            poll.type is td.PollTypeQuiz ? l10n.contentQuiz : l10n.contentPoll,
            style: MessageMeta.styleOf(c),
          ),
          const SizedBox(height: 6),
          for (final option in poll.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (showResults)
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${option.votePercentage}%',
                            style: mgTextStyle(c, weight: FontWeight.w600),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          option.text.text,
                          style: mgTextStyle(
                            c,
                            weight: option.isChosen
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (showResults)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: LayoutBuilder(
                            builder: (context, box) => Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width:
                                    box.maxWidth * option.votePercentage / 100,
                                color: c.accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Text(
            l10n.pollVotes(poll.totalVoterCount),
            style: MessageMeta.styleOf(c),
          ),
        ],
      ),
    );
  }
}

class _Checklist extends StatelessWidget {
  const _Checklist(this.list);

  final td.Checklist list;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(list.title.text, style: mgTextStyle(c, weight: FontWeight.w600)),
        const SizedBox(height: 4),
        for (final task in list.tasks)
          Text(
            '${task.completedBy != null ? '☑' : '☐'} ${task.text.text}',
            style: mgTextStyle(c),
          ),
      ],
    );
  }
}
