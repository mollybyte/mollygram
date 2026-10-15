import 'package:flutter/widgets.dart';

import '../theme/colors.dart';

/// A macOS switch, 34×20, the knob sliding on a spring-like curve.
///
/// With [onChanged] it flips itself when clicked; without, it only shows
/// [value], for a row that takes the click as a whole.
class MgSwitch extends StatelessWidget {
  const MgSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _duration = Duration(milliseconds: 220);
  static const _curve = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    Widget track = AnimatedContainer(
      duration: duration,
      curve: _curve,
      width: 34,
      height: 20,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value
            ? c.accent
            : c.isDark
            ? const Color(0xFF48484C)
            : const Color(0xFFD9D9DE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: _curve,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
    final onChanged = this.onChanged;
    if (onChanged != null) {
      track = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: () => onChanged(!value), child: track),
      );
    }
    return Semantics(
      toggled: value,
      onTap: onChanged == null ? null : () => onChanged(!value),
      child: track,
    );
  }
}
