import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../chat/message_tile.dart';
import '../chat/timeline.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';

/// One conversation: messages scroll under the floating header and
/// composer.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _draft = TextEditingController();
  late final ConversationController _conversations;

  /// Incoming messages already reported to TDLib as viewed.
  final _viewed = <int>{};
  final _toView = <int>{};
  var _viewScheduled = false;
  var _sendFailed = false;

  @override
  void initState() {
    super.initState();
    _conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    _draft.addListener(_clearSendError);
    _open(widget.chatId);
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.chatId == widget.chatId) return;
    _close(old.chatId);
    _viewed.clear();
    _toView.clear();
    _sendFailed = false;
    _open(widget.chatId);
  }

  @override
  void dispose() {
    _close(widget.chatId);
    _draft.dispose();
    super.dispose();
  }

  // Supergroups and channels get all their updates only while open.
  void _open(int chatId) => unawaited(_quiet(_conversations.openChat(chatId)));

  void _close(int chatId) =>
      unawaited(_quiet(_conversations.closeChat(chatId)));

  /// The session can close under the view (sign-out, app exit); a request
  /// that no longer matters must not surface as an unhandled error.
  static Future<void> _quiet(Future<void> request) =>
      request.catchError((Object _) {});

  void _clearSendError() {
    if (_sendFailed && _draft.text.isNotEmpty) {
      setState(() => _sendFailed = false);
    }
  }

  /// Called for each incoming message as it is laid out on screen; the ids
  /// are sent to TDLib together after the frame.
  void _shown(ConversationMessage message) {
    // A chat in a background tab stays built but is not on screen; its
    // messages count as read once the tab comes forward.
    if (!_onScreen) return;
    if (message.isOutgoing || !_viewed.add(message.id)) return;
    _toView.add(message.id);
    if (_viewScheduled) return;
    _viewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewScheduled = false;
      if (!mounted || _toView.isEmpty) return;
      final ids = _toView.toList();
      _toView.clear();
      unawaited(_quiet(_conversations.viewMessages(widget.chatId, ids)));
    });
  }

  late final _actions = MessageRowActions(
    onReaction: (message, reaction, chosen) => unawaited(
      _quiet(
        _conversations.toggleReaction(
          message.chatId,
          message.id,
          reaction,
          chosen: chosen,
        ),
      ),
    ),
    onNeedReplied: (reply) =>
        unawaited(_quiet(_conversations.loadReplied(reply.chatId, reply.id))),
  );

  var _olderScheduled = false;

  /// Asks for the page before the oldest message, once per frame.
  void _loadOlder() {
    if (_olderScheduled) return;
    _olderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _olderScheduled = false;
      if (!mounted) return;
      unawaited(_quiet(_conversations.loadOlder(widget.chatId).then((_) {})));
    });
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final chatId = widget.chatId;
    _draft.clear();
    setState(() => _sendFailed = false);
    try {
      await _conversations.sendText(chatId, text);
    } catch (_) {
      // Give the text back rather than lose it, unless the user has
      // started typing something else or moved to another chat.
      if (!mounted || widget.chatId != chatId) return;
      if (_draft.text.isEmpty) {
        _draft.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      setState(() => _sendFailed = true);
    }
  }

  /// False while the chat sits in a background tab (tickers are off there).
  var _onScreen = true;

  @override
  Widget build(BuildContext context) {
    _onScreen = TickerMode.valuesOf(context).enabled;
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final chat = ref.watch(chatEntryProvider(widget.chatId)).value;
    final messages = ref.watch(conversationProvider(widget.chatId));
    final store = session.conversations.store;

    return Stack(
      children: [
        Positioned.fill(
          child: switch (messages) {
            AsyncData(value: final list)
                when list.isEmpty && store.reachedStart(widget.chatId) =>
              Center(child: DatePill(l10n.noMessages)),
            AsyncData(value: final list) => _Messages(
              messages: list,
              store: store,
              chatId: widget.chatId,
              isGroup: chat?.isGroup ?? false,
              onShown: _shown,
              onNearTop: _loadOlder,
              actions: _actions,
            ),
            _ => const SizedBox.shrink(),
          },
        ),
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: ChatHeaderBar(
            title: ChatTitleCapsule(title: chat?.title ?? ''),
            actions: const SizedBox.shrink(),
            fill: const WindowDragArea(),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sendFailed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.sendFailed,
                    textAlign: TextAlign.center,
                    style: mgTextStyle(
                      c,
                      size: MgType.small,
                      color: MessageMeta.failedColor,
                    ),
                  ),
                ),
              Composer(
                controller: _draft,
                labels: ComposerLabels(
                  hint: l10n.messageHint,
                  attach: l10n.attach,
                  emoji: l10n.emoji,
                  record: l10n.record,
                  send: l10n.send,
                ),
                onSend: (text) => unawaited(_send(text)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The timeline, newest at the bottom: rows of messages and albums with a
/// date pill above the first message of each day.
class _Messages extends StatelessWidget {
  const _Messages({
    required this.messages,
    required this.store,
    required this.chatId,
    required this.isGroup,
    required this.onShown,
    required this.onNearTop,
    required this.actions,
  });

  /// Newest first, so the list starts at the bottom.
  final List<ConversationMessage> messages;
  final ConversationStore store;
  final int chatId;
  final bool isGroup;

  /// Called as a message is built, which is when it is on screen or about
  /// to be.
  final void Function(ConversationMessage message) onShown;

  /// Called when the oldest loaded messages come into view.
  final VoidCallback onNearTop;
  final MessageRowActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final items = timelineItems(
      messages,
      reachedStart: store.reachedStart(chatId),
    );
    final isChannel = store.isChannel(chatId);
    final lastReadOutbox = store.lastReadOutbox(chatId);
    return ListView.builder(
      reverse: true,
      // No off-screen cache: a message is built when it enters the
      // viewport, which is when onShown reports it to TDLib as viewed.
      scrollCacheExtent: const ScrollCacheExtent.pixels(0),
      padding: const EdgeInsets.only(top: 72, bottom: 88),
      itemCount: items.length,
      findChildIndexCallback: (key) {
        final value = (key as ValueKey<Object>).value;
        final index = items.indexWhere((item) => item.key == value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, i) {
        if (i >= items.length - 8) onNearTop();
        final item = items[i];
        final Widget child = switch (item) {
          TimelineDate(:final day) => DatePill(formatDay(l10n, day, locale)),
          TimelineRow(:final row, :final startsRun, :final endsRun) => () {
            row.messages.forEach(onShown);
            return Padding(
              padding: EdgeInsets.only(top: startsRun ? 6 : 2),
              child: MessageTile(
                row: row,
                store: store,
                context: MessageRowContext(
                  isGroup: isGroup,
                  isChannel: isChannel,
                  startsRun: startsRun,
                  endsRun: endsRun,
                  lastReadOutbox: lastReadOutbox,
                ),
                actions: actions,
              ),
            );
          }(),
        };
        return Padding(
          key: ValueKey<Object>(item.key),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        );
      },
    );
  }
}
