import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'format.dart';

/// One conversation: text messages scroll under the floating header and
/// composer. Media rendering arrives with the chat and media stages.
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

  /// Called while one of the oldest loaded messages is built: asks TDLib
  /// for the page before it.
  void _nearTop() {
    final chatId = widget.chatId;
    if (!_conversations.hasOlder(chatId)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.chatId != chatId) return;
      unawaited(_quiet(_conversations.loadOlder(chatId)));
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

  @override
  Widget build(BuildContext context) {
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
            AsyncData(value: final list) when list.isEmpty => Center(
              child: Text(l10n.noTextMessages, style: TextStyle(color: c.fg2)),
            ),
            AsyncData(value: final list) => _Messages(
              messages: list,
              senderName: chat?.isGroup ?? false
                  ? (message) => switch (message.sender) {
                      final sender? => store.nameOf(sender),
                      null => null,
                    }
                  : null,
              onShown: _shown,
              onNearTop: _nearTop,
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

class _Messages extends StatelessWidget {
  const _Messages({
    required this.messages,
    required this.onShown,
    required this.onNearTop,
    this.senderName,
  });

  /// Newest first, so the list starts at the bottom.
  final List<ConversationMessage> messages;

  /// Called as a message is built, which is when it is on screen or about
  /// to be.
  final void Function(ConversationMessage message) onShown;

  /// Called while one of the oldest loaded messages is built.
  final VoidCallback onNearTop;

  /// How many messages before the oldest the previous page is asked for.
  static const _preload = 15;

  /// The author shown over incoming messages; null outside groups.
  final String? Function(ConversationMessage message)? senderName;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.only(top: 72, bottom: 88),
      itemCount: messages.length,
      itemBuilder: (context, i) {
        final message = messages[i];
        final newer = i > 0 ? messages[i - 1] : null;
        final older = i + 1 < messages.length ? messages[i + 1] : null;
        final out = message.isOutgoing;
        onShown(message);
        if (i >= messages.length - _preload) onNearTop();
        // The name goes on the first message of a run from one sender.
        final startsRun = older == null || older.sender != message.sender;
        final name = !out && startsRun ? senderName?.call(message) : null;
        return Center(
          key: ValueKey(message.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                newer != null && newer.isOutgoing == out ? 0 : 6,
                24,
                4,
              ),
              child: Align(
                alignment: out ? Alignment.centerRight : Alignment.centerLeft,
                child: TextMessageBubble(
                  text: message.text,
                  time: formatMessageTime(message.date, locale),
                  outgoing: out,
                  sender: name == null || name.isEmpty ? null : name,
                  status: switch (message.sendState) {
                    MessageSendState.pending => MessageStatus.sending,
                    MessageSendState.failed => MessageStatus.failed,
                    MessageSendState.sent => MessageStatus.none,
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
