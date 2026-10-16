import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';

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
    final button = MgPressable(
      onTap: enabled ? onPressed : null,
      semanticsLabel: label,
      focusRadius: MgRadius.control,
      builder: (context, st) => Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: AnimatedContainer(
          duration: MgMotion.fast,
          curve: MgMotion.standardCurve,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: st.pressed
                ? Color.alphaBlend(const Color(0x26000000), c.accent)
                : (st.hovered
                      ? Color.alphaBlend(const Color(0x14FFFFFF), c.accent)
                      : c.accent),
            borderRadius: BorderRadius.circular(MgRadius.control),
          ),
          // The label and the spinner cross-fade: no jump when a request
          // starts or comes back.
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : MgMotion.fast,
            child: loading
                ? SizedBox.square(
                    key: const ValueKey('spinner'),
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.onAccent,
                    ),
                  )
                : Text(
                    label,
                    key: const ValueKey('label'),
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
  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onPressed != null;
    return MgPressable(
      onTap: widget.onPressed,
      semanticsLabel: widget.label,
      scale: 0.97,
      builder: (context, st) => AnimatedContainer(
        duration: MgMotion.fast,
        curve: MgMotion.standardCurve,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: MgSpace.ml),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (st.hovered || st.pressed) && enabled
              ? c.hover
              : const Color(0x00000000),
          borderRadius: BorderRadius.circular(MgRadius.control),
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
    );
  }
}
