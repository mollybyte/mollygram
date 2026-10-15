import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../home/workspace.dart';
import '../profile/manage_sheet.dart';
import '../session/providers.dart';
import '../shared_media/message_jump.dart';
import 'describe.dart';
import 'load_spinner.dart';
import 'message_tile.dart' show SenderAvatar;
import 'segmented_tabs.dart';

/// Shows the messages with [tag] (its `#` or `$` included): the ones in
/// [chatId] when it is a chat, the user's own and public channel posts,
/// as the official clients do for a tapped hashtag. A row opens its
/// message in the chat.
Future<void> showHashtagResults(
  BuildContext context, {
  required String tag,
  int chatId = 0,
}) => showManageSheet<void>(
  context,
  HashtagResultsSheet(tag: tag, chatId: chatId),
);

class HashtagResultsSheet extends ConsumerStatefulWidget {
  const HashtagResultsSheet({super.key, required this.tag, this.chatId = 0});

  final String tag;
  final int chatId;

  @override
  ConsumerState<HashtagResultsSheet> createState() =>
      _HashtagResultsSheetState();
}

class _HashtagResultsSheetState extends ConsumerState<HashtagResultsSheet> {
  late HashtagScope _scope = widget.chatId == 0
      ? HashtagScope.myMessages
      : HashtagScope.thisChat;

  void _open(td.Message message) {
    final jumps = ref.read(messageJumpProvider.notifier);
    final workspace = ref.read(workspaceControllerProvider);
    Navigator.of(context).pop();
    jumps.request(message.chatId, message.id);
    if (message.chatId != widget.chatId) workspace.open(message.chatId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ManageSheetFrame(
      title: widget.tag,
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SegmentedTabs<HashtagScope>(
              selected: _scope,
              labels: {
                if (widget.chatId != 0)
                  HashtagScope.thisChat: l10n.hashtagThisChat,
                HashtagScope.myMessages: l10n.hashtagMyMessages,
                HashtagScope.publicPosts: l10n.hashtagPublicPosts,
              },
              onSelect: (scope) => setState(() => _scope = scope),
            ),
          ),
          Expanded(
            child: _Results(
              key: ValueKey(_scope),
              tag: widget.tag,
              scope: _scope,
              chatId: widget.chatId,
              onOpen: _open,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Load { loading, ready, failed }

class _Results extends ConsumerStatefulWidget {
  const _Results({
    super.key,
    required this.tag,
    required this.scope,
    required this.chatId,
    required this.onOpen,
  });

  final String tag;
  final HashtagScope scope;
  final int chatId;
  final ValueChanged<td.Message> onOpen;

  @override
  ConsumerState<_Results> createState() => _ResultsState();
}

class _ResultsState extends ConsumerState<_Results> {
  final _scroll = ScrollController();
  final _messages = <td.Message>[];
  var _load = _Load.loading;
  var _offset = '';
  var _fromMessageId = 0;
  var _complete = false;
  var _loading = false;

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
    if (_scroll.position.extentAfter < 200) unawaited(_loadMore());
  }

  Future<void> _loadMore() async {
    if (_loading || _complete) return;
    _loading = true;
    final search = ref.read(telegramSessionProvider).requireValue.search;
    try {
      final page = await search.hashtag(
        widget.tag,
        scope: widget.scope,
        chatId: widget.chatId,
        offset: _offset,
        fromMessageId: _fromMessageId,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(page.messages);
        _offset = page.nextOffset;
        _fromMessageId = page.nextFromMessageId;
        _complete =
            page.messages.isEmpty ||
            (page.nextOffset.isEmpty && page.nextFromMessageId == 0);
        _load = _Load.ready;
      });
    } on td.TdException {
      if (mounted && _messages.isEmpty) setState(() => _load = _Load.failed);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (_load) {
      case _Load.loading:
        return const Center(child: LoadSpinner());
      case _Load.failed:
        return _Notice(l10n.hashtagFailed);
      case _Load.ready:
        if (_messages.isEmpty) return _Notice(l10n.hashtagEmpty(widget.tag));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _ResultRow(
          key: ValueKey((message.chatId, message.id)),
          message: message,
          onTap: () => widget.onOpen(message),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: mgTextStyle(c, size: MgType.small, color: c.fg2),
      ),
    );
  }
}

/// A message found: the chat's avatar and title, when it was sent, who
/// sent it in a group, and its text or what it carries.
class _ResultRow extends ConsumerStatefulWidget {
  const _ResultRow({super.key, required this.message, required this.onTap});

  final td.Message message;
  final VoidCallback onTap;

  @override
  ConsumerState<_ResultRow> createState() => _ResultRowState();
}

class _ResultRowState extends ConsumerState<_ResultRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final message = widget.message;
    final entry = ref.watch(chatEntryProvider(message.chatId)).value;
    final store = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations
        .store;
    final title = entry?.title ?? '';
    final sender = nameOfSender(
      l10n,
      store,
      MessageSenderId.of(message.senderId),
    );
    final text = switch (message.content) {
      td.MessageText(:final text) => text.text,
      final content => describeContent(l10n, content),
    };
    final showSender =
        (entry?.isGroup ?? false) && sender.isNotEmpty && sender != title;
    return Semantics(
      button: true,
      label: '$title: $text',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
            decoration: BoxDecoration(
              color: _hover ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SenderAvatar(name: title, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(
                                c,
                                weight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatChatTime(message.date, locale),
                            style: mgTextStyle(
                              c,
                              size: MgType.small,
                              color: c.fg2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (showSender)
                              TextSpan(
                                text: '$sender: ',
                                style: mgTextStyle(c, color: c.fg),
                              ),
                            TextSpan(text: text),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, color: c.fg2, height: 1.3),
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
