import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/tokens.dart';

/// What a [MgPressable] knows about its state, for its builder.
class MgPressState {
  const MgPressState({
    required this.hovered,
    required this.pressed,
    required this.focused,
  });

  final bool hovered;
  final bool pressed;

  /// Keyboard focus only; a click does not show the ring.
  final bool focused;
}

/// The one way a control responds to the pointer: it reacts on pointer
/// down (not on release), sinks a hair while pressed and springs back,
/// shows a focus ring for the keyboard, and is activated by Space and Enter.
///
/// Reduced motion keeps the colour feedback and drops the scale.
class MgPressable extends StatefulWidget {
  const MgPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onSecondaryTapUp,
    this.semanticsLabel,
    this.cursor,
    this.scale = MgMotion.pressScale,
    this.focusRadius = MgRadius.control,
    this.focusable = true,
    this.toggled,
  });

  final Widget Function(BuildContext context, MgPressState state) builder;
  final VoidCallback? onTap;
  final GestureTapUpCallback? onSecondaryTapUp;
  final String? semanticsLabel;
  final MouseCursor? cursor;

  /// Scale while pressed; 1 turns the sink off (large rows).
  final double scale;

  /// Corner radius of the focus ring.
  final double focusRadius;
  final bool focusable;

  /// A toggle's state for screen readers; null for a plain button.
  final bool? toggled;

  @override
  State<MgPressable> createState() => _MgPressableState();
}

class _MgPressableState extends State<MgPressable> {
  bool _hover = false;
  bool _pressed = false;
  bool _focus = false;

  late final FocusNode _focusNode = FocusNode(
    debugLabel: 'MgPressable',
    canRequestFocus: _focusable,
    skipTraversal: !_focusable,
  );

  bool get _enabled => widget.onTap != null;

  bool get _focusable => widget.focusable && _enabled;

  @override
  void didUpdateWidget(MgPressable old) {
    super.didUpdateWidget(old);
    _focusNode
      ..canRequestFocus = _focusable
      ..skipTraversal = !_focusable;
    if (!_enabled) {
      _hover = false;
      _pressed = false;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final pressed = _pressed && _enabled;
    final child = widget.builder(
      context,
      MgPressState(
        hovered: _hover && _enabled,
        pressed: pressed,
        focused: _focus,
      ),
    );
    final scaled = widget.scale == 1 || still
        ? child
        : AnimatedScale(
            scale: pressed ? widget.scale : 1,
            duration: pressed ? MgMotion.press : MgMotion.settleDuration,
            curve: pressed ? Curves.easeOut : MgMotion.spring,
            child: child,
          );
    return Semantics(
      button: true,
      enabled: _enabled,
      toggled: widget.toggled,
      label: widget.semanticsLabel,
      onTap: widget.onTap,
      excludeSemantics: widget.semanticsLabel != null,
      child: FocusableActionDetector(
        // Always on: switching it off rewraps the subtree and drops the
        // state below (a label to spinner cross-fade, say). Without a tap
        // the node takes no focus and the actions do nothing.
        enabled: true,
        focusNode: _focusNode,
        mouseCursor:
            widget.cursor ??
            (_enabled ? SystemMouseCursors.click : MouseCursor.defer),
        onShowHoverHighlight: (v) => _set(() => _hover = v),
        onShowFocusHighlight: (v) => _set(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: (e) {
            if (e.buttons == kPrimaryButton) _set(() => _pressed = true);
          },
          onPointerUp: (_) => _set(() => _pressed = false),
          onPointerCancel: (_) => _set(() => _pressed = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            // A drag or a scroll that wins the gesture cancels the tap: the
            // control lets go then, not when the pointer is lifted.
            onTapCancel: () => _set(() => _pressed = false),
            onSecondaryTapUp: widget.onSecondaryTapUp,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.focusRadius),
                border: Border.all(
                  color: _focus
                      ? c.accent.withValues(alpha: 0.7)
                      : const Color(0x00000000),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
              ),
              child: scaled,
            ),
          ),
        ),
      ),
    );
  }
}
