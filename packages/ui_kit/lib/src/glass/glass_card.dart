import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';
import 'glass.dart';

/// A floating glass card on the wallpaper, like the sign-in card. Same
/// material as the sidebar island; use it only on the floating layer.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;

  /// A fixed width; otherwise the card hugs its content.
  final double? width;
  final EdgeInsetsGeometry padding;

  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox(
      width: width,
      child: Glass(
        radius: radius,
        padding: padding,
        child: DefaultTextStyle.merge(style: mgTextStyle(c), child: child),
      ),
    );
  }
}
