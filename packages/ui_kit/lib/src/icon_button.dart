import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme/colors.dart';

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
  });

  final MgIconData icon;

  /// Shown on hover and read by screen readers. Pass a localized string.
  final String tooltip;
  final VoidCallback? onPressed;

  /// A toggled state, like ghost mode being on.
  final bool selected;
  final double iconSize;

  @override
  State<MgIconButton> createState() => _MgIconButtonState();
}

class _MgIconButtonState extends State<MgIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onPressed != null;
    final hover = _hover && enabled;
    final fg = widget.selected ? c.accent : (hover ? c.fg : c.icon);
    final bg = widget.selected
        ? c.field
        : (hover ? c.hover : const Color(0x00000000));
    return Tooltip(
      message: widget.tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: enabled,
        toggled: widget.selected ? true : null,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onPressed,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: MgIcon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// The filled send button, an accent rounded square, that replaces the
/// microphone when the composer has a draft.
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

  static const double radius = 10;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onPressed,
            onSecondaryTapUp: onMenu == null
                ? null
                : (details) => onMenu!(details.globalPosition),
            onLongPressStart: onMenu == null
                ? null
                : (details) => onMenu!(details.globalPosition),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(radius),
              ),
              child: MgIcon(icon, size: 15, stroke: 1.9, color: c.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}

/// The microphone in the send button's place while there is no draft: the
/// same accent square.
class MgRecordButton extends MgSendButton {
  const MgRecordButton({super.key, required super.tooltip, super.onPressed})
    : super(icon: MgIcons.mic);
}
