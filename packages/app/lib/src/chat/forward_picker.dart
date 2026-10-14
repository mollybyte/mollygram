import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../session/providers.dart';

/// Asks which chat to forward to. Completes with its id, or null when the
/// user closes the picker.
Future<int?> pickForwardTarget(BuildContext context) => showGeneralDialog<int>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => const Material(
    type: MaterialType.transparency,
    child: Center(child: _ForwardPicker()),
  ),
);

class _ForwardPicker extends ConsumerStatefulWidget {
  const _ForwardPicker();

  @override
  ConsumerState<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends ConsumerState<_ForwardPicker> {
  var _query = '';
  final _search = FocusNode();
  final _scroll = ScrollController();

  /// Chats TDLib found for the query, archived ones included; null while
  /// the query is empty.
  List<ChatListEntry>? _found;
  var _searchId = 0;

  @override
  void initState() {
    super.initState();
    _search.requestFocus();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The sidebar loads chats page by page; so does the picker as it is
  /// scrolled to the end.
  void _maybeLoadMore() {
    if (_query.trim().isNotEmpty) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    final chatLists = ref.read(telegramSessionProvider).requireValue.chatLists;
    if (chatLists.hasMore()) unawaited(chatLists.loadMore().catchError((_) {}));
  }

  Future<void> _find(String query) async {
    final id = ++_searchId;
    setState(() {
      _query = query;
      if (query.trim().isEmpty) _found = null;
    });
    if (query.trim().isEmpty) return;
    final session = ref.read(telegramSessionProvider).requireValue;
    List<int> ids;
    try {
      ids = await session.search.chats(query, limit: 30);
    } on Object {
      ids = const [];
    }
    if (!mounted || id != _searchId) return;
    setState(() {
      _found = [
        for (final chatId in ids) ?session.chatLists.store.chat(chatId),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final loaded = ref
        .watch(chatListProvider(const ChatListLocation.main()))
        .value;
    final chats = loaded ?? const <ChatListEntry>[];
    final query = _query.trim().toLowerCase();
    // Loaded chats match at once; TDLib's search adds the rest.
    final matches = [
      for (final chat in chats)
        if (query.isEmpty || chat.title.toLowerCase().contains(query)) chat,
    ];
    final ids = {for (final chat in matches) chat.id};
    for (final chat in _found ?? const <ChatListEntry>[]) {
      if (ids.add(chat.id)) matches.add(chat);
    }
    return SizedBox(
      width: 360,
      height: 480,
      child: Glass(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                l10n.forwardTitle,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
            ),
            MgSearchField(
              focusNode: _search,
              hintText: l10n.forwardSearch,
              onChanged: (value) => unawaited(_find(value)),
              onSubmitted: (_) {
                if (matches.isNotEmpty) {
                  Navigator.of(context).pop(matches.first.id);
                }
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loaded == null
                  ? const SizedBox.shrink()
                  : matches.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noChatsFound,
                        style: mgTextStyle(c, color: c.fg2),
                      ),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final chat = matches[i];
                        return ChatListTile(
                          key: ValueKey(chat.id),
                          title: chat.title,
                          subtitle: formatPreview(l10n, chat.lastMessage),
                          onTap: () => Navigator.of(context).pop(chat.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
