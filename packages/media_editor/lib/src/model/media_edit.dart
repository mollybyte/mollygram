import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'adjustments.dart';
import 'overlay.dart';
import 'stroke.dart';

/// The whole rectangle in normalized coordinates.
const Rect unitRect = Rect.fromLTRB(0, 0, 1, 1);

/// Crop aspect ratios offered in the crop tool.
enum AspectPreset {
  free(null),
  original(null),
  square(1),
  ratio3x2(3 / 2),
  ratio4x3(4 / 3),
  ratio16x9(16 / 9);

  const AspectPreset(this._landscape);

  /// Width over height in landscape, at least 1. Null for [free] and
  /// [original], which has no fixed value.
  final double? _landscape;

  /// Whether the preset has a portrait and a landscape variant.
  bool get hasOrientation => this != free && this != square;
}

/// What the editor did to a picture, applied to the original file on export.
///
/// Geometry lives in the *oriented* space: the source picture after
/// [quarterTurns] clockwise turns and then the optional horizontal [flipped]
/// mirror. [crop] is a rectangle in that space, normalized to 0..1, so it
/// stays valid whatever resolution the picture is decoded at.
@immutable
final class MediaEdit {
  const MediaEdit({
    this.quarterTurns = 0,
    this.flipped = false,
    this.crop = unitRect,
    this.aspect = AspectPreset.free,
    this.portrait = false,
    this.strokes = const [],
    this.overlays = const [],
    this.adjustments = const Adjustments(),
  }) : assert(quarterTurns >= 0 && quarterTurns < 4);

  /// Clockwise quarter turns of the source, 0 to 3.
  final int quarterTurns;

  /// Mirrored left to right, after the turns.
  final bool flipped;

  /// The kept part of the oriented picture, normalized.
  final Rect crop;

  /// The locked crop ratio, or [AspectPreset.free].
  final AspectPreset aspect;

  /// Whether a preset with an orientation is used upright (taller than
  /// wide).
  final bool portrait;

  /// Drawn lines in the oriented picture, oldest first.
  final List<Stroke> strokes;

  /// Text, emoji and shapes over the strokes, bottom first.
  final List<MediaOverlay> overlays;

  /// Colour adjustments and the vignette.
  final Adjustments adjustments;

  /// Nothing to apply: the original file can be sent as is.
  bool get isIdentity =>
      quarterTurns == 0 &&
      !flipped &&
      _nearlyUnit(crop) &&
      strokes.isEmpty &&
      overlays.isEmpty &&
      adjustments.isIdentity;

  /// Size of the oriented picture for a source of [source] pixels.
  Size orientedSize(Size source) =>
      quarterTurns.isOdd ? source.flipped : source;

  /// [crop] in pixels of the oriented picture.
  Rect cropIn(Size oriented) => denormalize(crop, oriented);

  /// The locked width over height for a source of [source] pixels, or null
  /// when the crop is free.
  double? ratioFor(Size source) {
    final double base;
    switch (aspect) {
      case AspectPreset.free:
        return null;
      case AspectPreset.original:
        final long = math.max(source.width, source.height);
        final short = math.min(source.width, source.height);
        if (short <= 0) return null;
        base = long / short;
      default:
        base = aspect._landscape!;
    }
    return portrait ? 1 / base : base;
  }

  /// Turned a quarter counterclockwise, crop and locked ratio included.
  MediaEdit rotatedLeft() => MediaEdit(
    // Turning the mirrored picture left is a right turn before the mirror.
    quarterTurns: (quarterTurns + (flipped ? 1 : 3)) % 4,
    flipped: flipped,
    crop: Rect.fromLTRB(crop.top, 1 - crop.right, crop.bottom, 1 - crop.left),
    aspect: aspect,
    portrait: aspect.hasOrientation ? !portrait : portrait,
    strokes: [
      for (final s in strokes) s.mapPoints((p) => Offset(p.dy, 1 - p.dx)),
    ],
    overlays: [for (final o in overlays) o.rotatedLeft()],
    adjustments: adjustments,
  );

  /// Mirrored left to right, crop included.
  MediaEdit flippedHorizontally() => MediaEdit(
    quarterTurns: quarterTurns,
    flipped: !flipped,
    crop: Rect.fromLTRB(1 - crop.right, crop.top, 1 - crop.left, crop.bottom),
    aspect: aspect,
    portrait: portrait,
    strokes: [
      for (final s in strokes) s.mapPoints((p) => Offset(1 - p.dx, p.dy)),
    ],
    overlays: [for (final o in overlays) o.flippedHorizontally()],
    adjustments: adjustments,
  );

  MediaEdit copyWith({
    Rect? crop,
    AspectPreset? aspect,
    bool? portrait,
    List<Stroke>? strokes,
    List<MediaOverlay>? overlays,
    Adjustments? adjustments,
  }) => MediaEdit(
    quarterTurns: quarterTurns,
    flipped: flipped,
    crop: crop ?? this.crop,
    aspect: aspect ?? this.aspect,
    portrait: portrait ?? this.portrait,
    strokes: strokes ?? this.strokes,
    overlays: overlays ?? this.overlays,
    adjustments: adjustments ?? this.adjustments,
  );

  /// With [stroke] drawn on top.
  MediaEdit withStroke(Stroke stroke) =>
      copyWith(strokes: [...strokes, stroke]);

  /// With [overlay] added on top, or replacing the one with its id.
  MediaEdit withOverlay(MediaOverlay overlay) {
    final i = overlays.indexWhere((o) => o.id == overlay.id);
    if (i < 0) return copyWith(overlays: [...overlays, overlay]);
    final next = [...overlays];
    next[i] = overlay;
    return copyWith(overlays: next);
  }

  /// Without the overlay with [id].
  MediaEdit withoutOverlay(int id) => copyWith(
    overlays: [
      for (final o in overlays)
        if (o.id != id) o,
    ],
  );

  /// The overlay with [id], or null.
  MediaOverlay? overlay(int? id) {
    for (final o in overlays) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// An id no overlay uses.
  int get nextOverlayId => overlays.fold(0, (m, o) => math.max(m, o.id)) + 1;

  /// Locks the crop to [preset], fitting the largest rectangle of that ratio
  /// around the current crop's center. [portrait] defaults to the shape of
  /// the oriented picture.
  MediaEdit withAspect(AspectPreset preset, Size source, {bool? portrait}) {
    final oriented = orientedSize(source);
    final next = copyWith(
      aspect: preset,
      portrait:
          portrait ??
          (preset.hasOrientation ? oriented.height > oriented.width : false),
    );
    final ratio = next.ratioFor(source);
    if (ratio == null) return next;
    final fitted = fitRatio(cropIn(oriented), oriented, ratio);
    return next.copyWith(crop: normalize(fitted, oriented));
  }

  @override
  bool operator ==(Object other) =>
      other is MediaEdit &&
      other.quarterTurns == quarterTurns &&
      other.flipped == flipped &&
      other.crop == crop &&
      other.aspect == aspect &&
      other.portrait == portrait &&
      listEquals(other.strokes, strokes) &&
      listEquals(other.overlays, overlays) &&
      other.adjustments == adjustments;

  @override
  int get hashCode => Object.hash(
    quarterTurns,
    flipped,
    crop,
    aspect,
    portrait,
    Object.hashAll(strokes),
    Object.hashAll(overlays),
    adjustments,
  );

  @override
  String toString() =>
      'MediaEdit(turns: $quarterTurns, flipped: $flipped, crop: $crop, '
      'aspect: ${aspect.name}${portrait ? ' portrait' : ''}, '
      '${strokes.length} strokes, ${overlays.length} overlays)';
}

bool _nearlyUnit(Rect r) =>
    r.left.abs() < 1e-4 &&
    r.top.abs() < 1e-4 &&
    (r.right - 1).abs() < 1e-4 &&
    (r.bottom - 1).abs() < 1e-4;

/// [rect] in pixels of [size] as a normalized rectangle.
Rect normalize(Rect rect, Size size) => Rect.fromLTRB(
  rect.left / size.width,
  rect.top / size.height,
  rect.right / size.width,
  rect.bottom / size.height,
);

/// [rect] normalized to 0..1 as pixels of [size].
Rect denormalize(Rect rect, Size size) => Rect.fromLTRB(
  rect.left * size.width,
  rect.top * size.height,
  rect.right * size.width,
  rect.bottom * size.height,
);

/// The largest rectangle of [ratio] inside [bounds], centered on [around]'s
/// center and pushed back inside [bounds] where needed.
Rect fitRatio(Rect around, Size bounds, double ratio) {
  var width = bounds.width;
  var height = width / ratio;
  if (height > bounds.height) {
    height = bounds.height;
    width = height * ratio;
  }
  final center = around.center;
  final left = (center.dx - width / 2).clamp(0.0, bounds.width - width);
  final top = (center.dy - height / 2).clamp(0.0, bounds.height - height);
  return Rect.fromLTWH(left, top, width, height);
}
