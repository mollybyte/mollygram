import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../model/overlay.dart';

/// The family of the overlay text: the system font on every platform.
const _fontFamily = '.SF Pro Text';
const _fontFallback = ['.AppleSystemUIFont', 'Segoe UI', 'Roboto', 'Noto Sans'];

/// Size of [overlay] in pixels of the oriented picture, before rotation.
Size overlaySize(MediaOverlay overlay, Size oriented) {
  final short = math.min(oriented.width, oriented.height);
  switch (overlay) {
    case TextOverlay():
      final painter = _textPainter(overlay, short, oriented);
      final pad = _framePadding(overlay, short);
      final size = painter.size;
      painter.dispose();
      return Size(size.width + pad.horizontal, size.height + pad.vertical);
    case EmojiOverlay():
      final painter = _emojiPainter(overlay, short);
      final size = painter.size;
      painter.dispose();
      return size;
    case ShapeOverlay():
      final width = overlay.scale * short;
      return Size(width, width / overlay.aspect);
    case ImageOverlay():
      final width = overlay.scale * short;
      return Size(width, width / overlay.aspect);
  }
}

/// Draws [overlays] over the oriented picture of [oriented] pixels, in
/// that space, bottom first. [images] holds the decoded pictures of
/// image overlays by path; one that is missing is not drawn.
void paintOverlays(
  Canvas canvas,
  List<MediaOverlay> overlays,
  Size oriented, {
  Map<String, ui.Image> images = const {},
}) {
  for (final overlay in overlays) {
    paintOverlay(canvas, overlay, oriented, images: images);
  }
}

/// Draws one [overlay], rotated around its center.
void paintOverlay(
  Canvas canvas,
  MediaOverlay overlay,
  Size oriented, {
  Map<String, ui.Image> images = const {},
}) {
  final short = math.min(oriented.width, oriented.height);
  final center = Offset(
    overlay.center.dx * oriented.width,
    overlay.center.dy * oriented.height,
  );
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(overlay.rotation);
  switch (overlay) {
    case TextOverlay():
      _paintText(canvas, overlay, short, oriented);
    case EmojiOverlay():
      final painter = _emojiPainter(overlay, short);
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      painter.dispose();
    case ShapeOverlay():
      _paintShape(canvas, overlay, short);
    case ImageOverlay():
      final image = images[overlay.path];
      if (image != null) {
        final size = overlaySize(overlay, oriented);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCenter(
            center: Offset.zero,
            width: size.width,
            height: size.height,
          ),
          Paint()
            ..filterQuality = FilterQuality.high
            ..isAntiAlias = true,
        );
      }
  }
  canvas.restore();
}

/// Letters of a text overlay at [scale] on a picture with a shorter side
/// of [short] pixels.
double textFontSize(double scale, double short) => math.max(4.0, scale * short);

EdgeInsets _framePadding(TextOverlay overlay, double short) {
  if (overlay.look != TextLook.frame) return EdgeInsets.zero;
  final size = textFontSize(overlay.scale, short);
  return EdgeInsets.symmetric(horizontal: size * 0.45, vertical: size * 0.2);
}

TextPainter _textPainter(TextOverlay overlay, double short, Size oriented) {
  final size = textFontSize(overlay.scale, short);
  final color = switch (overlay.look) {
    TextLook.plain || TextLook.outline => overlay.color,
    TextLook.frame => _onColor(overlay.color),
  };
  final painter = TextPainter(
    text: TextSpan(
      text: overlay.text.isEmpty ? ' ' : overlay.text,
      style: TextStyle(
        fontFamily: _fontFamily,
        fontFamilyFallback: _fontFallback,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
        shadows: overlay.look == TextLook.plain
            ? [
                Shadow(
                  color: const Color(0x66000000),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
              ]
            : null,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: oriented.width * 0.9);
  return painter;
}

void _paintText(
  Canvas canvas,
  TextOverlay overlay,
  double short,
  Size oriented,
) {
  final painter = _textPainter(overlay, short, oriented);
  final size = textFontSize(overlay.scale, short);
  final pad = _framePadding(overlay, short);
  final origin = Offset(-painter.width / 2, -painter.height / 2);
  switch (overlay.look) {
    case TextLook.plain:
      break;
    case TextLook.outline:
      final outline = TextPainter(
        text: TextSpan(
          text: overlay.text.isEmpty ? ' ' : overlay.text,
          style: TextStyle(
            fontFamily: _fontFamily,
            fontFamilyFallback: _fontFallback,
            fontSize: size,
            fontWeight: FontWeight.w700,
            height: 1.2,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeJoin = StrokeJoin.round
              ..strokeWidth = size * 0.14
              ..color = _onColor(overlay.color),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: oriented.width * 0.9);
      outline.paint(canvas, origin);
      outline.dispose();
    case TextLook.frame:
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: painter.width + pad.horizontal,
        height: painter.height + pad.vertical,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(size * 0.3)),
        Paint()..color = overlay.color,
      );
  }
  painter.paint(canvas, origin);
  painter.dispose();
}

TextPainter _emojiPainter(EmojiOverlay overlay, double short) => TextPainter(
  text: TextSpan(
    text: overlay.emoji,
    style: TextStyle(
      fontSize: math.max(4.0, overlay.scale * short),
      fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
      height: 1.2,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout();

void _paintShape(Canvas canvas, ShapeOverlay overlay, double short) {
  final width = overlay.scale * short;
  final height = width / overlay.aspect;
  final rect = Rect.fromCenter(
    center: Offset.zero,
    width: width,
    height: height,
  );
  final stroke = math.max(1.0, overlay.strokeWidth * short);
  final paint = Paint()
    ..color = overlay.color
    ..isAntiAlias = true
    ..style = overlay.filled ? PaintingStyle.fill : PaintingStyle.stroke
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  switch (overlay.kind) {
    case ShapeKind.rectangle:
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(stroke)),
        paint,
      );
    case ShapeKind.ellipse:
      canvas.drawOval(rect, paint);
    case ShapeKind.line:
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(Offset(rect.left, 0), Offset(rect.right, 0), paint);
    case ShapeKind.arrow:
      paint.style = PaintingStyle.stroke;
      final length = math.max(stroke * 3.2, 10.0);
      const spread = math.pi / 6;
      final tip = Offset(rect.right, 0);
      canvas
        ..drawLine(Offset(rect.left, 0), tip, paint)
        ..drawPath(
          Path()
            ..moveTo(
              tip.dx - length * math.cos(spread),
              -length * math.sin(spread),
            )
            ..lineTo(tip.dx, 0)
            ..lineTo(
              tip.dx - length * math.cos(spread),
              length * math.sin(spread),
            ),
          paint,
        );
  }
}

/// White or near-black, whichever reads on [color].
Color _onColor(Color color) => color.computeLuminance() > 0.5
    ? const Color(0xFF1D1D1F)
    : const Color(0xFFFFFFFF);

/// The point [p] in overlay-local coordinates of [overlay] placed on a
/// picture of [oriented] pixels: the overlay's center is the origin and
/// its rotation is undone.
Offset toOverlaySpace(Offset p, MediaOverlay overlay, Size oriented) {
  final center = Offset(
    overlay.center.dx * oriented.width,
    overlay.center.dy * oriented.height,
  );
  final d = p - center;
  final cos = math.cos(-overlay.rotation);
  final sin = math.sin(-overlay.rotation);
  return Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
}

/// The overlay under [p] (oriented pixels), topmost first, with [slack]
/// extra pixels around each so thin shapes can be grabbed.
MediaOverlay? hitOverlay(
  Offset p,
  List<MediaOverlay> overlays,
  Size oriented, {
  double slack = 0,
}) {
  for (final overlay in overlays.reversed) {
    final size = overlaySize(overlay, oriented);
    final local = toOverlaySpace(p, overlay, oriented);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    ).inflate(slack);
    if (rect.contains(local)) return overlay;
  }
  return null;
}
