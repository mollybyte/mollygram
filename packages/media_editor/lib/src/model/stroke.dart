import 'dart:ui';

import 'package:flutter/foundation.dart';

/// What a stroke is drawn with.
enum BrushTool {
  /// A solid line.
  pen,

  /// A wide, translucent line, like a highlighter.
  marker,

  /// A line with an arrowhead at its end.
  arrow,

  /// Removes what was drawn under it.
  eraser,

  /// Blurs the picture under it.
  blur,

  /// Turns the picture under it into large square cells.
  pixelate;

  /// Changes the picture itself rather than painting over it.
  bool get isEffect => this == blur || this == pixelate;
}

/// One drawn line in the oriented picture, with every coordinate
/// normalized to 0..1 of the oriented size so it survives rotation, crops
/// and any preview resolution.
@immutable
final class Stroke {
  const Stroke({
    required this.tool,
    required this.color,
    required this.width,
    required this.points,
  });

  final BrushTool tool;
  final Color color;

  /// Line width as a fraction of the shorter side of the oriented picture.
  final double width;

  /// Normalized points, at least one.
  final List<Offset> points;

  Stroke withPoints(List<Offset> points) =>
      Stroke(tool: tool, color: color, width: width, points: points);

  /// Mapped through [f], used for turns and mirrors.
  Stroke mapPoints(Offset Function(Offset) f) =>
      withPoints([for (final p in points) f(p)]);

  @override
  bool operator ==(Object other) =>
      other is Stroke &&
      other.tool == tool &&
      other.color == color &&
      other.width == width &&
      listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(tool, color, width, Object.hashAll(points));

  @override
  String toString() => 'Stroke(${tool.name}, ${points.length} points)';
}
