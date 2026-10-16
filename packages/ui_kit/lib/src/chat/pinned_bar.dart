import 'package:flutter/widgets.dart';

import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'bar_strip.dart';

/// The pinned message under the chat header, as in Telegram for macOS: a
/// full-width strip with a segmented indicator on the left that shows which
/// of [count] pinned messages is [index], the title and the text. A click
/// goes to the message and the bar moves on to the previous one, so the
/// text slides as they cycle.
class PinnedBar extends StatelessWidget {
  const PinnedBar({
    super.key,
    required this.title,
    required this.text,
    required this.index,
    required this.count,
    required this.onTap,
    required this.closeTooltip,
    required this.onClose,
    this.thumbnail,
    this.listTooltip,
    this.onList,
  });

  final String title;
  final String text;

  /// Which pinned message shows, 0 for the newest, up to [count] - 1.
  final int index;
  final int count;
  final VoidCallback onTap;
  final String closeTooltip;
  final VoidCallback onClose;
  final Widget? thumbnail;

  /// The list button, which opens all the pinned messages; shown when
  /// both are given.
  final String? listTooltip;
  final VoidCallback? onList;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return BarStrip(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Row(
                    children: [
                      _Indicator(index: index, count: count),
                      const SizedBox(width: 10),
                      if (thumbnail case final thumbnail?) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: SizedBox.square(
                            dimension: 26,
                            child: thumbnail,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: ClipRect(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0, 0.6),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Column(
                              key: ValueKey(index),
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: mgTextStyle(
                                    c,
                                    size: MgType.caption,
                                    weight: FontWeight.w600,
                                    color: c.accent,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: mgTextStyle(
                                    c,
                                    size: MgType.small,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onList != null && listTooltip != null)
              MgIconButton(
                icon: MgIcons.list,
                tooltip: listTooltip!,
                iconSize: 15,
                onPressed: onList,
              ),
            MgIconButton(
              icon: MgIcons.close,
              tooltip: closeTooltip,
              iconSize: 15,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to three short accent bars, stacked, the lit one marking the
/// current message; it slides as the index changes.
class _Indicator extends StatelessWidget {
  const _Indicator({required this.index, required this.count});

  final int index;
  final int count;

  static const int _max = 3;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final shown = count.clamp(1, _max);
    // The lit segment stays in the middle while the list goes on either
    // side, as in the official app.
    final lit = count <= _max
        ? index
        : index == 0
        ? 0
        : index >= count - 1
        ? _max - 1
        : 1;
    const h = 24.0;
    final segment = (h - _gap * (shown - 1)) / shown;
    return SizedBox(
      width: 2.5,
      height: h,
      child: Stack(
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              top: i * (segment + _gap),
              left: 0,
              right: 0,
              height: segment,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: i == lit ? 1 : 0.3),
                  borderRadius: BorderRadius.circular(1.25),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
