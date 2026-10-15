import 'dart:async';

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
import '../privacy/ghost_mode_capsule.dart';
import '../session/providers.dart';
import '../settings/preferences.dart';
import '../window_drag_area.dart';
import 'chat_menu.dart';
import 'chat_status.dart';
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
    _search.addListener(() {
      setState(() {});
      _searchOnServer();
    });
  }

  /// Chats found by TDLib for the current query, beyond the loaded pages.
  List<int> _foundIds = const [];
  Timer? _searchTimer;

  void _searchOnServer() {
    final text = _search.text.trim();
    _searchTimer?.cancel();
    if (text.isEmpty) {
      _foundIds = const [];
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 200), () async {
      final session = ref.read(telegramSessionProvider).value;
      if (session == null) return;
      try {
        final ids = await session.search.chats(text, limit: 50);
        if (!mounted || _search.text.trim() != text) return;
        setState(() {
          _foundIds = ids;
        });
      } on Object {
        // The loaded chats still match.
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
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
    // The archive row on the main list needs the archive loaded too, and a
    // search looks there as well.
    final archived = list.isMain || query.isNotEmpty
        ? ref.watch(chatListProvider(const ChatListLocation.archive())).value ??
              const <ChatListEntry>[]
        : const <ChatListEntry>[];
    // A search looks through every chat, whatever folder is open, as the
    // official client does: the open list first, then the rest.
    final everything = query.isEmpty
        ? const <ChatListEntry>[]
        : ref.watch(chatListProvider(const ChatListLocation.main())).value ??
              const <ChatListEntry>[];
    final store = ref.read(telegramSessionProvider).value?.chatLists.store;
    final found = query.isEmpty || store == null
        ? const <ChatListEntry>[]
        : [for (final id in _foundIds) ?store.chat(id)];
    final shown = query.isEmpty
        ? chats
        : _matching(query, [...chats, ...everything, ...archived, ...found]);
    final select = ref.read(selectedChatListProvider.notifier).select;
    final hideArchive = ref.watch(
      preferencesProvider.select((p) => p.hideArchive),
    );
    final showArchive =
        list.isMain && query.isEmpty && archived.isNotEmpty && !hideArchive;

    // In the archive the way back takes the folders' place.
    final Widget header = list.isArchive
        ? Align(
            key: const ValueKey('archive'),
            alignment: Alignment.centerLeft,
            child: _BackPill(
              label: l10n.archivedChats,
              tooltip: l10n.back,
              onTap: () => select(const ChatListLocation.main()),
            ),
          )
        : FolderSegments(
            key: const ValueKey('folders'),
            selected: list.isMain
                ? 0
                : 1 +
                      folders.indexWhere(
                        (folder) => list == ChatListLocation.folder(folder.id),
                      ),
            segments: [
              FolderSegment(
                label: l10n.folderAll,
                onTap: () => select(const ChatListLocation.main()),
              ),
              for (final folder in folders)
                FolderSegment(
                  label: folder.title,
                  onTap: () => select(ChatListLocation.folder(folder.id)),
                ),
            ],
          );

    return SidebarIsland(
      titleBarFill: const WindowDragArea(),
      search: MgSearchField(hintText: l10n.searchHint, controller: _search),
      actions: [
        GhostModeCapsule(onTap: widget.onPrivacy),
        // With the row hidden the archive is one tap away.
        if (hideArchive && (list.isArchive || archived.isNotEmpty))
          _ArchiveButton(
            tooltip: l10n.archivedChats,
            selected: list.isArchive,
            onTap: () => select(const ChatListLocation.archive()),
            onShow: () => ref
                .read(preferencesProvider.notifier)
                .update((p) => p.copyWith(hideArchive: false)),
            showLabel: l10n.menuShowArchive,
          ),
        MgIconButton(
          icon: MgIcons.settings,
          tooltip: l10n.settings,
          onPressed: widget.onSettings,
        ),
        MgIconButton(
          icon: MgIcons.compose,
          tooltip: l10n.newMessage,
          onPressed: widget.onNewMessage,
        ),
      ],
      folders: AnimatedSwitcher(
        duration: _listSwitch,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        child: header,
      ),
      banner: const DownloadsBar(),
      body: AnimatedSwitcher(
        duration: _listSwitch,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Into the archive the list slides in from the right; back out of
        // it, the main list comes back from the left.
        transitionBuilder: (child, animation) {
          final fromRight =
              child.key == const ValueKey(ChatListLocation.archive());
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(fromRight ? 0.18 : -0.18, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(list.isArchive ? list : const ChatListLocation.main()),
          child: shown.isEmpty && !showArchive
              ? Center(
                  child: Text(
                    query.isNotEmpty
                        ? l10n.nothingFound
                        : list.isArchive
                        ? l10n.noArchivedChats
                        : l10n.noChats,
                    style: TextStyle(color: c.fg2),
                  ),
                )
              : _ChatList(
                  list: list,
                  chats: shown,
                  archived: showArchive ? archived : null,
                  animate: query.isEmpty,
                  // TDLib sends the list a page at a time; the next page is
                  // asked for as the end comes on screen. Search filters
                  // only what is loaded, so it doesn't page.
                  onNearEnd: query.isEmpty ? () => _loadMore(list) : null,
                ),
        ),
      ),
    );
  }

  static const _listSwitch = Duration(milliseconds: 240);

  /// The chats whose title contains [query], each once, in list order.
  static List<ChatListEntry> _matching(
    String query,
    Iterable<ChatListEntry> chats,
  ) {
    final seen = <int>{};
    return [
      for (final chat in chats)
        if (chat.title.toLowerCase().contains(query) && seen.add(chat.id)) chat,
    ];
  }
}

/// The archive in the rail while its row is hidden; right-click brings the
/// row back.
class _ArchiveButton extends StatelessWidget {
  const _ArchiveButton({
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.onShow,
    required this.showLabel,
  });

  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onShow;
  final String showLabel;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onSecondaryTapUp: (details) => unawaited(
      showMgMenu(
        context,
        position: details.globalPosition,
        items: [MgMenuItem(label: showLabel, onSelected: onShow)],
      ),
    ),
    child: MgIconButton(
      icon: MgIcons.archive,
      tooltip: tooltip,
      selected: selected,
      onPressed: onTap,
    ),
  );
}

/// The way back from the archive: a pill with a chevron and the title.
class _BackPill extends StatefulWidget {
  const _BackPill({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_BackPill> createState() => _BackPillState();
}

class _BackPillState extends State<_BackPill> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 26,
            padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
            decoration: BoxDecoration(
              color: _hover ? c.hover : c.field,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MgIcon(MgIcons.back, size: 13, stroke: 2.2, color: c.fg),
                const SizedBox(width: 4),
                Text(
                  widget.label,
                  style: mgTextStyle(
                    c,
                    size: MgType.tab,
                    weight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How a row comes in after the list changed: [from] is the index it had
/// before (null for a chat that just joined the list).
final class _Entrance {
  const _Entrance(this.from, this.at);

  final int? from;
  final DateTime at;

  /// Only a row built right after the change animates; one that scrolls
  /// into view later just appears.
  bool get fresh =>
      DateTime.now().difference(at) < const Duration(milliseconds: 200);
}

class _ChatList extends ConsumerStatefulWidget {
  const _ChatList({
    required this.list,
    required this.chats,
    this.archived,
    this.animate = true,
    this.onNearEnd,
  });

  final ChatListLocation list;
  final List<ChatListEntry> chats;

  /// Pinned chats for the grid over the list; they are not in [chats].

  /// Archived chats, for the archive row at the top; null hides it.
  final List<ChatListEntry>? archived;

  /// Rows slide to their new places when the order changes.
  final bool animate;

  /// Called while one of the last rows is built.
  final VoidCallback? onNearEnd;

  @override
  ConsumerState<_ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<_ChatList> {
  /// How many rows before the end the next page is asked for.
  static const _preload = 20;

  var _index = <int, int>{};
  var _entrances = <int, _Entrance>{};
  int? _menuFor;
  var _notice = false;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _index = _indexOf(widget.chats);
  }

  @override
  void didUpdateWidget(_ChatList old) {
    super.didUpdateWidget(old);
    if (identical(old.chats, widget.chats) &&
        (old.archived == null) == (widget.archived == null)) {
      return;
    }
    final index = _indexOf(widget.chats);
    final now = DateTime.now();
    final shift = widget.archived != null ? 1 : 0;
    final oldShift = old.archived != null ? 1 : 0;
    _entrances = {
      if (widget.animate && old.animate && old.chats.isNotEmpty)
        for (final MapEntry(key: id, value: i) in index.entries)
          if (_index[id] case final before
              when before != i || shift != oldShift)
            id: _Entrance(
              before == null ? null : before + oldShift - shift,
              now,
            ),
    };
    _index = index;
  }

  static Map<int, int> _indexOf(List<ChatListEntry> chats) => {
    for (final (i, chat) in chats.indexed) chat.id: i,
  };

  Future<void> _openMenu(ChatListEntry chat, Offset position) async {
    final session = ref.read(telegramSessionProvider).requireValue;
    setState(() => _menuFor = chat.id);
    await showChatMenu(
      context,
      chat: chat,
      // A search result can belong to another list than the open one.
      list: _ownerList(chat),
      chats: session.chatLists,
      myId: session.presence.myId,
      position: position,
      onFailed: _failed,
    );
    if (mounted) setState(() => _menuFor = null);
  }

  ChatListLocation _ownerList(ChatListEntry chat) {
    if (chat.positionFor(widget.list) != null) return widget.list;
    const main = ChatListLocation.main();
    return chat.positionFor(main) != null
        ? main
        : const ChatListLocation.archive();
  }

  Future<void> _openArchiveMenu(Offset position) async {
    final session = ref.read(telegramSessionProvider).requireValue;
    setState(() => _menuFor = _archiveRowId);
    await showArchiveMenu(
      context,
      chats: session.chatLists,
      position: position,
      onFailed: _failed,
      onHide: () => ref
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(hideArchive: true)),
    );
    if (mounted) setState(() => _menuFor = null);
  }

  /// Shows a short notice at the bottom of the list that a menu action
  /// didn't go through, then fades it away.
  void _failed() {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = true);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _notice = false);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  /// Not a chat id TDLib uses.
  static const _archiveRowId = 0;

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final chats = widget.chats;
    final archived = widget.archived;
    final shift = archived != null ? 1 : 0;
    return ValueListenableBuilder(
      valueListenable: workspace,
      builder: (context, layout, _) {
        final selected = layout.focusedChat;
        final list = ListView.builder(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          itemExtent: ChatListTile.extent,
          itemCount: chats.length + shift,
          // Keeps each row's state (and its animation) when it moves.
          findChildIndexCallback: (key) => switch (key) {
            ValueKey<int>(value: _archiveRowId) when archived != null => 0,
            ValueKey<int>(:final value) => switch (_index[value]) {
              final i? => i + shift,
              null => null,
            },
            _ => null,
          },
          itemBuilder: (context, i) {
            if (archived != null && i == 0) {
              return _ArchiveRow(
                key: const ValueKey(_archiveRowId),
                archived: archived,
                unread: ref
                    .read(telegramSessionProvider)
                    .requireValue
                    .chatLists
                    .store
                    .unreadChatsIn(const ChatListLocation.archive())
                    .unread,
                menuOpen: _menuFor == _archiveRowId,
                onTap: () => ref
                    .read(selectedChatListProvider.notifier)
                    .select(const ChatListLocation.archive()),
                onContextMenu: _openArchiveMenu,
              );
            }
            final index = i - shift;
            final chat = chats[index];
            if (index >= chats.length - _preload) widget.onNearEnd?.call();
            return _ChatRow(
              key: ValueKey(chat.id),
              chat: chat,
              list: widget.list,
              index: i,
              entrance: _entrances[chat.id],
              selected: chat.id == selected,
              menuOpen: _menuFor == chat.id,
              onTap: () => workspace.open(chat.id, target: _clickTarget()),
              onContextMenu: (position) => _openMenu(chat, position),
            );
          },
        );
        return Stack(
          children: [
            Positioned.fill(child: list),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _notice ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Glass(
                    radius: 10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      AppLocalizations.of(context).chatActionFailed,
                      textAlign: TextAlign.center,
                      style: mgTextStyle(MgColors.of(context)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One chat in the list. When the list reorders, the row slides from where
/// it was; a chat that jumps several places, or joins the list, fades in
/// with a shorter slide so it doesn't sweep across the rows between.
class _ChatRow extends ConsumerStatefulWidget {
  const _ChatRow({
    super.key,
    required this.chat,
    required this.list,
    required this.index,
    required this.entrance,
    required this.selected,
    required this.menuOpen,
    required this.onTap,
    required this.onContextMenu,
  });

  final ChatListEntry chat;
  final ChatListLocation list;
  final int index;
  final _Entrance? entrance;
  final bool selected;
  final bool menuOpen;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  ConsumerState<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends ConsumerState<_ChatRow>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );

  /// Where the row starts, in rows from its place; and whether it fades.
  double _from = 0;
  bool _fade = false;

  @override
  void initState() {
    super.initState();
    _enter(widget.entrance);
  }

  @override
  void didUpdateWidget(_ChatRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.entrance, widget.entrance)) _enter(widget.entrance);
  }

  void _enter(_Entrance? entrance) {
    if (entrance == null || !entrance.fresh) return;
    final from = entrance.from;
    final rows = from == null ? null : (from - widget.index).toDouble();
    if (rows == 0) return;
    if (rows != null && rows.abs() <= 1) {
      _from = rows;
      _fade = false;
    } else {
      _from = rows == null ? -0.35 : rows.sign * 0.6;
      _fade = true;
    }
    _motion.forward(from: 0);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final chat = widget.chat;
    final last = chat.lastMessage;
    final actors = ref.watch(chatActivityProvider(chat.id)).value ?? const [];
    final online = ref.watch(chatOnlineProvider(chat.id)).value ?? false;
    final draft = chat.draft;
    final info =
        ref.watch(chatRowInfoProvider(chat.id)).value ??
        (sender: '', verified: false);
    // In a group, who wrote last gets a line of their own with their
    // small avatar, and so does "You" anywhere but a channel; otherwise
    // the message takes both lines.
    final named =
        last != null &&
        draft == null &&
        (chat.isGroup || (last.isOutgoing && chat.type != ChatType.channel));
    final sender = !named
        ? null
        : last.isOutgoing
        ? l10n.senderYou
        : info.sender.isEmpty
        ? null
        : info.sender;
    final thumbnail = draft == null ? last?.thumbnail : null;
    final tile = ChatListTile(
      title: chat.title,
      avatar: PeerAvatar.chat(
        name: chat.title,
        size: ChatListTile.avatarSize,
        photo: chat.photo,
      ),
      subtitle: draft == null
          ? formatPreview(l10n, last, you: sender == null)
          : draftText(l10n, draft),
      sender: sender,
      // "You" needs no face of its own.
      senderAvatar: sender == null || last!.isOutgoing
          ? null
          : _senderAvatar(ref, sender, last),
      thumbnails: [?thumbnail == null ? null : MemoryImage(thumbnail)],
      kind: switch (chat.type) {
        ChatType.basicGroup || ChatType.supergroup => ChatRowKind.group,
        ChatType.channel => ChatRowKind.channel,
        _ => ChatRowKind.private,
      },
      status: switch (last) {
        _ when draft != null => MessageStatus.none,
        ChatPreview(isOutgoing: true, sendState: PreviewSendState.sending) =>
          MessageStatus.sending,
        ChatPreview(isOutgoing: true, sendState: PreviewSendState.failed) =>
          MessageStatus.failed,
        ChatPreview(isOutgoing: true) when chat.type != ChatType.channel =>
          chat.lastMessageRead ? MessageStatus.read : MessageStatus.sent,
        _ => MessageStatus.none,
      },
      verified: info.verified,
      draftLabel: draft == null ? null : l10n.draftLabel,
      time: switch ((draft, last)) {
        (final draft?, _) => formatChatTime(draft.date, locale),
        (null, final last?) => formatChatTime(last.date, locale),
        (null, null) => '',
      },
      unread: chat.unreadCount,
      unreadLabel: NumberFormat.compact(locale: locale)
          .format(chat.unreadCount),
      markedUnread: chat.isMarkedAsUnread,
      mentions: chat.unreadMentionCount > 0,
      reactions: chat.unreadReactionCount > 0,
      muted: chat.isMuted,
      pinned: chat.isPinnedIn(widget.list),
      secret: chat.type == ChatType.secret,
      online: online,
      activity: actors.isEmpty
          ? null
          : formatActivity(l10n, actors, named: !chat.type.isPrivate),
      selected: widget.selected,
      menuOpen: widget.menuOpen,
      onTap: widget.onTap,
      onContextMenu: widget.onContextMenu,
    );
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_motion.value);
        return Transform.translate(
          offset: Offset(0, _from * ChatListTile.extent * (1 - t)),
          child: Opacity(opacity: _fade ? t : 1, child: child),
        );
      },
      child: tile,
    );
  }
}

/// The small avatar before the sender's name in a group's row: the user's
/// profile photo, or the chat's when a chat posted.
Widget _senderAvatar(WidgetRef ref, String name, ChatPreview last) {
  final session = ref.read(telegramSessionProvider).requireValue;
  const size = ChatListTile.senderAvatarSize;
  if (last.senderChatId != 0) {
    return PeerAvatar.chat(
      name: name,
      size: size,
      photo: session.chatLists.store.chat(last.senderChatId)?.photo,
    );
  }
  final userId = last.isOutgoing ? session.presence.myId : last.senderUserId;
  final photo = session.presence.photoOf(userId);
  return PeerAvatar(
    name: name,
    size: size,
    photo: photo?.small,
    minithumbnail: photo?.minithumbnail,
  );
}

/// The first row of the main list: the archive, with the names of the
/// chats in it and how many of them are unread, always in muted gray.
class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({
    super.key,
    required this.archived,
    required this.unread,
    required this.menuOpen,
    required this.onTap,
    required this.onContextMenu,
  });

  final List<ChatListEntry> archived;

  /// Unread archived chats as TDLib counts them, including those not
  /// loaded yet; 0 until it says.
  final int unread;
  final bool menuOpen;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counted = this.unread;
    final unread = counted > 0
        ? counted
        : archived.where((chat) => chat.isUnread).length;
    return ChatListTile(
      title: l10n.archivedChats,
      subtitle: archived.take(6).map((chat) => chat.title).join(', '),
      unread: unread,
      muted: true,
      menuOpen: menuOpen,
      avatar: const _ArchiveAvatar(),
      onTap: onTap,
      onContextMenu: onContextMenu,
    );
  }
}

class _ArchiveAvatar extends StatelessWidget {
  const _ArchiveAvatar();

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: ChatListTile.avatarSize,
      height: ChatListTile.avatarSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.field),
      child: MgIcon(MgIcons.archive, size: 19, color: c.fg2),
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
