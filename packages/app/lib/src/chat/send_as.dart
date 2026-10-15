import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'describe.dart';
import 'message_tile.dart' show SenderAvatar;

/// Who the user posts as, at the left of the composer, where Telegram
/// offers a choice: a group the user owns a channel in, or a channel's
/// comments. The avatar is the identity in use; a click lists the others,
/// as the official client's "Send as" picker does.
class SendAsButton extends StatelessWidget {
  const SendAsButton({
    super.key,
    required this.chatId,
    required this.sender,
    required this.store,
    required this.conversations,
  });

  final int chatId;
  final td.MessageSender sender;
  final ConversationStore store;
  final ConversationController conversations;

  static const double _side = 28;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final position = box.localToGlobal(Offset(0, -8));
    final List<td.ChatMessageSender> senders;
    try {
      senders = await conversations.availableSenders(chatId);
    } on Object {
      return;
    }
    if (!context.mounted || senders.isEmpty) return;
    await showMgPopover(
      context,
      position: position,
      child: _SendAsList(
        senders: senders,
        current: MessageSenderId.of(sender),
        store: store,
        onPick: (picked) =>
            unawaited(conversations.setMessageSender(chatId, picked)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = MessageSenderId.of(sender);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Tooltip(
        message: l10n.sendAs,
        excludeFromSemantics: true,
        child: Semantics(
          button: true,
          label: l10n.sendAs,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              key: const ValueKey('sendAs'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_open(context)),
              child: SizedBox.square(
                dimension: 32,
                child: Center(
                  child: SenderAvatar(
                    name: nameOfSender(l10n, store, id),
                    photo: store.photoOf(id),
                    size: _side,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SendAsList extends StatelessWidget {
  const _SendAsList({
    required this.senders,
    required this.current,
    required this.store,
    required this.onPick,
  });

  final List<td.ChatMessageSender> senders;
  final MessageSenderId current;
  final ConversationStore store;
  final ValueChanged<td.MessageSender> onPick;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Glass(
      radius: 12,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280, maxHeight: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Text(
                l10n.sendAs,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  color: c.fg2,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in senders)
                    _SendAsRow(
                      entry: entry,
                      store: store,
                      chosen: MessageSenderId.of(entry.sender) == current,
                      onTap: entry.needsPremium
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              if (MessageSenderId.of(entry.sender) != current) {
                                onPick(entry.sender);
                              }
                            },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendAsRow extends StatefulWidget {
  const _SendAsRow({
    required this.entry,
    required this.store,
    required this.chosen,
    required this.onTap,
  });

  final td.ChatMessageSender entry;
  final ConversationStore store;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  State<_SendAsRow> createState() => _SendAsRowState();
}

class _SendAsRowState extends State<_SendAsRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final id = MessageSenderId.of(widget.entry.sender);
    final enabled = widget.onTap != null;
    final subtitle = widget.entry.needsPremium
        ? l10n.sendAsPremium
        : id.isChat
        ? l10n.sendAsChannel
        : l10n.sendAsPersonal;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: _hover && enabled ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Row(
              children: [
                SenderAvatar(
                  name: nameOfSender(l10n, widget.store, id),
                  photo: widget.store.photoOf(id),
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nameOfSender(l10n, widget.store, id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          weight: widget.chosen
                              ? FontWeight.w600
                              : FontWeight.w400,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          size: MgType.caption,
                          color: c.fg2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.chosen) ...[
                  const SizedBox(width: 8),
                  MgIcon(MgIcons.check, size: 14, color: c.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
