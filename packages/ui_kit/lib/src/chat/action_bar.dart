import 'package:flutter/widgets.dart';

import '../glass/glass.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// What stands in for the composer when the user can't write in a chat:
/// one action across the whole bar, such as joining a channel or muting
/// it, as in Telegram for macOS.
class ComposerActionBar extends StatefulWidget {
  const ComposerActionBar({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The action is on its way; the bar waits and the label dims.
  final bool loading;

  @override
  State<ComposerActionBar> createState() => _ComposerActionBarState();
}

class _ComposerActionBarState extends State<ComposerActionBar> {
  var _hover = false;
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onPressed != null && !widget.loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _down ? 0.985 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Glass(
              radius: 22,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 44,
                alignment: Alignment.center,
                color: _hover && enabled ? c.hover : const Color(0x00000000),
                child: AnimatedOpacity(
                  opacity: widget.loading ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    widget.label,
                    style: mgTextStyle(
                      c,
                      weight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
