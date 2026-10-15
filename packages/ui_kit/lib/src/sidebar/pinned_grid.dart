import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badge.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The pinned chats as a grid of avatars over the chat list, four to a
/// row, each with its name under it.
class PinnedChatGrid extends StatelessWidget {
  const PinnedChatGrid({super.key, required this.children});

  /// Usually [PinnedChatTile]s.
  final List<Widget> children;

  static const int columns = 4;

  /// The most pinned chats the grid shows; the rest stay in the list.
  static const int capacity = 8;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[
      for (var i = 0; i < children.length; i += columns)
        children.sublist(i, (i + columns).clamp(0, children.length)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        children: [
          for (final row in rows)
            Row(
              children: [
                for (var i = 0; i < columns; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(child: i < row.length ? row[i] : const SizedBox()),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// One pinned chat: a 40 px avatar with its name under it. The open chat
/// gets an accent ring; unread messages a badge at the avatar's corner,
/// cut out of the frame by a ring of the frame's colour.
class PinnedChatTile extends StatefulWidget {
  const PinnedChatTile({
    super.key,
    required this.title,
    this.avatar,
    this.unread = 0,
    this.unreadLabel,
    this.markedUnread = false,
    this.mentions = false,
    this.muted = false,
    this.online = false,
    this.selected = false,
    this.menuOpen = false,
    this.onTap,
    this.onContextMenu,
  });

  final String title;

  /// Defaults to a [MonogramAvatar] of [title].
  final Widget? avatar;
  final int unread;

  /// A formatted [unread] count, such as "1.2K".
  final String? unreadLabel;
  final bool markedUnread;
  final bool mentions;
  final bool muted;
  final bool online;
  final bool selected;

  /// The tile's context menu is open: an accent outline, as on macOS.
  final bool menuOpen;
  final VoidCallback? onTap;

  /// A secondary click or a long press, with its global position.
  final ValueChanged<Offset>? onContextMenu;

  static const double avatarSize = 40;

  @override
  State<PinnedChatTile> createState() => _PinnedChatTileState();
}

class _PinnedChatTileState extends State<PinnedChatTile> {
  var _hover = false;

  static const _ease = Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final on = widget.selected;
    final badge = widget.mentions
        ? const GlyphBadge.mention()
        : (widget.unread > 0 || widget.markedUnread)
        ? UnreadBadge(
            count: widget.unread,
            label: widget.unreadLabel,
            muted: widget.muted,
          )
        : null;
    return Semantics(
      button: true,
      selected: on,
      label: widget.title,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onSecondaryTapUp: widget.onContextMenu == null
              ? null
              : (details) => widget.onContextMenu!(details.globalPosition),
          onLongPressStart: widget.onContextMenu == null
              ? null
              : (details) => widget.onContextMenu!(details.globalPosition),
          child: AnimatedContainer(
            duration: _ease,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
            decoration: BoxDecoration(
              color: _hover || widget.menuOpen
                  ? c.hover
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.menuOpen ? c.accent : const Color(0x00000000),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: PinnedChatTile.avatarSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The ring: a frame-coloured gap, then the accent.
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: _ease,
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: on
                                    ? c.accent
                                    : c.accent.withValues(alpha: 0),
                                spreadRadius: on ? 4 : 2,
                              ),
                              BoxShadow(color: c.frame, spreadRadius: 2),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child:
                            widget.avatar ??
                            MonogramAvatar(
                              name: widget.title,
                              size: PinnedChatTile.avatarSize,
                            ),
                      ),
                      if (widget.online)
                        Positioned(
                          right: -1,
                          bottom: -1,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c.accent,
                              border: Border.all(color: c.frame, width: 2.5),
                            ),
                          ),
                        ),
                      if (badge != null)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.frame,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: badge,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: mgTextStyle(
                    c,
                    size: MgType.meta,
                    color: on ? c.fg : c.fg2,
                    height: 1.25,
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
