import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
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

    return Glass(
      radius: 16,
      child: DefaultTextStyle.merge(
        style: mgText(c),
        child: Column(
          children: [
            // Room for the system window buttons.
            const SizedBox(height: 44, child: WindowDragArea()),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: c.field,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(color: c.fg2),
                      child: const MgIcon(
                        MgIcons.search,
                        size: 14,
                        stroke: 2.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        style: mgText(c),
                        cursorHeight: 15,
                        decoration: InputDecoration.collapsed(
                          hintText: l10n.searchHint,
                          hintStyle: mgText(c).copyWith(color: c.fg2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (folders.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Row(
                  children: [
                    _FolderTab(
                      label: l10n.folderAll,
                      on: list.isMain,
                      onTap: () => ref
                          .read(selectedChatListProvider.notifier)
                          .select(const ChatListLocation.main()),
                    ),
                    for (final folder in folders)
                      _FolderTab(
                        label: folder.title,
                        on: list == ChatListLocation.folder(folder.id),
                        onTap: () => ref
                            .read(selectedChatListProvider.notifier)
                            .select(ChatListLocation.folder(folder.id)),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: shown.isEmpty
                  ? Center(
                      child: Text(l10n.noChats, style: TextStyle(color: c.fg2)),
                    )
                  : _ChatList(chats: shown),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends ConsumerWidget {
  const _ChatList({required this.chats});

  final List<ChatListEntry> chats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedChatProvider);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      itemCount: chats.length,
      itemExtent: 59,
      itemBuilder: (context, i) {
        final chat = chats[i];
        return _ChatRow(
          key: ValueKey(chat.id),
          chat: chat,
          on: chat.id == selected,
          onTap: () => ref.read(selectedChatProvider.notifier).select(chat.id),
        );
      },
    );
  }
}

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.field : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: on ? c.fg : c.fg2,
          ),
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  const _ChatRow({
    super.key,
    required this.chat,
    required this.on,
    required this.onTap,
  });

  final ChatListEntry chat;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final chat = widget.chat;
    final on = widget.on;
    final sub = on ? const Color(0xD1FFFFFF) : c.fg2;
    final last = chat.lastMessage;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: on ? c.accent : (_hover ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Avatar(initialsOf(chat.title), size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: on ? Colors.white : c.fg,
                            ),
                          ),
                        ),
                        if (last != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            formatChatTime(last.date, locale),
                            style: TextStyle(fontSize: 11.5, color: sub),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            formatPreview(l10n, last),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: sub),
                          ),
                        ),
                        if (chat.unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(chat.unreadCount, onAccent: on),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count, {required this.onAccent});

  final int count;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? Colors.white : c.accent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w600,
          color: onAccent ? c.accent : Colors.white,
        ),
      ),
    );
  }
}
