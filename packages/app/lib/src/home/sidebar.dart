import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../downloads/downloads_bar.dart';
import '../folders/folder_icons.dart';
import '../privacy/ghost_mode_capsule.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'format.dart';
import 'workspace.dart';

/// The floating glass island: the folder rail, search and the chat list.
class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({
    super.key,
    this.onSettings,
    this.onPrivacy,
    this.onNewMessage,
  });

  /// The settings button at the rail's bottom.
  final VoidCallback? onSettings;

  /// The ghost in the title bar, shown while a privacy extra is on.
  final VoidCallback? onPrivacy;

  /// The compose button in the title bar.
  final VoidCallback? onNewMessage;

  @override
  ConsumerState<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends ConsumerState<Sidebar> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _loadMore(ChatListLocation list) {
    final chatLists = ref.read(telegramSessionProvider).requireValue.chatLists;
    if (!chatLists.hasMore(list)) return;
    // Called during build: the request starts after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      chatLists.loadMore(list).catchError((Object _) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(selectedChatListProvider);
    final folders = ref.watch(chatFoldersProvider).value ?? const [];
    final chats = ref.watch(chatListProvider(list)).value ?? const [];
    final query = _search.text.trim().toLowerCase();
    final shown = query.isEmpty
        ? chats
        : [
            for (final chat in chats)
              if (chat.title.toLowerCase().contains(query)) chat,
          ];
    final select = ref.read(selectedChatListProvider.notifier).select;

    return SidebarIsland(
      rail: FolderRail(
        topFill: const WindowDragArea(),
        trailing: [
          MgIconButton(
            icon: MgIcons.settings,
            tooltip: l10n.settings,
            onPressed: widget.onSettings,
          ),
        ],
        children: [
          FolderRailItem(
            icon: folderIcon('All'),
            label: l10n.folderAll,
            selected: list.isMain,
            onTap: () => select(const ChatListLocation.main()),
          ),
          for (final folder in folders)
            FolderRailItem(
              icon: folderIcon(folder.iconName),
              label: folder.title,
              selected: list == ChatListLocation.folder(folder.id),
              onTap: () => select(ChatListLocation.folder(folder.id)),
            ),
        ],
      ),
      search: MgSearchField(hintText: l10n.searchHint, controller: _search),
      actions: [
        GhostModeCapsule(onTap: widget.onPrivacy),
        MgIconButton(
          icon: MgIcons.compose,
          tooltip: l10n.newMessage,
          onPressed: widget.onNewMessage,
        ),
      ],
      banner: const DownloadsBar(),
      body: shown.isEmpty
          ? Center(
              child: Text(
                query.isEmpty ? l10n.noChats : l10n.nothingFound,
                style: TextStyle(color: c.fg2),
              ),
            )
          : _ChatList(
              chats: shown,
              // TDLib sends the list a page at a time; the next page is
              // asked for as the end comes on screen. Search filters only
              // what is loaded, so it doesn't page.
              onNearEnd: query.isEmpty ? () => _loadMore(list) : null,
            ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.chats, this.onNearEnd});

  final List<ChatListEntry> chats;

  /// Called while one of the last rows is built.
  final VoidCallback? onNearEnd;

  /// How many rows before the end the next page is asked for.
  static const _preload = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unread = NumberFormat.compact(locale: locale);
    final workspace = ref.watch(workspaceControllerProvider);
    return ValueListenableBuilder(
      valueListenable: workspace,
      builder: (context, layout, _) {
        final selected = layout.focusedChat;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          itemCount: chats.length,
          itemBuilder: (context, i) {
            final chat = chats[i];
            final last = chat.lastMessage;
            if (i >= chats.length - _preload) onNearEnd?.call();
            return ChatListTile(
              key: ValueKey(chat.id),
              title: chat.title,
              avatar: PeerAvatar.chat(
                name: chat.title,
                size: ChatListTile.avatarSize,
                photo: chat.photo,
              ),
              subtitle: formatPreview(l10n, last),
              time: last == null ? '' : formatChatTime(last.date, locale),
              unread: chat.unreadCount,
              unreadLabel: unread.format(chat.unreadCount),
              selected: chat.id == selected,
              onTap: () => workspace.open(chat.id, target: _clickTarget()),
            );
          },
        );
      },
    );
  }
}

/// Where a click on a chat opens it, as in the palette: ⌘-click (Ctrl-click
/// off macOS) beside the current chat, ⌥-click in a new tab.
OpenTarget _clickTarget() {
  final keys = HardwareKeyboard.instance;
  final primary = usesCommandKey ? keys.isMetaPressed : keys.isControlPressed;
  if (primary) return OpenTarget.split;
  if (keys.isAltPressed) return OpenTarget.newTab;
  return OpenTarget.current;
}
