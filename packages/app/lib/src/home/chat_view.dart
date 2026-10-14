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

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    final session = ref.read(telegramSessionProvider).requireValue;
    unawaited(session.conversations.sendText(widget.chatId, text));
    _draft.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final title = session.chatLists.store.chat(widget.chatId)?.title ?? '';
    final messages = ref.watch(conversationProvider(widget.chatId));

    return Stack(
      children: [
        Positioned.fill(
          child: switch (messages) {
            AsyncData(value: final list) when list.isEmpty => Center(
              child: Text(l10n.noTextMessages, style: TextStyle(color: c.fg2)),
            ),
            AsyncData(value: final list) => _Messages(messages: list),
            _ => const SizedBox.shrink(),
          },
        ),
        Positioned(
          top: 10,
          left: 14,
          right: 14,
          child: ChatHeaderBar(
            title: ChatTitleCapsule(title: title),
            actions: const SizedBox.shrink(),
            fill: const WindowDragArea(),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: Composer(
            controller: _draft,
            labels: ComposerLabels(
              hint: l10n.messageHint,
              attach: l10n.attach,
              emoji: l10n.emoji,
              record: l10n.record,
              send: l10n.send,
            ),
            onSend: _send,
          ),
        ),
      ],
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.messages});

  /// Newest first, so the list starts at the bottom.
  final List<ConversationMessage> messages;

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
        final out = message.isOutgoing;
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
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
