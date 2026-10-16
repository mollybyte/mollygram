import 'package:flutter/widgets.dart';

import '../theme/colors.dart';

/// The shared surface of the bars under the chat header (pinned message,
/// translation, saved tags): a solid strip in the card colour that spans
/// the chat, tinted a shade off the card so it reads as its own band, with
/// a hairline below it. No glass, no floating capsule.
class BarStrip extends StatelessWidget {
  const BarStrip({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          c.fg.withValues(alpha: c.isDark ? 0.07 : 0.04),
          c.solid(c.card),
        ),
        border: Border(bottom: BorderSide(color: c.separator, width: 1)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
