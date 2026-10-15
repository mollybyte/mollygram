import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../model/adjustments.dart';
import '../strings.dart';
import 'controls.dart';

/// The adjust tool: a row of looks, then the adjustments with one slider
/// for the selected one.
class AdjustPanel extends StatelessWidget {
  const AdjustPanel({
    super.key,
    required this.values,
    required this.selected,
    required this.onPreset,
    required this.onSelect,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final Adjustments values;
  final Adjustment selected;
  final ValueChanged<FilterPreset> onPreset;
  final ValueChanged<Adjustment> onSelect;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    final c = MgColors.of(context);
    final preset = values.preset;
    final value = values[selected];
    final percent = (value * 100).round();
    // IntrinsicWidth keeps the panel as wide as its widest row, so the
    // divider between the rows does not stretch across the window.
    return IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 2),
              for (final p in FilterPreset.values) ...[
                EditorChip(
                  label: s.preset(p),
                  selected: preset == p,
                  onPressed: () => onPreset(p),
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.fromLTRB(6, 3, 6, 3),
            color: c.separator,
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 2),
              for (final a in Adjustment.values) ...[
                EditorChip(
                  label: s.adjustment(a),
                  selected: selected == a,
                  onPressed: () => onSelect(a),
                ),
                const SizedBox(width: 2),
              ],
              const EditorDivider(),
              _LevelSlider(
                value: value,
                signed: selected.isSigned,
                label: s.adjustment(selected),
                onChanged: onChanged,
                onChangeStart: onChangeStart,
                onChangeEnd: onChangeEnd,
              ),
              SizedBox(
                width: 36,
                child: Text(
                  percent > 0 && selected.isSigned ? '+$percent' : '$percent',
                  textAlign: TextAlign.right,
                  style:
                      mgTextStyle(
                        c,
                        size: MgType.caption,
                        color: percent == 0 ? c.fg2 : c.fg,
                        height: 1,
                      ).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// A slider with a thin track and a tick at zero. A signed one runs from
/// -1 to 1 and fills from the middle; the rest fill from the left.
class _LevelSlider extends StatelessWidget {
  const _LevelSlider({
    required this.value,
    required this.signed,
    required this.label,
    required this.onChanged,
    required this.onChangeStart,
    required this.onChangeEnd,
  });

  final double value;
  final bool signed;
  final String label;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      slider: true,
      label: label,
      value: '${(value * 100).round()}',
      child: SizedBox(
        width: 150,
        height: 32,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            trackShape: _LevelTrack(
              signed: signed,
              track: c.fg2.withValues(alpha: 0.3),
              fill: c.accent,
            ),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              elevation: 1,
              pressedElevation: 2,
            ),
            overlayShape: SliderComponentShape.noOverlay,
            thumbColor: c.isDark ? const Color(0xFFF5F5F7) : Colors.white,
          ),
          child: Slider(
            value: value,
            min: signed ? -1 : 0,
            max: 1,
            onChanged: onChanged,
            onChangeStart: (_) => onChangeStart(),
            onChangeEnd: (_) => onChangeEnd(),
          ),
        ),
      ),
    );
  }
}

class _LevelTrack extends SliderTrackShape {
  const _LevelTrack({
    required this.signed,
    required this.track,
    required this.fill,
  });

  final bool signed;
  final Color track;
  final Color fill;

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final height = sliderTheme?.trackHeight ?? 3;
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
    final canvas = context.canvas;
    final radius = Radius.circular(rect.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = track,
    );
    final zero = signed ? rect.center.dx : rect.left;
    final filled = Rect.fromLTRB(
      thumbCenter.dx < zero ? thumbCenter.dx : zero,
      rect.top,
      thumbCenter.dx < zero ? zero : thumbCenter.dx,
      rect.bottom,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(filled, radius),
      Paint()..color = fill,
    );
    if (signed) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(zero, rect.center.dy),
          width: 2,
          height: 9,
        ),
        Paint()..color = track,
      );
    }
  }
}
