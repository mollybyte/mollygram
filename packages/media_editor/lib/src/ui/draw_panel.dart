import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../model/stroke.dart';
import '../strings.dart';
import 'controls.dart';
import 'editor_icons.dart';

/// The drawing colors, white and black first, then the Telegram palette.
const brushColors = <Color>[
  Color(0xFFFFFFFF),
  Color(0xFFFE3B30),
  Color(0xFFFF9500),
  Color(0xFFFFCC00),
  Color(0xFF34C759),
  Color(0xFF007AFF),
  Color(0xFFAF52DE),
  Color(0xFFFF2D55),
  Color(0xFF000000),
];

/// The options of the draw tool: the brush, the color and the thickness.
class DrawPanel extends StatelessWidget {
  const DrawPanel({
    super.key,
    required this.brush,
    required this.color,
    required this.thickness,
    required this.onBrush,
    required this.onColor,
    required this.onThickness,
  });

  final BrushTool brush;
  final Color color;
  final double thickness;
  final ValueChanged<BrushTool> onBrush;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onThickness;

  @override
  Widget build(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    final c = MgColors.of(context);
    final erasing = brush == BrushTool.eraser || brush.isEffect;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (tool, icon, label) in [
          (BrushTool.pen, EditorIcons.pen, s.pen),
          (BrushTool.marker, EditorIcons.marker, s.marker),
          (BrushTool.arrow, EditorIcons.arrow, s.arrow),
          (BrushTool.eraser, EditorIcons.eraser, s.eraser),
          (BrushTool.blur, EditorIcons.blur, s.blur),
          (BrushTool.pixelate, EditorIcons.pixelate, s.pixelate),
        ])
          MgIconButton(
            icon: icon,
            tooltip: label,
            selected: brush == tool,
            onPressed: () => onBrush(tool),
          ),
        const EditorDivider(),
        AnimatedOpacity(
          opacity: erasing ? 0.35 : 1,
          duration: const Duration(milliseconds: 160),
          child: IgnorePointer(
            ignoring: erasing,
            child: ColorSwatches(color: color, onColor: onColor),
          ),
        ),
        const EditorDivider(),
        EditorSlider(
          value: thickness,
          color: erasing ? c.fg2 : color,
          label: s.thickness,
          onChanged: onThickness,
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// The row of [brushColors], the current one ringed.
class ColorSwatches extends StatelessWidget {
  const ColorSwatches({super.key, required this.color, required this.onColor});

  final Color color;
  final ValueChanged<Color> onColor;

  @override
  Widget build(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final swatch in brushColors)
          _Swatch(
            color: swatch,
            selected: swatch == color,
            label: s.color,
            onPressed: () => onColor(swatch),
          ),
      ],
    );
  }
}

/// A round color, with a ring when selected. It grows a little on hover
/// and springs when picked.
class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final Color color;
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final scale = widget.selected ? 1.0 : (_hover ? 0.92 : 0.8);
    // White and black need an outline to be seen on both themes.
    final isWhite = widget.color.computeLuminance() > 0.9;
    final isBlack = widget.color.computeLuminance() < 0.02;
    final outline = (isWhite && !c.isDark) || (isBlack && c.isDark)
        ? c.separator
        : const Color(0x00000000);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                width: 22 * scale,
                height: 22 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: outline),
                  boxShadow: widget.selected
                      ? [
                          BoxShadow(
                            color: c.isDark
                                ? const Color(0xFF1C1E22)
                                : const Color(0xFFFFFFFF),
                            spreadRadius: 2,
                          ),
                          BoxShadow(color: widget.color, spreadRadius: 3.5),
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A short slider whose thumb is a dot of the current color and whose
/// track thickens from left to right.
class EditorSlider extends StatelessWidget {
  const EditorSlider({
    super.key,
    required this.value,
    required this.color,
    required this.label,
    required this.onChanged,
  });

  final double value;
  final Color color;
  final String label;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      slider: true,
      label: label,
      value: '${(value * 100).round()}%',
      child: SizedBox(
        width: 112,
        height: 32,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 14,
            trackShape: _WedgeTrack(c.fg2.withValues(alpha: 0.3)),
            thumbShape: _DotThumb(color, c.isDark),
            overlayShape: SliderComponentShape.noOverlay,
            activeTrackColor: const Color(0x00000000),
            inactiveTrackColor: const Color(0x00000000),
            thumbColor: color,
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ),
    );
  }
}

class _WedgeTrack extends SliderTrackShape {
  const _WedgeTrack(this.color);

  final Color color;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme?.trackHeight ?? 14;
    return Rect.fromLTWH(
      offset.dx + 8,
      offset.dy + (parentBox.size.height - height) / 2,
      parentBox.size.width - 16,
      height,
    );
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
    );
    final path = Path()
      ..moveTo(rect.left, rect.center.dy - 1)
      ..lineTo(rect.right, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.bottom),
        radius: Radius.circular(rect.height / 2),
      )
      ..lineTo(rect.left, rect.center.dy + 1)
      ..arcToPoint(
        Offset(rect.left, rect.center.dy - 1),
        radius: const Radius.circular(1),
      )
      ..close();
    context.canvas.drawPath(path, Paint()..color = color);
  }
}

class _DotThumb extends SliderComponentShape {
  const _DotThumb(this.color, this.dark);

  final Color color;
  final bool dark;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(16);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center,
        8,
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawCircle(
        center,
        8,
        Paint()
          ..color = dark ? const Color(0xFF2A2C31) : const Color(0xFFFFFFFF),
      )
      ..drawCircle(center, 5.5, Paint()..color = color);
  }
}
