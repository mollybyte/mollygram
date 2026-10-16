import 'dart:math' as math;
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

/// A small pointer on one edge of a [Glass] panel, aimed at what opened
/// it, as macOS popovers have.
@immutable
final class GlassTail {
  const GlassTail({required this.x, this.up = true, this.fromRight = false});

  /// The tip's distance from the panel's left edge, or its right one.
  final double x;
  final bool fromRight;

  /// On the top edge, pointing up; else on the bottom, pointing down.
  final bool up;

  static const double height = 8;
  static const double width = 20;

  @override
  bool operator ==(Object other) =>
      other is GlassTail &&
      other.x == x &&
      other.up == up &&
      other.fromRight == fromRight;

  @override
  int get hashCode => Object.hash(x, up, fromRight);

  /// The panel's outline: its rounded body with the pointer joined on.
  Path shape(Size size, double radius) {
    final body = Rect.fromLTRB(
      0,
      up ? height : 0,
      size.width,
      size.height - (up ? 0 : height),
    );
    // The pointer stays on the straight part of the edge.
    final tip = (fromRight ? size.width - x : x).clamp(
      radius + width / 2,
      size.width - radius - width / 2,
    );
    final edge = up ? body.top : body.bottom;
    final point = up ? 0.0 : size.height;
    final toward = up ? 1.0 : -1.0;
    final pointer = Path()
      ..moveTo(tip - width / 2, edge + toward)
      ..lineTo(tip - 2.5, point + 2 * toward)
      ..quadraticBezierTo(tip, point, tip + 2.5, point + 2 * toward)
      ..lineTo(tip + width / 2, edge + toward)
      ..close();
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius))),
      pointer,
    );
  }
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
    this.tail,
    this.dense = false,
  });

  final double radius;

  /// A denser, clearer pane for menus and alerts: more fill and no inner
  /// glow, so rows of text read crisply over busy chats.
  final bool dense;
  final EdgeInsetsGeometry padding;
  final Widget child;

  /// A pointer on the top or bottom edge; the panel grows by its height.
  final GlassTail? tail;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final blur = GlassScope.blurOf(context);
    final tail = this.tail;
    final body = BackdropFilter.grouped(
      filter: GlassSpec.filter,
      enabled: blur,
      child: CustomPaint(
        painter: _GlassBodyPainter(
          radius: radius,
          tail: tail,
          fill: !blur
              ? c.glassSolid
              : dense
              ? c.glass.withValues(alpha: math.max(c.glass.a, 0.62))
              : c.glass,
        ),
        foregroundPainter: _GlassRimPainter(
          radius: radius,
          tail: tail,
          rim: c.rim,
          highlight: c.highlight,
          lowlight: c.lowlight,
          glow: dense ? const Color(0x00000000) : c.glow,
        ),
        child: Padding(
          padding: tail == null
              ? EdgeInsets.zero
              : EdgeInsets.only(
                  top: tail.up ? GlassTail.height : 0,
                  bottom: tail.up ? 0 : GlassTail.height,
                ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return RepaintBoundary(
      child: CustomPaint(
        painter: _OuterShadowPainter(
          radius: radius,
          tail: tail,
          color: c.shadow,
        ),
        child: tail == null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: body,
              )
            : ClipPath(clipper: _TailClipper(tail, radius), child: body),
      ),
    );
  }
}

class _TailClipper extends CustomClipper<Path> {
  _TailClipper(this.tail, this.radius);

  final GlassTail tail;
  final double radius;

  @override
  Path getClip(Size size) => tail.shape(size, radius);

  @override
  bool shouldReclip(_TailClipper old) =>
      old.tail != tail || old.radius != radius;
}

class _GlassBodyPainter extends CustomPainter {
  _GlassBodyPainter({required this.radius, required this.fill, this.tail});

  final double radius;
  final Color fill;
  final GlassTail? tail;

  @override
  void paint(Canvas canvas, Size size) {
    if (tail case final tail?) {
      canvas.drawPath(tail.shape(size, radius), Paint()..color = fill);
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      Paint()..color = fill,
    );
  }

  @override
  bool shouldRepaint(_GlassBodyPainter old) =>
      old.fill != fill || old.radius != radius || old.tail != tail;
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
    this.tail,
  });

  final double radius;
  final GlassTail? tail;
  final Color rim;
  final Color highlight;
  final Color lowlight;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (tail case final tail?) {
      _paintPath(canvas, tail.shape(size, radius));
      return;
    }
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

  /// The same layers along any outline, for a panel with a tail.
  void _paintPath(Canvas canvas, Path outer) {
    canvas.save();
    canvas.clipPath(outer);
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, 1)),
      ),
      Paint()..color = highlight,
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        outer,
        outer.shift(const Offset(0, -1)),
      ),
      Paint()..color = lowlight,
    );
    // The rim, drawn inside the clip so it stays 1 px along the pointer.
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = rim,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) =>
      old.tail != tail ||
      old.rim != rim ||
      old.highlight != highlight ||
      old.lowlight != lowlight ||
      old.glow != glow ||
      old.radius != radius;
}

/// Paints the drop shadow only outside the shape, so it does not darken the
/// glass (BoxShadow also fills the area under the box).
class _OuterShadowPainter extends CustomPainter {
  _OuterShadowPainter({required this.radius, required this.color, this.tail});

  final double radius;
  final Color color;
  final GlassTail? tail;

  @override
  void paint(Canvas canvas, Size size) {
    if (tail case final tail?) {
      final shape = tail.shape(size, radius);
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect((Offset.zero & size).inflate(80))
          ..addPath(shape, Offset.zero),
      );
      canvas.drawPath(
        shape.shift(const Offset(0, 12)),
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 17),
      );
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0x0F000000),
      );
      canvas.restore();
      return;
    }
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
      old.color != color || old.radius != radius || old.tail != tail;
}
