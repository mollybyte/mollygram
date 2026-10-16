import 'package:flutter/widgets.dart';

import '../avatar.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'status_text.dart';

/// The chat header: a solid bar across the top of the chat card, in the
/// card's colour with a hairline under it, the title at the left edge and
/// the actions at the right. [fill] lies under both and takes the whole bar
/// but the actions (the app puts its window drag area there).
class ChatHeaderBar extends StatelessWidget {
  const ChatHeaderBar({
    super.key,
    required this.title,
    required this.actions,
    this.fill,
  });

  /// Usually a [ChatTitleCapsule].
  final Widget title;

  /// Usually a [ChatActionsCapsule].
  final Widget actions;
  final Widget? fill;

  static const double height = 50;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.solid(c.card),
        border: Border(bottom: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
        child: SizedBox(
          height: height,
          child: CustomMultiChildLayout(
            delegate: _HeaderLayout(),
            children: [
              if (fill != null) LayoutId(id: _Slot.fill, child: fill!),
              LayoutId(id: _Slot.actions, child: actions),
              LayoutId(id: _Slot.title, child: title),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Slot { title, fill, actions }

/// Actions keep their natural width at the right edge, the title takes its
/// natural width at the left and shrinks only when there is no room, and
/// the fill lies under the title and spans everything but the actions.
class _HeaderLayout extends MultiChildLayoutDelegate {
  static const double _gap = 8;

  @override
  void performLayout(Size size) {
    final h = size.height;
    final actions = layoutChild(
      _Slot.actions,
      BoxConstraints(maxWidth: size.width, minHeight: h, maxHeight: h),
    );
    positionChild(_Slot.actions, Offset(size.width - actions.width, 0));

    final titleMax = (size.width - actions.width - _gap).clamp(0.0, size.width);
    layoutChild(
      _Slot.title,
      BoxConstraints(maxWidth: titleMax, minHeight: h, maxHeight: h),
    );
    positionChild(_Slot.title, Offset.zero);

    if (hasChild(_Slot.fill)) {
      final w = (size.width - actions.width).clamp(0.0, size.width);
      layoutChild(_Slot.fill, BoxConstraints.tightFor(width: w, height: h));
      positionChild(_Slot.fill, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_HeaderLayout oldDelegate) => false;
}

/// The title at the bar's left: avatar, chat name and the status line under
/// it. It draws no fill of its own; the bar does.
class ChatTitleCapsule extends StatelessWidget {
  const ChatTitleCapsule({
    super.key,
    required this.title,
    this.subtitle = '',
    this.subtitleAccent = false,
    this.subtitleActivity = false,
    this.avatar,
    this.titleIcon,
    this.onTap,
  });

  final String title;

  /// Drawn just before the title, such as a secret chat's lock.
  final Widget? titleIcon;

  /// Online status, members count, "typing…" and so on.
  final String subtitle;

  /// Draws [subtitle] in the accent color, as for "online".
  final bool subtitleAccent;

  /// [subtitle] is what someone is doing, such as "typing": it is drawn in
  /// the secondary text colour with animated dots.
  final bool subtitleActivity;

  /// Defaults to a 30 px [MonogramAvatar] of [title].
  final Widget? avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Center(
                child: avatar ?? MonogramAvatar(name: title, size: 32),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (titleIcon case final icon?) ...[
                        icon,
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.title,
                            weight: MgWeight.semibold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // A longer or shorter status resizes the capsule
                  // smoothly; the title never waits for it.
                  AnimatedSize(
                    duration: MgStatusText.duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.centerLeft,
                    child: subtitle.isEmpty
                        ? const SizedBox.shrink()
                        : MgStatusText(
                            subtitle,
                            accent: subtitleAccent && !subtitleActivity,
                            activity: subtitleActivity,
                          ),
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

/// The actions at the bar's right edge: a row of [MgIconButton]s, 2 px
/// apart.
class ChatActionsCapsule extends StatelessWidget {
  const ChatActionsCapsule({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            children[i],
          ],
        ],
      ),
    );
  }
}
