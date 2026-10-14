import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// The main action of a form: a 34 px accent-filled button. While [loading]
/// it shows a spinner and ignores taps.
class MgPrimaryButton extends StatelessWidget {
  const MgPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.expand = false,
    this.height = 34,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Fills the available width.
  final bool expand;

  /// 34 in forms on glass, 42 on the sign-in screens.
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = onPressed != null && !loading;
    final button = Semantics(
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onPressed : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: enabled ? onPressed : null,
          child: Opacity(
            opacity: onPressed == null ? 0.45 : 1,
            child: Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: loading
                  ? SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.onAccent,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      style: mgTextStyle(
                        c,
                        size: MgType.title,
                        weight: FontWeight.w600,
                        color: c.onAccent,
                        height: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A secondary text action in the accent color, such as "Sign in with a
/// phone number".
class MgTextButton extends StatefulWidget {
  const MgTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  State<MgTextButton> createState() => _MgTextButtonState();
}

class _MgTextButtonState extends State<MgTextButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover && enabled ? c.hover : const Color(0x00000000),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.label,
              style: mgTextStyle(
                c,
                weight: FontWeight.w500,
                color: enabled ? c.accent : c.fg2,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
