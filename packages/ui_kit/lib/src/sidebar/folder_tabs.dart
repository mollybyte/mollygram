import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// A horizontally scrolling row of [FolderTab]s.
class FolderTabBar extends StatelessWidget {
  const FolderTabBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          for (final child in children)
            Padding(padding: const EdgeInsets.only(right: 2), child: child),
        ],
      ),
    );
  }
}

/// A chat folder pill (`.tabf`): label and an optional unread counter.
class FolderTab extends StatefulWidget {
  const FolderTab({
    super.key,
    required this.label,
    this.count = 0,
    this.selected = false,
    this.onTap,
  });

  final String label;

  /// Unread chats in the folder; hidden when zero.
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? c.field : const Color(0x00000000),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: mgTextStyle(
                    c,
                    size: MgType.tab,
                    weight: FontWeight.w500,
                    color: on || _hover ? c.fg : c.fg2,
                    height: 1.2,
                  ),
                ),
                if (widget.count > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    '${widget.count}',
                    style: mgTextStyle(
                      c,
                      size: MgType.caption,
                      color: c.fg2,
                      height: 1.2,
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
