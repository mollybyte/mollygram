import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_draw');
    path = '${dir.path}/p.png';
    File(path).writeAsBytesSync(
      img.encodePng(
        img.Image(width: 100, height: 100)..clear(img.ColorRgb8(0, 0, 0)),
      ),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  const red = Stroke(
    tool: BrushTool.pen,
    color: Color(0xFFFF0000),
    width: 0.1,
    points: [Offset(0.1, 0.5), Offset(0.9, 0.5)],
  );

  test('strokes turn and mirror with the picture', () {
    final edit = const MediaEdit().withStroke(red);
    expect(edit.isIdentity, isFalse);
    final turned = edit.rotatedLeft();
    expect(turned.strokes.single.points.first.dx, closeTo(0.5, 1e-9));
    expect(turned.strokes.single.points.first.dy, closeTo(0.9, 1e-9));
    final mirrored = edit.flippedHorizontally();
    expect(mirrored.strokes.single.points.first.dx, closeTo(0.9, 1e-9));
    expect(edit, const MediaEdit().withStroke(red));
  });

  testWidgets('a pen stroke is in the export', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit().withStroke(red),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      expect(image.getPixel(50, 50).r, 255);
      expect(image.getPixel(50, 10).r, 0);
    });
  });

  testWidgets('the eraser clears paint but not the picture', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit()
            .withStroke(red)
            .withStroke(
              const Stroke(
                tool: BrushTool.eraser,
                color: Color(0xFFFFFFFF),
                width: 0.2,
                points: [Offset(0.5, 0.3), Offset(0.5, 0.7)],
              ),
            ),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      final erased = image.getPixel(50, 50);
      expect((erased.r, erased.g, erased.b, erased.a), (0, 0, 0, 255));
      expect(image.getPixel(20, 50).r, 255);
    });
  });

  testWidgets('the marker is translucent', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit().withStroke(
          const Stroke(
            tool: BrushTool.marker,
            color: Color(0xFFFFFFFF),
            width: 0.1,
            points: [Offset(0.1, 0.5), Offset(0.9, 0.5)],
          ),
        ),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      final r = image.getPixel(50, 50).r;
      expect(r, greaterThan(80));
      expect(r, lessThan(180));
    });
  });

  testWidgets('a cropped export keeps strokes in place', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit(crop: Rect.fromLTRB(0.5, 0, 1, 1)).withStroke(red),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      expect((out.width, out.height), (50, 100));
      expect(image.getPixel(10, 50).r, 255);
      expect(image.getPixel(48, 50).r, 0);
    });
  });
}
