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
    this.onSelected,
    this.destructive = false,
    this.submenu = const [],
  }) : _divider = false;

  /// A thin line between groups of items.
  const MgMenuItem.divider()
    : label = '',
      onSelected = null,
      destructive = false,
      submenu = const [],
      _divider = true;

  final String label;

  /// Runs after the menu closes; an item with a [submenu] may leave it out.
  final VoidCallback? onSelected;

  /// Drawn in red, like Delete.
  final bool destructive;

  /// Items shown beside this one while it is hovered, like a macOS
  /// submenu; the row gets a chevron.
  final List<MgMenuItem> submenu;
  final bool _divider;

  bool get isDivider => _divider;
}

/// Shows a context menu at [position] (global coordinates), kept inside
/// the window. [header] goes above the items, such as a row of reactions;
/// it closes the menu itself through [Navigator.pop].
///
/// Like a macOS menu it appears at once, with no animation and no dimming;
/// a click outside or Esc closes it. Items with a submenu open it beside
/// themselves on hover.
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
    pageBuilder: (context, _, _) =>
        _MenuRoot(position: position, items: items, header: header),
  );
}

/// Shows [child] at [position], flipped to the left or upwards when there
/// is no room, as a menu does. Closes on a click outside, with no
/// animation and no dimming.
Future<void> showMgPopover(
  BuildContext context, {
  required Offset position,
  required Widget child,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => CustomSingleChildLayout(
      delegate: _MenuLayout(position),
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

/// The menu and, while an item with a submenu is hovered, that submenu.
class _MenuRoot extends StatefulWidget {
  const _MenuRoot({required this.position, required this.items, this.header});

  final Offset position;
  final List<MgMenuItem> items;
  final Widget? header;

  @override
  State<_MenuRoot> createState() => _MenuRootState();
}

class _MenuRootState extends State<_MenuRoot> {
  MgMenuItem? _open;
  Rect? _anchor;

  void _hover(MgMenuItem item, Rect row) {
    if (item.submenu.isEmpty) {
      if (_open != null) setState(() => _open = null);
      return;
    }
    if (identical(_open, item)) return;
    setState(() {
      _open = item;
      _anchor = row;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomSingleChildLayout(
            delegate: _MenuLayout(widget.position),
            child: _Menu(
              items: widget.items,
              header: widget.header,
              openItem: _open,
              onHover: _hover,
            ),
          ),
        ),
        if ((_open, _anchor) case (final open?, final anchor?))
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _SubmenuLayout(anchor),
              child: _Menu(items: open.submenu, onHover: (_, _) {}),
            ),
          ),
      ],
    );
  }
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

/// Puts a submenu beside its row: to the right, its first item level with
/// the row, or to the left when the window has no room on the right.
class _SubmenuLayout extends SingleChildLayoutDelegate {
  _SubmenuLayout(this.row);

  final Rect row;
  static const double _margin = 8;

  /// The menu's padding, so the submenu's first row lines up with [row].
  static const double _inset = 5;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest)
          .deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size child) {
    var x = row.right + _inset;
    if (x + child.width > size.width - _margin) {
      x = row.left - _inset - child.width;
    }
    final y = row.top - _inset;
    return Offset(
      x.clamp(_margin, size.width - child.width - _margin).toDouble(),
      y.clamp(_margin, size.height - child.height - _margin).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_SubmenuLayout old) => old.row != row;
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.items,
    required this.onHover,
    this.header,
    this.openItem,
  });

  final List<MgMenuItem> items;
  final Widget? header;

  /// The item whose submenu is showing; it stays highlighted.
  final MgMenuItem? openItem;

  /// A row was hovered; its rect is in global coordinates.
  final void Function(MgMenuItem item, Rect row) onHover;

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
                for (final item in items)
                  item.isDivider
                      ? const _Separator()
                      : _MenuRow(
                          item: item,
                          open: identical(item, openItem),
                          onHover: onHover,
                        ),
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
  const _MenuRow({
    required this.item,
    required this.open,
    required this.onHover,
  });

  final MgMenuItem item;

  /// This row's submenu is showing.
  final bool open;
  final void Function(MgMenuItem item, Rect row) onHover;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  var _hover = false;

  Rect _rect() {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _select() {
    final item = widget.item;
    if (item.submenu.isNotEmpty) {
      widget.onHover(item, _rect());
      return;
    }
    Navigator.of(context).pop();
    item.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final item = widget.item;
    final lit = _hover || widget.open;
    final color = lit
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
        onEnter: (_) {
          setState(() => _hover = true);
          widget.onHover(item, _rect());
        },
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _select,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: lit
                  ? (item.destructive ? MgDestructive.color : c.accent)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, color: color, height: 1.2),
                  ),
                ),
                if (item.submenu.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  MgIcon(MgIcons.chevron, size: 11, stroke: 2.4, color: color),
                ],
              ],
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

/// Draws a reaction that is not an emoji, such as a custom emoji's
/// sticker, [size] wide; null for one drawn as its text.
typedef ReactionIconBuilder = Widget? Function(String reaction, double size);

/// The quick reactions at the top of a message menu. [chosen] reactions
/// get a filled circle; picking one again takes it back. With [onMore] a
/// round chevron at the end closes the menu and opens the full picker.
class ReactionBar extends StatelessWidget {
  const ReactionBar({
    super.key,
    required this.reactions,
    required this.onPick,
    this.chosen = const {},
    this.onMore,
    this.moreTooltip,
    this.icons,
  });

  /// Emoji, or keys of reactions that [icons] draws.
  final List<String> reactions;
  final Set<String> chosen;
  final ValueChanged<String> onPick;
  final VoidCallback? onMore;
  final String? moreTooltip;
  final ReactionIconBuilder? icons;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final onMore = this.onMore;
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
              child: icons?.call(emoji, _ReactionButton.iconSize),
            ),
          if (onMore != null)
            _ReactionButton(
              label: moreTooltip ?? '',
              chosen: false,
              fill: c.field,
              hover: c.hover,
              onTap: () {
                Navigator.of(context).maybePop();
                onMore();
              },
              child: RotatedBox(
                quarterTurns: 2,
                child: MgIcon(MgIcons.chevronUp, size: 15, color: c.fg2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Every reaction the user may pick, in rows of eight, shown with
/// [showMgPopover] from the chevron of a [ReactionBar].
class ReactionGrid extends StatelessWidget {
  const ReactionGrid({
    super.key,
    required this.reactions,
    required this.onPick,
    this.chosen = const {},
    this.icons,
  });

  /// Emoji, or keys of reactions that [icons] draws.
  final List<String> reactions;
  final Set<String> chosen;
  final ValueChanged<String> onPick;
  final ReactionIconBuilder? icons;

  static const int columns = 8;
  static const double cell = 36;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Glass(
      radius: 14,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: cell * columns,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: cell * 7),
          child: GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
            ),
            itemCount: reactions.length,
            itemBuilder: (context, index) {
              final emoji = reactions[index];
              final picked = chosen.contains(emoji);
              return _ReactionButton(
                emoji: emoji,
                chosen: picked,
                fill: c.field,
                hover: c.hover,
                size: cell - 2,
                onTap: () {
                  Navigator.of(context).maybePop();
                  onPick(emoji);
                },
                child: icons?.call(emoji, _ReactionButton.iconSize),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  const _ReactionButton({
    this.emoji = '',
    this.label,
    this.child,
    required this.chosen,
    required this.fill,
    required this.hover,
    required this.onTap,
    this.size = 32,
  });

  final String emoji;

  /// What an icon drawn in place of the emoji measures, matching the
  /// emoji's glyph.
  static const double iconSize = 22;

  /// What the button is for when it has no [emoji], such as "More".
  final String? label;

  /// Drawn in place of the [emoji].
  final Widget? child;
  final bool chosen;
  final Color fill;
  final Color hover;
  final VoidCallback onTap;
  final double size;

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final button = Semantics(
      button: true,
      selected: widget.chosen,
      label: label ?? widget.emoji,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.chosen
                  ? widget.fill
                  : _hover
                  ? widget.hover
                  : const Color(0x00000000),
            ),
            child:
                widget.child ??
                Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 19, height: 1.1),
                ),
          ),
        ),
      ),
    );
    if (label == null || label.isEmpty) return button;
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: button,
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
                    MgCheckRow(
                      label: widget.option!,
                      value: _checked,
                      onChanged: (value) => setState(() => _checked = value),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      MgDialogButton(
                        label: widget.cancelLabel,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      MgDialogButton(
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

/// A button of an alert: filled with [color] for the main action, grey
/// otherwise.
class MgDialogButton extends StatelessWidget {
  const MgDialogButton({
    super.key,
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

/// A checkbox with its label, the whole row clickable, as in the confirm
/// dialog and the forward picker.
class MgCheckRow extends StatelessWidget {
  const MgCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MergeSemantics(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 18,
                child: Checkbox(
                  value: value,
                  activeColor: c.accent,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  onChanged: (checked) => onChanged(checked ?? false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: mgTextStyle(c))),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row at the top of a message menu that tells who saw the message or
/// reacted to it, with their avatars on the right, as in Telegram for
/// macOS. A click closes the menu and runs [onSelected], which shows the
/// list.
class MgMenuInfoRow extends StatefulWidget {
  const MgMenuInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.avatars,
    this.onSelected,
  });

  final MgIconData icon;
  final String label;

  /// Up to three small avatars, drawn overlapping.
  final List<Widget> avatars;
  final VoidCallback? onSelected;

  @override
  State<MgMenuInfoRow> createState() => _MgMenuInfoRowState();
}

class _MgMenuInfoRowState extends State<MgMenuInfoRow> {
  var _hover = false;

  void _select() {
    final onSelected = widget.onSelected;
    if (onSelected == null) return;
    Navigator.of(context).pop();
    onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = widget.onSelected != null;
    final lit = _hover && enabled;
    final color = lit ? c.onAccent : c.fg;
    return Semantics(
      button: enabled,
      label: widget.label,
      onTap: enabled ? _select : null,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: enabled ? _select : null,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: lit ? c.accent : const Color(0x00000000),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                MgIcon(widget.icon, size: 14, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, color: color),
                  ),
                ),
                if (widget.avatars.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 18 + 12.0 * (widget.avatars.length - 1),
                    height: 18,
                    child: Stack(
                      children: [
                        for (var i = 0; i < widget.avatars.length; i++)
                          Positioned(
                            left: 12.0 * i,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: lit ? c.accent : c.glassSolid,
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: SizedBox.square(
                                  dimension: 18,
                                  child: widget.avatars[i],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One person of an [MgPeopleList]: avatar, name and what they did on the
/// right, such as a reaction or when they read the message.
@immutable
class MgPerson {
  const MgPerson({required this.avatar, required this.name, this.trailing});

  final Widget avatar;
  final String name;
  final String? trailing;
}

/// The people who saw a message or reacted to it, in a glass panel shown
/// with [showMgPopover].
class MgPeopleList extends StatelessWidget {
  const MgPeopleList({super.key, required this.title, required this.people});

  final String title;
  final List<MgPerson> people;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: Glass(
        radius: 12,
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
              child: Text(
                title,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  weight: FontWeight.w600,
                  color: c.fg2,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final person in people)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox.square(
                              dimension: 24,
                              child: person.avatar,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c),
                            ),
                          ),
                          if (person.trailing case final trailing?) ...[
                            const SizedBox(width: 10),
                            Text(
                              trailing,
                              style: mgTextStyle(
                                c,
                                size: MgType.caption,
                                color: c.fg2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
