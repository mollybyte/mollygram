import 'package:flutter/material.dart';

import '../glass/glass.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'message_menu.dart';

/// One formatting button in the compact row of a [SelectionMenu].
@immutable
class SelectionFormatButton {
  const SelectionFormatButton({
    required this.glyph,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  /// What the button shows, such as a bold B or an icon.
  final Widget Function(Color color) glyph;

  /// The format's name with its shortcut.
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;
}

/// One command of a [SelectionMenu], such as Copy, with its shortcut hint.
@immutable
class SelectionCommand {
  const SelectionCommand({
    required this.label,
    required this.onPressed,
    this.shortcut,
  });

  final String label;
  final String? shortcut;
  final VoidCallback onPressed;
}

/// The menu on a text selection in the composer: a glass popup in the
/// style of the message menu, with a compact row of formatting buttons on
/// top (when [formats] is not empty) and the clipboard commands below it.
/// It fades and scales in from the selection.
class SelectionMenu extends StatelessWidget {
  const SelectionMenu({
    super.key,
    required this.anchors,
    required this.formats,
    required this.commands,
    this.extra = const [],
  });

  final TextSelectionToolbarAnchors anchors;
  final List<SelectionFormatButton> formats;
  final List<SelectionCommand> commands;

  /// Commands after a divider, such as clearing the formatting.
  final List<SelectionCommand> extra;

  @override
  Widget build(BuildContext context) {
    final above = anchors.primaryAnchor;
    final below = anchors.secondaryAnchor ?? above;
    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: above - const Offset(0, MgSpace.m),
        anchorBelow: below + const Offset(0, MgSpace.m),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : MgMotion.fast,
        curve: MgMotion.enter,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(
            scale: 0.97 + 0.03 * t,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 232),
              child: Glass(
                dense: true,
                radius: MgRadius.card,
                // Keeps the rows' corners concentric with the panel's.
                padding: const EdgeInsets.all(MgRadius.card - MgRadius.small),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (formats.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final format in formats) _FormatButton(format),
                        ],
                      ),
                      if (commands.isNotEmpty) const _Divider(),
                    ],
                    for (final command in commands) _CommandRow(command),
                    if (extra.isNotEmpty) ...[
                      const _Divider(),
                      for (final command in extra) _CommandRow(command),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: MgSpace.xs,
      horizontal: MgSpace.m,
    ),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: MgColors.of(context).separator),
    ),
  );
}

class _FormatButton extends StatefulWidget {
  const _FormatButton(this.format);

  final SelectionFormatButton format;

  @override
  State<_FormatButton> createState() => _FormatButtonState();
}

class _FormatButtonState extends State<_FormatButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final format = widget.format;
    final color = format.active ? c.accent : c.fg;
    return Tooltip(
      message: format.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: format.onPressed,
          child: AnimatedContainer(
            duration: MgMotion.fast,
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: format.active
                  ? c.accent.withValues(alpha: 0.16)
                  : _hover
                  ? c.fg.withValues(alpha: 0.08)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(MgRadius.small),
            ),
            child: format.glyph(color),
          ),
        ),
      ),
    );
  }
}

class _CommandRow extends StatefulWidget {
  const _CommandRow(this.command);

  final SelectionCommand command;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final command = widget.command;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: command.onPressed,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: MgSpace.ml),
          // The soft fill of the context menus; the text keeps its colour.
          decoration: BoxDecoration(
            color: _hover ? menuHighlight(c) : const Color(0x00000000),
            borderRadius: BorderRadius.circular(MgRadius.small),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  command.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, height: 1.2),
                ),
              ),
              if (command.shortcut case final shortcut?) ...[
                const SizedBox(width: MgSpace.xxl),
                Text(
                  shortcut,
                  style: mgTextStyle(
                    c,
                    size: MgType.small,
                    color: c.fg2,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The glyph of a formatting button: a letter in the format's own style.
Widget selectionLetter(
  BuildContext context,
  String letter,
  Color color, {
  FontWeight? weight,
  FontStyle? style,
  TextDecoration? decoration,
  String? family,
}) {
  final c = MgColors.of(context);
  return Text(
    letter,
    style: mgTextStyle(c, color: color, height: 1).copyWith(
      fontWeight: weight,
      fontStyle: style,
      decoration: decoration,
      fontFamily: family,
    ),
  );
}

/// The glyph of a formatting button drawn as a line icon.
Widget selectionIcon(MgIconData icon, Color color) =>
    MgIcon(icon, size: 15, color: color);
