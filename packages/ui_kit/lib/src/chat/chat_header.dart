import 'package:flutter/widgets.dart';

import '../avatar.dart';
import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

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
      child: Row(
        children: [
          Flexible(child: title),
          Expanded(child: fill ?? const SizedBox()),
          actions,
        ],
      ),
    );
  }
}

/// The left capsule: avatar, chat name and status line.
class ChatTitleCapsule extends StatelessWidget {
  const ChatTitleCapsule({
    super.key,
    required this.title,
    this.subtitle = '',
    this.avatar,
    this.onTap,
  });

  final String title;

  /// Online status, members count, "typing…" and so on.
  final String subtitle;

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
                  if (subtitle.isNotEmpty)
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
