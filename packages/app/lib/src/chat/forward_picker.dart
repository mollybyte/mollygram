import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../home/format.dart';
import '../session/providers.dart';

/// Where to forward, and how: without the senders' names, and then
/// without the captions, as the official apps offer.
@immutable
final class ForwardChoice {
  const ForwardChoice({
    required this.chatId,
    this.hideSender = false,
    this.hideCaptions = false,
  });

  final int chatId;
  final bool hideSender;
  final bool hideCaptions;
}

/// Asks which chat to forward to. Completes with the choice, or null when
/// the user closes the picker. [hasCaptions] offers hiding the captions.
Future<ForwardChoice?> pickForwardTarget(
  BuildContext context, {
  bool hasCaptions = false,
}) => showGeneralDialog<ForwardChoice>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => Material(
    type: MaterialType.transparency,
    child: Center(child: _ForwardPicker(hasCaptions: hasCaptions)),
  ),
);

class _ForwardPicker extends ConsumerStatefulWidget {
  const _ForwardPicker({required this.hasCaptions});

  final bool hasCaptions;

  @override
  ConsumerState<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends ConsumerState<_ForwardPicker> {
  var _query = '';
  final _search = FocusNode();
  final _scroll = ScrollController();
  var _hideSender = false;
  var _hideCaptions = false;

  /// The row the arrow keys are on; Enter forwards there.
  var _cursor = 0;
  var _matches = const <ChatListEntry>[];

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = _matches.length;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      if (count == 0) return KeyEventResult.handled;
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() => _cursor = (_cursor + delta).clamp(0, count - 1));
      _reveal();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && event is KeyDownEvent) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Scrolls by the least that shows the cursor's row whole.
  void _reveal() {
    if (!_scroll.hasClients) return;
    final extent = ChatListTile.extentOf(context);
    final top = _cursor * extent;
    final position = _scroll.position;
    final target = top < position.pixels
        ? top
        : top + extent > position.pixels + position.viewportDimension
        ? top + extent - position.viewportDimension
        : null;
    if (target == null) return;
    unawaited(
      _scroll.animateTo(
        target.clamp(0.0, position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _pick(int chatId) => Navigator.of(context).pop(
    ForwardChoice(
      chatId: chatId,
      hideSender: _hideSender,
      hideCaptions: _hideSender && _hideCaptions,
    ),
  );

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
      _cursor = 0;
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
    _matches = matches;
    final cursor = matches.isEmpty ? 0 : _cursor.clamp(0, matches.length - 1);
    return SizedBox(
      width: 360,
      height: 540,
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
            Focus(
              canRequestFocus: false,
              onKeyEvent: _onKey,
              child: MgSearchField(
                focusNode: _search,
                hintText: l10n.forwardSearch,
                onChanged: (value) => unawaited(_find(value)),
                onSubmitted: (_) {
                  if (matches.isNotEmpty) _pick(matches[cursor].id);
                },
              ),
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
                      itemExtent: ChatListTile.extentOf(context),
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final chat = matches[i];
                        return ChatListTile(
                          key: ValueKey(chat.id),
                          title: chat.title,
                          avatar: PeerAvatar.chat(
                            name: chat.title,
                            size: ChatListTile.avatarSize,
                            photo: chat.photo,
                          ),
                          subtitle: formatPreview(l10n, chat.lastMessage),
                          highlighted: i == cursor,
                          onTap: () => _pick(chat.id),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: MgCheckRow(
                label: l10n.forwardHideSender,
                value: _hideSender,
                onChanged: (value) => setState(() => _hideSender = value),
              ),
            ),
            // Captions can only go once the messages are sent as copies.
            if (widget.hasCaptions)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 6),
                child: AnimatedOpacity(
                  opacity: _hideSender ? 1 : 0.45,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !_hideSender,
                    child: MgCheckRow(
                      label: l10n.forwardHideCaptions,
                      value: _hideSender && _hideCaptions,
                      onChanged: (value) =>
                          setState(() => _hideCaptions = value),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
