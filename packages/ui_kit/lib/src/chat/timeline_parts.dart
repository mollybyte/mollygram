import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../badge.dart';
import '../glass/glass.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The band above the first message the user hadn't read when they opened
/// the chat, as in Telegram for macOS. It spans the whole timeline.
class UnreadDivider extends StatelessWidget {
  const UnreadDivider(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        height: 26,
        alignment: Alignment.center,
        color: c.datePill,
        child: Text(
          label,
          style: mgTextStyle(
            c,
            size: MgType.small,
            weight: FontWeight.w500,
            color: const Color(0xFFFFFFFF),
            height: 1.2,
          ),
        ),
      ),
    );
  }
}

/// A round glass button floating over the bottom right of the timeline:
/// scroll to the bottom, the next mention or the next reaction. [count]
/// sits on top of it when not zero; it fades and scales in and out with
/// [visible].
class JumpButton extends StatefulWidget {
  const JumpButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.count = 0,
    this.countLabel,
    this.visible = true,
  });

  final MgIconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final int count;

  /// Shown instead of [count], such as a compact "1.2K".
  final String? countLabel;
  final bool visible;

  static const double size = 40;

  @override
  State<JumpButton> createState() => _JumpButtonState();
}

class _JumpButtonState extends State<JumpButton> {
  var _hover = false;
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final scale = !widget.visible
        ? 0.8
        : _down
        ? 0.92
        : (_hover ? 1.04 : 1.0);
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Tooltip(
            message: widget.tooltip,
            excludeFromSemantics: true,
            child: Semantics(
              button: true,
              label: widget.tooltip,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hover = true),
                onExit: (_) => setState(() => _hover = false),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _down = true),
                  onTapUp: (_) => setState(() => _down = false),
                  onTapCancel: () => setState(() => _down = false),
                  onTap: widget.onPressed,
                  child: SizedBox(
                    width: JumpButton.size,
                    height: JumpButton.size + 9,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Glass(
                          radius: JumpButton.size / 2,
                          child: SizedBox.square(
                            dimension: JumpButton.size,
                            child: Center(
                              child: MgIcon(
                                widget.icon,
                                size: 20,
                                color: _hover ? c.fg : c.fg2,
                              ),
                            ),
                          ),
                        ),
                        if (widget.count > 0)
                          Positioned(
                            top: 0,
                            child: UnreadBadge(
                              count: widget.count,
                              label: widget.countLabel,
                            ),
                          ),
                      ],
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

/// Lights up [child] for a moment each time [flash] grows, to show the
/// message a jump landed on.
class MessageFlash extends StatefulWidget {
  const MessageFlash({super.key, required this.flash, required this.child});

  /// Bumped by the app for each new flash; 0 is none.
  final int flash;
  final Widget child;

  @override
  State<MessageFlash> createState() => _MessageFlashState();
}

class _MessageFlashState extends State<MessageFlash>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.flash > 0) unawaited(_controller.forward(from: 0));
  }

  @override
  void didUpdateWidget(MessageFlash old) {
    super.didUpdateWidget(old);
    if (widget.flash > old.flash) unawaited(_controller.forward(from: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Quick to light, held, then a long calm fade.
        final strength = !_controller.isAnimating && t == 0
            ? 0.0
            : t < 0.1
            ? t / 0.1
            : t < 0.35
            ? 1.0
            : 1 - Curves.easeInOut.transform((t - 0.35) / 0.65);
        if (strength <= 0) return child!;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.16 * strength),
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
