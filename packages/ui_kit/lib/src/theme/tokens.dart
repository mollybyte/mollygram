import 'package:flutter/animation.dart';

/// Corner radii, in points.
///
/// They follow the official macOS client's 5, 6 and 10 steps (rows and
/// fields, controls, the floating layer), with a card step for the Stage
/// layout and a tiny one for small thumbnails.
abstract final class MgRadius {
  /// Tiny thumbnails and badges, 24 px across or less.
  static const double tiny = 4;

  /// Text fields, menu and choice rows, chips.
  static const double small = 6;

  /// Buttons, media and thumbnails larger than 24 px.
  static const double control = 8;

  /// The floating layer: menus, popovers, dialogs, sheets and toasts.
  static const double popover = 10;

  /// The chat card of the Stage layout.
  static const double card = 12;
}

/// The spacing scale, in points: paddings, gaps and margins.
abstract final class MgSpace {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 6;
  static const double m = 8;
  static const double ml = 10;
  static const double l = 12;
  static const double xl = 16;
  static const double xxl = 20;
}

/// Durations and curves of motion. Nothing overshoots on the floating
/// layer: it eases in and fades out, as the official macOS client does.
/// Only small acknowledgements, such as choosing a reaction, pop.
abstract final class MgMotion {
  /// Hover and press feedback.
  static const Duration fast = Duration(milliseconds: 120);

  /// Layout changes and things appearing.
  static const Duration standard = Duration(milliseconds: 200);

  /// Things leaving: a popover's or a dialog's fade out.
  static const Duration exit = Duration(milliseconds: 150);

  /// Something arriving.
  static const Curve enter = Curves.easeOutCubic;

  /// Something leaving.
  static const Curve exitCurve = Curves.easeInCubic;

  /// Everything else, such as hover fills and layout changes.
  static const Curve standardCurve = Curves.easeOut;

  /// A small thing acknowledging a tap: a reaction landing, a count
  /// changing.
  static const Duration pop = Duration(milliseconds: 300);

  /// Settles a hair past its size and back, a spring without the wobble.
  static const Curve popCurve = Cubic(0.34, 1.35, 0.64, 1);
}
