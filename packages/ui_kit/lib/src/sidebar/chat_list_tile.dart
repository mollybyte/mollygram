import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badge.dart';
import '../chat/status_text.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/metrics.dart';
import '../theme/theme.dart';

/// A row of the chat list (`.row`). Rows are solid, never glass; the
/// selected row is filled with the accent.
///
/// Like the official client's dialog row: a lock before the title of a
/// secret chat, a crossed-out speaker after the title of a muted one, the
/// time on the right; the last message below, or what someone is doing
/// right now in the accent color; then the reaction, mention and unread
/// badges, or a pin when a pinned chat has nothing unread. An online user
/// gets a dot on the avatar.
class ChatListTile extends StatefulWidget {
  const ChatListTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.time = '',
    this.unread = 0,
    this.unreadLabel,
    this.markedUnread = false,
    this.mentions = false,
    this.reactions = false,
    this.muted = false,
    this.pinned = false,
    this.secret = false,
    this.online = false,
    this.activity,
    this.draftLabel,
    this.selected = false,
    this.menuOpen = false,
    this.avatar,
    this.onTap,
    this.onContextMenu,
  });

  final String title;

  /// The last message preview.
  final String subtitle;
  final String time;
  final int unread;

  /// A formatted [unread] count, such as "1.2K"; see [UnreadBadge.label].
  final String? unreadLabel;

  /// The user marked the chat as unread: an empty badge when [unread] is 0.
  final bool markedUnread;

  /// Unread mentions of the user: an "@" badge.
  final bool mentions;

  /// Unread reactions to the user's messages: a heart badge.
  final bool reactions;
  final bool muted;
  final bool pinned;

  /// An end-to-end encrypted chat: a lock before the title.
  final bool secret;

  /// The user of a private chat is online: a dot on the avatar.
  final bool online;

  /// What someone is doing, such as "typing"; shown instead of [subtitle].
  final String? activity;

  /// "Draft:" before [subtitle] when the chat has an unsent draft, drawn
  /// in red as the official client does.
  final String? draftLabel;
  final bool selected;

  /// The row's context menu is open: an accent outline, as on macOS.
  final bool menuOpen;

  /// Defaults to a 42 px [MonogramAvatar] of [title].
  final Widget? avatar;
  final VoidCallback? onTap;

  /// A secondary click or a long press, with its global position.
  final ValueChanged<Offset>? onContextMenu;

  static const double avatarSize = 42;

  /// The height of every row, including the gap below it; the list lays
  /// rows out at this fixed extent.
  static const double extent = avatarSize + 2 * 8 + 1;

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  bool _hover = false;

  /// Set after the first frame: badges that are there from the start, or
  /// when the row scrolls into view, don't pop in.
  bool _settled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _settled = true);
  }

  static const _badgeDuration = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final metrics = MgMetrics.of(context);
    final on = widget.selected;
    final sub = on ? c.onAccentSecondary : c.fg2;
    final activity = widget.activity;
    final badges = <Widget>[
      if (widget.reactions)
        GlyphBadge.reaction(key: const ValueKey('reactions'), onAccent: on),
      if (widget.mentions)
        GlyphBadge.mention(key: const ValueKey('mentions'), onAccent: on),
      // A lone mention says it all: a "1" next to the "@" would repeat it.
      if ((widget.unread > 0 && !(widget.mentions && widget.unread == 1)) ||
          (widget.markedUnread && widget.unread == 0))
        UnreadBadge(
          key: const ValueKey('unread'),
          count: widget.unread,
          label: widget.unreadLabel,
          muted: widget.muted,
          onAccent: on,
        ),
    ];
    final trailing = badges.isEmpty && widget.pinned
        ? [
            Padding(
              key: const ValueKey('pin'),
              padding: const EdgeInsets.only(right: 1),
              child: MgIcon(MgIcons.pin, size: 15, color: sub),
            ),
          ]
        : badges;

    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
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
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.only(bottom: 1),
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: metrics.rowPadding,
            ),
            decoration: BoxDecoration(
              color: on
                  ? c.accent
                  : (_hover || widget.menuOpen
                        ? c.hover
                        : const Color(0x00000000)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.menuOpen && !on
                    ? c.accent
                    : const Color(0x00000000),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: Row(
              children: [
                _AvatarWithDot(
                  avatar:
                      widget.avatar ??
                      MonogramAvatar(
                        name: widget.title,
                        size: ChatListTile.avatarSize,
                      ),
                  online: widget.online,
                  selected: on,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (widget.secret) ...[
                                  MgIcon(
                                    MgIcons.lock,
                                    size: 13,
                                    stroke: 2.2,
                                    color: on ? c.onAccent : c.fg,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: mgTextStyle(
                                      c,
                                      size: MgType.title,
                                      weight: MgWeight.medium,
                                      height: 1.3,
                                      color: on ? c.onAccent : c.fg,
                                    ),
                                  ),
                                ),
                                _Appear(
                                  visible: widget.muted,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: MgIcon(
                                      MgIcons.muted,
                                      size: 13,
                                      color: on ? c.onAccentSecondary : c.muted,
                                    ),
                                  ),
                                ),
                              ],
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
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: activity != null
                                ? MgStatusText(
                                    activity,
                                    accent: true,
                                    activity: true,
                                    size: MgType.body,
                                    accentColor: on ? c.onAccent : null,
                                  )
                                : MgStatusText(
                                    widget.subtitle,
                                    lead: widget.draftLabel,
                                    leadColor: on
                                        ? c.onAccent
                                        : MgColors.draftRed,
                                    size: MgType.body,
                                    color: sub,
                                  ),
                          ),
                          AnimatedSize(
                            duration: _badgeDuration,
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final badge in trailing)
                                  Padding(
                                    key: badge.key,
                                    padding: const EdgeInsets.only(left: 4),
                                    child: _PopIn(
                                      animate: _settled,
                                      child: badge,
                                    ),
                                  ),
                              ],
                            ),
                          ),
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

/// The avatar with the online dot at its lower right, cut out of the row
/// by a ring of the row's own color. The dot springs in and shrinks away.
class _AvatarWithDot extends StatelessWidget {
  const _AvatarWithDot({
    required this.avatar,
    required this.online,
    required this.selected,
  });

  final Widget avatar;
  final bool online;
  final bool selected;

  static const double _dot = 13;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox.square(
      dimension: ChatListTile.avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -1,
            bottom: -1,
            child: AnimatedScale(
              scale: online ? 1 : 0,
              duration: Duration(milliseconds: online ? 420 : 200),
              curve: online ? Curves.elasticOut : Curves.easeInCubic,
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? c.onAccent : c.accent,
                  border: Border.all(
                    color: selected ? c.accent : c.glassSolid,
                    width: 2.5,
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

/// Grows a badge in from nothing when it appears on a row already shown.
class _PopIn extends StatefulWidget {
  const _PopIn({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> {
  late final double _from = widget.animate ? 0.4 : 1;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: _from, end: 1),
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutBack,
    builder: (context, t, child) => Opacity(
      opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
      child: Transform.scale(scale: t, child: child),
    ),
    child: widget.child,
  );
}

/// Shows [child], or nothing, sliding its width open or closed with a fade.
class _Appear extends StatelessWidget {
  const _Appear({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 200),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        axis: Axis.horizontal,
        alignment: Alignment.centerLeft,
        child: child,
      ),
    ),
    child: visible ? child : const SizedBox.shrink(),
  );
}
