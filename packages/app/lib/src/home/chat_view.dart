import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../ui/glass.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'format.dart';

/// One conversation: text messages scroll under the floating header and
/// composer. Media rendering arrives with the chat and media stages.
class ChatView extends ConsumerWidget {
  const ChatView({super.key, required this.chatId});

  final int chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final title = session.chatLists.store.chat(chatId)?.title ?? '';
    final messages = ref.watch(conversationProvider(chatId));

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
          height: 44,
          child: Row(
            children: [
              Glass(
                radius: 22,
                padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(initialsOf(title), size: 32),
                    const SizedBox(width: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgText(c, size: 13.5, weight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: WindowDragArea()),
            ],
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 12,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 712),
              child: _Composer(
                onSend: (text) =>
                    unawaited(session.conversations.sendText(chatId, text)),
              ),
            ),
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
  Widget build(BuildContext context) => ListView.builder(
    reverse: true,
    padding: const EdgeInsets.only(top: 72, bottom: 88),
    itemCount: messages.length,
    itemBuilder: (context, i) {
      final message = messages[i];
      final newer = i > 0 ? messages[i - 1] : null;
      return Center(
        key: ValueKey(message.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              newer != null && newer.isOutgoing == message.isOutgoing ? 0 : 6,
              24,
              4,
            ),
            child: Align(
              alignment: message.isOutgoing
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _TextBubble(message),
            ),
          ),
        ),
      );
    },
  );
}

class _TextBubble extends StatelessWidget {
  const _TextBubble(this.message);

  final ConversationMessage message;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final out = message.isOutgoing;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = formatMessageTime(message.date, locale);
    final timeStyle = TextStyle(fontSize: 11, height: 1.35, color: c.fg2);
    const tail = Radius.circular(5);
    const round = Radius.circular(16);
    return Container(
      constraints: const BoxConstraints(maxWidth: 480),
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 5),
      decoration: BoxDecoration(
        color: out ? c.bubbleOut : c.bubbleIn,
        borderRadius: BorderRadius.only(
          topLeft: round,
          topRight: round,
          bottomLeft: out ? round : tail,
          bottomRight: out ? tail : round,
        ),
        boxShadow: c.bubbleShadow == null
            ? null
            : [
                BoxShadow(
                  color: c.bubbleShadow!,
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
              ],
      ),
      // The time sits in the bottom-right corner and the text flows around
      // it: an invisible spacer the width of the label ends the text.
      child: Stack(
        children: [
          SelectableText.rich(
            TextSpan(
              text: message.text,
              style: mgText(c),
              children: const [
                WidgetSpan(child: SizedBox(width: 40, height: 14)),
              ],
            ),
          ),
          Positioned(right: 0, bottom: -1, child: Text(time, style: timeStyle)),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _text.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final hasDraft = _text.text.trim().isNotEmpty;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: Center(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter): _send,
                  },
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    autofocus: true,
                    minLines: 1,
                    maxLines: 8,
                    style: mgText(c, size: 13.5),
                    cursorHeight: 16,
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.messageHint,
                      hintStyle: mgText(c, size: 13.5).copyWith(color: c.fg2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: hasDraft ? 1 : 0.4,
            child: Semantics(
              button: true,
              label: l10n.send,
              child: GestureDetector(
                onTap: hasDraft ? _send : null,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const DefaultTextStyle(
                    style: TextStyle(color: Colors.white),
                    child: MgIcon(MgIcons.send, size: 16, stroke: 2.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
