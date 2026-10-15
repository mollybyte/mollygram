import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../model/media_edit.dart';
import '../model/stroke.dart';
import 'overlays.dart';
import 'strokes.dart';

/// Paints the edited picture so that [viewport], a rectangle of the
/// oriented picture in its pixels, lands on [dest].
///
/// [image] may be a downscaled copy of the [source]-sized original: it is
/// stretched over the full source rectangle, so the same call draws the
/// on-screen preview and the exported file.
void paintEdited(
  Canvas canvas, {
  required ui.Image image,
  required Size source,
  required MediaEdit edit,
  required Rect viewport,
  required Rect dest,
  double opacity = 1,
  Stroke? liveStroke,
  ui.Image? pixelated,
}) {
  if (viewport.isEmpty || dest.isEmpty) return;
  final oriented = edit.orientedSize(source);
  final effects = [
    for (final s in edit.strokes)
      if (s.tool.isEffect) s,
    if (liveStroke != null && liveStroke.tool.isEffect) liveStroke,
  ];
  final paint = [
    for (final s in edit.strokes)
      if (!s.tool.isEffect) s,
  ];
  canvas
    ..save()
    ..translate(dest.left, dest.top)
    ..scale(dest.width / viewport.width, dest.height / viewport.height)
    ..translate(-viewport.left, -viewport.top);
  if (opacity < 1) {
    canvas.saveLayer(
      Offset.zero & oriented,
      Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
    );
  }
  void picture(ui.Image image, Paint paint) {
    canvas
      ..save()
      ..translate(oriented.width / 2, oriented.height / 2);
    if (edit.flipped) canvas.scale(-1, 1);
    canvas
      ..rotate(edit.quarterTurns * math.pi / 2)
      ..translate(-source.width / 2, -source.height / 2)
      ..drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & source,
        paint,
      )
      ..restore();
  }

  final colorFilter = edit.adjustments.isIdentity
      ? null
      : ColorFilter.matrix(edit.adjustments.colorMatrix);
  picture(
    image,
    Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..colorFilter = colorFilter,
  );
  final short = math.min(oriented.width, oriented.height);
  for (final stroke in effects) {
    if (stroke.tool == BrushTool.pixelate && pixelated == null) continue;
    // The stroke goes into a layer first, then the treated picture is
    // drawn over the whole layer with srcIn, so it survives only where
    // the stroke was painted.
    canvas.saveLayer(Offset.zero & oriented, Paint());
    paintStrokeMask(canvas, stroke, oriented);
    if (stroke.tool == BrushTool.blur) {
      final sigma = math.max(2.0, short * 0.012);
      picture(
        image,
        Paint()
          ..filterQuality = FilterQuality.high
          ..blendMode = BlendMode.srcIn
          ..colorFilter = colorFilter
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.clamp,
          ),
      );
    } else {
      picture(
        pixelated!,
        Paint()
          ..filterQuality = FilterQuality.none
          ..blendMode = BlendMode.srcIn
          ..colorFilter = colorFilter,
      );
    }
    canvas.restore();
  }
  if (edit.adjustments.vignette > 0) {
    paintVignette(canvas, edit.cropIn(oriented), edit.adjustments.vignette);
  }
  paintStrokes(
    canvas,
    paint,
    oriented,
    live: liveStroke != null && !liveStroke.tool.isEffect ? liveStroke : null,
  );
  paintOverlays(canvas, edit.overlays, oriented);
  if (opacity < 1) canvas.restore();
  canvas.restore();
}

/// The largest side of an exported picture. Larger crops are scaled down
/// to stay inside GPU texture limits.
const maxExportSide = 8192;

/// Decodes [bytes] into an image no larger than [maxSide] on its long side,
/// along with the full-resolution size. EXIF orientation is applied by the
/// decoder.
Future<(ui.Image, Size)> decodePicture(Uint8List bytes, {int? maxSide}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final full = frame.image;
  final source = Size(full.width.toDouble(), full.height.toDouble());
  final long = math.max(full.width, full.height);
  if (maxSide == null || long <= maxSide) return (full, source);
  final scale = maxSide / long;
  final width = math.max(1, (full.width * scale).round());
  final height = math.max(1, (full.height * scale).round());
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    full,
    Offset.zero & source,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  final small = await picture.toImage(width, height);
  picture.dispose();
  full.dispose();
  return (small, source);
}

/// Darkens the corners of [rect] by [amount], 0 to 1.
void paintVignette(Canvas canvas, Rect rect, double amount) {
  final radius = math.max(rect.width, rect.height) * 0.75;
  canvas.drawRect(
    rect,
    Paint()
      ..shader = ui.Gradient.radial(
        rect.center,
        radius,
        [
          const Color(0x00000000),
          const Color(0x00000000),
          Color.fromRGBO(0, 0, 0, 0.85 * amount),
        ],
        [0, 0.45, 1],
        TileMode.clamp,
        // Squash the circle into the picture's shape, around its centre.
        Float64List.fromList([
          1,
          0,
          0,
          0,
          0,
          rect.height / rect.width,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          rect.center.dy * (1 - rect.height / rect.width),
          0,
          1,
        ]),
      ),
  );
}

/// Cells of the pixelate brush, as a fraction of the longer side.
const pixelateCell = 1 / 40;

/// A copy of [image] with one pixel per pixelate cell. Stretched back
/// over the picture without smoothing, it is the pixelated look.
Future<ui.Image> pixelatedCopy(ui.Image image) async {
  final long = math.max(image.width, image.height);
  final cells = (1 / pixelateCell).round();
  final scale = math.min(1.0, cells / long);
  final width = math.max(1, (image.width * scale).round());
  final height = math.max(1, (image.height * scale).round());
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final small = await picture.toImage(width, height);
  picture.dispose();
  return small;
}

/// An edited file written by [exportEdit].
typedef ExportedPicture = ({String path, int width, int height});

/// Applies [edit] to the picture at [path] at full resolution and writes
/// the result into a new folder under [outputDirectory] (the system temp
/// folder by default). PNG sources stay PNG to keep transparency; the rest
/// become JPEG.
Future<ExportedPicture> exportEdit(
  String path,
  MediaEdit edit, {
  String? outputDirectory,
}) async {
  final bytes = await File(path).readAsBytes();
  final (image, source) = await decodePicture(bytes);
  final oriented = edit.orientedSize(source);
  final crop = edit.cropIn(oriented);
  final scale = math.min(
    1.0,
    maxExportSide / math.max(crop.width, crop.height),
  );
  final width = math.max(1, (crop.width * scale).round());
  final height = math.max(1, (crop.height * scale).round());

  final pixelated = edit.strokes.any((s) => s.tool == BrushTool.pixelate)
      ? await pixelatedCopy(image)
      : null;
  final recorder = ui.PictureRecorder();
  paintEdited(
    Canvas(recorder),
    image: image,
    source: source,
    edit: edit,
    viewport: crop,
    dest: Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    pixelated: pixelated,
  );
  final picture = recorder.endRecording();
  final out = await picture.toImage(width, height);
  picture.dispose();
  image.dispose();
  pixelated?.dispose();

  final name = _baseName(path);
  final png = name.ext == 'png';
  final Uint8List encoded;
  if (png) {
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    encoded = data!.buffer.asUint8List();
  } else {
    final data = await out.toByteData();
    final rgba = data!.buffer.asUint8List();
    encoded = await Isolate.run(() => _encodeJpeg(rgba, width, height));
  }
  out.dispose();

  final parent = Directory(outputDirectory ?? Directory.systemTemp.path);
  final dir = await parent.createTemp('mollygram-edit-');
  final file = File('${dir.path}/${name.stem}.${png ? 'png' : 'jpg'}');
  await file.writeAsBytes(encoded, flush: true);
  return (path: file.path, width: width, height: height);
}

Uint8List _encodeJpeg(Uint8List rgba, int width, int height) {
  final image = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(image, quality: 93);
}

({String stem, String ext}) _baseName(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return (stem: name, ext: '');
  return (
    stem: name.substring(0, dot),
    ext: name.substring(dot + 1).toLowerCase(),
  );
}
