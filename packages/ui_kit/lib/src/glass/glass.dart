import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Shares one backdrop read between all [Glass] panels below it and lets the
/// app switch blur off (the mockup's prefers-reduced-transparency fallback).
///
/// Put one scope around the whole window, above the wallpaper and the
/// content that scrolls under the glass. Without a scope [Glass] still
/// works, but every panel reads the backdrop on its own.
class GlassScope extends StatelessWidget {
  const GlassScope({super.key, this.blur = true, required this.child});

  /// When false, glass is a near-opaque fill with no backdrop filter.
  final bool blur;
  final Widget child;

  /// Whether glass below [context] should blur its backdrop.
  static bool blurOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GlassSettings>()?.blur ??
      true;

  @override
  Widget build(BuildContext context) => _GlassSettings(
    blur: blur,
    child: BackdropGroup(child: child),
  );
}

class _GlassSettings extends InheritedWidget {
  const _GlassSettings({required this.blur, required super.child});

  final bool blur;

  @override
  bool updateShouldNotify(_GlassSettings old) => old.blur != blur;
}

/// CSS saturate() as a color matrix.
List<double> _saturate(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// Material parameters of the floating layer.
abstract final class GlassSpec {
  /// blur(30px): in CSS the blur radius is the Gaussian sigma.
  static const double blurSigma = 30;

  /// saturate(190%).
  static const double saturation = 1.9;

  /// The backdrop filter: blur first, then saturate.
  static final ui.ImageFilter filter = ui.ImageFilter.compose(
    outer: ui.ColorFilter.matrix(_saturate(saturation)),
    inner: ui.ImageFilter.blur(
      sigmaX: blurSigma,
      sigmaY: blurSigma,
      tileMode: TileMode.clamp,
    ),
  );
}

/// A liquid glass surface.
///
/// Glass belongs to the floating layer only: the sidebar island, the two
/// chat header capsules, the composer and the command palette. Messages,
/// rows and everything that scrolls stay solid.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double radius;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final blur = GlassScope.blurOf(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OuterShadowPainter(radius: radius, color: c.shadow),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter.grouped(
            filter: GlassSpec.filter,
            enabled: blur,
            child: CustomPaint(
              painter: _GlassBodyPainter(
                radius: radius,
                fill: blur ? c.glass : c.glassSolid,
              ),
              foregroundPainter: _GlassRimPainter(
                radius: radius,
                rim: c.rim,
                highlight: c.highlight,
                lowlight: c.lowlight,
                glow: c.glow,
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBodyPainter extends CustomPainter {
  _GlassBodyPainter({required this.radius, required this.fill});

  final double radius;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_GlassBodyPainter old) =>
      old.fill != fill || old.radius != radius;
}

/// The 1 px rim, the top highlight, the bottom line and the inner glow: the
/// mockup's inset shadows, which BoxShadow does not support.
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.radius,
    required this.rim,
    required this.highlight,
    required this.lowlight,
    required this.glow,
  });

  final double radius;
  final Color rim;
  final Color highlight;
  final Color lowlight;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);

    // inset 0 0 18px glow
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );

    final outer = Path()..addRRect(rrect);
    // inset 0 1px 0 highlight
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, 1)),
      ),
      Paint()..color = highlight,
    );
    // inset 0 -1px 0 lowlight
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, -1)),
      ),
      Paint()..color = lowlight,
    );
    canvas.restore();

    // 1px border
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = rim,
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.rim != rim ||
      old.highlight != highlight ||
      old.lowlight != lowlight ||
      old.glow != glow ||
      old.radius != radius;
}

/// Paints the drop shadow only outside the shape, so it does not darken the
/// glass (BoxShadow also fills the area under the box).
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect((Offset.zero & size).inflate(80))
      ..addRRect(rrect);
    canvas.save();
    canvas.clipPath(outside);
    // 0 12px 34px shadow
    canvas.drawRRect(
      rrect.shift(const Offset(0, 12)),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17),
    );
    // 0 0 0 .5px rgba(0,0,0,.06)
    canvas.drawRRect(
      rrect.inflate(0.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..color = const Color(0x0F000000),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) =>
      old.color != color || old.radius != radius;
}
