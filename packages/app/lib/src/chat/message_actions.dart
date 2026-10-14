import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'message_tile.dart';

/// What the chat does for the commands of the message menu.
final class MessageMenuHandlers {
  const MessageMenuHandlers({
    required this.onReply,
    required this.onEdit,
    required this.onForward,
  });

  final void Function(ConversationMessage message) onReply;
  final void Function(ConversationMessage message) onEdit;
  final void Function(List<ConversationMessage> messages) onForward;
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
  String? peerName,
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
          .quickReactions(chatId, row.primary.id)
          .catchError((Object _) => const <String>[]),
    ]);
    properties = results[0] as td.MessageProperties;
    reactions = results[1] as List<String>;
  } on Object {
    // A message that is still being sent has no properties yet; only
    // copying makes sense then.
  }
  if (!context.mounted) return;

  // Reactions go where the tile draws them: on the row's last message.
  final reacted = row.primary;
  final chosen = <String>{
    for (final reaction
        in reacted.message.interactionInfo?.reactions?.reactions ??
            const <td.MessageReaction>[])
      if (reaction.isChosen)
        if (reaction.type case td.ReactionTypeEmoji(:final emoji)) emoji,
  };
  final protected =
      properties != null &&
      (properties.hasProtectedContentByCurrentUser ||
          properties.hasProtectedContentByOtherUser);
  final canDelete =
      properties != null &&
      (properties.canBeDeletedOnlyForSelf ||
          properties.canBeDeletedForAllUsers);

  final items = <MgMenuItem>[
    if (properties?.canBeReplied ?? false)
      MgMenuItem(
        label: l10n.menuReply,
        onSelected: () => handlers.onReply(target),
      ),
    if ((properties?.canBeEdited ?? false) && _isEditable(target))
      MgMenuItem(
        label: l10n.menuEdit,
        onSelected: () => handlers.onEdit(target),
      ),
    if (target.text.isNotEmpty && !protected)
      MgMenuItem(
        label: l10n.menuCopyText,
        onSelected: () =>
            unawaited(Clipboard.setData(ClipboardData(text: target.text))),
      ),
    if (properties?.canGetLink ?? false)
      MgMenuItem(
        label: l10n.menuCopyLink,
        onSelected: () => unawaited(
          conversations
              .linkOf(chatId, target.id)
              .then((link) => Clipboard.setData(ClipboardData(text: link)))
              .catchError((Object _) {}),
        ),
      ),
    if (properties?.canBeForwarded ?? false)
      MgMenuItem(
        label: l10n.menuForward,
        onSelected: () => handlers.onForward(row.messages),
      ),
    if (canDelete)
      MgMenuItem(
        label: l10n.menuDelete,
        destructive: true,
        onSelected: () => unawaited(
          _confirmDelete(
            context,
            conversations: conversations,
            messages: row.messages,
            properties: properties!,
            peerName: peerName,
          ),
        ),
      ),
  ];
  if (items.isEmpty && reactions.isEmpty) return;

  await showMgMenu(
    context,
    position: position,
    items: items,
    header: reactions.isEmpty
        ? null
        : ReactionBar(
            reactions: reactions,
            chosen: chosen,
            onPick: (emoji) => unawaited(
              conversations
                  .toggleReaction(
                    chatId,
                    reacted.id,
                    td.ReactionTypeEmoji(emoji: emoji),
                    chosen: chosen.contains(emoji),
                  )
                  .catchError((Object _) {}),
            ),
          ),
  );
}

/// Text messages and media with a caption; stickers, polls and the like
/// have nothing to edit here.
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

Future<void> _confirmDelete(
  BuildContext context, {
  required ConversationController conversations,
  required List<ConversationMessage> messages,
  required td.MessageProperties properties,
  required String? peerName,
}) async {
  final l10n = AppLocalizations.of(context);
  final count = messages.length;
  // In a channel, or for an outgoing message in a basic group, only
  // deleting for everyone may be possible; there is nothing to choose.
  final choice =
      properties.canBeDeletedForAllUsers && properties.canBeDeletedOnlyForSelf;
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
  if (checked == null) return;
  final revoke = choice ? checked : properties.canBeDeletedForAllUsers;
  await conversations
      .deleteMessages(messages.first.chatId, [
        for (final message in messages) message.id,
      ], revoke: revoke)
      .catchError((Object _) {});
}
