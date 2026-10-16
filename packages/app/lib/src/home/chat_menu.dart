import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';

/// The context menu of a chat-list row, laid out like the official
/// client's: pin, mute, read state; archive; then clearing and leaving.
///
/// [myId] marks Saved Messages, which can't be muted, archived or left.
/// A failed request calls [onFailed].
Future<void> showChatMenu(
  BuildContext context, {
  required ChatListEntry chat,
  required ChatListLocation list,
  required ChatListController chats,
  required int myId,
  required Offset position,
  required VoidCallback onFailed,
}) {
  final l10n = AppLocalizations.of(context);
  final saved =
      myId != 0 && chat.type == ChatType.private && chat.peerId == myId;
  final service =
      chat.type == ChatType.private &&
      chat.peerId == PresenceController.serviceUserId;
  final pinned = chat.isPinnedIn(list);

  void run(Future<void> Function() request) {
    unawaited(request().catchError((Object _) => onFailed()));
  }

  void mute(Duration duration) => run(() => chats.setMuted(chat.id, duration));

  Future<void> confirm({
    required String title,
    required String confirmLabel,
    required Future<void> Function(bool option) action,
    String? message,
    String? option,
  }) async {
    final checked = await showMgConfirm(
      context,
      title: title,
      message: message,
      option: option,
      confirmLabel: confirmLabel,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (checked != null) run(() => action(checked));
  }

  // In a private chat the history can go for the other side too.
  final otherSide = chat.type == ChatType.private && chat.canDeleteForAll
      ? chat.title
      : null;

  final clear = MgMenuItem(
    label: l10n.menuClearHistory,
    icon: MgIcons.clear,
    onSelected: () => unawaited(
      confirm(
        title: l10n.clearHistoryTitle,
        message: l10n.clearHistoryMessage(chat.title),
        option: otherSide == null ? null : l10n.clearAlsoFor(otherSide),
        confirmLabel: l10n.clear,
        action: (all) => chats.clearHistory(chat.id, forEveryone: all),
      ),
    ),
  );

  final MgMenuItem? remove = switch (chat.type) {
    _ when saved => null,
    ChatType.private || ChatType.secret => MgMenuItem(
      label: l10n.menuDeleteChat,
      icon: MgIcons.trash,
      destructive: true,
      onSelected: () => unawaited(
        confirm(
          title: l10n.deleteChatTitle,
          message: l10n.deleteChatMessage(chat.title),
          option: otherSide == null ? null : l10n.deleteAlsoFor(otherSide),
          confirmLabel: l10n.menuDelete,
          action: (all) => chats.deleteChat(chat.id, forEveryone: all),
        ),
      ),
    ),
    ChatType.basicGroup => MgMenuItem(
      label: l10n.menuDeleteAndLeave,
      icon: MgIcons.leave,
      destructive: true,
      onSelected: () => unawaited(
        confirm(
          title: l10n.deleteAndLeaveTitle(chat.title),
          confirmLabel: l10n.menuDeleteAndLeave,
          action: (_) => chats.deleteChat(chat.id),
        ),
      ),
    ),
    ChatType.supergroup || ChatType.channel => MgMenuItem(
      label: chat.type == ChatType.channel
          ? l10n.menuLeaveChannel
          : l10n.menuLeaveGroup,
      icon: MgIcons.leave,
      destructive: true,
      onSelected: () => unawaited(
        confirm(
          title: l10n.leaveTitle(chat.title),
          confirmLabel: l10n.leave,
          action: (_) => chats.deleteChat(chat.id),
        ),
      ),
    ),
  };

  // A public group or a channel can't be cleared, only left.
  final canClear =
      chat.type.isPrivate ||
      chat.type == ChatType.basicGroup ||
      (chat.type == ChatType.supergroup && chat.canDeleteOnlyForSelf);

  return showMgMenu(
    context,
    position: position,
    items: [
      MgMenuItem(
        label: pinned ? l10n.menuUnpin : l10n.menuPin,
        icon: pinned ? MgIcons.unpin : MgIcons.pinOutline,
        onSelected: () => run(() => chats.setPinned(chat.id, list, !pinned)),
      ),
      if (!saved)
        chat.isMuted
            ? MgMenuItem(
                label: l10n.menuUnmute,
                icon: MgIcons.volume,
                onSelected: () => run(() => chats.setMuted(chat.id, null)),
              )
            : MgMenuItem(
                label: l10n.menuMute,
                icon: MgIcons.muted,
                submenu: [
                  MgMenuItem(
                    label: l10n.muteFor1Hour,
                    onSelected: () => mute(const Duration(hours: 1)),
                  ),
                  MgMenuItem(
                    label: l10n.muteFor8Hours,
                    onSelected: () => mute(const Duration(hours: 8)),
                  ),
                  MgMenuItem(
                    label: l10n.muteFor3Days,
                    onSelected: () => mute(const Duration(days: 3)),
                  ),
                  const MgMenuItem.divider(),
                  MgMenuItem(
                    label: l10n.muteForever,
                    onSelected: () => mute(ChatListController.muteForever),
                  ),
                ],
              ),
      if (chat.type != ChatType.secret)
        chat.isUnread || chat.unreadMentionCount > 0
            ? MgMenuItem(
                label: l10n.menuMarkRead,
                icon: MgIcons.readTicks,
                onSelected: () => run(() => chats.markAsRead(chat.id)),
              )
            : MgMenuItem(
                label: l10n.menuMarkUnread,
                icon: MgIcons.markUnread,
                onSelected: () => run(() => chats.markAsUnread(chat.id)),
              ),
      if (!saved && !service) ...[
        const MgMenuItem.divider(),
        MgMenuItem(
          label: chat.isArchived ? l10n.menuUnarchive : l10n.menuArchive,
          icon: chat.isArchived ? MgIcons.unarchive : MgIcons.archive,
          onSelected: () =>
              run(() => chats.setArchived(chat.id, !chat.isArchived)),
        ),
      ],
      if (canClear || remove != null) const MgMenuItem.divider(),
      if (canClear) clear,
      ?remove,
    ],
  );
}

/// The context menu of the archive row: read every archived chat.
Future<void> showArchiveMenu(
  BuildContext context, {
  required ChatListController chats,
  required Offset position,
  required VoidCallback onFailed,
  required VoidCallback onHide,
}) {
  final l10n = AppLocalizations.of(context);
  return showMgMenu(
    context,
    position: position,
    items: [
      MgMenuItem(
        label: l10n.menuHideArchive,
        icon: MgIcons.hide,
        onSelected: onHide,
      ),
      MgMenuItem(
        label: l10n.menuMarkAllRead,
        icon: MgIcons.readTicks,
        onSelected: () => unawaited(
          chats
              .markListAsRead(const ChatListLocation.archive())
              .catchError((Object _) => onFailed()),
        ),
      ),
    ],
  );
}
