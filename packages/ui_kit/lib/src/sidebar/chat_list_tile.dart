import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badge.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// A row of the chat list (`.row`). Rows are solid, never glass; the
/// selected row is filled with the accent.
class ChatListTile extends StatefulWidget {
  const ChatListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.time = '',
    this.unread = 0,
    this.unreadLabel,
    this.muted = false,
    this.selected = false,
    this.avatar,
    this.onTap,
  });

  final String title;

  /// The last message preview.
  final String subtitle;
  final String time;
  final int unread;

  /// A formatted [unread] count, such as "1.2K"; see [UnreadBadge.label].
  final String? unreadLabel;
  final bool muted;
  final bool selected;

  /// Defaults to a 42 px [MonogramAvatar] of [title].
  final Widget? avatar;
  final VoidCallback? onTap;

  static const double avatarSize = 42;

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final on = widget.selected;
    final sub = on ? c.onAccentSecondary : c.fg2;
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: on
                  ? c.accent
                  : (_hover ? c.hover : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                widget.avatar ??
                    MonogramAvatar(
                      name: widget.title,
                      size: ChatListTile.avatarSize,
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
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(
                                c,
                                size: MgType.title,
                                weight: FontWeight.w600,
                                color: on ? c.onAccent : c.fg,
                              ),
                            ),
                          ),
                          if (widget.time.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              widget.time,
                              style: mgTextStyle(
                                c,
                                size: MgType.caption,
                                color: sub,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, color: sub),
                            ),
                          ),
                          if (widget.unread > 0) ...[
                            const SizedBox(width: 6),
                            UnreadBadge(
                              count: widget.unread,
                              label: widget.unreadLabel,
                              muted: widget.muted,
                              onAccent: on,
                            ),
                          ],
                        ],
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
