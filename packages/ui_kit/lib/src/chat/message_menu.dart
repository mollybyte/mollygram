import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../glass/glass.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../sign_in/sign_in.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'dialogs.dart';

/// One command in a [showMgMenu] menu.
final class MgMenuItem {
  const MgMenuItem({
    required this.label,
    this.icon,
    this.leading,
    this.onSelected,
    this.destructive = false,
    this.submenu = const [],
  }) : _divider = false;

  /// A thin line between groups of items.
  const MgMenuItem.divider()
    : label = '',
      icon = null,
      leading = null,
      onSelected = null,
      destructive = false,
      submenu = const [],
      _divider = true;

  final String label;

  /// A small line icon before the label; when any item of a menu has one,
  /// the labels of all of them line up after the icon column.
  final MgIconData? icon;

  /// A small widget (an avatar) in the icon's place, about 18 px across.
  final Widget? leading;

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

/// Shows a dropdown under the button at [anchor] (its rect in global
/// coordinates), with a pointer aimed at the button, as Telegram's popovers
/// have. It opens upwards near the bottom of the window and leans left
/// for a button on the right half. Keys and submenus work as in
/// [showMgMenu].
Future<void> showMgDropdown(
  BuildContext context, {
  required Rect anchor,
  required List<MgMenuItem> items,
  Widget? header,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => _MenuRoot(
      position: anchor.bottomLeft,
      anchor: anchor,
      items: items,
      header: header,
    ),
  );
}

/// The global rect of the widget at [context], for [showMgDropdown].
Rect mgAnchorOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
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
  const _MenuRoot({
    required this.position,
    required this.items,
    this.header,
    this.anchor,
  });

  final Offset position;

  /// The button a dropdown hangs from; null for a context menu at
  /// [position].
  final Rect? anchor;
  final List<MgMenuItem> items;
  final Widget? header;

  @override
  State<_MenuRoot> createState() => _MenuRootState();
}

class _MenuRootState extends State<_MenuRoot> {
  MgMenuItem? _open;
  Rect? _anchor;

  /// The highlighted row of the menu and of the open submenu: under the
  /// mouse, or moved there with the arrow keys.
  MgMenuItem? _active;
  MgMenuItem? _subActive;

  /// The arrow keys move in the submenu, after → or Enter opened it.
  var _inSubmenu = false;

  final _rows = <MgMenuItem, GlobalKey>{};
  final _focus = FocusNode(debugLabel: 'menu');

  GlobalKey _keyOf(MgMenuItem item) => _rows[item] ??= GlobalKey();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _hover(MgMenuItem item, Rect row) {
    setState(() {
      _active = item;
      _inSubmenu = false;
      _subActive = null;
    });
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

  void _hoverSub(MgMenuItem item, Rect row) => setState(() {
    _subActive = item;
    _inSubmenu = true;
  });

  void _leave(MgMenuItem item) {
    if (identical(_active, item) && !identical(_open, item)) {
      setState(() => _active = null);
    } else if (identical(_subActive, item)) {
      setState(() => _subActive = null);
    }
  }

  /// Opens [item]'s submenu with its first row highlighted.
  void _openSubmenu(MgMenuItem item) {
    final row = _rows[item]?.currentContext?.findRenderObject();
    if (row is! RenderBox) return;
    setState(() {
      _open = item;
      _anchor = row.localToGlobal(Offset.zero) & row.size;
      _inSubmenu = true;
      _subActive = _step(item.submenu, null, 1);
    });
  }

  /// The next selectable item of [items] after [from], [delta] rows on;
  /// the first (or last) one when nothing is highlighted. Stops at the
  /// ends, as macOS menus do.
  static MgMenuItem? _step(
    List<MgMenuItem> items,
    MgMenuItem? from,
    int delta,
  ) {
    final rows = [
      for (final item in items)
        if (!item.isDivider) item,
    ];
    if (rows.isEmpty) return null;
    final at = from == null ? -1 : rows.indexWhere((i) => identical(i, from));
    if (at < 0) return delta > 0 ? rows.first : rows.last;
    return rows[(at + delta).clamp(0, rows.length - 1)];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final open = _open;
    final sub = _inSubmenu && open != null;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final delta = key == LogicalKeyboardKey.arrowDown ? 1 : -1;
      setState(() {
        if (sub) {
          _subActive = _step(open.submenu, _subActive, delta);
        } else {
          _active = _step(widget.items, _active, delta);
          // Moving off a row closes its submenu, as the mouse does.
          if (!identical(_open, _active)) _open = null;
        }
      });
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final active = sub ? _subActive : _active;
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!sub && active != null && active.submenu.isNotEmpty) {
        _openSubmenu(active);
      }
      return KeyEventResult.handled;
    }
    if (sub &&
        (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.escape)) {
      setState(() {
        _inSubmenu = false;
        _subActive = null;
        _open = null;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (active == null) return KeyEventResult.handled;
      if (active.submenu.isNotEmpty) {
        _openSubmenu(active);
      } else {
        Navigator.of(context).pop();
        active.onSelected?.call();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final dropdown = switch (widget.anchor) {
      final anchor? => _DropdownPlacement(anchor, MediaQuery.sizeOf(context)),
      null => null,
    };
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: dropdown?.layout ?? _MenuLayout(widget.position),
              child: _Menu(
                items: widget.items,
                header: widget.header,
                tail: dropdown?.tail,
                openItem: _open,
                activeItem: _active,
                keyOf: _keyOf,
                onHover: _hover,
                onLeave: _leave,
              ),
            ),
          ),
          if ((_open, _anchor) case (final open?, final anchor?))
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _SubmenuLayout(anchor),
                child: _Menu(
                  items: open.submenu,
                  activeItem: _subActive,
                  keyOf: _keyOf,
                  onHover: _hoverSub,
                  onLeave: _leave,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Where a dropdown goes beside its [anchor], decided before layout so
/// the pointer can be drawn on the first frame.
class _DropdownPlacement {
  factory _DropdownPlacement(Rect anchor, Size window) {
    const margin = _MenuLayout._margin;
    // Leans away from the nearer window edge, its corner just past the
    // button's.
    final right = anchor.center.dx > window.width / 2;
    final down = anchor.bottom < window.height * 0.6;
    final edge = right
        ? (anchor.right + _overhang).clamp(margin, window.width - margin)
        : (anchor.left - _overhang).clamp(margin, window.width - margin);
    final x = right ? edge - anchor.center.dx : anchor.center.dx - edge;
    return _DropdownPlacement._(
      _AnchoredLayout(anchor: anchor, edge: edge, right: right, down: down),
      GlassTail(x: x, up: down, fromRight: right),
    );
  }

  const _DropdownPlacement._(this.layout, this.tail);

  static const double _overhang = 6;

  final _AnchoredLayout layout;
  final GlassTail tail;
}

class _AnchoredLayout extends SingleChildLayoutDelegate {
  _AnchoredLayout({
    required this.anchor,
    required this.edge,
    required this.right,
    required this.down,
  });

  final Rect anchor;

  /// The menu's right edge when [right], else its left one.
  final double edge;
  final bool right;
  final bool down;

  static const double _gap = 2;
  static const double _margin = _MenuLayout._margin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest)
          .deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = right ? edge - child.width : edge;
    final y = down ? anchor.bottom + _gap : anchor.top - _gap - child.height;
    return Offset(
      x.clamp(_margin, size.width - child.width - _margin).toDouble(),
      y.clamp(_margin, size.height - child.height - _margin).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_AnchoredLayout old) =>
      old.anchor != anchor ||
      old.edge != edge ||
      old.right != right ||
      old.down != down;
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(this.position);

  final Offset position;
  static const double _margin = MgSpace.m;

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
  static const double _margin = MgSpace.m;

  /// The menu's padding, so the submenu's first row lines up with [row].
  static const double _inset = _Menu.padding;

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
    required this.onLeave,
    required this.keyOf,
    this.header,
    this.openItem,
    this.activeItem,
    this.tail,
  });

  /// A dropdown's pointer at its button.
  final GlassTail? tail;

  final List<MgMenuItem> items;
  final Widget? header;

  /// The item whose submenu is showing; it stays highlighted.
  final MgMenuItem? openItem;

  /// The highlighted row, by the mouse or the arrow keys.
  final MgMenuItem? activeItem;

  /// A row was hovered; its rect is in global coordinates.
  final void Function(MgMenuItem item, Rect row) onHover;

  /// The mouse left a row.
  final ValueChanged<MgMenuItem> onLeave;

  /// Each row's key, so the keyboard can find its rect.
  final GlobalKey Function(MgMenuItem item) keyOf;

  /// Keeps the rows' corners concentric with the panel's.
  static const double padding = radius - _rowRadius + 1;

  /// A touch rounder than other popovers, as Telegram's menus are.
  static const double radius = MgRadius.card;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: IntrinsicWidth(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 236, maxWidth: 320),
          child: Glass(
            dense: true,
            radius: radius,
            tail: tail,
            padding: const EdgeInsets.all(padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[
                  header!,
                  if (_tidy(items).isNotEmpty) const _Separator(),
                ],
                for (final item in _tidy(items))
                  item.isDivider
                      ? const _Separator()
                      : _MenuRow(
                          key: keyOf(item),
                          item: item,
                          iconColumn: items.any(
                            (i) => i.icon != null || i.leading != null,
                          ),
                          open: identical(item, openItem),
                          active: identical(item, activeItem),
                          onHover: onHover,
                          onLeave: onLeave,
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [items] without dividers at the ends or two in a row, so callers can
/// put one between each group whether or not the group has rows.
List<MgMenuItem> _tidy(List<MgMenuItem> items) {
  final rows = <MgMenuItem>[];
  for (final item in items) {
    if (item.isDivider && (rows.isEmpty || rows.last.isDivider)) continue;
    rows.add(item);
  }
  if (rows.isNotEmpty && rows.last.isDivider) rows.removeLast();
  return rows;
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: SizedBox(
      height: 1,
      child: ColoredBox(color: MgColors.of(context).separator),
    ),
  );
}

class _MenuRow extends StatefulWidget {
  const _MenuRow({
    super.key,
    required this.item,
    required this.open,
    required this.active,
    required this.onHover,
    required this.onLeave,
    this.iconColumn = false,
  });

  final MgMenuItem item;

  /// Some row of this menu has an icon: reserve its column.
  final bool iconColumn;

  /// This row's submenu is showing.
  final bool open;

  /// Highlighted by the mouse or the arrow keys.
  final bool active;
  final void Function(MgMenuItem item, Rect row) onHover;
  final ValueChanged<MgMenuItem> onLeave;

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
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
    final lit = widget.active || widget.open;
    // A soft fill under the row, as Telegram does: the text keeps its
    // colour and the icons stay a quiet grey beside it.
    final color = item.destructive ? MgDestructive.color : c.fg;
    final iconColor = item.destructive ? MgDestructive.color : c.fg2;
    return Semantics(
      button: true,
      label: item.label,
      onTap: _select,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => widget.onHover(item, _rect()),
        onExit: (_) => widget.onLeave(item),
        child: GestureDetector(
          onTap: _select,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: lit ? menuHighlight(c) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(_rowRadius),
            ),
            child: Row(
              children: [
                if (widget.iconColumn)
                  SizedBox(
                    width: 27,
                    child: item.leading != null
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: item.leading,
                          )
                        : item.icon == null
                        ? null
                        : Align(
                            alignment: Alignment.centerLeft,
                            child: MgIcon(
                              item.icon!,
                              size: 15,
                              color: iconColor,
                            ),
                          ),
                  ),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(
                      c,
                      size: MgType.small,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ),
                if (item.submenu.isNotEmpty) ...[
                  const SizedBox(width: MgSpace.xl),
                  MgIcon(MgIcons.chevron, size: 11, stroke: 2.4, color: c.fg2),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The corners of a menu row, concentric with the menu's.
const double _rowRadius = 7;

/// The fill under a highlighted menu row: a soft tint of the text colour
/// that reads on light and dark glass alike.
Color menuHighlight(MgColors c) => c.fg.withValues(alpha: 0.08);

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
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: MgSpace.xxs,
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
      dense: true,
      radius: MgRadius.popover,
      padding: const EdgeInsets.all(MgSpace.s),
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
    this.size = 28,
  });

  final String emoji;

  /// What an icon drawn in place of the emoji measures, matching the
  /// emoji's glyph.
  static const double iconSize = 19;

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
                  style: const TextStyle(fontSize: 17, height: 1.1),
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
    this.icon = MgIcons.reply,
  });

  final String title;
  final String text;
  final String closeTooltip;
  final VoidCallback onClose;

  /// Scrolls to the quoted message.
  final VoidCallback? onTap;

  /// What is happening, in the column of the composer's attach button so
  /// that the text lines up with the field below.
  final MgIconData icon;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: MouseRegion(
              cursor: onTap == null
                  ? MouseCursor.defer
                  : SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: MgSendButton.size,
                      child: Center(
                        child: MgIcon(icon, size: 20, color: c.accent),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
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
                              size: MgType.small,
                              weight: MgWeight.medium,
                              color: c.accent,
                              height: 1.3,
                            ),
                          ),
                          Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mgTextStyle(
                              c,
                              size: MgType.small,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          MgIconButton(
            icon: MgIcons.close,
            tooltip: closeTooltip,
            iconSize: 16,
            size: MgSendButton.size,
            quiet: true,
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
  return showMgSheet<bool>(
    context,
    _Confirm(
      title: title,
      message: message,
      option: option,
      optionValue: optionValue,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
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
          child: MgAlert(
            title: widget.title,
            message: widget.message,
            option: widget.option == null
                ? null
                : MgCheckRow(
                    label: widget.option!,
                    value: _checked,
                    onChanged: (value) => setState(() => _checked = value),
                  ),
            actions: [
              MgDialogButton(
                label: widget.confirmLabel,
                filled: true,
                color: widget.destructive ? MgDestructive.color : c.accent,
                onTap: _confirm,
              ),
              MgDialogButton(
                label: widget.cancelLabel,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The shell of an alert, as macOS draws one: the app's mark, a bold
/// centred title, the message under it, an optional control such as a
/// checkbox, and the buttons stacked full width, the main one first.
class MgAlert extends StatelessWidget {
  const MgAlert({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.option,
  });

  final String title;
  final String? message;
  final Widget? option;

  /// [MgDialogButton]s, the main action first.
  final List<Widget> actions;

  static const double width = 260;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox(
      width: width,
      child: Glass(
        dense: true,
        radius: MgRadius.card,
        padding: const EdgeInsets.fromLTRB(
          MgSpace.xl,
          MgSpace.xxl,
          MgSpace.xl,
          MgSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: AppMark(size: 52)),
            const SizedBox(height: MgSpace.l),
            Text(
              title,
              textAlign: TextAlign.center,
              style: mgTextStyle(c, weight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: MgSpace.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: mgTextStyle(c, size: MgType.caption, height: 1.35),
              ),
            ],
            if (option != null) ...[
              const SizedBox(height: MgSpace.l),
              Center(child: option),
            ],
            const SizedBox(height: MgSpace.xl),
            for (final (i, action) in actions.indexed) ...[
              if (i > 0) const SizedBox(height: MgSpace.m),
              action,
            ],
          ],
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
            padding: const EdgeInsets.symmetric(horizontal: MgSpace.xl),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? color : c.field,
              borderRadius: BorderRadius.circular(MgRadius.control),
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
              const SizedBox(width: MgSpace.m),
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
    final color = c.fg;
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
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: lit ? menuHighlight(c) : const Color(0x00000000),
              borderRadius: BorderRadius.circular(_rowRadius),
            ),
            child: Row(
              children: [
                MgIcon(widget.icon, size: 15, color: c.fg2),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, size: MgType.small, color: color),
                  ),
                ),
                if (widget.avatars.isNotEmpty) ...[
                  const SizedBox(width: MgSpace.ml),
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
                                  color: c.glassSolid,
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
        dense: true,
        radius: MgRadius.popover,
        padding: const EdgeInsets.all(MgSpace.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MgSpace.ml,
                vertical: MgSpace.s,
              ),
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
                        horizontal: MgSpace.ml,
                        vertical: MgSpace.xs,
                      ),
                      child: Row(
                        children: [
                          ClipOval(
                            child: SizedBox.square(
                              dimension: 24,
                              child: person.avatar,
                            ),
                          ),
                          const SizedBox(width: MgSpace.m),
                          Expanded(
                            child: Text(
                              person.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c),
                            ),
                          ),
                          if (person.trailing case final trailing?) ...[
                            const SizedBox(width: MgSpace.ml),
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
