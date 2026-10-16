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
  ForwardChoice({
    required int chatId,
    this.hideSender = false,
    this.hideCaptions = false,
  }) : chatIds = [chatId],
       comment = '';

  const ForwardChoice._(
    this.chatIds, {
    required this.hideSender,
    required this.hideCaptions,
    required this.comment,
  });

  /// The chats picked, at least one; one unless the picker was opened
  /// with `multiple`.
  final List<int> chatIds;
  final bool hideSender;
  final bool hideCaptions;

  /// A message to send before the forwarded ones; empty for none.
  final String comment;

  int get chatId => chatIds.first;
}

/// Asks which chat to forward to. Completes with the choice, or null when
/// the user closes the picker. [hasCaptions] offers hiding the captions.
/// With [multiple] a click ticks chats, as Telegram's share sheet does,
/// and a comment can go with them; Enter with nothing ticked still sends
/// to the highlighted chat at once.
Future<ForwardChoice?> pickForwardTarget(
  BuildContext context, {
  bool hasCaptions = false,
  bool multiple = false,
}) => showGeneralDialog<ForwardChoice>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: _ForwardPicker(hasCaptions: hasCaptions, multiple: multiple),
    ),
  ),
);

class _ForwardPicker extends ConsumerStatefulWidget {
  const _ForwardPicker({required this.hasCaptions, required this.multiple});

  final bool hasCaptions;
  final bool multiple;

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

  /// The ticked chats, in the order they were ticked.
  final _picked = <int>[];
  final _comment = TextEditingController();
  final _commentFocus = FocusNode();

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

  /// Reveals the cursor once new results are laid out, since the list
  /// keeps its scroll offset while the cursor goes back to the top.
  void _revealAfterLayout() =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reveal();
      });

  /// Scrolls by the least that shows the cursor's row whole.
  void _reveal() {
    if (!_scroll.hasClients) return;
    const extent = _ForwardRow.extent;
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

  void _send(List<int> chatIds) => Navigator.of(context).pop(
    ForwardChoice._(
      chatIds,
      hideSender: _hideSender,
      hideCaptions: _hideSender && _hideCaptions,
      comment: _comment.text.trim(),
    ),
  );

  /// A click: ticks the chat in a multiple pick, else forwards there.
  void _tap(int chatId) {
    if (!widget.multiple) return _send([chatId]);
    setState(() {
      if (!_picked.remove(chatId)) _picked.add(chatId);
    });
  }

  /// Enter: sends to the ticked chats, or to the highlighted one.
  void _submit(List<ChatListEntry> matches) {
    if (_picked.isNotEmpty) return _send(List.of(_picked));
    if (matches.isNotEmpty) {
      _send([matches[_cursor.clamp(0, matches.length - 1)].id]);
    }
  }

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
    _comment.dispose();
    _commentFocus.dispose();
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
    _revealAfterLayout();
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
    _revealAfterLayout();
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
    // A plain card, as Telegram's share sheet is: the list reads better
    // on a solid surface than on glass.
    return Container(
      width: 330,
      height: 500,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: c.glassSolid.withValues(alpha: 1),
        borderRadius: BorderRadius.circular(MgRadius.card),
        border: Border.all(color: c.separator, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 40,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.forwardTitle,
                    style: mgTextStyle(
                      c,
                      size: 15,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                MgIconButton(
                  icon: MgIcons.close,
                  size: 24,
                  iconSize: 14,
                  tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Focus(
            canRequestFocus: false,
            onKeyEvent: _onKey,
            child: MgSearchField(
              focusNode: _search,
              hintText: l10n.forwardSearch,
              onChanged: (value) => unawaited(_find(value)),
              onSubmitted: (_) => _submit(matches),
            ),
          ),
          const SizedBox(height: 10),
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
                    itemExtent: _ForwardRow.extent,
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final chat = matches[i];
                      return _ForwardRow(
                        key: ValueKey(chat.id),
                        title: chat.title,
                        avatar: PeerAvatar.chat(
                          name: chat.title,
                          size: _ForwardRow.avatarSize,
                          photo: chat.photo,
                        ),
                        subtitle: formatPreview(l10n, chat.lastMessage),
                        highlighted: i == cursor,
                        tick: widget.multiple
                            ? _Tick(on: _picked.contains(chat.id))
                            : null,
                        onTap: () => _tap(chat.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
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
                    onChanged: (value) => setState(() => _hideCaptions = value),
                  ),
                ),
              ),
            ),
          // The comment and Send slide in once a chat is ticked.
          AnimatedSize(
            duration: MgMotion.standard,
            curve: MgMotion.enter,
            alignment: Alignment.topCenter,
            child: _picked.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(
                              horizontal: MgSpace.l,
                            ),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: c.field,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: TextField(
                              controller: _comment,
                              focusNode: _commentFocus,
                              style: mgTextStyle(c),
                              cursorHeight: 15,
                              onSubmitted: (_) => _submit(matches),
                              decoration: InputDecoration.collapsed(
                                hintText: l10n.forwardComment,
                                hintStyle: mgTextStyle(c, color: c.fg2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: MgSpace.m),
                        _SendButton(
                          label: '${l10n.send} ${_picked.length}',
                          onTap: () => _submit(matches),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A chat in the picker: a small avatar, the name over one line of the
/// last message, and the tick of a multiple pick on the right.
class _ForwardRow extends StatefulWidget {
  const _ForwardRow({
    super.key,
    required this.title,
    required this.avatar,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
    this.tick,
  });

  static const double extent = 46;
  static const double avatarSize = 34;

  final String title;
  final Widget avatar;
  final String subtitle;

  /// The keyboard cursor is on this row.
  final bool highlighted;
  final VoidCallback onTap;
  final Widget? tick;

  @override
  State<_ForwardRow> createState() => _ForwardRowState();
}

class _ForwardRowState extends State<_ForwardRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final tick = widget.tick;
    return Semantics(
      button: true,
      label: widget.title,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hover || widget.highlighted
                  ? c.hover
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                widget.avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.small,
                          weight: MgWeight.medium,
                          height: 1.25,
                        ),
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: c.fg2,
                            height: 1.3,
                          ),
                        ),
                    ],
                  ),
                ),
                if (tick != null) ...[const SizedBox(width: 10), tick],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round tick on a chat of a multiple pick.
class _Tick extends StatelessWidget {
  const _Tick({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedContainer(
      duration: MgMotion.fast,
      curve: MgMotion.enter,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.accent : const Color(0x00000000),
        border: on ? null : Border.all(color: c.fg2, width: 1.5),
      ),
      child: AnimatedScale(
        scale: on ? 1 : 0.4,
        duration: MgMotion.fast,
        curve: MgMotion.enter,
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: MgMotion.fast,
          child: MgIcon(
            MgIcons.check,
            size: 12,
            stroke: 2.4,
            color: c.onAccent,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: MgSpace.l),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              label,
              style: mgTextStyle(
                c,
                weight: MgWeight.medium,
                color: c.onAccent,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
