import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import 'describe.dart';
import 'file_content.dart';
import 'formatted_text.dart';
import 'media_content.dart';
import 'other_content.dart';
import 'td_file.dart';

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
  });

  /// Incoming messages show the sender's name and avatar.
  final bool isGroup;
  final bool isChannel;

  /// The first message of a run from one sender: it gets the name.
  final bool startsRun;

  /// The last one: it gets the avatar.
  final bool endsRun;

  /// Outgoing messages up to this id are read by the other side.
  final int lastReadOutbox;
}

/// Callbacks of a message row.
@immutable
class MessageRowActions {
  const MessageRowActions({
    required this.onReaction,
    required this.onNeedReplied,
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
  static const double avatarSize = 36;
  static const double contentIndent = avatarSize + 10;

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

  @override
  Widget build(BuildContext buildContext) {
    final l10n = AppLocalizations.of(buildContext);
    final c = MgColors.of(buildContext);
    final message = row.primary;
    if (message.isService) {
      return ServiceMessage(
        describeService(l10n, store, message, isChannel: context.isChannel),
      );
    }
    final locale = Localizations.localeOf(buildContext).toLanguageTag();
    final meta = MessageMeta(
      time: formatMessageTime(message.date, locale),
      status: _status,
      label: message.editDate > 0 ? l10n.edited : null,
    );
    final reactions = message.message.interactionInfo?.reactions?.reactions;
    final name = nameOfSender(l10n, store, message.sender);
    return Padding(
      padding: EdgeInsets.only(top: context.startsRun ? 10 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: avatarSize,
            child: context.startsRun
                ? SenderAvatar(
                    name: name,
                    photo: store.photoOf(message.sender),
                    size: avatarSize,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (context.startsRun)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      weight: FontWeight.w600,
                      color: peerNameColor(c, store.colorOf(message.sender)),
                    ),
                  ),
                _MessageBody(row: row, store: store, actions: actions),
                if (reactions != null && reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final reaction in reactions)
                          ReactionChip(
                            emoji: _reactionEmoji(reaction.type),
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
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(padding: const EdgeInsets.only(top: 1), child: meta),
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

String _reactionEmoji(td.ReactionType type) => switch (type) {
  td.ReactionTypeEmoji(:final emoji) => emoji,
  td.ReactionTypePaid() => '⭐',
  // Custom emoji need their stickers; a sparkle stands in until then.
  _ => '✨',
};

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [..._headers(l10n), _content(context, l10n)],
    );
  }

  Widget _content(BuildContext context, AppLocalizations l10n) {
    final content = message.content;
    switch (content) {
      case td.MessageSticker(:final sticker):
        return StickerContent(sticker: sticker);
      case td.MessageAnimatedEmoji(:final animatedEmoji, :final emoji):
        final sticker = animatedEmoji.sticker;
        if (sticker == null) return _BigEmoji(emoji);
        return SizedBox.square(
          dimension: 120,
          child: FittedBox(child: StickerContent(sticker: sticker)),
        );
      case td.MessageDice(:final emoji):
        return _BigEmoji(emoji);
      case td.MessageVideoNote(:final videoNote):
        return VideoNoteContent(
          chatId: message.chatId,
          messageId: message.id,
          videoNote: videoNote,
        );
      case td.MessageText(:final text, linkPreview: null)
          when text.entities.isEmpty && isEmojiOnly(text.text):
        return _BigEmoji(text.text);
      case td.MessageText(:final text, :final linkPreview):
        if (linkPreview == null) return FormattedTextView(text: text);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!linkPreview.showAboveText) FormattedTextView(text: text),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _LinkPreview(linkPreview),
            ),
            if (linkPreview.showAboveText)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FormattedTextView(text: text),
              ),
          ],
        );
      case td.MessageDocument(:final document):
        return _withCaption(DocumentContent(document: document));
      case td.MessageVoiceNote(:final voiceNote):
        return _withCaption(
          VoiceNoteContent(
            chatId: message.chatId,
            messageId: message.id,
            voiceNote: voiceNote,
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
    final visual = _visualFor(row);
    if (visual != null) {
      final caption = _caption(row);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: visual.widget,
            ),
          ),
          if (caption != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: math.max(visual.width, 420),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FormattedTextView(text: caption),
              ),
            ),
        ],
      );
    }
    return otherContent(context, content) ??
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
            child: FormattedTextView(text: caption),
          ),
      ],
    );
  }

  /// "Forwarded from" and the reply quote.
  List<Widget> _headers(AppLocalizations l10n) {
    final headers = <Widget>[];
    final forward = message.message.forwardInfo;
    if (forward != null) {
      headers.add(
        ForwardHeader(
          l10n.forwardedFrom(forwardOriginName(l10n, store, forward.origin)),
        ),
      );
    }
    final reply = message.message.replyTo;
    if (reply is td.MessageReplyToMessage) {
      headers.add(
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: _replyHeader(l10n, reply),
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
    return ReplyHeader(
      author: author,
      text: text,
      thumbnail: content == null ? null : _replyThumbnail(content),
    );
  }

  Widget? _replyThumbnail(td.MessageContent content) => switch (content) {
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

  static td.FormattedText? _caption(MessageRow row) {
    for (final m in row.messages) {
      final caption = captionOf(m.content);
      if (caption != null && caption.text.isNotEmpty) return caption;
    }
    return null;
  }
}

/// The media of a row and the width it takes.
typedef _Visual = ({Widget widget, double width});

_Visual? _visualFor(MessageRow row) {
  if (row.messages.length > 1) return _album(row);
  final content = row.primary.content;
  switch (content) {
    case td.MessagePhoto(:final photo):
      final largest = photo.sizes.isEmpty ? null : photo.sizes.last;
      final size = fitMedia(largest?.width ?? 0, largest?.height ?? 0);
      return (
        widget: PhotoContent(photo: photo, size: size),
        width: size.width,
      );
    case td.MessageVideo(:final video):
      final size = fitMedia(video.width, video.height);
      return (
        widget: VideoContent(video: video, size: size),
        width: size.width,
      );
    case td.MessageAnimation(:final animation):
      final size = fitMedia(animation.width, animation.height);
      return (
        widget: AnimationContent(animation: animation, size: size),
        width: size.width,
      );
    default:
      return null;
  }
}

/// Photos and videos sent together, in justified rows: every row is as
/// wide as the bubble and as tall as its pictures' proportions allow.
_Visual _album(MessageRow row) {
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
              child: _albumCell(
                cells[i],
                Size((width - gap * (count - 1)) * ratios[i] / sum, height),
              ),
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

Widget _albumCell(ConversationMessage message, Size size) =>
    switch (message.content) {
      td.MessagePhoto(:final photo) => PhotoContent(photo: photo, size: size),
      td.MessageVideo(:final video) => VideoContent(video: video, size: size),
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
      onTap: () => openLink(preview.url),
    );
  }
}
