import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/file_content.dart';
import '../chat/formatted_text.dart' show openLink;
import '../chat/load_spinner.dart';
import '../chat/media_content.dart';
import '../chat/media_viewer.dart';
import '../chat/message_tile.dart' show SenderAvatar;
import '../chat/segmented_tabs.dart';
import '../home/format.dart';
import '../session/providers.dart';
import 'shared_link.dart';

/// A chat's shared media: tabs for photos and videos, files, links, voice
/// messages, music and GIFs, each loaded page by page with
/// `searchChatMessages`, and for a user the groups in common.
///
/// Photos, videos and GIFs open in the media viewer, files and audio play
/// or open in place, links open in the browser. [onOpenMessage] shows a
/// message in the chat ("Show in chat"); [onOpenChat] opens a group in
/// common. [userId] is the user of a private chat, 0 elsewhere.
class SharedMediaView extends ConsumerStatefulWidget {
  const SharedMediaView({
    super.key,
    required this.chatId,
    this.userId = 0,
    this.onOpenMessage,
    this.onOpenChat,
    this.initialKind = SharedMediaKind.media,
  });

  final int chatId;
  final int userId;
  final ValueChanged<ConversationMessage>? onOpenMessage;
  final ValueChanged<int>? onOpenChat;
  final SharedMediaKind initialKind;

  @override
  ConsumerState<SharedMediaView> createState() => _SharedMediaViewState();
}

/// The groups-in-common tab, which is no message filter.
enum _Groups { tab }

class _SharedMediaViewState extends ConsumerState<SharedMediaView> {
  late Object _tab = widget.initialKind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tab = _tab;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: SegmentedTabs<Object>(
            selected: tab,
            labels: {
              SharedMediaKind.media: l10n.sharedMediaTab,
              SharedMediaKind.files: l10n.sharedFilesTab,
              SharedMediaKind.links: l10n.sharedLinksTab,
              SharedMediaKind.voice: l10n.sharedVoiceTab,
              SharedMediaKind.music: l10n.sharedMusicTab,
              SharedMediaKind.gifs: l10n.sharedGifsTab,
              if (widget.userId != 0) _Groups.tab: l10n.sharedGroupsTab,
            },
            onSelect: (tab) => setState(() => _tab = tab),
          ),
        ),
        Expanded(
          child: switch (tab) {
            final SharedMediaKind kind => _SharedList(
              // A new list per chat and tab, so each starts from the newest.
              key: ValueKey((widget.chatId, kind)),
              chatId: widget.chatId,
              kind: kind,
              onOpenMessage: widget.onOpenMessage,
            ),
            _ => _GroupsList(
              key: ValueKey((widget.chatId, _Groups.tab)),
              userId: widget.userId,
              onOpen: widget.onOpenChat,
            ),
          },
        ),
      ],
    );
  }
}

/// The groups the user shares with the chat's user, as rows with the
/// group's photo and title; a click opens the group.
class _GroupsList extends ConsumerStatefulWidget {
  const _GroupsList({super.key, required this.userId, required this.onOpen});

  final int userId;
  final ValueChanged<int>? onOpen;

  @override
  ConsumerState<_GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends ConsumerState<_GroupsList> {
  late final Future<List<td.Chat>> _groups = ref
      .read(telegramSessionProvider)
      .requireValue
      .conversations
      .groupsInCommon(widget.userId);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<td.Chat>>(
      future: _groups,
      builder: (context, snapshot) {
        final groups = snapshot.data;
        if (groups == null) {
          return Center(
            child: snapshot.hasError
                ? Text(
                    l10n.sharedLoadFailed,
                    style: mgTextStyle(c, color: c.fg2),
                  )
                : const LoadSpinner(),
          );
        }
        if (groups.isEmpty) {
          return Center(
            child: Text(
              l10n.sharedGroupsEmpty,
              textAlign: TextAlign.center,
              style: mgTextStyle(c, color: c.fg2),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          itemCount: groups.length,
          itemBuilder: (context, i) {
            final group = groups[i];
            return _GroupRow(
              key: ValueKey(group.id),
              title: group.title,
              photo: group.photo?.small,
              onTap: switch (widget.onOpen) {
                final open? => () => open(group.id),
                null => null,
              },
            );
          },
        );
      },
    );
  }
}

class _GroupRow extends StatefulWidget {
  const _GroupRow({
    super.key,
    required this.title,
    required this.photo,
    required this.onTap,
  });

  final String title;
  final td.File? photo;
  final VoidCallback? onTap;

  @override
  State<_GroupRow> createState() => _GroupRowState();
}

class _GroupRowState extends State<_GroupRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: widget.onTap != null,
      label: widget.title,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: _hover && widget.onTap != null
                  ? c.fg.withValues(alpha: 0.06)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SenderAvatar(name: widget.title, size: 36, photo: widget.photo),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, weight: FontWeight.w500),
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

/// A macOS-style segmented control.
class _SharedList extends ConsumerStatefulWidget {
  const _SharedList({
    super.key,
    required this.chatId,
    required this.kind,
    required this.onOpenMessage,
  });

  final int chatId;
  final SharedMediaKind kind;
  final ValueChanged<ConversationMessage>? onOpenMessage;

  @override
  ConsumerState<_SharedList> createState() => _SharedListState();
}

enum _Load { loading, ready, failed }

class _SharedListState extends ConsumerState<_SharedList> {
  late final SharedMediaList _list = ref
      .read(telegramSessionProvider)
      .requireValue
      .chatSearch
      .sharedMedia(widget.chatId, widget.kind);
  final _scroll = ScrollController();
  var _load = _Load.loading;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
    unawaited(_loadMore());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_list.isComplete || _load == _Load.loading) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadMore() async {
    // The first load starts in initState, already marked as loading.
    if (_load != _Load.loading) setState(() => _load = _Load.loading);
    try {
      await _list.loadMore();
      if (!mounted) return;
      setState(() => _load = _Load.ready);
      // A first page that does not fill the panel leaves nothing to scroll.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _maybeLoadMore();
      });
    } on Object {
      if (mounted) setState(() => _load = _Load.failed);
    }
  }

  String _empty(AppLocalizations l10n) => switch (widget.kind) {
    SharedMediaKind.media => l10n.sharedMediaEmpty,
    SharedMediaKind.files => l10n.sharedFilesEmpty,
    SharedMediaKind.links => l10n.sharedLinksEmpty,
    SharedMediaKind.voice => l10n.sharedVoiceEmpty,
    SharedMediaKind.music => l10n.sharedMusicEmpty,
    SharedMediaKind.gifs => l10n.sharedGifsEmpty,
  };

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final messages = _list.messages;
    if (messages.isEmpty) {
      return Center(
        child: switch (_load) {
          _Load.loading => const LoadSpinner(),
          _Load.failed => Text(
            l10n.sharedLoadFailed,
            style: mgTextStyle(c, color: c.fg2),
          ),
          _Load.ready => Text(
            _empty(l10n),
            textAlign: TextAlign.center,
            style: mgTextStyle(c, color: c.fg2),
          ),
        },
      );
    }
    if (widget.kind case SharedMediaKind.media || SharedMediaKind.gifs) {
      return _grid(messages);
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: messages.length,
      itemBuilder: (context, i) => _row(context, messages[i]),
    );
  }

  Widget _grid(List<ConversationMessage> messages) {
    final conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 128,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];
        void view() => unawaited(
          showChatMediaViewer(
            context,
            message: message,
            conversations: conversations,
          ),
        );
        return LayoutBuilder(
          key: ValueKey(message.id),
          builder: (context, box) {
            final size = Size.square(box.maxWidth);
            return ClipRect(
              child: switch (message.content) {
                td.MessagePhoto(:final photo) => PhotoContent(
                  photo: photo,
                  size: size,
                  onTap: view,
                ),
                td.MessageVideo(:final video) => VideoContent(
                  video: video,
                  size: size,
                  onTap: view,
                ),
                td.MessageAnimation(:final animation) => AnimationContent(
                  animation: animation,
                  size: size,
                  onTap: view,
                ),
                _ => const SizedBox.shrink(),
              },
            );
          },
        );
      },
    );
  }

  Widget _row(BuildContext context, ConversationMessage message) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = Text(
      formatChatTime(message.date, locale),
      style: mgTextStyle(c, size: MgType.small, color: c.fg2),
    );
    final Widget body = switch (message.content) {
      td.MessageDocument(:final document) => DocumentContent(
        chatId: message.chatId,
        messageId: message.id,
        document: document,
        meta: date,
      ),
      td.MessageVoiceNote(:final voiceNote, :final isListened) =>
        VoiceNoteContent(
          chatId: message.chatId,
          messageId: message.id,
          voiceNote: voiceNote,
          unread: !isListened,
          meta: date,
        ),
      td.MessageAudio(:final audio) => AudioContent(
        chatId: message.chatId,
        messageId: message.id,
        audio: audio,
        meta: date,
      ),
      _ => switch (sharedLinkOf(message)) {
        final link? => _LinkRow(link: link, date: date),
        null => const SizedBox.shrink(),
      },
    };
    final open = widget.onOpenMessage;
    return Padding(
      key: ValueKey(message.id),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: body),
          if (open != null) ...[
            const SizedBox(width: 4),
            MgIconButton(
              icon: MgIcons.chat,
              iconSize: 15,
              tooltip: l10n.showInChat,
              onPressed: () => open(message),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatefulWidget {
  const _LinkRow({required this.link, required this.date});

  final SharedLink link;
  final Widget date;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final link = widget.link;
    final initial = link.title.characters.firstOrNull?.toUpperCase() ?? '';
    return Semantics(
      link: true,
      label: link.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => unawaited(openLink(link.url)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hover ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.field,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    initial,
                    style: mgTextStyle(
                      c,
                      size: 17,
                      weight: FontWeight.w600,
                      color: c.fg2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              link.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, weight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          widget.date,
                        ],
                      ),
                      if (link.description.isNotEmpty)
                        Text(
                          link.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(c, size: MgType.small),
                        ),
                      Text(
                        link.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.small,
                          color: c.accent,
                        ),
                      ),
                    ],
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
