import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

/// A 40x20 PNG: left half red, right half blue.
Uint8List _twoColors() {
  final image = img.Image(width: 40, height: 20);
  for (var y = 0; y < 20; y++) {
    for (var x = 0; x < 40; x++) {
      image.setPixelRgb(x, y, x < 20 ? 255 : 0, 0, x < 20 ? 0 : 255);
    }
  }
  return img.encodePng(image);
}

Future<img.Image> _read(String path) async =>
    img.decodeImage(await File(path).readAsBytes())!;

void main() {
  late Directory dir;
  late String png;
  late String jpg;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_test');
    png = '${dir.path}/two.png';
    File(png).writeAsBytesSync(_twoColors());
    jpg = '${dir.path}/two.jpg';
    File(jpg).writeAsBytesSync(img.encodeJpg(img.decodePng(_twoColors())!));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('crop keeps the chosen half', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        png,
        const MediaEdit(crop: ui.Rect.fromLTRB(0.5, 0, 1, 1)),
        outputDirectory: dir.path,
      );
      expect(out.path, endsWith('.png'));
      expect((out.width, out.height), (20, 20));
      final pixel = (await _read(out.path)).getPixel(10, 10);
      expect((pixel.r, pixel.b), (0, 255));
    });
  });

  testWidgets('a left turn puts the right half on top', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        png,
        const MediaEdit().rotatedLeft(),
        outputDirectory: dir.path,
      );
      expect((out.width, out.height), (20, 40));
      final image = await _read(out.path);
      expect(image.getPixel(10, 5).b, 255);
      expect(image.getPixel(10, 35).r, 255);
    });
  });

  testWidgets('a mirror swaps the halves; JPEG stays JPEG', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        jpg,
        const MediaEdit().flippedHorizontally(),
        outputDirectory: dir.path,
      );
      expect(out.path, endsWith('.jpg'));
      final image = await _read(out.path);
      expect(image.getPixel(5, 10).b, greaterThan(200));
      expect(image.getPixel(35, 10).r, greaterThan(200));
    });
  });

  test('Rect helpers are exported', () {
    expect(unitRect, const Rect.fromLTRB(0, 0, 1, 1));
  });
}
