import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// How a text overlay is drawn.
enum TextLook {
  /// Coloured letters with a soft shadow.
  plain,

  /// Coloured letters with a contrasting outline.
  outline,

  /// Light or dark letters on a coloured rounded frame.
  frame,
}

/// Shapes the shape tool can place.
enum ShapeKind { rectangle, ellipse, line, arrow }

/// Something placed on the picture: text, an emoji or a shape.
///
/// Every overlay has a [center] normalized to the oriented picture, a
/// [scale] that is its size as a fraction of the picture's shorter side,
/// and a [rotation] in radians, clockwise.
@immutable
sealed class MediaOverlay {
  const MediaOverlay({
    required this.id,
    required this.center,
    required this.scale,
    required this.rotation,
  });

  /// Stable across edits, so a selection survives undo and redo.
  final int id;
  final Offset center;
  final double scale;
  final double rotation;

  MediaOverlay placed({Offset? center, double? scale, double? rotation});

  /// Moved with the picture when it turns a quarter counterclockwise.
  MediaOverlay rotatedLeft() => placed(
    center: Offset(center.dy, 1 - center.dx),
    rotation: rotation - math.pi / 2,
  );

  /// Moved with the picture when it is mirrored. The content itself stays
  /// readable, so only the position and the tilt mirror.
  MediaOverlay flippedHorizontally() =>
      placed(center: Offset(1 - center.dx, center.dy), rotation: -rotation);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is MediaOverlay &&
      other.id == id &&
      other.center == center &&
      other.scale == scale &&
      other.rotation == rotation &&
      sameContent(other);

  /// Whether [other], of the same type, has the same content.
  @protected
  bool sameContent(covariant MediaOverlay other);

  /// Content is left out of the hash on purpose: [sameContent] is what
  /// tells overlays of one id apart, and a hash on the placement alone is
  /// still consistent with [==].
  @override
  int get hashCode => Object.hash(runtimeType, id, center, scale, rotation);
}

final class TextOverlay extends MediaOverlay {
  const TextOverlay({
    required super.id,
    required super.center,
    required this.text,
    required this.color,
    this.look = TextLook.plain,
    super.scale = 0.08,
    super.rotation = 0,
  });

  final String text;
  final Color color;
  final TextLook look;

  @override
  TextOverlay placed({Offset? center, double? scale, double? rotation}) =>
      copyWith(center: center, scale: scale, rotation: rotation);

  TextOverlay copyWith({
    Offset? center,
    double? scale,
    double? rotation,
    String? text,
    Color? color,
    TextLook? look,
  }) => TextOverlay(
    id: id,
    center: center ?? this.center,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    text: text ?? this.text,
    color: color ?? this.color,
    look: look ?? this.look,
  );

  @override
  bool sameContent(TextOverlay other) =>
      other.text == text && other.color == color && other.look == look;
}

final class EmojiOverlay extends MediaOverlay {
  const EmojiOverlay({
    required super.id,
    required super.center,
    required this.emoji,
    super.scale = 0.18,
    super.rotation = 0,
  });

  final String emoji;

  @override
  EmojiOverlay placed({Offset? center, double? scale, double? rotation}) =>
      EmojiOverlay(
        id: id,
        center: center ?? this.center,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        emoji: emoji,
      );

  @override
  bool sameContent(EmojiOverlay other) => other.emoji == emoji;
}

final class ShapeOverlay extends MediaOverlay {
  const ShapeOverlay({
    required super.id,
    required super.center,
    required this.kind,
    required this.color,
    this.aspect = 1.5,
    this.strokeWidth = 0.012,
    this.filled = false,
    super.scale = 0.4,
    super.rotation = 0,
  });

  final ShapeKind kind;
  final Color color;

  /// Width over height; [scale] is the width.
  final double aspect;

  /// Line width as a fraction of the shorter side.
  final double strokeWidth;
  final bool filled;

  @override
  ShapeOverlay placed({Offset? center, double? scale, double? rotation}) =>
      copyWith(center: center, scale: scale, rotation: rotation);

  ShapeOverlay copyWith({
    Offset? center,
    double? scale,
    double? rotation,
    Color? color,
    double? aspect,
    double? strokeWidth,
    bool? filled,
  }) => ShapeOverlay(
    id: id,
    center: center ?? this.center,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    kind: kind,
    color: color ?? this.color,
    aspect: aspect ?? this.aspect,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    filled: filled ?? this.filled,
  );

  @override
  bool sameContent(ShapeOverlay other) =>
      other.kind == kind &&
      other.color == color &&
      other.aspect == aspect &&
      other.strokeWidth == strokeWidth &&
      other.filled == filled;
}

/// A picture file placed on the photo, such as a sticker. [scale] is its
/// width as a fraction of the shorter side.
final class ImageOverlay extends MediaOverlay {
  const ImageOverlay({
    required super.id,
    required super.center,
    required this.path,
    this.aspect = 1,
    super.scale = 0.3,
    super.rotation = 0,
  });

  /// The image file, decoded by whoever draws the overlay.
  final String path;

  /// Width over height of the image.
  final double aspect;

  @override
  ImageOverlay placed({Offset? center, double? scale, double? rotation}) =>
      ImageOverlay(
        id: id,
        center: center ?? this.center,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        path: path,
        aspect: aspect,
      );

  @override
  bool sameContent(ImageOverlay other) =>
      other.path == path && other.aspect == aspect;
}
