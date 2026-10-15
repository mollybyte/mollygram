import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// What the translation bar offers or says.
enum TranslateBarState {
  /// The chat is in another language: "Translate to English".
  offer,

  /// Messages are on their way: "Translating…".
  working,

  /// The chat is translated: "Translated from Russian · Show original".
  shown,
}

/// The slim bar under the chat header that translates the whole chat, as
/// in Telegram for macOS: a glass capsule with the action in the middle
/// and the options behind three dots. The text fades between its states.
class ChatTranslateBar extends StatelessWidget {
  const ChatTranslateBar({
    super.key,
    required this.state,
    required this.primary,
    this.secondary,
    required this.optionsTooltip,
    required this.onPrimary,
    required this.onOptions,
  });

  final TranslateBarState state;

  /// The action, in the accent color: "Translate to English" or "Show
  /// original", and "Translating…" while it works.
  final String primary;

  /// What the chat is, such as "Translated from Russian", before the action
  /// while it is [TranslateBarState.shown].
  final String? secondary;
  final String optionsTooltip;
  final VoidCallback onPrimary;

  /// The options button was pressed, at [position] in global coordinates,
  /// where the menu opens.
  final void Function(Offset position) onOptions;

  static const double height = 36;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return BarStrip(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: KeyedSubtree(
                  key: ValueKey((state, primary, secondary)),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (secondary case final secondary?) ...[
                          Flexible(
                            child: Text(
                              secondary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(
                                c,
                                weight: FontWeight.w400,
                                color: c.fg2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: state == TranslateBarState.working
                              ? Text(
                                  primary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: mgTextStyle(
                                    c,
                                    weight: FontWeight.w400,
                                    color: c.fg2,
                                  ),
                                )
                              : _Action(label: primary, onTap: onPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _Dots(tooltip: optionsTooltip, onTap: onOptions),
          ],
        ),
      ),
    );
  }
}

/// The accent text button: it dims a little under the pointer.
class _Action extends StatefulWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: _hover ? 0.7 : 1,
          duration: const Duration(milliseconds: 120),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mgTextStyle(c, weight: FontWeight.w500, color: c.accent),
          ),
        ),
      ),
    );
  }
}

/// The three-dots button for the options.
class _Dots extends StatefulWidget {
  const _Dots({required this.tooltip, required this.onTap});

  final String tooltip;
  final void Function(Offset position) onTap;

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
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
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) => widget.onTap(details.globalPosition),
            child: SizedBox.square(
              dimension: ChatTranslateBar.height - 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hover ? c.hover : const Color(0x00000000),
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(14, 4),
                    painter: _DotsPainter(c.fg2),
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

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(2 + i * 5, size.height / 2), 1.6, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.color != color;
}
