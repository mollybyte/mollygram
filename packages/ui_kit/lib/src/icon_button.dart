import 'package:flutter/material.dart';

import 'forms/pressable.dart';
import 'icons.dart';
import 'theme/colors.dart';
import 'theme/tokens.dart';

/// A round 32 px icon button (`.ib` in the mockup): secondary color at rest,
/// a hover fill, the accent with a field fill when [selected].
class MgIconButton extends StatefulWidget {
  const MgIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
    this.iconSize = 17,
    this.size = 32,
    this.quiet = false,
  });

  final MgIconData icon;

  /// Shown on hover and read by screen readers. Pass a localized string.
  final String tooltip;
  final VoidCallback? onPressed;

  /// A toggled state, like ghost mode being on.
  final bool selected;
  final double iconSize;

  /// The side of the round hit area and hover fill.
  final double size;

  /// Rest in the lighter [MgColors.quiet] grey, as the composer's buttons.
  final bool quiet;

  @override
  State<MgIconButton> createState() => _MgIconButtonState();
}

class _MgIconButtonState extends State<MgIconButton> {
  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: MgPressable(
        onTap: widget.onPressed,
        semanticsLabel: widget.tooltip,
        toggled: widget.selected ? true : null,
        focusRadius: widget.size / 2,
        scale: 0.92,
        builder: (context, st) {
          final hover = st.hovered;
          final fg = widget.selected
              ? c.accent
              : (hover ? c.fg : (widget.quiet ? c.quiet : c.icon));
          final bg = widget.selected
              ? c.field
              : (st.pressed || hover ? c.hover : const Color(0x00000000));
          return AnimatedContainer(
            duration: MgMotion.fast,
            curve: MgMotion.standardCurve,
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: MgIcon(widget.icon, size: widget.iconSize, color: fg),
          );
        },
      ),
    );
  }
}

/// The composer's action: a 32 px accent rounded square with a white glyph,
/// which is the send arrow while there is a draft and the microphone
/// otherwise ([MgSendButton] and [MgRecordButton]). Both draw the same
/// square, so the composer can morph one glyph into the other in place.
class _ActionSquare extends StatelessWidget {
  const _ActionSquare({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onMenu,
  });

  final MgIconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final void Function(Offset position)? onMenu;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: GestureDetector(
        onLongPressStart: onMenu == null
            ? null
            : (details) => onMenu!(details.globalPosition),
        child: MgPressable(
          onTap: onTap,
          onSecondaryTapUp: onMenu == null
              ? null
              : (details) => onMenu!(details.globalPosition),
          semanticsLabel: tooltip,
          focusRadius: MgSendButton.radius,
          builder: (context, st) => AnimatedContainer(
            duration: MgMotion.fast,
            curve: MgMotion.standardCurve,
            width: MgSendButton.size,
            height: MgSendButton.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(
                c.accent,
                c.onAccent,
                st.pressed ? 0.12 : (st.hovered ? 0.06 : 0),
              ),
              borderRadius: BorderRadius.circular(MgSendButton.radius),
            ),
            child: MgIcon(icon, size: 18, stroke: 2, color: c.onAccent),
          ),
        ),
      ),
    );
  }
}

/// The send half of the composer's action, shown while there is a draft.
class MgSendButton extends StatelessWidget {
  const MgSendButton({
    super.key,
    required this.tooltip,
    this.icon = MgIcons.send,
    this.onPressed,
    this.onMenu,
  });

  final String tooltip;
  final MgIconData icon;
  final VoidCallback? onPressed;

  /// A right click or a long press, with where it happened: the place for
  /// a menu of other ways to send, such as without sound or later.
  final void Function(Offset position)? onMenu;

  static const double size = 32;
  static const double radius = 10;

  /// The height of a composer row, which the 32 px action sits centred in.
  static const double rowHeight = 36;

  @override
  Widget build(BuildContext context) => _ActionSquare(
    icon: icon,
    tooltip: tooltip,
    onTap: onPressed,
    onMenu: onMenu,
  );
}

/// The microphone half of the composer's action, shown while there is no
/// draft.
class MgRecordButton extends StatelessWidget {
  const MgRecordButton({super.key, required this.tooltip, this.onPressed});

  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) =>
      _ActionSquare(icon: MgIcons.mic, tooltip: tooltip, onTap: onPressed);
}
