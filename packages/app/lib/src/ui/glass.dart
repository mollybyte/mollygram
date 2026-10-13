import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Glass settings toggled from the benchmark overlay.
class GlassSettings extends InheritedWidget {
  const GlassSettings({super.key, required this.blur, required super.child});

  /// When false, blur is off and only the translucent fill remains.
  final bool blur;

  static bool blurOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassSettings>()?.blur ?? true;

  @override
  bool updateShouldNotify(GlassSettings old) => old.blur != blur;
}

/// CSS saturate(190%) as a color matrix.
List<double> _saturate(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
  0, 0, 0, 1, 0, //
];

/// blur(30px) saturate(190%): in CSS the blur radius is the sigma.
final ui.ImageFilter glassFilter = ui.ImageFilter.compose(
  outer: ui.ColorFilter.matrix(_saturate(1.9)),
  inner: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30, tileMode: TileMode.clamp),
);

/// A glass surface of the floating layer. All instances read the backdrop
/// through one shared BackdropGroup (see main.dart), so the backdrop is
/// captured once per frame rather than once per panel.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.radius,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final double radius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final blur = GlassSettings.blurOf(context);
    final r = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OuterShadowPainter(radius: radius, color: c.shadow),
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter.grouped(
            filter: glassFilter,
            enabled: blur,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GlassBodyPainter(
                  radius: radius,
                  fill: blur ? c.glass : c.glassSolid,
                ),
                foregroundPainter: _GlassRimPainter(
                  radius: radius,
                  rim: c.rim,
                  hi: c.hi,
                  lo: c.lo,
                  glow: c.glow,
                ),
                child: Padding(padding: padding, child: child),
              ),
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

/// A light 1 px rim, a top highlight, a bottom shadow and an inner glow
/// (the mockup's inset shadows, which BoxShadow does not support).
class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({
    required this.radius,
    required this.rim,
    required this.hi,
    required this.lo,
    required this.glow,
  });

  final double radius;
  final Color rim;
  final Color hi;
  final Color lo;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
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
    // inset 0 1px 0 hi
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, 1)),
      ),
      Paint()..color = hi,
    );
    // inset 0 -1px 0 lo
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, -1)),
      ),
      Paint()..color = lo,
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
      old.hi != hi ||
      old.lo != lo ||
      old.glow != glow ||
      old.radius != radius;
}

/// Paints the outer shadow only outside the shape so it does not darken
/// the glass (Flutter's BoxShadow also fills the area under the box).
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
