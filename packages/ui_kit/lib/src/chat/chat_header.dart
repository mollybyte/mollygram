import 'package:flutter/widgets.dart';

import '../avatar.dart';
import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The chat header: two glass capsules over the message list, the title
/// centred and the actions at the right edge. [fill] lies under both and
/// takes the whole bar but the actions (the app puts its window drag area
/// there).
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
          if (fill != null) LayoutId(id: _Slot.fill, child: fill!),
          LayoutId(id: _Slot.actions, child: actions),
          LayoutId(id: _Slot.title, child: title),
        ],
      ),
    );
  }
}

enum _Slot { title, fill, actions }

/// Actions keep their natural width at the right edge; the title takes its
/// natural width, centred in the bar while it fits between the actions'
/// mirror image and the actions, else pushed left of them, and shrinks only
/// when there is no room at all. The fill lies under the title and spans
/// everything but the actions.
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
    final centred = (size.width - title.width) / 2;
    final rightMost = size.width - actions.width - _gap - title.width;
    positionChild(_Slot.title, Offset(centred.clamp(0.0, rightMost.clamp(0.0, size.width)), 0));

    if (hasChild(_Slot.fill)) {
      final w = (size.width - actions.width).clamp(0.0, size.width);
      layoutChild(_Slot.fill, BoxConstraints.tightFor(width: w, height: h));
      positionChild(_Slot.fill, Offset.zero);
    }
  }

  @override
  bool shouldRelayout(_HeaderLayout oldDelegate) => false;
}

/// The centred capsule: avatar, chat name and, after it, the status in the
/// accent colour.
class ChatTitleCapsule extends StatelessWidget {
  const ChatTitleCapsule({
    super.key,
    required this.title,
    this.subtitle = '',
    this.avatar,
    this.titleIcon,
    this.onTap,
  });

  final String title;

  /// Drawn just before the title, such as a secret chat's lock.
  final Widget? titleIcon;

  /// Online status, members count, "typing…" and so on.
  final String subtitle;

  /// Defaults to a 28 px [MonogramAvatar] of [title].
  final Widget? avatar;
  final VoidCallback? onTap;

  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: Glass(
          radius: height / 2,
          padding: const EdgeInsets.fromLTRB(5, 0, 14, 0),
          child: SizedBox(
            height: height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: Center(
                    child: avatar ?? MonogramAvatar(name: title, size: 28),
                  ),
                ),
                const SizedBox(width: 8),
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
                      weight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        size: MgType.caption,
                        color: c.accent,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
      radius: ChatTitleCapsule.height / 2,
      padding: const EdgeInsets.all(3),
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
