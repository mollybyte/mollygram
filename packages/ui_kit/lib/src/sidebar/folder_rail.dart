import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The icon rail at the left edge of the sidebar island: one [FolderRailItem]
/// per chat folder, [trailing] widgets (such as a settings button) at the
/// bottom.
///
/// The top [SidebarIsland.titleBarHeight] is left free for the window
/// buttons, which the macOS runner centres in that row.
class FolderRail extends StatelessWidget {
  const FolderRail({
    super.key,
    required this.children,
    this.trailing = const [],
    this.topInset = 44,
    this.topFill,
  });

  /// Usually [FolderRailItem]s.
  final List<Widget> children;

  /// Pinned under the folders, at the bottom of the rail.
  final List<Widget> trailing;
  final double topInset;

  /// Fills the top inset (the app puts its window drag area there).
  final Widget? topFill;

  static const double width = 80;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(height: topInset, width: width, child: topFill),
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
                children: [
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: child,
                    ),
                ],
              ),
            ),
          ),
          if (trailing.isNotEmpty) ...[
            Container(height: 1, color: c.separator),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                children: [
                  for (var i = 0; i < trailing.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    trailing[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One folder on the rail: a 20 px line icon over a short label, 64x48,
/// filled and tinted with the accent while selected.
class FolderRailItem extends StatefulWidget {
  const FolderRailItem({
    super.key,
    required this.icon,
    required this.label,
    this.count = 0,
    this.selected = false,
    this.onTap,
  });

  final MgIconData icon;

  /// The folder title, one line, cut with an ellipsis when long.
  final String label;

  /// Unread chats in the folder; a dot at the icon's corner when positive.
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  static const double height = 48;

  @override
  State<FolderRailItem> createState() => _FolderRailItemState();
}

class _FolderRailItemState extends State<FolderRailItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final on = widget.selected;
    final fg = on ? c.accent : (_hover ? c.fg : c.fg2);
    final bg = on ? c.field : (_hover ? c.hover : const Color(0x00000000));
    return Tooltip(
      message: widget.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: on,
        label: widget.label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              height: FolderRailItem.height,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      MgIcon(widget.icon, size: 20, color: fg),
                      if (widget.count > 0)
                        Positioned(
                          top: -2,
                          right: -3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: mgTextStyle(
                      c,
                      size: 10,
                      weight: MgWeight.medium,
                      color: fg,
                      height: 1.2,
                    ),
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
