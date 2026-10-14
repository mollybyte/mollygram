import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'format.dart';

/// The floating glass island with folders and the chat list.
class Sidebar extends ConsumerStatefulWidget {
  const Sidebar({super.key});

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
      titleBarFill: const WindowDragArea(),
      search: MgSearchField(hintText: l10n.searchHint, controller: _search),
      folders: folders.isEmpty
          ? null
          : FolderTabBar(
              children: [
                FolderTab(
                  label: l10n.folderAll,
                  selected: list.isMain,
                  onTap: () => select(const ChatListLocation.main()),
                ),
                for (final folder in folders)
                  FolderTab(
                    label: folder.title,
                    selected: list == ChatListLocation.folder(folder.id),
                    onTap: () => select(ChatListLocation.folder(folder.id)),
                  ),
              ],
            ),
      body: shown.isEmpty
          ? Center(
              child: Text(
                query.isEmpty ? l10n.noChats : l10n.nothingFound,
                style: TextStyle(color: c.fg2),
              ),
            )
          : _ChatList(chats: shown),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.chats});

  final List<ChatListEntry> chats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final unread = NumberFormat.compact(locale: locale);
    final selected = ref.watch(selectedChatProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      itemCount: chats.length,
      itemBuilder: (context, i) {
        final chat = chats[i];
        final last = chat.lastMessage;
        return ChatListTile(
          key: ValueKey(chat.id),
          title: chat.title,
          subtitle: formatPreview(l10n, last),
          time: last == null ? '' : formatChatTime(last.date, locale),
          unread: chat.unreadCount,
          unreadLabel: unread.format(chat.unreadCount),
          selected: chat.id == selected,
          onTap: () => ref.read(selectedChatProvider.notifier).select(chat.id),
        );
      },
    );
  }
}
