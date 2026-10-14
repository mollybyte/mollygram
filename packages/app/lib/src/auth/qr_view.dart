import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

/// A QR code in the official apps' style: round dots and rounded finder
/// squares. High error correction leaves room for the mark in the middle.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, required this.color});

  final String data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.high,
      ),
    );
    return Semantics(
      image: true,
      child: CustomPaint(
        painter: _QrPainter(image, color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, this.color);

  final QrImage image;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final module = size.shortestSide / count;
    final paint = Paint()
      ..color = color
      ..isAntiAlias = true;

    bool inFinder(int row, int col) =>
        (row < 7 && col < 7) ||
        (row < 7 && col >= count - 7) ||
        (row >= count - 7 && col < 7);

    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (inFinder(row, col) || !image.isDark(row, col)) continue;
        canvas.drawCircle(
          Offset((col + 0.5) * module, (row + 0.5) * module),
          module * 0.42,
          paint,
        );
      }
    }

    for (final (row, col) in [(0, 0), (0, count - 7), (count - 7, 0)]) {
      final outer = Rect.fromLTWH(
        col * module,
        row * module,
        module * 7,
        module * 7,
      );
      canvas.drawDRRect(
        RRect.fromRectAndRadius(outer, Radius.circular(module * 2)),
        RRect.fromRectAndRadius(
          outer.deflate(module),
          Radius.circular(module * 1.4),
        ),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          outer.deflate(module * 2),
          Radius.circular(module * 0.9),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.image != image || old.color != color;
}
