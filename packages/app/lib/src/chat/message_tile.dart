import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../links/link_router.dart';
import '../plugins/message_hooks.dart';
import '../settings/stickers/sticker_options.dart';
import '../settings/stickers/sticker_set_sheet.dart';
import 'bot_keyboard.dart';
import 'chat_translation.dart';
import 'concealed.dart';
import 'custom_emoji.dart';
import 'describe.dart';
import 'file_content.dart';
import 'formatted_text.dart';
import 'media_content.dart';
import 'other_content.dart';
import 'td_file.dart';
import 'upload_overlay.dart';

/// One row of the chat: a single message, or the photos and videos of an
/// album sent together.
final class MessageRow {
  MessageRow(List<ConversationMessage> messages)
    : messages = List.unmodifiable(
        <ConversationMessage>[...messages]
          ..sort((a, b) => a.id.compareTo(b.id)),
      );

  /// Oldest first.
  final List<ConversationMessage> messages;

  /// The message whose time, sender and reactions the row shows.
  ConversationMessage get primary => messages.last;

  /// Whether [message] can join an album row next to others with the same
  /// album id.
  static bool joinsAlbum(ConversationMessage message) =>
      message.albumId != 0 &&
      (message.content is td.MessagePhoto ||
          message.content is td.MessageVideo);
}

/// How a row sits among its neighbours.
@immutable
class MessageRowContext {
  const MessageRowContext({
    required this.isGroup,
    required this.isChannel,
    required this.startsRun,
    required this.endsRun,
    required this.lastReadOutbox,
    this.startsForwards = false,
    this.selecting = false,
    this.selected = false,
  });

  /// Incoming messages show the sender's name and avatar.
  final bool isGroup;
  final bool isChannel;

  /// The first message of a run from one sender: it gets the name.
  final bool startsRun;

  /// The last one: it gets the avatar.
  final bool endsRun;

  /// The first of forwarded messages in a row: "Forwarded messages" goes
  /// above it.
  final bool startsForwards;

  /// Outgoing messages up to this id are read by the other side.
  final int lastReadOutbox;

  /// Messages are being selected: a check shows at the left of each row
  /// and a click picks the row instead of acting on its content.
  final bool selecting;

  /// This row is among the selected ones.
  final bool selected;
}

/// Tells its child whether the pointer is over it, for what shows only
/// on hover, without rebuilding the child as the pointer moves.
class _HoverScope extends StatefulWidget {
  const _HoverScope({required this.builder});

  final Widget Function(BuildContext context, ValueListenable<bool> hovered)
  builder;

  @override
  State<_HoverScope> createState() => _HoverScopeState();
}

class _HoverScopeState extends State<_HoverScope> {
  final _hovered = ValueNotifier(false);

  @override
  void dispose() {
    _hovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _hovered.value = true,
    onExit: (_) => _hovered.value = false,
    child: widget.builder(context, _hovered),
  );
}

/// Callbacks of a message row.
@immutable
class MessageRowActions {
  const MessageRowActions({
    required this.onReaction,
    required this.onNeedReplied,
    this.onMenu,
    this.onOpen,
    this.onViewMedia,
    this.onCancelSend,
    this.onRetrySend,
    this.onJump,
    this.onSelectToggle,
    this.onTextSelected,
    this.onPollVote,
    this.onPollVoters,
    this.onChecklistToggle,
    this.onInlineButton,
    this.onComments,
    this.onOpenForwardSource,
    this.onOpenSender,
  });

  /// Adds the reaction, or takes it back when the user had chosen it.
  final void Function(
    ConversationMessage message,
    td.ReactionType reaction,
    bool chosen,
  )
  onReaction;

  /// The original of a reply isn't loaded yet.
  final void Function(ConversationMessage reply) onNeedReplied;

  /// A right click on the row, at [position] in global coordinates.
  final void Function(MessageRow row, Offset position)? onMenu;

  /// The user revealed self-destructing media, which starts its timer.
  final void Function(ConversationMessage message)? onOpen;

  /// A click on a photo, video or GIF, which opens the media viewer.
  final void Function(ConversationMessage message)? onViewMedia;

  /// The cross on a photo or video still going up, or the delete button
  /// of one that failed.
  final void Function(ConversationMessage message)? onCancelSend;

  /// Try again, on a photo or video that failed to send.
  final void Function(ConversationMessage message)? onRetrySend;

  /// A click on a reply's quote, which scrolls to the message it answers.
  final void Function(int messageId)? onJump;

  /// A click on a row while selecting: the row joins or leaves the
  /// selection.
  final void Function(MessageRow row)? onSelectToggle;

  /// The text selection within a message changed; null once nothing of
  /// it is selected. Turns on text selection in the timeline.
  final void Function(ConversationMessage message, QuoteSelection? quote)?
  onTextSelected;

  /// A vote in a poll for the options with [optionIds]; an empty list
  /// takes the vote back.
  final void Function(ConversationMessage message, List<int> optionIds)?
  onPollVote;

  /// A click on an option's results in a public poll, at [position]:
  /// lists who voted for it.
  final void Function(
    ConversationMessage message,
    int optionIndex,
    Offset position,
  )?
  onPollVoters;

  /// A click on a task of the checklist in [message], marking it done or
  /// not done.
  final void Function(ConversationMessage message, int taskId, bool done)?
  onChecklistToggle;

  /// A press on one of a bot's buttons under [message].
  final void Function(
    ConversationMessage message,
    td.InlineKeyboardButton button,
  )?
  onInlineButton;

  /// A click on the comments row under a channel post, which opens them.
  final void Function(ConversationMessage message)? onComments;

  /// A click on the name a forward came from, which opens that channel, at
  /// the original post when it is known, or that person's profile.
  final void Function(td.MessageOrigin origin)? onOpenForwardSource;

  /// A click on a sender's avatar or name, which opens their profile, or
  /// the channel's info for a channel post.
  final void Function(MessageSenderId sender)? onOpenSender;
}

/// Makes [child] open a sender's profile: a pointer cursor over it and, for
/// the avatar, a faint dimming on hover.
class _SenderLink extends StatefulWidget {
  const _SenderLink({
    required this.onTap,
    required this.child,
    this.dimOnHover = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final bool dimOnHover;

  @override
  State<_SenderLink> createState() => _SenderLinkState();
}

class _SenderLinkState extends State<_SenderLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: widget.dimOnHover
            ? AnimatedOpacity(
                duration: const Duration(milliseconds: 120),
                opacity: _hover ? 0.82 : 1,
                child: widget.child,
              )
            : widget.child,
      ),
    );
  }
}

/// A message, or an album, in Telegram's flat layout: no bubbles, the
/// sender's avatar and coloured name at the start of a run, the time and
/// ticks on the right of each message, chat events centered.
class MessageTile extends StatelessWidget {
  const MessageTile({
    super.key,
    required this.row,
    required this.store,
    required this.context,
    required this.actions,
  });

  final MessageRow row;
  final ConversationStore store;
  final MessageRowContext context;
  final MessageRowActions actions;

  /// The avatar column and the gap after it.
  static const double avatarSize = 32;
  static const double contentIndent = avatarSize + 12;

  MessageStatus get _status {
    final message = row.primary;
    if (!message.isOutgoing || message.message.isChannelPost) {
      return MessageStatus.none;
    }
    return switch (message.sendState) {
      MessageSendState.pending => MessageStatus.sending,
      MessageSendState.failed => MessageStatus.failed,
      MessageSendState.sent when message.id <= context.lastReadOutbox =>
        MessageStatus.read,
      MessageSendState.sent => MessageStatus.sent,
    };
  }

  Widget _replierAvatar(AppLocalizations l10n, td.MessageSender sender) {
    final id = MessageSenderId.of(sender);
    return SenderAvatar(
      name: nameOfSender(l10n, store, id),
      photo: store.photoOf(id),
      size: 19,
    );
  }

  @override
  Widget build(BuildContext buildContext) =>
      PluginFilteredMessage(message: row.primary, child: _build(buildContext));

  Widget _build(BuildContext buildContext) {
    final l10n = AppLocalizations.of(buildContext);
    final c = MgColors.of(buildContext);
    final message = row.primary;
    if (message.isService) {
      final service = SelectionContainer.disabled(
        child: ServiceMessage(
          describeService(l10n, store, message, isChannel: context.isChannel),
        ),
      );
      // Chat events can't be selected; while selecting they just sit there.
      return context.selecting ? IgnorePointer(child: service) : service;
    }
    final locale = Localizations.localeOf(buildContext).toLanguageTag();
    final info = message.message.interactionInfo;
    final isPost = message.message.isChannelPost;
    final compact = NumberFormat.compact(locale: locale);
    final meta = MessageMeta(
      time: formatMessageTime(message.date, locale),
      status: _status,
      label: message.isDeleted
          ? l10n.deletedMark
          : message.editDate > 0
          ? l10n.edited
          : null,
      views: isPost && info != null && info.viewCount > 0
          ? compact.format(info.viewCount)
          : null,
      forwards: isPost && info != null && info.forwardCount > 0
          ? compact.format(info.forwardCount)
          : null,
      tooltip: [
        formatFullDate(message.date, locale),
        if (message.editDate > 0)
          l10n.editedAt(formatFullDate(message.editDate, locale)),
        if (message.deletedAt case final deletedAt?)
          l10n.deletedAt(
            formatFullDate(deletedAt.millisecondsSinceEpoch ~/ 1000, locale),
          ),
      ].join('\n'),
    );
    final reactions = info?.reactions?.reactions;
    // A channel post carries its comments; a group message with replies,
    // the thread of those replies.
    final replyInfo = info?.replyInfo;
    final comments = isPost || (replyInfo?.replyCount ?? 0) > 0
        ? replyInfo
        : null;
    final forward = message.message.forwardInfo;
    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A deleted message stays readable, but steps back a little.
        if (message.isDeleted)
          Opacity(
            opacity: 0.62,
            child: _MessageBody(row: row, store: store, actions: actions),
          )
        else
          _MessageBody(row: row, store: store, actions: actions),
        if (message.message.replyMarkup case td.ReplyMarkupInlineKeyboard(
          :final rows,
        ))
          SelectionContainer.disabled(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: InlineKeyboard(
                  rows: rows,
                  onPressed: switch (actions.onInlineButton) {
                    null => null,
                    final press => (button) => press(message, button),
                  },
                ),
              ),
            ),
          ),
        // Always mounted, so the first reaction on a message pops in too.
        SelectionContainer.disabled(
          child: Padding(
            padding: EdgeInsets.only(
              top: reactions == null || reactions.isEmpty ? 0 : 5,
            ),
            child: ReactionRow(
              chips: [
                for (final reaction
                    in reactions ?? const <td.MessageReaction>[])
                  (
                    reaction.type is td.ReactionTypePaid
                        ? 'paid'
                        : reactionKey(reaction.type),
                    ReactionChip(
                      emoji: reactionKey(reaction.type),
                      icon: customReactionIcon(
                        reactionKey(reaction.type),
                        ReactionChip.iconSize,
                      ),
                      count: reaction.totalCount,
                      chosen: reaction.isChosen,
                      onTap: reaction.type is td.ReactionTypePaid
                          ? null
                          : () => actions.onReaction(
                              message,
                              reaction.type,
                              reaction.isChosen,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (comments != null)
          SelectionContainer.disabled(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CommentsRow(
                label: comments.replyCount == 0
                    ? l10n.leaveComment
                    : isPost
                    ? l10n.commentCount(comments.replyCount)
                    : l10n.replyCount(comments.replyCount),
                avatars: [
                  for (final sender in comments.recentReplierIds.take(3))
                    _replierAvatar(l10n, sender),
                ],
                unread:
                    comments.lastMessageId > comments.lastReadInboxMessageId,
                onTap: actions.onComments == null
                    ? null
                    : () => actions.onComments!(message),
              ),
            ),
          ),
      ],
    );
    if (forward != null) {
      final source = originSender(forward.origin);
      content = ForwardedBlock(
        source: forwardOriginName(l10n, store, forward.origin),
        date: formatChatTime(forward.date, locale),
        color: source == null ? null : peerNameColor(c, store.colorOf(source)),
        onSourceTap:
            actions.onOpenForwardSource == null ||
                forward.origin is td.MessageOriginHiddenUser
            ? null
            : () => actions.onOpenForwardSource!(forward.origin),
        child: content,
      );
    }
    final name = nameOfSender(l10n, store, message.sender);
    final onMenu = actions.onMenu;
    final onOpenSender = actions.onOpenSender;
    final VoidCallback? openSender = onOpenSender == null
        ? null
        : () => onOpenSender(message.sender);
    final metrics = MgMetrics.of(buildContext);
    final tile = Padding(
      padding: EdgeInsets.only(
        top: context.startsRun
            ? (metrics.compact ? 6 : 12)
            : metrics.messageGap,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: avatarSize,
            child: context.startsRun
                ? _SenderLink(
                    dimOnHover: true,
                    onTap: openSender,
                    child: SenderAvatar(
                      name: name,
                      photo: store.photoOf(message.sender),
                      size: avatarSize,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (context.startsRun)
                  SelectionContainer.disabled(
                    // Lifted so the name sits on the avatar's top edge.
                    child: Transform.translate(
                      offset: const Offset(0, -2),
                      child: _SenderLink(
                        onTap: openSender,
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.small,
                            weight: MgWeight.medium,
                            color: peerNameColor(
                              c,
                              store.colorOf(message.sender),
                            ),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (context.startsForwards)
                  SelectionContainer.disabled(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        l10n.forwardedMessages,
                        style: mgTextStyle(c, color: c.fg2),
                      ),
                    ),
                  ),
                // Message text reads a step larger than the rest, on
                // lines just open enough for long paragraphs.
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: MgType.message,
                    height: 1.35,
                    letterSpacing: mgTracking(MgType.message),
                  ),
                  child: content,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SelectionContainer.disabled(
            child: Padding(padding: const EdgeInsets.only(top: 1), child: meta),
          ),
        ],
      ),
    );
    final onSelectToggle = actions.onSelectToggle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onMenu == null
          ? null
          : (details) => onMenu(row, details.globalPosition),
      onTap: context.selecting && onSelectToggle != null
          ? () => onSelectToggle(row)
          : null,
      child: _Selectable(
        selecting: context.selecting,
        selected: context.selected,
        // The check sits level with the first line of the row.
        top: context.startsRun ? 9 : 3,
        child: tile,
      ),
    );
  }
}

/// The check column that slides in at the left while selecting, and the
/// accent tint over a selected row. The row's own controls stop taking
/// clicks, which go to the selection instead.
class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.selecting,
    required this.selected,
    required this.top,
    required this.child,
  });

  final bool selecting;
  final bool selected;
  final double top;
  final Widget child;

  static const double _column = SelectCheck.size + 12;
  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected
            ? c.accent.withValues(alpha: 0.12)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(8),
      ),
      // The check is laid over the row rather than beside it, so a short
      // row keeps its height while selecting.
      child: Stack(
        children: [
          AnimatedPadding(
            duration: _duration,
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(left: selecting ? _column : 0),
            child: AbsorbPointer(absorbing: selecting, child: child),
          ),
          Positioned(
            left: 4,
            top: top,
            child: IgnorePointer(
              child: AnimatedSlide(
                duration: _duration,
                curve: Curves.easeOutCubic,
                offset: selecting ? Offset.zero : const Offset(-1.3, 0),
                child: AnimatedOpacity(
                  duration: _duration,
                  opacity: selecting ? 1 : 0,
                  child: SelectCheck(selected: selected),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A round avatar: the photo once it has downloaded, the gray monogram
/// until then.
class SenderAvatar extends StatelessWidget {
  const SenderAvatar({
    super.key,
    required this.name,
    required this.size,
    this.photo,
  });

  final String name;
  final double size;
  final td.File? photo;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    if (photo == null) return MonogramAvatar(name: name, size: size);
    return TdFileBuilder(
      file: photo,
      download: true,
      priority: DownloadPriority.preview,
      builder: (context, file) {
        final path = downloadedPath(file);
        return MonogramAvatar(
          name: name,
          size: size,
          image: path == null
              ? null
              : ResizeImage(
                  FileImage(File(path)),
                  width: (size * MediaQuery.devicePixelRatioOf(context))
                      .round(),
                ),
        );
      },
    );
  }
}

/// What a message shows under its sender's name: "Forwarded from", the
/// reply quote, then the content.
class _MessageBody extends StatelessWidget {
  const _MessageBody({
    required this.row,
    required this.store,
    required this.actions,
  });

  final MessageRow row;
  final ConversationStore store;
  final MessageRowActions actions;

  ConversationMessage get message => row.primary;

  /// The text of [of] reports its selection for a quote.
  Widget _text(td.FormattedText text, {ConversationMessage? of}) {
    final onTextSelected = actions.onTextSelected;
    final owner = of ?? message;
    // The chat may be shown translated; the text is then the translation.
    return TranslatedText(
      message: owner,
      text: text,
      // Bot commands in it go to this chat, meant for the bot that sent it.
      builder: (shown) => FormattedTextView(
        text: shown,
        chatId: owner.chatId,
        senderUserId: owner.sender.isChat ? null : owner.sender.id,
        onSelection: onTextSelected == null
            ? null
            : (quote) => onTextSelected(owner, quote),
      ),
    );
  }

  /// Up to three of the poll's latest voters, overlapping a little, as
  /// Telegram shows them next to a public poll's kind.
  Widget? _recentVoters(
    BuildContext context,
    AppLocalizations l10n,
    List<td.MessageSender> ids,
  ) {
    if (ids.isEmpty) return null;
    final shown = ids.take(3).toList();
    const size = 16.0;
    const step = 11.0;
    return SizedBox(
      width: size + step * (shown.length - 1),
      height: size,
      child: Stack(
        children: [
          for (final (i, sender) in shown.indexed.toList().reversed)
            Positioned(
              left: step * i,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: MgColors.of(context).windowBackground,
                    width: 1.5,
                  ),
                ),
                child: _senderAvatar(l10n, sender, size - 3),
              ),
            ),
        ],
      ),
    );
  }

  Widget _senderAvatar(
    AppLocalizations l10n,
    td.MessageSender sender,
    double size,
  ) {
    final id = MessageSenderId.of(sender);
    return SenderAvatar(
      name: nameOfSender(l10n, store, id),
      photo: store.photoOf(id),
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _HoverScope(
      builder: (context, hovered) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._headers(l10n),
          _content(context, l10n),
          PluginMessageExtras(message: message, hovered: hovered),
        ],
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n) {
    final content = message.content;
    final restriction = message.message.restrictionInfo?.restrictionReason;
    if (restriction != null && restriction.isNotEmpty) {
      final c = MgColors.of(context);
      return Text(
        restriction,
        style: mgTextStyle(
          c,
          color: c.fg2,
        ).copyWith(fontStyle: FontStyle.italic),
      );
    }
    switch (content) {
      case td.MessageSticker(:final sticker):
        return _TimelineSticker(sticker);
      case td.MessageAnimatedEmoji(:final animatedEmoji, :final emoji):
        final sticker = animatedEmoji.sticker;
        if (sticker == null) return _BigEmoji(emoji);
        return _LargeSticker(sticker);
      case td.MessageDice(
        :final initialState,
        :final finalState,
        :final emoji,
        :final value,
      ):
        // The thrown value is a sticker of its own; before the server has
        // picked one (the message just went out) the dice is shown rolling.
        final state = value > 0 ? finalState ?? initialState : initialState;
        return switch (state) {
          td.DiceStickersRegular(:final sticker) => _LargeSticker(sticker),
          td.DiceStickersSlotMachine(
            :final background,
            :final lever,
            :final leftReel,
            :final centerReel,
            :final rightReel,
          ) =>
            SizedBox.square(
              dimension: _LargeSticker.side,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (final part in [
                    background,
                    leftReel,
                    centerReel,
                    rightReel,
                    lever,
                  ])
                    FittedBox(child: StickerContent(sticker: part)),
                ],
              ),
            ),
          null => _BigEmoji(emoji),
        };
      case td.MessageVideoNote(:final videoNote, :final isViewed):
        final note = VideoNoteContent(
          chatId: message.chatId,
          messageId: message.id,
          videoNote: videoNote,
          unread: !isViewed,
        );
        final reason = concealmentOf(message);
        if (reason == null) return note;
        return ClipOval(
          child: Concealed(
            reason: reason,
            minithumbnail: videoNote.minithumbnail,
            size: const Size.square(VideoNoteContent.side),
            child: note,
          ),
        );
      case td.MessageText(:final text, linkPreview: null)
          when text.entities.isEmpty && isEmojiOnly(text.text):
        return LargeEmoji(big: _BigEmoji(text.text), small: _text(text));
      case td.MessageText(:final text, :final linkPreview):
        if (linkPreview == null) return _text(text);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!linkPreview.showAboveText) _text(text),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _LinkPreview(linkPreview),
            ),
            if (linkPreview.showAboveText)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _text(text),
              ),
          ],
        );
      case td.MessageDocument(:final document):
        return _withCaption(
          DocumentContent(
            chatId: message.chatId,
            messageId: message.id,
            document: document,
          ),
        );
      case td.MessageVoiceNote(:final voiceNote, :final isListened):
        return _withCaption(
          VoiceNoteContent(
            chatId: message.chatId,
            messageId: message.id,
            voiceNote: voiceNote,
            unread: !isListened,
          ),
        );
      case td.MessageAudio(:final audio):
        return _withCaption(
          AudioContent(
            chatId: message.chatId,
            messageId: message.id,
            audio: audio,
          ),
        );
      default:
    }
    final visual = _visualFor(row, actions);
    if (visual != null) {
      final caption = _caption(row);
      final media = Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            MgMetrics.of(context).mediaRadius,
          ),
          child: visual.widget,
        ),
      );
      if (caption == null) return media;
      final text = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(visual.width, 420)),
        child: _text(caption.text, of: caption.of),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: caption.above
            ? [text, const SizedBox(height: 2), media]
            : [media, const SizedBox(height: 4), text],
      );
    }
    final onPollVote = actions.onPollVote;
    final onPollVoters = actions.onPollVoters;
    final onChecklistToggle = actions.onChecklistToggle;
    return otherContent(
          context,
          content,
          isOutgoing: message.isOutgoing,
          chatId: message.chatId,
          sender: message.message.senderId,
          onPollVote: onPollVote == null
              ? null
              : (optionIds) => onPollVote(message, optionIds),
          onPollVoters: onPollVoters == null
              ? null
              : (index, position) => onPollVoters(message, index, position),
          recentVoters: content is td.MessagePoll
              ? _recentVoters(context, l10n, content.poll.recentVoterIds)
              : null,
          onChecklistToggle: onChecklistToggle == null
              ? null
              : (taskId, done) => onChecklistToggle(message, taskId, done),
          completerAvatar: (sender, size) => _senderAvatar(l10n, sender, size),
        ) ??
        Text(describeContent(l10n, content));
  }

  /// Files and audio: a fixed-width row, the caption under it.
  Widget _withCaption(Widget file) {
    final caption = captionOf(message.content);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SizedBox(width: 320, child: file),
        ),
        if (caption != null && caption.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _text(caption),
          ),
      ],
    );
  }

  /// The reply quote; the source of a forward is drawn around the body.
  List<Widget> _headers(AppLocalizations l10n) {
    final headers = <Widget>[];
    final reply = message.message.replyTo;
    if (reply is td.MessageReplyToMessage) {
      headers.add(
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SelectionContainer.disabled(
              child: _replyHeader(l10n, reply),
            ),
          ),
        ),
      );
    }
    return headers;
  }

  Widget _replyHeader(AppLocalizations l10n, td.MessageReplyToMessage reply) {
    final original = reply.messageId == 0
        ? null
        : store.message(reply.chatId, reply.messageId);
    final quote = reply.quote?.text.text;
    String author;
    String text;
    td.MessageContent? content;
    if (original != null) {
      author = nameOfSender(l10n, store, original.sender);
      content = original.content;
      text = describeContent(l10n, original.content);
    } else if (reply.origin != null) {
      // A reply to a message of another chat carries its own copy.
      author = forwardOriginName(l10n, store, reply.origin!);
      content = reply.content;
      text = content == null ? '' : describeContent(l10n, content);
    } else if (store.isMissing(message.chatId, message.id)) {
      author = l10n.deletedMessage;
      text = '';
    } else {
      // Asked for after the frame, so the build stays free of requests.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => actions.onNeedReplied(message),
      );
      author = l10n.loadingMessage;
      text = '';
    }
    if (quote != null && quote.isNotEmpty) text = quote;
    final jump = actions.onJump;
    // Only an original of this chat that still exists can be scrolled to.
    final canJump =
        jump != null &&
        reply.chatId == message.chatId &&
        reply.messageId != 0 &&
        !store.isMissing(message.chatId, message.id);
    return ReplyHeader(
      author: author,
      text: text,
      thumbnail: content == null ? null : mediaThumbnail(content),
      onTap: canJump ? () => jump(reply.messageId) : null,
    );
  }

  /// The caption of a row's media and whether it goes above the media.
  static ({td.FormattedText text, bool above, ConversationMessage of})?
  _caption(MessageRow row) {
    for (final m in row.messages) {
      final caption = captionOf(m.content);
      if (caption == null || caption.text.isEmpty) continue;
      final above = switch (m.content) {
        td.MessagePhoto(:final showCaptionAboveMedia) ||
        td.MessageVideo(:final showCaptionAboveMedia) ||
        td.MessageAnimation(
          :final showCaptionAboveMedia,
        ) => showCaptionAboveMedia,
        _ => false,
      };
      return (text: caption, above: above, of: m);
    }
    return null;
  }
}

/// The media of a row and the width it takes.
typedef _Visual = ({Widget widget, double width});

_Visual? _visualFor(MessageRow row, MessageRowActions actions) {
  final onOpen = actions.onOpen;
  if (row.messages.length > 1) return _album(row, actions);
  final message = row.primary;
  final view = _viewer(message, actions);
  final Widget media;
  final Size size;
  switch (message.content) {
    case td.MessagePhoto(:final photo):
      final largest = photo.sizes.isEmpty ? null : photo.sizes.last;
      size = fitMedia(largest?.width ?? 0, largest?.height ?? 0);
      media = PhotoContent(photo: photo, size: size, onTap: view);
    case td.MessageVideo(:final video):
      size = fitMedia(video.width, video.height);
      media = VideoContent(video: video, size: size, onTap: view);
    case td.MessageAnimation(:final animation):
      size = fitMedia(animation.width, animation.height);
      media = AnimationContent(animation: animation, size: size, onTap: view);
    default:
      return null;
  }
  return (
    // The upload controls stay above a spoiler or timer cover.
    widget: withUploadOverlay(
      message: message,
      child: _concealIfNeeded(message, size, media, onOpen),
      onCancel: actions.onCancelSend,
      onRetry: actions.onRetrySend,
    ),
    width: size.width,
  );
}

/// [media] behind a tap-to-show cover when [message] asks for one.
Widget _concealIfNeeded(
  ConversationMessage message,
  Size size,
  Widget media,
  void Function(ConversationMessage message)? onOpen,
) {
  final reason = concealmentOf(message);
  if (reason == null) return media;
  return Concealed(
    reason: reason,
    minithumbnail: minithumbnailOf(message.content),
    size: size,
    onReveal: reason == Concealment.secret && onOpen != null
        ? () => onOpen(message)
        : null,
    child: media,
  );
}

/// Photos and videos sent together, in justified rows: every row is as
/// wide as the bubble and as tall as its pictures' proportions allow.
VoidCallback? _viewer(ConversationMessage message, MessageRowActions actions) {
  final view = actions.onViewMedia;
  return view == null ? null : () => view(message);
}

_Visual _album(MessageRow row, MessageRowActions actions) {
  final onOpen = actions.onOpen;
  const width = kMaxMediaWidth;
  const gap = 2.0;
  final items = row.messages;
  double ratio(ConversationMessage m) {
    final (w, h) = switch (m.content) {
      td.MessagePhoto(:final photo) when photo.sizes.isNotEmpty => (
        photo.sizes.last.width,
        photo.sizes.last.height,
      ),
      td.MessageVideo(:final video) => (video.width, video.height),
      _ => (1, 1),
    };
    if (w <= 0 || h <= 0) return 1;
    return (w / h).clamp(0.5, 2.5).toDouble();
  }

  final counts = albumRows(items.length, ratio(items.first));
  final rows = <Widget>[];
  var index = 0;
  for (final count in counts) {
    final cells = items.sublist(index, index + count);
    index += count;
    final ratios = [for (final m in cells) ratio(m)];
    final sum = ratios.fold<double>(0, (a, b) => a + b);
    final height = math.min<double>(
      (width - gap * (count - 1)) / sum,
      count == 1 ? kMaxMediaHeight : 220,
    );
    rows.add(
      Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(
              flex: (ratios[i] * 1000).round(),
              child: () {
                final size = Size(
                  (width - gap * (count - 1)) * ratios[i] / sum,
                  height,
                );
                return withUploadOverlay(
                  message: cells[i],
                  child: _concealIfNeeded(
                    cells[i],
                    size,
                    _albumCell(cells[i], size, _viewer(cells[i], actions)),
                    onOpen,
                  ),
                  onCancel: actions.onCancelSend,
                  onRetry: actions.onRetrySend,
                );
              }(),
            ),
          ],
        ],
      ),
    );
  }
  return (
    widget: SizedBox(
      width: width,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            rows[i],
          ],
        ],
      ),
    ),
    width: width,
  );
}

Widget _albumCell(
  ConversationMessage message,
  Size size,
  VoidCallback? onTap,
) => switch (message.content) {
  td.MessagePhoto(:final photo) => PhotoContent(
    photo: photo,
    size: size,
    onTap: onTap,
  ),
  td.MessageVideo(:final video) => VideoContent(
    video: video,
    size: size,
    onTap: onTap,
  ),
  _ => SizedBox.fromSize(size: size),
};

/// How many pictures go in each album row, top to bottom. A wide first
/// picture of three gets a row of its own.
List<int> albumRows(int count, double firstRatio) => switch (count) {
  <= 0 => const [],
  1 => const [1],
  2 => const [2],
  3 => firstRatio > 1.2 ? const [1, 2] : const [3],
  4 => const [2, 2],
  5 => const [2, 3],
  6 => const [3, 3],
  7 => const [2, 2, 3],
  8 => const [2, 3, 3],
  9 => const [3, 3, 3],
  _ => [...albumRows(count - 3, firstRatio), 3],
};

final _emojiOnly = RegExp(
  // The lint checks the pattern without the unicode flag it is built with.
  // ignore: valid_regexps
  r'^(?:\p{Extended_Pictographic}|[\u{1F1E6}-\u{1F1FF}]|[\u{1F3FB}-\u{1F3FF}]'
  r'|\u200d|\ufe0f|\u20e3|\s)+$',
  unicode: true,
);

/// Whether [text] is one to three emoji and nothing else; Telegram draws
/// those large, without a bubble.
bool isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty || !_emojiOnly.hasMatch(trimmed)) return false;
  return trimmed.replaceAll(RegExp(r'\s'), '').characters.length <= 3;
}

/// A sticker message. A click opens its set, as in the official client,
/// so a set seen in any chat can be added from there. (While selecting,
/// the row absorbs the click and selects itself, like everywhere else.)
class _TimelineSticker extends StatelessWidget {
  const _TimelineSticker(this.sticker);

  final td.Sticker sticker;

  @override
  Widget build(BuildContext context) {
    final content = StickerContent(sticker: sticker);
    if (sticker.setId == 0) return content;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(showStickerSetSheetById(context, sticker.setId)),
        child: content,
      ),
    );
  }
}

/// An animated emoji or a dice, drawn at the size of a big emoji rather
/// than a sticker.
class _LargeSticker extends StatelessWidget {
  const _LargeSticker(this.sticker);

  final td.Sticker sticker;

  static const double side = 120;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: side,
    child: FittedBox(child: StickerContent(sticker: sticker)),
  );
}

class _BigEmoji extends StatelessWidget {
  const _BigEmoji(this.emoji);

  final String emoji;

  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: const TextStyle(fontSize: 44, height: 1.15));
}

class _LinkPreview extends StatelessWidget {
  const _LinkPreview(this.preview);

  final td.LinkPreview preview;

  @override
  Widget build(BuildContext context) {
    final photo = switch (preview.type) {
      td.LinkPreviewTypePhoto(:final photo) => photo,
      td.LinkPreviewTypeArticle(:final photo) => photo,
      td.LinkPreviewTypeVideo(:final cover) => cover,
      _ => null,
    };
    final large =
        preview.showLargeMedia || preview.type is td.LinkPreviewTypePhoto;
    Widget? image;
    if (photo != null && photo.sizes.isNotEmpty) {
      final size = photo.sizes.last;
      final side = large ? 300.0 : 52.0;
      image = large
          ? AspectRatio(
              aspectRatio: size.height == 0 ? 1.6 : size.width / size.height,
              child: TdImage(
                file: photoSizeFor(photo, side * 2)?.photo,
                minithumbnail: photo.minithumbnail,
                kind: MediaDownloadKind.photos,
              ),
            )
          : TdImage(
              file: photo.sizes.first.photo,
              minithumbnail: photo.minithumbnail,
            );
    }
    return LinkPreviewCard(
      siteName: preview.siteName,
      title: preview.title,
      description: preview.description.text,
      image: image,
      largeImage: large,
      onTap: () => openLinkFrom(context, preview.url),
    );
  }
}

/// The small picture of a photo, video or GIF, for a reply's quote and
/// the pinned bar; null for other content.
Widget? mediaThumbnail(td.MessageContent content) => switch (content) {
  td.MessagePhoto(:final photo) => TdImage(
    thumbnail: photo.sizes.isEmpty ? null : photo.sizes.first.photo,
    minithumbnail: photo.minithumbnail,
  ),
  td.MessageVideo(:final video) => TdImage(
    thumbnail: video.thumbnail?.file,
    minithumbnail: video.minithumbnail,
  ),
  td.MessageAnimation(:final animation) => TdImage(
    thumbnail: animation.thumbnail?.file,
    minithumbnail: animation.minithumbnail,
  ),
  _ => null,
};
