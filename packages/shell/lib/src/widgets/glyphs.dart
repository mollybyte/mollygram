import 'package:flutter/widgets.dart';

import '../palette/palette_search.dart';

enum ShellGlyph {
  search,
  close,
  plus,
  tab,
  split,
  swap,
  next,
  previous,
  chat,
  file,
  command,
}

ShellGlyph glyphFor(PaletteGlyph g) => switch (g) {
  PaletteGlyph.tab => ShellGlyph.tab,
  PaletteGlyph.closeTab => ShellGlyph.close,
  PaletteGlyph.split => ShellGlyph.split,
  PaletteGlyph.swap => ShellGlyph.swap,
  PaletteGlyph.next => ShellGlyph.next,
  PaletteGlyph.previous => ShellGlyph.previous,
  PaletteGlyph.generic => ShellGlyph.command,
};

/// Small line icons drawn in code, on a 24×24 grid like the mocks' SVGs.
class Glyph extends StatelessWidget {
  const Glyph(
    this.glyph, {
    super.key,
    this.size = 17,
    this.color,
    this.strokeWidth = 1.8,
  });

  final ShellGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color!;
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color, strokeWidth),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color, this.strokeWidth);

  final ShellGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.scale(s);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path();
    switch (glyph) {
      case ShellGlyph.search:
        canvas.drawCircle(const Offset(11, 11), 7, paint);
        p
          ..moveTo(20, 20)
          ..lineTo(16.5, 16.5);
      case ShellGlyph.close:
        p
          ..moveTo(7, 7)
          ..lineTo(17, 17)
          ..moveTo(17, 7)
          ..lineTo(7, 17);
      case ShellGlyph.plus:
        p
          ..moveTo(12, 5)
          ..lineTo(12, 19)
          ..moveTo(5, 12)
          ..lineTo(19, 12);
      case ShellGlyph.tab:
        p
          ..moveTo(3, 8)
          ..lineTo(21, 8)
          ..addRRect(RRect.fromLTRBR(3, 4, 21, 20, const Radius.circular(2)))
          ..moveTo(10, 4)
          ..lineTo(10, 8);
      case ShellGlyph.split:
        p
          ..addRRect(RRect.fromLTRBR(3, 4, 21, 20, const Radius.circular(2)))
          ..moveTo(12, 4)
          ..lineTo(12, 20);
      case ShellGlyph.swap:
        p
          ..moveTo(4, 8)
          ..lineTo(20, 8)
          ..moveTo(16, 4)
          ..lineTo(20, 8)
          ..lineTo(16, 12)
          ..moveTo(20, 16)
          ..lineTo(4, 16)
          ..moveTo(8, 12)
          ..lineTo(4, 16)
          ..lineTo(8, 20);
      case ShellGlyph.next:
        p
          ..moveTo(9, 5)
          ..lineTo(16, 12)
          ..lineTo(9, 19);
      case ShellGlyph.previous:
        p
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case ShellGlyph.chat:
        p
          ..moveTo(4, 5)
          ..lineTo(20, 5)
          ..lineTo(20, 16)
          ..lineTo(9, 16)
          ..lineTo(4, 20)
          ..close();
      case ShellGlyph.file:
        p
          ..moveTo(7, 3)
          ..lineTo(14, 3)
          ..lineTo(19, 8)
          ..lineTo(19, 21)
          ..lineTo(7, 21)
          ..close()
          ..moveTo(14, 3)
          ..lineTo(14, 8)
          ..lineTo(19, 8);
      case ShellGlyph.command:
        p
          ..moveTo(6, 7)
          ..lineTo(11, 12)
          ..lineTo(6, 17)
          ..moveTo(13, 17)
          ..lineTo(18, 17);
    }
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
