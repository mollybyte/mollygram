import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../model/overlay.dart';
import '../strings.dart';
import 'controls.dart';
import 'draw_panel.dart';
import 'editor_icons.dart';

/// The text tool: the words, their look, colour and size of the selected
/// text overlay.
class TextPanel extends StatelessWidget {
  const TextPanel({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.overlay,
    required this.onLook,
    required this.onColor,
    required this.onScale,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextOverlay? overlay;
  final ValueChanged<TextLook> onLook;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onScale;

  @override
  Widget build(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    final c = MgColors.of(context);
    final overlay = this.overlay;
    final style = mgTextStyle(c, size: MgType.title);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        Container(
          width: 180,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            style: style,
            cursorHeight: 16,
            decoration: InputDecoration.collapsed(
              hintText: s.textHint,
              hintStyle: style.copyWith(color: c.fg2),
            ),
          ),
        ),
        const EditorDivider(),
        for (final (look, label) in [
          (TextLook.plain, s.plain),
          (TextLook.outline, s.outline),
          (TextLook.frame, s.frame),
        ]) ...[
          EditorChip(
            label: label,
            selected: overlay?.look == look,
            onPressed: () => onLook(look),
          ),
          const SizedBox(width: 2),
        ],
        const EditorDivider(),
        ColorSwatches(
          color: overlay?.color ?? brushColors.first,
          onColor: onColor,
        ),
        const EditorDivider(),
        EditorSlider(
          value: ((overlay?.scale ?? 0.08) - 0.03) / 0.22,
          color: overlay?.color ?? c.fg2,
          label: s.size,
          onChanged: (v) => onScale(0.03 + v * 0.22),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Emoji the emoji tool offers. A click places one in the middle.
const editorEmoji = [
  '😀',
  '😂',
  '🥹',
  '😍',
  '😎',
  '🤔',
  '😱',
  '🥳',
  '😭',
  '🙄',
  '❤️',
  '🔥',
  '✨',
  '⭐',
  '💯',
  '👍',
  '👎',
  '👏',
  '🙏',
  '💪',
  '🎉',
  '🎂',
  '🎁',
  '🏆',
  '⚡',
  '💡',
  '✅',
  '❌',
  '❓',
  '❗',
  '👀',
  '🫶',
  '🤝',
  '🫡',
  '😴',
  '🤯',
  '🥶',
  '🤡',
  '💀',
  '👻',
  '🐱',
  '🐶',
  '🦊',
  '🐼',
  '🦄',
  '🌸',
  '🌈',
  '☀️',
  '🌙',
  '🍕',
];

/// A grid of [editorEmoji].
class EmojiGridPanel extends StatelessWidget {
  const EmojiGridPanel({super.key, required this.onEmoji});

  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 10 * 34,
    child: Wrap(
      children: [
        for (final emoji in editorEmoji)
          _EmojiCell(emoji: emoji, onPressed: () => onEmoji(emoji)),
      ],
    ),
  );
}

class _EmojiCell extends StatefulWidget {
  const _EmojiCell({required this.emoji, required this.onPressed});

  final String emoji;
  final VoidCallback onPressed;

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hover ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: AnimatedScale(
            scale: _hover ? 1.15 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutBack,
            child: Text(
              widget.emoji,
              style: const TextStyle(
                fontSize: 20,
                fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji'],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shape tool: a shape to add, and the colour, fill and line width of
/// the selected one.
class ShapePanel extends StatelessWidget {
  const ShapePanel({
    super.key,
    required this.overlay,
    required this.color,
    required this.thickness,
    required this.onAdd,
    required this.onColor,
    required this.onFilled,
    required this.onThickness,
  });

  final ShapeOverlay? overlay;
  final Color color;
  final double thickness;
  final ValueChanged<ShapeKind> onAdd;
  final ValueChanged<Color> onColor;
  final ValueChanged<bool> onFilled;
  final ValueChanged<double> onThickness;

  @override
  Widget build(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    final fillable =
        overlay != null &&
        (overlay!.kind == ShapeKind.rectangle ||
            overlay!.kind == ShapeKind.ellipse);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (kind, icon, label) in [
          (ShapeKind.rectangle, EditorIcons.rectangle, s.rectangle),
          (ShapeKind.ellipse, EditorIcons.ellipse, s.ellipse),
          (ShapeKind.line, EditorIcons.line, s.line),
          (ShapeKind.arrow, EditorIcons.arrow, s.arrow),
        ])
          MgIconButton(
            icon: icon,
            tooltip: label,
            onPressed: () => onAdd(kind),
          ),
        const EditorDivider(),
        EditorChip(
          label: s.filled,
          selected: overlay?.filled ?? false,
          onPressed: fillable ? () => onFilled(!overlay!.filled) : () {},
        ),
        const EditorDivider(),
        ColorSwatches(color: color, onColor: onColor),
        const EditorDivider(),
        EditorSlider(
          value: thickness,
          color: color,
          label: s.thickness,
          onChanged: onThickness,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
