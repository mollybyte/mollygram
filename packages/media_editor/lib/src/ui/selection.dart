import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import '../model/overlay.dart';
import '../render/overlays.dart';
import 'stage.dart';

/// What a drag on a selected overlay does.
enum OverlayHandle { move, transform, delete }

/// The selected overlay's frame on the stage: its four corners, in stage
/// coordinates, plus the transform and delete handles.
final class SelectionFrame {
  SelectionFrame._(this.corners, this.transform, this.delete);

  /// Top left, top right, bottom right, bottom left.
  final List<Offset> corners;

  /// The handle that scales and turns, at the bottom right corner.
  final Offset transform;

  /// The handle that removes the overlay, at the top left corner.
  final Offset delete;

  /// The frame of [overlay] on a picture of [oriented] pixels shown with
  /// [layout]. [pad] is a margin around the content, in stage pixels.
  factory SelectionFrame.of(
    MediaOverlay overlay,
    Size oriented,
    StageLayout layout, {
    double pad = 8,
  }) {
    final size = overlaySize(overlay, oriented);
    final scale = layout.scale;
    final center =
        layout.dest.topLeft +
        (Offset(
                  overlay.center.dx * oriented.width,
                  overlay.center.dy * oriented.height,
                ) -
                layout.viewport.topLeft) *
            scale;
    final half = Offset(
      size.width * scale / 2 + pad,
      size.height * scale / 2 + pad,
    );
    final cos = math.cos(overlay.rotation);
    final sin = math.sin(overlay.rotation);
    Offset at(double x, double y) =>
        center + Offset(x * cos - y * sin, x * sin + y * cos);
    final corners = [
      at(-half.dx, -half.dy),
      at(half.dx, -half.dy),
      at(half.dx, half.dy),
      at(-half.dx, half.dy),
    ];
    return SelectionFrame._(corners, corners[2], corners[0]);
  }

  Offset get center => (corners[0] + corners[2]) / 2;

  /// The handle under [p], if any; [move] inside the frame.
  OverlayHandle? hit(Offset p) {
    const radius = 14.0;
    if ((p - transform).distance <= radius) return OverlayHandle.transform;
    if ((p - delete).distance <= radius) return OverlayHandle.delete;
    final path = Path()..addPolygon(corners, true);
    return path.contains(p) ? OverlayHandle.move : null;
  }
}

/// Paints the selection frame: a thin dashed rounded outline, the delete
/// button and the transform handle.
class SelectionPainter extends CustomPainter {
  SelectionPainter({
    required this.frame,
    required this.accent,
    required this.opacity,
  });

  final SelectionFrame? frame;
  final Color accent;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = this.frame;
    if (frame == null || opacity <= 0.001) return;
    final white = Color.fromRGBO(255, 255, 255, opacity);
    final shade = Color.fromRGBO(0, 0, 0, 0.35 * opacity);

    final outline = Path()..addPolygon(frame.corners, true);
    canvas
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = shade
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      )
      ..drawPath(
        _dashed(outline, 5, 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = white,
      );

    void knob(Offset at, Color fill) {
      canvas
        ..drawCircle(
          at,
          9,
          Paint()
            ..color = shade
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        )
        ..drawCircle(at, 9, Paint()..color = white)
        ..drawCircle(at, 6.5, Paint()..color = fill);
    }

    knob(frame.transform, accent.withValues(alpha: opacity));
    // The transform knob: a small arc with an arrowhead, for "turn".
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = white;
    canvas.drawArc(
      Rect.fromCircle(center: frame.transform, radius: 3.6),
      -math.pi * 0.8,
      math.pi * 1.4,
      false,
      arc,
    );

    knob(frame.delete, Color.fromRGBO(255, 59, 48, opacity));
    final cross = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = white;
    const r = 2.6;
    canvas
      ..drawLine(
        frame.delete + const Offset(-r, -r),
        frame.delete + const Offset(r, r),
        cross,
      )
      ..drawLine(
        frame.delete + const Offset(r, -r),
        frame.delete + const Offset(-r, r),
        cross,
      );
  }

  Path _dashed(Path source, double dash, double gap) {
    final out = Path();
    for (final metric in source.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + dash, metric.length);
        out.addPath(metric.extractPath(d, end), Offset.zero);
        d = end + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(SelectionPainter old) =>
      old.opacity != opacity ||
      old.accent != accent ||
      old.frame?.corners.toString() != frame?.corners.toString();
}
