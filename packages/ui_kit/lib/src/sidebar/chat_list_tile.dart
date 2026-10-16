import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../avatar.dart';
import '../badge.dart';
import '../chat/bubbles.dart';
import '../chat/status_text.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/metrics.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// What a chat is, for the small glyph before its title.
enum ChatRowKind { private, group, channel }

/// A row of the chat list. Rows are solid, never glass; the selected row
/// is filled with the accent.
///
/// Like the official client's dialog row, at the Stage window's metrics: a
/// 44 px avatar, then the title line (a glyph for groups and channels, a
/// lock for secret chats, the title, a verified mark, a crossed-out
/// speaker for muted chats; the delivery ticks and the time at the right).
/// Under it, who wrote last on a line of their own (with their small
/// avatar in a group, "You" for the user), then the message with
/// thumbnails of its photos or videos; without a sender the message takes
/// both lines. What someone is doing right now replaces them in the
/// accent color. The reaction, mention and unread badges sit at the bottom
/// right, or a pin when a pinned chat has nothing unread. An online user
/// gets a green dot on the avatar.
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
    this.kind = ChatRowKind.private,
    this.online = false,
    this.activity,
    this.draftLabel,
    this.sender,
    this.senderAvatar,
    this.thumbnails = const [],
    this.status = MessageStatus.none,
    this.verified = false,
    this.selected = false,
    this.menuOpen = false,
    this.highlighted = false,
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

  /// A group or a channel gets its glyph before the title.
  final ChatRowKind kind;

  /// The user of a private chat is online: a dot on the avatar.
  final bool online;

  /// What someone is doing, such as "typing"; shown instead of [subtitle].
  final String? activity;

  /// "Draft:" before [subtitle] when the chat has an unsent draft, drawn
  /// in red as the official client does.
  final String? draftLabel;

  /// Who wrote the last message: a name in a group, "You" for the user;
  /// null to give the message both lines.
  final String? sender;

  /// A small avatar before [sender], [senderAvatarSize] across.
  final Widget? senderAvatar;

  /// Tiny pictures of the last message's photos or videos, drawn before
  /// the text.
  final List<ImageProvider> thumbnails;

  /// The delivery ticks of the user's own last message, before the time.
  final MessageStatus status;

  /// Telegram verified the chat: a mark after the title.
  final bool verified;
  final bool selected;

  /// The row's context menu is open: an accent outline, as on macOS.
  final bool menuOpen;

  /// The keyboard cursor is on the row (arrow keys in the search or a
  /// picker): the hover fill, so Enter's target is visible.
  final bool highlighted;

  /// Defaults to a [MonogramAvatar] of [title], [avatarSize] across.
  final Widget? avatar;
  final VoidCallback? onTap;

  /// A secondary click or a long press, with its global position.
  final ValueChanged<Offset>? onContextMenu;

  static const double avatarSize = 50;
  static const double senderAvatarSize = 15;

  static const double _titleLine = 19;
  static const double _line = 17;

  /// The title line, a 1 px gap and the two lines under it.
  static const double _content = _titleLine + 1 + 2 * _line;

  /// The menu outline, drawn over the row's padding.
  static const double _ring = 1.5;

  /// The height of every row, including the 1 px gap below it; the list
  /// lays rows out at this fixed extent. 70 tall rows with 50 avatars, as
  /// in TelegramSwift.
  static const double extent = _content + 2 * 8 + 1;

  /// [extent] for the density in [context]: compact rows are shorter.
  static double extentOf(BuildContext context) =>
      _content + 2 * MgMetrics.of(context).rowPadding + 1;

  /// The online dot's green.
  static const Color onlineGreen = Color(0xFF34C759);

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  bool _hover = false;

  /// The primary button is down on the row: the fill deepens at once, so
  /// the row answers the press, not the release.
  bool _pressed = false;

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
    final faint = on ? c.onAccentSecondary : c.muted;
    final icon = on ? c.onAccentSecondary : c.fg2;
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
              padding: const EdgeInsets.only(right: 2, bottom: 3),
              child: MgIcon(MgIcons.pin, size: 12, color: faint),
            ),
          ]
        : badges;
    final kindIcon = switch (widget.kind) {
      ChatRowKind.private => null,
      ChatRowKind.group => MgIcons.group,
      ChatRowKind.channel => MgIcons.channel,
    };

    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == 1) setState(() => _pressed = true);
          },
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onTapCancel: () => setState(() => _pressed = false),
            onSecondaryTapUp: widget.onContextMenu == null
                ? null
                : (details) => widget.onContextMenu!(details.globalPosition),
            onLongPressStart: widget.onContextMenu == null
                ? null
                : (details) => widget.onContextMenu!(details.globalPosition),
            child: AnimatedContainer(
              duration: _pressed ? MgMotion.press : MgMotion.fast,
              curve: MgMotion.standardCurve,
              margin: const EdgeInsets.only(bottom: 1),
              padding: EdgeInsets.fromLTRB(
                8,
                metrics.rowPadding,
                10,
                metrics.rowPadding,
              ),
              decoration: BoxDecoration(
                color: on
                    ? c.selected
                    : _pressed
                    ? Color.alphaBlend(c.hover, c.hover)
                    : (_hover || widget.menuOpen || widget.highlighted
                          ? c.hover
                          : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(10),
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.menuOpen && !on
                      ? c.accent
                      : const Color(0x00000000),
                  width: ChatListTile._ring,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: ChatListTile._titleLine,
                          child: Row(
                            children: [
                              if (kindIcon != null) ...[
                                MgIcon(kindIcon, size: 12, color: icon),
                                const SizedBox(width: 4),
                              ],
                              if (widget.secret) ...[
                                MgIcon(
                                  MgIcons.lock,
                                  size: 12,
                                  stroke: 2.2,
                                  color: on ? c.onAccent : c.fg,
                                ),
                                const SizedBox(width: 4),
                              ],
                              // The title and its marks take what the time
                              // leaves; a long title ellipsizes before them.
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        widget.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: mgTextStyle(
                                          c,
                                          size: MgType.body,
                                          weight: MgWeight.semibold,
                                          height: 1.3,
                                          color: on ? c.onAccent : c.fg,
                                        ),
                                      ),
                                    ),
                                    if (widget.verified)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: VerifiedMark(
                                          size: 13,
                                          onAccent: on,
                                        ),
                                      ),
                                    _Appear(
                                      visible: widget.muted,
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: MgIcon(
                                          MgIcons.muted,
                                          size: 11,
                                          stroke: 2.2,
                                          color: faint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.time.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _Ticks(status: widget.status, selected: on),
                                Padding(
                                  padding: const EdgeInsets.only(left: 2),
                                  child: Text(
                                    widget.time,
                                    style: mgTextStyle(
                                      c,
                                      size: MgType.caption,
                                      color: on ? c.onAccentSecondary : c.muted,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 2 * ChatListTile._line,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: _preview(c, on),
                                ),
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
      ),
    );
  }

  /// The two lines under the title: what someone is doing; or who wrote
  /// last and the message on one line each; or the message on both.
  Widget _preview(MgColors c, bool on) {
    const size = MgType.small;
    // Grey under a dark title, as in TelegramSwift; in dark themes the
    // muted grey is too dim for two lines of text.
    final grey = on ? c.onAccentSecondary : (c.isDark ? c.fg2 : c.muted);
    final activity = widget.activity;
    if (activity != null) {
      return MgStatusText(activity, activity: true, size: size, color: grey);
    }
    final sender = widget.draftLabel == null ? widget.sender : null;
    final thumbnails = widget.thumbnails;
    final text = MgStatusText(
      widget.subtitle,
      lead: widget.draftLabel,
      leadColor: on ? c.onAccent : MgColors.draftRed,
      size: size,
      lineHeight: ChatListTile._line / size,
      color: grey,
      maxLines: sender == null ? 2 : 1,
      leading: thumbnails.isEmpty
          ? null
          : Row(
              key: ValueKey(thumbnails.length),
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, image) in thumbnails.indexed)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image(
                        image: image,
                        width: 16,
                        height: 16,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
    );
    if (sender == null) return text;
    final senderAvatar = widget.senderAvatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: ChatListTile._line,
          child: Row(
            children: [
              if (senderAvatar != null) ...[
                SizedBox.square(
                  dimension: ChatListTile.senderAvatarSize,
                  child: senderAvatar,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(
                    c,
                    size: size,
                    color: on ? c.onAccent : c.fg,
                    height: ChatListTile._line / size,
                  ),
                ),
              ),
            ],
          ),
        ),
        text,
      ],
    );
  }
}

/// The delivery ticks before the time of a row whose last message is the
/// user's own: one tick sent, two read, a clock on its way, red failed.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.status, required this.selected});

  final MessageStatus status;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final (icon, color) = switch (status) {
      MessageStatus.none => (null, null),
      MessageStatus.sending => (
        MgIcons.sending,
        selected ? c.onAccentSecondary : c.fg2,
      ),
      MessageStatus.sent => (MgIcons.sent, selected ? c.onAccent : c.accent),
      MessageStatus.read => (
        MgIcons.readTicks,
        selected ? c.onAccent : c.accent,
      ),
      MessageStatus.failed => (MgIcons.failed, MessageMeta.failedColor),
    };
    if (icon == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: MgIcon(icon, size: 13, stroke: 1.6, color: color),
    );
  }
}

/// The blue rosette with a white tick after a verified chat's title.
class VerifiedMark extends StatelessWidget {
  const VerifiedMark({super.key, this.size = 14, this.onAccent = false});

  final double size;

  /// Inverted colors for a selected (accent-filled) row.
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _VerifiedPainter(
          fill: onAccent ? c.onAccent : c.accent,
          tick: onAccent ? c.accent : c.onAccent,
        ),
      ),
    );
  }
}

class _VerifiedPainter extends CustomPainter {
  _VerifiedPainter({required this.fill, required this.tick});

  final Color fill;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final center = Offset(size.width / 2, size.height / 2);
    // A twelve-point rosette: radii alternate between the points and the
    // notches between them.
    final rosette = Path();
    for (var i = 0; i < 24; i++) {
      final r = (i.isEven ? 11.0 : 9.4) * s;
      final a = i * math.pi / 12 - math.pi / 2;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? rosette.moveTo(p.dx, p.dy) : rosette.lineTo(p.dx, p.dy);
    }
    rosette.close();
    canvas.drawPath(rosette, Paint()..color = fill);
    canvas.drawPath(
      Path()
        ..moveTo(7.6 * s, 12.2 * s)
        ..lineTo(10.6 * s, 15.1 * s)
        ..lineTo(16.4 * s, 9.2 * s),
      Paint()
        ..color = tick
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 * s
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_VerifiedPainter old) =>
      old.fill != fill || old.tick != tick;
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
                  color: ChatListTile.onlineGreen,
                  border: Border.all(
                    color: selected ? c.selected : c.frame,
                    width: 2,
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
