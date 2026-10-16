import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

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

  /// Pressing in: instant, the control follows the pointer.
  static const Duration press = Duration(milliseconds: 80);

  /// Scale of a pressed control; a hair, so it reads as a push, not a jump.
  static const double pressScale = 0.97;

  /// A critically damped spring (damping 1.0, settles in 0.45 s): things that
  /// move and settle without overshoot. Pair with [settleDuration].
  static const Curve settle = MgSpringCurve(damping: 1, response: 0.45);

  /// A slightly under-damped spring (damping 0.8): only for motion that
  /// carries momentum, such as a release after a press or a flick.
  static const Curve spring = MgSpringCurve(damping: 0.8, response: 0.45);

  /// Long enough for [settle] and [spring] to come to rest.
  static const Duration settleDuration = Duration(milliseconds: 450);

  /// A small thing acknowledging a tap: a reaction landing, a count
  /// changing.
  static const Duration pop = Duration(milliseconds: 300);

  /// Settles a hair past its size and back, a spring without the wobble.
  static const Curve popCurve = Cubic(0.34, 1.35, 0.64, 1);
}

/// A spring as an animation [Curve], so implicit animations can use it.
///
/// [response] is the time in seconds the spring takes to come to rest,
/// [damping] the damping ratio: 1.0 settles without overshoot, below 1.0 it
/// overshoots and rings. Run it with a duration equal to [response].
class MgSpringCurve extends Curve {
  const MgSpringCurve({required this.damping, required this.response});

  final double damping;
  final double response;

  @override
  double transformInternal(double t) {
    if (t >= 1) return 1;
    // [response] is the whole settle window; ~7 / response puts a critically
    // damped spring within 1% of its target at the end of it.
    final omega = 7 / response;
    final sim = SpringSimulation(
      SpringDescription(
        mass: 1,
        stiffness: omega * omega,
        damping: 2 * damping * omega,
      ),
      0,
      1,
      0,
    );
    return sim.x(t * response);
  }
}

/// The Flutter [BoxShadow.blurRadius] that draws a CSS `box-shadow` blur of
/// [css] pixels: CSS blurs with a sigma of half the radius, Flutter with
/// `0.577 * r + 0.5`, so copying the canvas's numbers as they are spreads
/// every shadow by about 15 % and makes it read as a flat grey band.
double cssBlur(double css) => css <= 1 ? 0 : (css / 2 - 0.5) / 0.57735;
