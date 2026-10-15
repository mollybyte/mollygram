import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'message_menu.dart';

/// The round check at the left of a message while messages are being
/// selected, as in Telegram for macOS: a thin ring, filled with the accent
/// and a tick once [selected].
class SelectCheck extends StatelessWidget {
  const SelectCheck({super.key, required this.selected});

  final bool selected;

  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: c.fg2.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1 : 0.4,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                ),
                child: CustomPaint(painter: _TickPainter(c.onAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  const _TickPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.68)
      ..lineTo(s * 0.73, s * 0.36);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.color != color;
}

/// A command of the [SelectionBar].
@immutable
class SelectionBarAction {
  const SelectionBarAction({
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;

  /// Null when the command doesn't apply to what is selected; the label
  /// then dims.
  final VoidCallback? onPressed;
  final bool destructive;
}

/// The bar in place of the composer while messages are selected: a close
/// button and the count on the left, the commands on the right.
class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.countLabel,
    required this.actions,
    required this.closeTooltip,
    required this.onClose,
  });

  final String countLabel;
  final List<SelectionBarAction> actions;
  final String closeTooltip;
  final VoidCallback onClose;

  static const double height = 44;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Glass(
      radius: height / 2,
      padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            MgIconButton(
              icon: MgIcons.close,
              tooltip: closeTooltip,
              iconSize: 15,
              onPressed: onClose,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                countLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: 4),
              _BarButton(action: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarButton extends StatefulWidget {
  const _BarButton({required this.action});

  final SelectionBarAction action;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final action = widget.action;
    final enabled = action.onPressed != null;
    final color = action.destructive ? MgDestructive.color : c.accent;
    return Semantics(
      button: true,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover && enabled ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              action.label,
              style: mgTextStyle(
                c,
                weight: FontWeight.w600,
                color: enabled ? color : c.fg2.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
