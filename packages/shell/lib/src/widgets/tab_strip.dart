import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../data/chat_directory.dart';
import '../l10n/shell_strings.dart';
import '../model/workspace.dart';
import 'glyphs.dart';

/// The row of chat tabs. Solid, not glass: glass is only for the sidebar,
/// the chat header capsules, the composer and the palette.
///
/// Shown only while there are two or more tabs, so a single chat looks the
/// same as in a client without tabs.
class TabStrip extends StatelessWidget {
  const TabStrip({
    super.key,
    required this.controller,
    required this.directory,
    required this.strings,
  });

  static const double height = 36;

  final WorkspaceController controller;
  final ChatDirectory directory;
  final ShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final workspace = controller.value;
    final c = MgColors.of(context);
    return Semantics(
      container: true,
      label: strings.tabs,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(
            children: [
              for (var i = 0; i < workspace.tabs.length; i++)
                Flexible(
                  child: _TabPill(
                    key: ValueKey(workspace.tabs[i].id),
                    title: tabTitle(workspace.tabs[i], directory, strings),
                    selected: i == workspace.active,
                    strings: strings,
                    onSelect: () => controller.selectTab(i),
                    onClose: () => controller.closeTab(i),
                  ),
                ),
              const SizedBox(width: 2),
              _IconButton(
                glyph: ShellGlyph.plus,
                label: strings.newTab,
                color: c.fg2,
                onTap: controller.newTab,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab is named after its chats: "Anna", or "Anna · Product team" in a
/// split view.
String tabTitle(WorkspaceTab tab, ChatDirectory directory, ShellStrings s) {
  final names = [
    for (final id in tab.panes)
      if (id != null) directory.chat(id)?.title ?? '',
  ].where((n) => n.isNotEmpty).toList();
  return names.isEmpty ? s.newTab : names.join(' · ');
}

class _TabPill extends StatefulWidget {
  const _TabPill({
    super.key,
    required this.title,
    required this.selected,
    required this.strings,
    required this.onSelect,
    required this.onClose,
  });

  final String title;
  final bool selected;
  final ShellStrings strings;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  State<_TabPill> createState() => _TabPillState();
}

class _TabPillState extends State<_TabPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final showClose = _hover || widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        // Middle click closes a tab, as in browsers.
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse &&
              e.buttons == kMiddleMouseButton) {
            widget.onClose();
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelect,
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: widget.title,
            child: Container(
              height: 26,
              constraints: const BoxConstraints(maxWidth: 220, minWidth: 64),
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.only(left: 10, right: 4),
              decoration: BoxDecoration(
                color: widget.selected ? c.field : null,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: widget.selected || _hover ? c.fg : c.fg2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  // The slot keeps its width so titles do not jump on hover.
                  Opacity(
                    opacity: showClose ? 1 : 0,
                    child: _IconButton(
                      glyph: ShellGlyph.close,
                      label: widget.strings.closeTab,
                      color: c.fg2,
                      size: 18,
                      onTap: widget.onClose,
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

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.glyph,
    required this.label,
    required this.color,
    required this.onTap,
    this.size = 26,
  });

  final ShellGlyph glyph;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          label: widget.label,
          child: Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hover ? c.hover : null,
            ),
            child: Glyph(
              widget.glyph,
              size: widget.size * 0.55,
              color: _hover ? c.fg : widget.color,
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }
}
