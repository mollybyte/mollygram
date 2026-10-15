import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../model/crop_geometry.dart';
import '../model/media_edit.dart';
import '../model/stroke.dart';
import '../render/render.dart';

/// Where the picture sits on the stage for one frame.
@immutable
final class StageLayout {
  const StageLayout({
    required this.viewport,
    required this.dest,
    required this.crop,
  });

  /// Computes the layout of a stage of [stage] size.
  ///
  /// [crop] is the kept rectangle in pixels of the [oriented] picture and
  /// [cropMode] goes from 0 (only the crop, filling the stage) to 1 (the
  /// whole picture with the crop frame on it, inset by [inset] so the
  /// handles stay reachable).
  factory StageLayout.compute({
    required Size stage,
    required Size oriented,
    required Rect crop,
    required double cropMode,
    double inset = 28,
  }) {
    final viewport = Rect.lerp(crop, Offset.zero & oriented, cropMode)!;
    final room = (Offset.zero & stage).deflate(inset * cropMode);
    final dest = fitInside(viewport.size, room);
    final scale = viewport.width == 0 ? 0.0 : dest.width / viewport.width;
    return StageLayout(
      viewport: viewport,
      dest: dest,
      crop: Rect.fromLTWH(
        dest.left + (crop.left - viewport.left) * scale,
        dest.top + (crop.top - viewport.top) * scale,
        crop.width * scale,
        crop.height * scale,
      ),
    );
  }

  /// The part of the oriented picture on screen, in its pixels.
  final Rect viewport;

  /// Where [viewport] is drawn, in stage coordinates.
  final Rect dest;

  /// The crop rectangle in stage coordinates.
  final Rect crop;

  /// Stage pixels per picture pixel.
  double get scale => viewport.width == 0 ? 0 : dest.width / viewport.width;
}

/// Paints the picture, the dimmed part outside the crop, and the crop frame
/// with its handles and grid.
class StagePainter extends CustomPainter {
  StagePainter({
    required this.image,
    required this.source,
    required this.edit,
    required this.layout,
    required this.outsideOpacity,
    required this.frameOpacity,
    required this.gridOpacity,
    this.liveStroke,
  });

  final ui.Image image;
  final Size source;
  final MediaEdit edit;
  final StageLayout layout;

  /// Opacity of the picture outside the crop.
  final double outsideOpacity;

  /// Opacity of the frame and handles.
  final double frameOpacity;

  /// Opacity of the rule-of-thirds grid inside the frame.
  final double gridOpacity;

  /// The stroke being drawn right now.
  final Stroke? liveStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = layout.crop;
    canvas
      ..save()
      ..clipRect(crop);
    _picture(canvas, 1);
    canvas.restore();

    if (outsideOpacity > 0.001) {
      canvas
        ..save()
        ..clipPath(
          Path()
            ..fillType = PathFillType.evenOdd
            ..addRect(layout.dest)
            ..addRect(crop),
        );
      _picture(canvas, outsideOpacity);
      canvas.restore();
    }

    if (frameOpacity > 0.001) _frame(canvas, crop);
  }

  void _picture(Canvas canvas, double opacity) => paintEdited(
    canvas,
    image: image,
    source: source,
    edit: edit,
    viewport: layout.viewport,
    dest: layout.dest,
    opacity: opacity,
    liveStroke: liveStroke,
  );

  void _frame(Canvas canvas, Rect crop) {
    final a = frameOpacity;
    final white = Color.fromRGBO(255, 255, 255, a);
    final shade = Color.fromRGBO(0, 0, 0, 0.22 * a);

    if (gridOpacity > 0.001) {
      final grid = Paint()
        ..color = Color.fromRGBO(255, 255, 255, 0.55 * gridOpacity * a)
        ..strokeWidth = 1;
      for (var i = 1; i < 3; i++) {
        final x = crop.left + crop.width * i / 3;
        final y = crop.top + crop.height * i / 3;
        canvas
          ..drawLine(Offset(x, crop.top), Offset(x, crop.bottom), grid)
          ..drawLine(Offset(crop.left, y), Offset(crop.right, y), grid);
      }
    }

    canvas
      ..drawRect(
        crop.inflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = shade,
      )
      ..drawRect(
        crop.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = white,
      );

    // L-shaped corners and short bars on the edges, drawn just outside the
    // frame line so they do not cover the picture.
    const thick = 3.0;
    const arm = 18.0;
    final handle = Paint()
      ..color = white
      ..style = PaintingStyle.fill;
    final shadow = Paint()
      ..color = shade
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final o = crop.inflate(thick - 0.5);
    final arms = math.min(arm, math.min(crop.width, crop.height) / 2);
    final shapes = <Path>[
      for (final (corner, dx, dy) in [
        (o.topLeft, 1.0, 1.0),
        (o.topRight, -1.0, 1.0),
        (o.bottomRight, -1.0, -1.0),
        (o.bottomLeft, 1.0, -1.0),
      ])
        Path()
          ..moveTo(corner.dx, corner.dy)
          ..lineTo(corner.dx + dx * (arms + thick), corner.dy)
          ..lineTo(corner.dx + dx * (arms + thick), corner.dy + dy * thick)
          ..lineTo(corner.dx + dx * thick, corner.dy + dy * thick)
          ..lineTo(corner.dx + dx * thick, corner.dy + dy * (arms + thick))
          ..lineTo(corner.dx, corner.dy + dy * (arms + thick))
          ..close(),
      if (crop.width > arm * 4) ...[
        Path()..addRect(
          Rect.fromCenter(
            center: Offset(crop.center.dx, o.top + thick / 2),
            width: arm,
            height: thick,
          ),
        ),
        Path()..addRect(
          Rect.fromCenter(
            center: Offset(crop.center.dx, o.bottom - thick / 2),
            width: arm,
            height: thick,
          ),
        ),
      ],
      if (crop.height > arm * 4) ...[
        Path()..addRect(
          Rect.fromCenter(
            center: Offset(o.left + thick / 2, crop.center.dy),
            width: thick,
            height: arm,
          ),
        ),
        Path()..addRect(
          Rect.fromCenter(
            center: Offset(o.right - thick / 2, crop.center.dy),
            width: thick,
            height: arm,
          ),
        ),
      ],
    ];
    for (final path in shapes) {
      canvas.drawPath(path, shadow);
    }
    for (final path in shapes) {
      canvas.drawPath(path, handle);
    }
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.image != image ||
      old.edit != edit ||
      old.layout.viewport != layout.viewport ||
      old.layout.dest != layout.dest ||
      old.layout.crop != layout.crop ||
      old.outsideOpacity != outsideOpacity ||
      old.frameOpacity != frameOpacity ||
      old.gridOpacity != gridOpacity ||
      old.liveStroke != liveStroke;
}

/// The crop handle under [point], with [crop] in stage coordinates. Corners
/// win over edges, edges over the inside. Null outside the frame.
CropHandle? hitCropHandle(Offset point, Rect crop) {
  const corner = 22.0;
  const edge = 12.0;
  for (final (handle, at) in [
    (CropHandle.topLeft, crop.topLeft),
    (CropHandle.topRight, crop.topRight),
    (CropHandle.bottomRight, crop.bottomRight),
    (CropHandle.bottomLeft, crop.bottomLeft),
  ]) {
    if ((point - at).distance <= corner) return handle;
  }
  final inX = point.dx >= crop.left && point.dx <= crop.right;
  final inY = point.dy >= crop.top && point.dy <= crop.bottom;
  if (inX && (point.dy - crop.top).abs() <= edge) return CropHandle.top;
  if (inX && (point.dy - crop.bottom).abs() <= edge) return CropHandle.bottom;
  if (inY && (point.dx - crop.left).abs() <= edge) return CropHandle.left;
  if (inY && (point.dx - crop.right).abs() <= edge) return CropHandle.right;
  if (inX && inY) return CropHandle.move;
  return null;
}

/// The pointer shape over [handle].
MouseCursor cursorFor(CropHandle? handle, {bool dragging = false}) =>
    switch (handle) {
      null => MouseCursor.defer,
      CropHandle.topLeft ||
      CropHandle.bottomRight => SystemMouseCursors.resizeUpLeftDownRight,
      CropHandle.topRight ||
      CropHandle.bottomLeft => SystemMouseCursors.resizeUpRightDownLeft,
      CropHandle.left || CropHandle.right => SystemMouseCursors.resizeLeftRight,
      CropHandle.top || CropHandle.bottom => SystemMouseCursors.resizeUpDown,
      CropHandle.move =>
        dragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
    };
