import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// A text pill in a tool panel, such as an aspect ratio. The selected one
/// takes the accent.
class EditorChip extends StatefulWidget {
  const EditorChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<EditorChip> createState() => _EditorChipState();
}

class _EditorChipState extends State<EditorChip> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final bg = widget.selected
        ? c.accent
        : (_hover ? c.hover : const Color(0x00000000));
    final fg = widget.selected ? c.onAccent : (_hover ? c.fg : c.fg2);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              widget.label,
              style: mgTextStyle(
                c,
                size: MgType.small,
                weight: FontWeight.w500,
                color: fg,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin vertical line between groups of controls.
class EditorDivider extends StatelessWidget {
  const EditorDivider({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 18,
    margin: const EdgeInsets.symmetric(horizontal: 6),
    color: MgColors.of(context).separator,
  );
}
