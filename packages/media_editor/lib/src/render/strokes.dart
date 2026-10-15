import 'dart:math' as math;
import 'dart:ui';

import '../model/stroke.dart';

/// Opacity of the marker.
const markerOpacity = 0.45;

/// Draws [strokes] over the oriented picture of [oriented] pixels, in that
/// space. [live] is the stroke being drawn right now, on top.
///
/// The strokes go into their own layer so the eraser clears paint, not the
/// picture under it.
void paintStrokes(
  Canvas canvas,
  List<Stroke> strokes,
  Size oriented, {
  Stroke? live,
}) {
  if (strokes.isEmpty && live == null) return;
  canvas.saveLayer(Offset.zero & oriented, Paint());
  for (final stroke in strokes) {
    _paintStroke(canvas, stroke, oriented);
  }
  if (live != null) _paintStroke(canvas, live, oriented);
  canvas.restore();
}

/// Paints [stroke] as an opaque mask: the cut-out for the blur and
/// pixelate brushes, which draw the treated picture over it with srcIn.
void paintStrokeMask(Canvas canvas, Stroke stroke, Size oriented) {
  final short = math.min(oriented.width, oriented.height);
  canvas.drawPath(
    smoothPath(_points(stroke, oriented)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, stroke.width * short)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF000000),
  );
}

List<Offset> _points(Stroke stroke, Size oriented) => [
  for (final p in stroke.points)
    Offset(p.dx * oriented.width, p.dy * oriented.height),
];

void _paintStroke(Canvas canvas, Stroke stroke, Size oriented) {
  final short = math.min(oriented.width, oriented.height);
  final width = math.max(1.0, stroke.width * short);
  final points = _points(stroke, oriented);
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;
  switch (stroke.tool) {
    case BrushTool.pen:
    case BrushTool.arrow:
      paint.color = stroke.color;
    case BrushTool.marker:
      paint
        ..color = stroke.color.withValues(alpha: markerOpacity)
        ..strokeCap = StrokeCap.square;
    case BrushTool.eraser:
      paint
        ..color = const Color(0xFF000000)
        ..blendMode = BlendMode.clear;
    case BrushTool.blur:
    case BrushTool.pixelate:
      // Effects are applied to the picture in paintEdited.
      return;
  }
  canvas.drawPath(smoothPath(points), paint);
  if (stroke.tool == BrushTool.arrow && points.length >= 2) {
    _paintArrowhead(canvas, points, width, paint);
  }
}

/// A path through [points], rounded with quadratic curves through the
/// midpoints so fast mouse moves do not look jagged.
Path smoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  if (points.length == 1) {
    path.lineTo(points.first.dx, points.first.dy);
    return path;
  }
  if (points.length == 2) {
    path.lineTo(points[1].dx, points[1].dy);
    return path;
  }
  for (var i = 1; i < points.length - 1; i++) {
    final mid = (points[i] + points[i + 1]) / 2;
    path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
  }
  path.lineTo(points.last.dx, points.last.dy);
  return path;
}

void _paintArrowhead(
  Canvas canvas,
  List<Offset> points,
  double width,
  Paint paint,
) {
  final tip = points.last;
  // Take the direction from a point a little way back, so the last jitter
  // of the mouse does not turn the head.
  final back = math.max(width * 2, 6.0);
  var i = points.length - 2;
  while (i > 0 && (points[i] - tip).distance < back) {
    i--;
  }
  final from = points[i];
  if ((tip - from).distance < 0.5) return;
  final angle = math.atan2(tip.dy - from.dy, tip.dx - from.dx);
  final length = math.max(width * 3.2, 10.0);
  const spread = math.pi / 6;
  final head = Path()
    ..moveTo(
      tip.dx - length * math.cos(angle - spread),
      tip.dy - length * math.sin(angle - spread),
    )
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(
      tip.dx - length * math.cos(angle + spread),
      tip.dy - length * math.sin(angle + spread),
    );
  canvas.drawPath(head, paint);
}
