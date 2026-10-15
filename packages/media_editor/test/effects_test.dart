import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_effects');
    path = '${dir.path}/p.png';
    // Left half black, right half white, 200x100.
    final image = img.Image(width: 200, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 200; x++) {
        image.setPixelRgb(
          x,
          y,
          x < 100 ? 0 : 255,
          x < 100 ? 0 : 255,
          x < 100 ? 0 : 255,
        );
      }
    }
    File(path).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<img.Image> export(Stroke stroke) async {
    final out = await exportEdit(
      path,
      const MediaEdit().withStroke(stroke),
      outputDirectory: dir.path,
    );
    return img.decodeImage(await File(out.path).readAsBytes())!;
  }

  testWidgets('blur softens the edge only under the stroke', (tester) async {
    await tester.runAsync(() async {
      final image = await export(
        const Stroke(
          tool: BrushTool.blur,
          color: Color(0xFFFFFFFF),
          width: 0.3,
          points: [Offset(0.4, 0.3), Offset(0.6, 0.3)],
        ),
      );
      final under = image.getPixel(100, 30).r;
      expect(under, greaterThan(20));
      expect(under, lessThan(235));
      expect(image.getPixel(90, 30).r, 0);
      // Away from the stroke the edge stays hard.
      expect(image.getPixel(98, 85).r, 0);
      expect(image.getPixel(102, 85).r, 255);
    });
  });

  testWidgets('pixelate makes cells only under the stroke', (tester) async {
    await tester.runAsync(() async {
      final image = await export(
        const Stroke(
          tool: BrushTool.pixelate,
          color: Color(0xFFFFFFFF),
          width: 0.3,
          points: [Offset(0.4, 0.3), Offset(0.6, 0.3)],
        ),
      );
      // Cells are 5 px (200 / 40) and uniform inside.
      expect(image.getPixel(96, 30).r, image.getPixel(98, 30).r);
      expect(image.getPixel(101, 30).r, image.getPixel(103, 30).r);
      expect(image.getPixel(90, 30).r, lessThan(20));
      expect(image.getPixel(110, 30).r, greaterThan(235));
      expect(image.getPixel(98, 85).r, 0);
      expect(image.getPixel(102, 85).r, 255);
    });
  });
}
