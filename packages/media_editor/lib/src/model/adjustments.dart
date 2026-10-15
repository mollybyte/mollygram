import 'package:flutter/foundation.dart';

/// One adjustable quality of the picture.
enum Adjustment {
  brightness,
  contrast,
  saturation,
  warmth,
  fade,
  vignette;

  /// Whether the slider runs from -1 to 1 (otherwise 0 to 1).
  bool get isSigned => this != fade && this != vignette;
}

/// Named looks: a set of adjustment values applied at once.
enum FilterPreset {
  original(Adjustments()),
  vivid(Adjustments(saturation: 0.35, contrast: 0.15)),
  warm(Adjustments(warmth: 0.5, saturation: 0.1)),
  cool(Adjustments(warmth: -0.5, saturation: 0.05)),
  mono(Adjustments(saturation: -1, contrast: 0.1)),
  faded(Adjustments(fade: 0.6, saturation: -0.2, vignette: 0.3)),
  dramatic(Adjustments(contrast: 0.4, saturation: 0.1, vignette: 0.55));

  const FilterPreset(this.look);

  final Adjustments look;
}

/// Colour adjustments of the picture, each 0 when untouched.
@immutable
final class Adjustments {
  const Adjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.fade = 0,
    this.vignette = 0,
  });

  /// -1 to 1.
  final double brightness;

  /// -1 to 1.
  final double contrast;

  /// -1 (grey) to 1.
  final double saturation;

  /// -1 (cool) to 1 (warm).
  final double warmth;

  /// 0 to 1: lifted blacks and softer colours.
  final double fade;

  /// 0 to 1: darkened corners.
  final double vignette;

  bool get isIdentity =>
      brightness == 0 &&
      contrast == 0 &&
      saturation == 0 &&
      warmth == 0 &&
      fade == 0 &&
      vignette == 0;

  double operator [](Adjustment a) => switch (a) {
    Adjustment.brightness => brightness,
    Adjustment.contrast => contrast,
    Adjustment.saturation => saturation,
    Adjustment.warmth => warmth,
    Adjustment.fade => fade,
    Adjustment.vignette => vignette,
  };

  /// With [a] set to [value].
  Adjustments set(Adjustment a, double value) => Adjustments(
    brightness: a == Adjustment.brightness ? value : brightness,
    contrast: a == Adjustment.contrast ? value : contrast,
    saturation: a == Adjustment.saturation ? value : saturation,
    warmth: a == Adjustment.warmth ? value : warmth,
    fade: a == Adjustment.fade ? value : fade,
    vignette: a == Adjustment.vignette ? value : vignette,
  );

  /// The preset whose values these are, if any.
  FilterPreset? get preset {
    for (final p in FilterPreset.values) {
      if (p.look == this) return p;
    }
    return null;
  }

  /// The 4x5 colour matrix for `ColorFilter.matrix`, without the vignette,
  /// which is drawn separately.
  List<double> get colorMatrix {
    var m = _identity;
    // Contrast: scale around mid grey.
    final c = 1 + contrast * (contrast > 0 ? 0.8 : 0.6);
    m = _multiply(_scaleOffset(c, 128 * (1 - c)), m);
    // Brightness: a plain offset.
    m = _multiply(_scaleOffset(1, brightness * 80), m);
    // Saturation: blend with luminance.
    final s = 1 + saturation;
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    m = _multiply([
      lr * (1 - s) + s,
      lg * (1 - s),
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s) + s,
      lb * (1 - s),
      0,
      0,
      lr * (1 - s),
      lg * (1 - s),
      lb * (1 - s) + s,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ], m);
    // Warmth: push red up and blue down, or the reverse.
    final w = warmth * 28;
    m = _multiply([
      1,
      0,
      0,
      0,
      w,
      0,
      1,
      0,
      0,
      w * 0.25,
      0,
      0,
      1,
      0,
      -w,
      0,
      0,
      0,
      1,
      0,
    ], m);
    // Fade: lift the blacks and flatten.
    final f = 1 - fade * 0.35;
    m = _multiply(_scaleOffset(f, fade * 55), m);
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is Adjustments &&
      other.brightness == brightness &&
      other.contrast == contrast &&
      other.saturation == saturation &&
      other.warmth == warmth &&
      other.fade == fade &&
      other.vignette == vignette;

  @override
  int get hashCode =>
      Object.hash(brightness, contrast, saturation, warmth, fade, vignette);

  @override
  String toString() =>
      'Adjustments(b $brightness, c $contrast, s $saturation, w $warmth, '
      'f $fade, v $vignette)';
}

const _identity = <double>[
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

List<double> _scaleOffset(double scale, double offset) => [
  scale,
  0,
  0,
  0,
  offset,
  0,
  scale,
  0,
  0,
  offset,
  0,
  0,
  scale,
  0,
  offset,
  0,
  0,
  0,
  1,
  0,
];

/// [a] applied after [b], as 4x5 matrices over (r, g, b, a, 1).
List<double> _multiply(List<double> a, List<double> b) {
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += a[row * 5 + k] * b[k * 5 + col];
      }
      if (col == 4) v += a[row * 5 + 4];
      out[row * 5 + col] = v;
    }
  }
  return out;
}
