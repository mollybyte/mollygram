import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

/// A QR code drawn with rounded modules, sized to fill its box.
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, required this.color});

  final String data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
      QrCode(
        payload: QrPayload.fromString(data),
        errorCorrectLevel: QrErrorCorrectLevel.medium,
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
    final paint = Paint()..color = color;
    final radius = Radius.circular(module * 0.3);
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (!image.isDark(row, col)) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              col * module,
              row * module,
              module,
              module,
            ).inflate(0.15),
            radius,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) =>
      old.image != image || old.color != color;
}
