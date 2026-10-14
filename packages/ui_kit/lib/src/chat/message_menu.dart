import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// One command in a [showMgMenu] menu.
final class MgMenuItem {
  const MgMenuItem({
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onSelected;

  /// Drawn in red, like Delete.
  final bool destructive;
}

/// Shows a context menu at [position] (global coordinates), kept inside
/// the window. [header] goes above the items, such as a row of reactions;
/// it closes the menu itself through [Navigator.pop].
///
/// Like a macOS menu it appears at once, with no animation and no dimming;
/// a click outside or Esc closes it.
Future<void> showMgMenu(
  BuildContext context, {
  required Offset position,
  required List<MgMenuItem> items,
  Widget? header,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => CustomSingleChildLayout(
      delegate: _MenuLayout(position),
      child: _Menu(items: items, header: header),
    ),
  );
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.position);

  final Offset position;
  static const double _margin = 8;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest)
          .deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = position.dx;
    var y = position.dy;
    // Open to the left or upwards when there is no room, as macOS does.
    if (x + child.width > size.width - _margin) x -= child.width;
    if (y + child.height > size.height - _margin) y -= child.height;
    return Offset(
      x.clamp(_margin, size.width - child.width - _margin).toDouble(),
      y.clamp(_margin, size.height - child.height - _margin).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.position != position;
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items, this.header});

  final List<MgMenuItem> items;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 190, maxWidth: 320),
          child: Glass(
            radius: 12,
            padding: const EdgeInsets.all(5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  header!,
                  if (items.isNotEmpty) const _Separator(),
                ],
                for (final item in items) _MenuRow(item: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: MgColors.of(context).separator),
    ),
  );
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({required this.item});

  final MgMenuItem item;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  var _hover = false;

  void _select() {
    Navigator.of(context).pop();
    widget.item.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final item = widget.item;
    final color = _hover
        ? c.onAccent
        : item.destructive
        ? MgDestructive.color
        : c.fg;
    return Semantics(
      button: true,
      label: item.label,
      onTap: _select,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _select,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _hover
                  ? (item.destructive ? MgDestructive.color : c.accent)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mgTextStyle(c, color: color, height: 1.2),
            ),
          ),
        ),
      ),
    );
  }
}

/// The red of destructive actions.
abstract final class MgDestructive {
  static const Color color = Color(0xFFE5484D);
}

/// The quick reactions at the top of a message menu. [chosen] reactions
/// get a filled circle; picking one again takes it back.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onPick,
    this.chosen = const {},
  });

  final List<String> reactions;
  final Set<String> chosen;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          for (final emoji in reactions)
            _ReactionButton(
              emoji: emoji,
              chosen: chosen.contains(emoji),
              fill: c.field,
              hover: c.hover,
              onTap: () {
                Navigator.of(context).maybePop();
                onPick(emoji);
              },
            ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    required this.emoji,
    required this.chosen,
    required this.fill,
    required this.hover,
    required this.onTap,
  });

  final String emoji;
  final bool chosen;
  final Color fill;
  final Color hover;
  final VoidCallback onTap;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.chosen,
      label: widget.emoji,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.chosen
                  ? widget.fill
                  : _hover
                  ? widget.hover
                  : const Color(0x00000000),
            ),
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 19, height: 1.1),
            ),
          ),
        ),
      ),
    );
  }
}

/// The strip above the composer's text field while replying to or editing
/// a message: an accent line, what is happening ([title], such as "Reply
/// to Alina") and the quoted [text], with a button to cancel.
class ComposerContextBar extends StatelessWidget {
  const ComposerContextBar({
    super.key,
    required this.title,
    required this.text,
    required this.closeTooltip,
    required this.onClose,
    this.onTap,
  });

  final String title;
  final String text;
  final String closeTooltip;
  final VoidCallback onClose;

  /// Scrolls to the quoted message.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 0, 2),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: onTap == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: c.accent, width: 2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(
                          c,
                          weight: FontWeight.w600,
                          color: c.accent,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, color: c.fg2, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          MgIconButton(
            icon: MgIcons.close,
            tooltip: closeTooltip,
            iconSize: 14,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// A macOS-style alert: [title], an optional [message] and [option] (a
/// checkbox, such as "Also delete for Alina"), and the two buttons.
/// Completes with null when cancelled, otherwise with whether [option] was
/// checked.
Future<bool?> showMgConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String cancelLabel,
  String? message,
  String? option,
  bool optionValue = false,
  bool destructive = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => Center(
      child: _Confirm(
        title: title,
        message: message,
        option: option,
        optionValue: optionValue,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
      ),
    ),
  );
}

class _Confirm extends StatefulWidget {
  const _Confirm({
    required this.title,
    required this.message,
    required this.option,
    required this.optionValue,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String? message;
  final String? option;
  final bool optionValue;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  State<_Confirm> createState() => _ConfirmState();
}

class _ConfirmState extends State<_Confirm> {
  late var _checked = widget.optionValue;

  void _confirm() => Navigator.of(context).pop(_checked);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _confirm,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _confirm,
      },
      child: Focus(
        autofocus: true,
        // The checkbox paints on Material.
        child: Material(
          type: MaterialType.transparency,
          child: SizedBox(
            width: 300,
            child: Glass(
              radius: 14,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    style: mgTextStyle(c, weight: FontWeight.w600),
                  ),
                  if (widget.message != null) ...[
                    const SizedBox(height: 6),
                    Text(widget.message!, style: mgTextStyle(c, color: c.fg2)),
                  ],
                  if (widget.option != null) ...[
                    const SizedBox(height: 10),
                    MergeSemantics(
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => setState(() => _checked = !_checked),
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: 18,
                                child: Checkbox(
                                  value: _checked,
                                  activeColor: c.accent,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  onChanged: (value) =>
                                      setState(() => _checked = value ?? false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.option!,
                                  style: mgTextStyle(c),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _DialogButton(
                        label: widget.cancelLabel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      _DialogButton(
                        label: widget.confirmLabel,
                        filled: true,
                        color: widget.destructive
                            ? MgDestructive.color
                            : c.accent,
                        onTap: _confirm,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? color : c.field,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              style: mgTextStyle(
                c,
                weight: filled ? FontWeight.w600 : null,
                color: filled ? c.onAccent : c.fg,
                height: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
