import 'package:flutter/widgets.dart';

import '../avatar.dart';
import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'status_text.dart';

/// The chat header: two glass capsules over the message list, the title on
/// the left and the actions on the right. [fill] takes the space between
/// them (the app puts its window drag area there).
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

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomMultiChildLayout(
        delegate: _HeaderLayout(),
        children: [
          LayoutId(id: _Slot.actions, child: actions),
          LayoutId(id: _Slot.title, child: title),
          if (fill != null) LayoutId(id: _Slot.fill, child: fill!),
        ],
      ),
    );
  }
}

enum _Slot { title, fill, actions }

/// Actions keep their natural width at the right edge, the title takes its
/// natural width and shrinks only when there is no room, and the fill gets
/// whatever is left between them.
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
    final title = layoutChild(
      _Slot.title,
      BoxConstraints(maxWidth: titleMax, minHeight: h, maxHeight: h),
    );
    positionChild(_Slot.title, Offset.zero);

    if (hasChild(_Slot.fill)) {
      final w = (size.width - actions.width - title.width).clamp(
        0.0,
        size.width,
      );
      layoutChild(_Slot.fill, BoxConstraints.tightFor(width: w, height: h));
      positionChild(_Slot.fill, Offset(title.width, 0));
    }
  }

  @override
  bool shouldRelayout(_HeaderLayout oldDelegate) => false;
}

/// The left capsule: avatar, chat name and status line.
class ChatTitleCapsule extends StatelessWidget {
  const ChatTitleCapsule({
    super.key,
    required this.title,
    this.subtitle = '',
    this.subtitleAccent = false,
    this.subtitleActivity = false,
    this.avatar,
    this.onTap,
  });

  final String title;

  /// Online status, members count, "typing…" and so on.
  final String subtitle;

  /// Draws [subtitle] in the accent color, as for "online".
  final bool subtitleAccent;

  /// [subtitle] is what someone is doing, such as "typing": it is drawn in
  /// the accent color with animated dots.
  final bool subtitleActivity;

  /// Defaults to a 32 px [MonogramAvatar] of [title].
  final Widget? avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Glass(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            avatar ?? MonogramAvatar(name: title, size: 32),
            const SizedBox(width: 9),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      size: MgType.title,
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
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
                            accent: subtitleAccent || subtitleActivity,
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

/// The right capsule: a row of [MgIconButton]s, 2 px apart.
class ChatActionsCapsule extends StatelessWidget {
  const ChatActionsCapsule({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            children[i],
          ],
        ],
      ),
    );
  }
}
