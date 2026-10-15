import 'package:flutter/widgets.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// A status line, such as "online", "last seen 5 minutes ago" or
/// "Alina is typing". [accent] draws it in the accent color (online,
/// activity); [activity] adds three pulsing dots after the text, the way
/// the official client animates "typing…".
///
/// A new status cross-fades in, sliding up a little, rather than
/// replacing the old one at once.
class MgStatusText extends StatelessWidget {
  const MgStatusText(
    this.text, {
    super.key,
    this.accent = false,
    this.activity = false,
    this.size = MgType.caption,
    this.color,
    this.accentColor,
    this.lead,
    this.leadColor,
    this.leading,
    this.maxLines = 1,
    this.lineHeight,
  });

  final String text;
  final bool accent;
  final bool activity;
  final double size;

  /// The color of a plain status; defaults to the secondary text color.
  final Color? color;

  /// The color of an [accent] status; defaults to the accent.
  final Color? accentColor;

  /// A word before [text] in its own color, such as "Draft:".
  final String? lead;
  final Color? leadColor;

  /// A small widget inline before the text, such as a media thumbnail.
  final Widget? leading;

  /// The text wraps to this many lines before it is cut with an ellipsis.
  final int maxLines;

  /// The line height as a multiple of the font size; 1.2 by default.
  final double? lineHeight;

  static const Duration duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final tint = accent ? (accentColor ?? c.accent) : (color ?? c.fg2);
    final style = mgTextStyle(
      c,
      size: size,
      color: tint,
      height: lineHeight ?? 1.2,
    );
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Row(
        key: ValueKey((text, accent, activity, lead, leading?.key)),
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  if (leading case final leading?)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: leading,
                      ),
                    ),
                  if (lead case final lead?)
                    TextSpan(
                      text: '$lead ',
                      style: style.copyWith(color: leadColor ?? tint),
                    ),
                  TextSpan(text: text),
                ],
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          if (activity) TypingDots(color: tint, size: size),
        ],
      ),
    );
  }
}

/// Three dots that light up one after another, after an activity such as
/// "typing". Sized to sit on the text baseline of [size] text.
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    required this.color,
    this.size = MgType.caption,
  });

  final Color color;
  final double size;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = (widget.size * 0.2).roundToDouble().clamp(2.0, 4.0);
    return Padding(
      padding: EdgeInsets.only(left: dot * 0.75, top: widget.size * 0.35),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: dot * 0.6,
          children: [
            for (var i = 0; i < 3; i++)
              Opacity(
                opacity: _opacity(_controller.value, i),
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Each dot brightens in turn, a third of a cycle after the previous
  /// one, then fades back.
  static double _opacity(double t, int index) {
    final phase = (t - index / 3) % 1;
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + 0.7 * Curves.easeInOut.transform(wave);
  }
}
