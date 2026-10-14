import 'package:flutter/widgets.dart';

import 'theme/colors.dart';

/// The four-point Telegram gradient wallpaper: four elliptical radial
/// gradients over a base color, as in the mockup.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _WallpaperPainter(c.wallpaperBase, c.wallpaper),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Spot {
  const _Spot(this.rx, this.ry, this.cx, this.cy);

  final double rx, ry, cx, cy;
}

// radial-gradient(60% 55% at 12% 18%, ...), and so on, per the mockup.
const _spots = [
  _Spot(0.60, 0.55, 0.12, 0.18),
  _Spot(0.55, 0.55, 0.88, 0.12),
  _Spot(0.60, 0.60, 0.82, 0.88),
  _Spot(0.55, 0.60, 0.18, 0.90),
];

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.base, this.colors);

  final Color base;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    // In CSS the first layer is on top, so paint from the last one.
    for (var i = _spots.length - 1; i >= 0; i--) {
      final s = _spots[i];
      final color = colors[i];
      canvas.save();
      canvas.translate(s.cx * size.width, s.cy * size.height);
      canvas.scale(s.rx * size.width, s.ry * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 0.7],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 1));
      canvas.drawRect(const Rect.fromLTRB(-3, -3, 3, 3), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) =>
      old.base != base || !_sameColors(old.colors, colors);

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
