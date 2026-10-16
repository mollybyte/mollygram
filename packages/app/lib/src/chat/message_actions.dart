import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../home/format.dart';
import 'custom_emoji.dart';
import 'describe.dart';
import 'formatted_text.dart';
import 'message_tile.dart';
import 'report.dart';
import 'save_file.dart';

/// What the chat does for the commands of the message menu.
final class MessageMenuHandlers {
  const MessageMenuHandlers({
    required this.onReply,
    required this.onEdit,
    required this.onForward,
    this.recentChats,
    this.onForwardTo,
    this.onSelect,
    required this.onQuote,
    this.onEditHistory,
  });

  final void Function(ConversationMessage message) onReply;

  /// Replies to [message] quoting [quote] of its text.
  final void Function(ConversationMessage message, QuoteSelection quote)
  onQuote;
  final void Function(ConversationMessage message) onEdit;
  final void Function(List<ConversationMessage> messages) onForward;

  /// The chats offered right in the menu under Forward, most recent first;
  /// without them Forward opens the picker at once.
  final List<ChatListEntry> Function()? recentChats;

  /// Forwards [messages] to [chatId] without asking again.
  final void Function(List<ConversationMessage> messages, int chatId)?
  onForwardTo;

  /// Starts selecting messages with this row, or adds it to the selection;
  /// a list without selection, such as a comments thread, leaves it out.
  final void Function(MessageRow row)? onSelect;

  /// Shows the earlier versions of an edited message, kept in the privacy
  /// store; absent when the edit history is not kept.
  final void Function(ConversationMessage message)? onEditHistory;
}

/// The message a command like Reply or Edit acts on in [row]: the one with
/// the caption in an album, otherwise the row's own message.
ConversationMessage targetOf(MessageRow row) {
  for (final message in row.messages) {
    if (message.text.isNotEmpty) return message;
  }
  return row.primary;
}

/// The context menu of a message: quick reactions on top, then Reply,
/// Edit, Copy text, Copy link, Forward and Delete, each only when TDLib
/// allows it for this message. [peerName] is the other person in a
/// private chat, named in the delete dialog.
Future<void> showMessageMenu(
  BuildContext context, {
  required ConversationController conversations,
  required MessageRow row,
  required Offset position,
  required MessageMenuHandlers handlers,
  required bool Function() isShown,
  String? peerName,
  ({ConversationMessage message, QuoteSelection quote})? quote,
}) async {
  final l10n = AppLocalizations.of(context);
  final target = targetOf(row);
  final chatId = target.chatId;

  td.MessageProperties? properties;
  var reactions = const <String>[];
  try {
    final results = await Future.wait<Object>([
      conversations.propertiesOf(chatId, target.id),
      conversations
          .quickReactionTypes(chatId, row.primary.id)
          .catchError((Object _) => const <td.ReactionType>[]),
    ]);
    properties = results[0] as td.MessageProperties;
    reactions = [
      for (final type in results[1] as List<td.ReactionType>) reactionKey(type),
    ];
  } on Object {
    // A message that is still being sent has no properties yet; only
    // copying makes sense then.
  }
  // Who saw the message and who reacted, when TDLib can tell.
  final reacted = row.primary;
  final reactionsInfo = reacted.message.interactionInfo?.reactions;
  final info = await _MessageInfo.load(
    conversations,
    reacted,
    viewers: properties?.canGetViewers ?? false,
    reactions:
        reactionsInfo != null &&
        reactionsInfo.reactions.isNotEmpty &&
        reactionsInfo.canGetAddedReactions,
    readDate: (properties?.canGetReadDate ?? false) && reacted.isOutgoing,
  );
  // The user may have moved to another chat meanwhile.
  if (!context.mounted || !isShown()) return;

  // Reactions go where the tile draws them: on the row's last message.
  final chosen = <String>{
    for (final reaction
        in reacted.message.interactionInfo?.reactions?.reactions ??
            const <td.MessageReaction>[])
      if (reaction.isChosen) reactionKey(reaction.type),
  };
  // Without properties, the message's own flag still says whether it may
  // leave the app.
  final protected = properties == null
      ? !target.message.canBeSaved
      : properties.hasProtectedContentByCurrentUser ||
            properties.hasProtectedContentByOtherUser;
  final canDelete =
      properties != null &&
      (properties.canBeDeletedOnlyForSelf ||
          properties.canBeDeletedForAllUsers);
  final savable = protected ? null : savableFileOf(target.message);
  final savedPath = savable == null ? null : downloadedPath(savable.file);

  final items = <MgMenuItem>[
    if (properties?.canBeReplied ?? false)
      MgMenuItem(
        label: l10n.menuReply,
        icon: MgIcons.reply,
        onSelected: () => handlers.onReply(target),
      ),
    // Part of this row's text is selected: it can be quoted.
    if ((properties?.canBeReplied ?? false) &&
        quote != null &&
        row.messages.any((m) => m.id == quote.message.id))
      MgMenuItem(
        label: l10n.menuQuote,
        icon: MgIcons.quote,
        onSelected: () => handlers.onQuote(quote.message, quote.quote),
      ),
    if ((properties?.canBeEdited ?? false) && _isEditable(target))
      MgMenuItem(
        label: l10n.menuEdit,
        icon: MgIcons.edit,
        onSelected: () => handlers.onEdit(target),
      ),
    if (target.editDate > 0 && !target.isDeleted)
      if (handlers.onEditHistory case final onEditHistory?)
        MgMenuItem(
          label: l10n.menuEditHistory,
          icon: MgIcons.recent,
          onSelected: () => onEditHistory(target),
        ),
    if ((properties?.canBeEdited ?? false) && _isOpenPoll(target))
      MgMenuItem(
        label: l10n.menuStopPoll,
        icon: MgIcons.close,
        onSelected: () => unawaited(
          _confirmStopPoll(
            context,
            conversations: conversations,
            message: target,
            isShown: isShown,
          ),
        ),
      ),
    // Groups as in Telegram's menu; empty groups leave no line.
    const MgMenuItem.divider(),
    if (target.text.isNotEmpty && !protected)
      MgMenuItem(
        label: l10n.menuCopyText,
        icon: MgIcons.copy,
        onSelected: () =>
            unawaited(Clipboard.setData(ClipboardData(text: target.text))),
      ),
    if (properties?.canGetLink ?? false)
      MgMenuItem(
        label: l10n.menuCopyLink,
        icon: MgIcons.link,
        onSelected: () => unawaited(
          conversations
              .linkOf(chatId, target.id)
              .then((link) => Clipboard.setData(ClipboardData(text: link)))
              .catchError((Object _) {}),
        ),
      ),
    if (savable != null) ...[
      MgMenuItem(
        label: l10n.menuSaveAs,
        icon: MgIcons.download,
        onSelected: () => unawaited(
          saveMessageFile(
            context,
            file: savable.file,
            name: savable.name,
            chatId: chatId,
            messageId: target.id,
            toDownloads: false,
            isShown: isShown,
          ),
        ),
      ),
      MgMenuItem(
        label: l10n.menuSaveToDownloads,
        icon: MgIcons.downloadAll,
        onSelected: () => unawaited(
          saveMessageFile(
            context,
            file: savable.file,
            name: savable.name,
            chatId: chatId,
            messageId: target.id,
            toDownloads: true,
            isShown: isShown,
          ),
        ),
      ),
      if (savedPath != null && Platform.isMacOS)
        MgMenuItem(
          label: l10n.menuQuickLook,
          icon: MgIcons.views,
          onSelected: () => unawaited(quickLookFile(savedPath)),
        ),
      if (savedPath != null)
        MgMenuItem(
          label: Platform.isMacOS
              ? l10n.menuShowInFinder
              : l10n.menuShowInFolder,
          icon: MgIcons.file,
          onSelected: () => unawaited(revealFile(savedPath)),
        ),
    ],
    const MgMenuItem.divider(),
    if (properties?.canBeForwarded ?? false)
      MgMenuItem(
        label: l10n.menuForward,
        icon: MgIcons.forward,
        onSelected: () => handlers.onForward(row.messages),
        submenu: [
          if (handlers.onForwardTo case final forwardTo?)
            for (final chat
                in handlers.recentChats?.call() ?? const <ChatListEntry>[])
              MgMenuItem(
                label: chat.title,
                leading: PeerAvatar.chat(
                  name: chat.title,
                  size: 18,
                  photo: chat.photo,
                ),
                onSelected: () => forwardTo(row.messages, chat.id),
              ),
          if (handlers.onForwardTo != null &&
              (handlers.recentChats?.call().isNotEmpty ?? false))
            const MgMenuItem.divider(),
          if (handlers.onForwardTo != null &&
              (handlers.recentChats?.call().isNotEmpty ?? false))
            MgMenuItem(
              label: l10n.menuChooseChat,
              icon: MgIcons.search,
              onSelected: () => handlers.onForward(row.messages),
            ),
        ],
      ),
    if (properties?.canBePinned ?? false)
      MgMenuItem(
        label: target.message.isPinned ? l10n.menuUnpin : l10n.menuPin,
        icon: MgIcons.pin,
        onSelected: () => unawaited(
          conversations
              .setPinned(chatId, target.id, pinned: !target.message.isPinned)
              .catchError((Object _) {}),
        ),
      ),
    if (handlers.onSelect case final onSelect?)
      MgMenuItem(
        label: l10n.menuSelect,
        icon: MgIcons.select,
        onSelected: () => onSelect(row),
      ),
    const MgMenuItem.divider(),
    if (properties?.canReportChat ?? false)
      MgMenuItem(
        label: l10n.menuReport,
        icon: MgIcons.flag,
        onSelected: () => unawaited(
          reportMessages(
            context,
            conversations: conversations,
            chatId: chatId,
            messageIds: [for (final message in row.messages) message.id],
            isShown: isShown,
          ),
        ),
      ),
    if (canDelete)
      MgMenuItem(
        label: l10n.menuDelete,
        icon: MgIcons.trash,
        destructive: true,
        onSelected: () => unawaited(
          confirmDeleteMessages(
            context,
            conversations: conversations,
            messages: row.messages,
            properties: [properties!],
            peerName: peerName,
            isShown: isShown,
          ),
        ),
      ),
  ];
  final infoRows = info.rows(
    context,
    conversations.store,
    onShow: (title, people) => unawaited(
      showMgPopover(
        context,
        position: position,
        child: MgPeopleList(title: title, people: people),
      ),
    ),
  );
  if (items.every((i) => i.isDivider) &&
      reactions.isEmpty &&
      infoRows.isEmpty) {
    return;
  }
  void pick(String key) => unawaited(
    conversations
        .toggleReaction(
          chatId,
          reacted.id,
          reactionOfKey(key),
          chosen: chosen.contains(key),
        )
        .catchError((Object _) {}),
  );

  await showMgMenu(
    context,
    position: position,
    items: items,
    header: reactions.isEmpty && infoRows.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (reactions.isNotEmpty)
                ReactionBar(
                  reactions: reactions,
                  chosen: chosen,
                  onPick: pick,
                  icons: customReactionIcon,
                  moreTooltip: l10n.moreReactions,
                  onMore: () => unawaited(
                    _showAllReactions(
                      context,
                      conversations: conversations,
                      chatId: chatId,
                      messageId: reacted.id,
                      position: position,
                      chosen: chosen,
                      onPick: pick,
                      isShown: isShown,
                    ),
                  ),
                ),
              ...infoRows,
            ],
          ),
  );
}

/// The full reaction picker in place of the menu: every emoji the user may
/// react with, in a glass grid at the same spot.
Future<void> _showAllReactions(
  BuildContext context, {
  required ConversationController conversations,
  required int chatId,
  required int messageId,
  required Offset position,
  required Set<String> chosen,
  required ValueChanged<String> onPick,
  required bool Function() isShown,
}) async {
  final List<td.ReactionType> all;
  try {
    all = await conversations.allReactionTypes(chatId, messageId);
  } on Object {
    return;
  }
  if (all.isEmpty || !context.mounted || !isShown()) return;
  await showMgPopover(
    context,
    position: position,
    child: ReactionGrid(
      reactions: [for (final type in all) reactionKey(type)],
      chosen: chosen,
      onPick: onPick,
      icons: customReactionIcon,
    ),
  );
}

/// Who saw a message, who reacted to it, and when it was read in a
/// private chat, fetched for the menu's top rows.
final class _MessageInfo {
  const _MessageInfo({
    required this.viewers,
    required this.reactions,
    required this.readDate,
  });

  final List<td.MessageViewer> viewers;
  final List<td.AddedReaction> reactions;
  final td.MessageReadDate? readDate;

  static Future<_MessageInfo> load(
    ConversationController conversations,
    ConversationMessage message, {
    required bool viewers,
    required bool reactions,
    required bool readDate,
  }) async {
    final chatId = message.chatId;
    final results = await Future.wait<Object?>([
      viewers
          ? conversations
                .viewers(chatId, message.id)
                .catchError((Object _) => const <td.MessageViewer>[])
          : Future.value(const <td.MessageViewer>[]),
      reactions
          ? conversations
                .addedReactions(chatId, message.id)
                .catchError((Object _) => const <td.AddedReaction>[])
          : Future.value(const <td.AddedReaction>[]),
      readDate
          ? conversations
                .readDate(chatId, message.id)
                .then<td.MessageReadDate?>(
                  (date) => date,
                  onError: (Object _) => null,
                )
          : Future<td.MessageReadDate?>.value(null),
    ]);
    return _MessageInfo(
      viewers: results[0]! as List<td.MessageViewer>,
      reactions: results[1]! as List<td.AddedReaction>,
      readDate: results[2] as td.MessageReadDate?,
    );
  }

  List<Widget> rows(
    BuildContext context,
    ConversationStore store, {
    required void Function(String title, List<MgPerson> people) onShow,
  }) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget avatar(MessageSenderId id) => SenderAvatar(
      name: nameOfSender(l10n, store, id),
      photo: store.photoOf(id),
      size: 24,
    );
    final rows = <Widget>[];
    switch (readDate) {
      case td.MessageReadDateRead(:final readDate):
        rows.add(
          MgMenuInfoRow(
            icon: MgIcons.readTicks,
            label: l10n.readAt(formatChatTime(readDate, locale)),
            avatars: const [],
          ),
        );
      case td.MessageReadDateUnread():
        rows.add(
          MgMenuInfoRow(
            icon: MgIcons.sent,
            label: l10n.notReadYet,
            avatars: const [],
          ),
        );
      default:
        break;
    }
    if (viewers.isNotEmpty) {
      final people = [
        for (final viewer in viewers)
          MgPerson(
            avatar: avatar(MessageSenderId.user(viewer.userId)),
            name: nameOfSender(
              l10n,
              store,
              MessageSenderId.user(viewer.userId),
            ),
            trailing: formatChatTime(viewer.viewDate, locale),
          ),
      ];
      final title = l10n.seenBy(viewers.length);
      rows.add(
        MgMenuInfoRow(
          icon: MgIcons.views,
          label: title,
          avatars: [
            for (final viewer in viewers.take(3))
              avatar(MessageSenderId.user(viewer.userId)),
          ],
          onSelected: () => onShow(title, people),
        ),
      );
    }
    if (reactions.isNotEmpty) {
      final people = [
        for (final reaction in reactions)
          MgPerson(
            avatar: avatar(MessageSenderId.of(reaction.senderId)),
            name: nameOfSender(
              l10n,
              store,
              MessageSenderId.of(reaction.senderId),
            ),
            trailing: switch (reaction.type) {
              td.ReactionTypeEmoji(:final emoji) => emoji,
              _ => null,
            },
          ),
      ];
      final title = l10n.reactedCount(reactions.length);
      rows.add(
        MgMenuInfoRow(
          icon: MgIcons.heart,
          label: title,
          avatars: [
            for (final reaction in reactions.take(3))
              avatar(MessageSenderId.of(reaction.senderId)),
          ],
          onSelected: () => onShow(title, people),
        ),
      );
    }
    return rows;
  }
}

/// Text messages and media with a caption; stickers, polls and the like
/// have nothing to edit here.
bool _isOpenPoll(ConversationMessage message) => switch (message.content) {
  td.MessagePoll(:final poll) => !poll.isClosed,
  _ => false,
};

/// Asks before closing a poll for good, then closes it.
Future<void> _confirmStopPoll(
  BuildContext context, {
  required ConversationController conversations,
  required ConversationMessage message,
  required bool Function() isShown,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showMgConfirm(
    context,
    title: l10n.stopPollTitle,
    message: l10n.stopPollMessage,
    confirmLabel: l10n.menuStopPoll,
    cancelLabel: l10n.cancel,
    destructive: true,
  );
  if (confirmed == null || !isShown()) return;
  await conversations
      .stopPoll(message.chatId, message.id)
      .catchError((Object _) {});
}

bool _isEditable(ConversationMessage message) => switch (message.content) {
  td.MessageText() ||
  td.MessagePhoto() ||
  td.MessageVideo() ||
  td.MessageAnimation() ||
  td.MessageDocument() ||
  td.MessageAudio() ||
  td.MessageVoiceNote() => true,
  _ => false,
};

/// Asks before deleting [messages], whose [properties] say how each may go:
/// the "also for" option shows only when every one of them can be deleted
/// both ways. Nothing happens when one of them can't be deleted at all.
/// Returns whether the deletion was requested.
Future<bool> confirmDeleteMessages(
  BuildContext context, {
  required ConversationController conversations,
  required List<ConversationMessage> messages,
  required List<td.MessageProperties> properties,
  required String? peerName,
  required bool Function() isShown,
}) async {
  final l10n = AppLocalizations.of(context);
  final count = messages.length;
  final forAll = properties.every((p) => p.canBeDeletedForAllUsers);
  final forSelf = properties.every((p) => p.canBeDeletedOnlyForSelf);
  if (!forAll && !forSelf) return false;
  // In a channel, or for an outgoing message in a basic group, only
  // deleting for everyone may be possible; there is nothing to choose.
  final choice = forAll && forSelf;
  final revokeOption = !choice
      ? null
      : peerName != null
      ? l10n.deleteAlsoFor(peerName)
      : l10n.deleteForEveryone;
  final checked = await showMgConfirm(
    context,
    title: count == 1
        ? l10n.deleteMessageTitle
        : l10n.deleteMessagesTitle(count),
    confirmLabel: l10n.menuDelete,
    cancelLabel: l10n.cancel,
    option: revokeOption,
    optionValue: true,
    destructive: true,
  );
  if (checked == null || !isShown()) return false;
  final revoke = choice ? checked : forAll;
  await conversations
      .deleteMessages(messages.first.chatId, [
        for (final message in messages) message.id,
      ], revoke: revoke)
      .catchError((Object _) {});
  return true;
}
