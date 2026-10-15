import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_overlay');
    path = '${dir.path}/p.png';
    File(path).writeAsBytesSync(
      img.encodePng(
        img.Image(width: 200, height: 100)..clear(img.ColorRgb8(0, 0, 0)),
      ),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  const box = ShapeOverlay(
    id: 1,
    center: Offset(0.25, 0.5),
    kind: ShapeKind.rectangle,
    color: Color(0xFFFF0000),
    filled: true,
    scale: 0.4,
    aspect: 1,
  );

  test('overlays are replaced by id and removed', () {
    var edit = const MediaEdit().withOverlay(box);
    expect(edit.nextOverlayId, 2);
    edit = edit.withOverlay(box.copyWith(color: Colors.blue));
    expect(edit.overlays, hasLength(1));
    expect((edit.overlays.single as ShapeOverlay).color, Colors.blue);
    expect(edit.overlay(1), isNotNull);
    expect(edit.withoutOverlay(1).overlays, isEmpty);
    expect(edit.withoutOverlay(1).isIdentity, isTrue);
  });

  test('overlays turn and mirror with the picture', () {
    final turned = const MediaEdit().withOverlay(box).rotatedLeft();
    final o = turned.overlays.single;
    expect(o.center.dx, closeTo(0.5, 1e-9));
    expect(o.center.dy, closeTo(0.75, 1e-9));
    expect(o.rotation, closeTo(-math.pi / 2, 1e-9));
    final mirrored = const MediaEdit()
        .withOverlay(box.copyWith(rotation: 0.3))
        .flippedHorizontally();
    expect(mirrored.overlays.single.center.dx, closeTo(0.75, 1e-9));
    expect(mirrored.overlays.single.rotation, closeTo(-0.3, 1e-9));
  });

  test('hit testing honours rotation', () {
    const oriented = Size(200, 100);
    // A 40x40 box at (50, 50).
    expect(hitOverlay(const Offset(50, 50), [box], oriented), box);
    expect(hitOverlay(const Offset(75, 50), [box], oriented), isNull);
    final turned = box.copyWith(rotation: math.pi / 4, aspect: 4, scale: 0.8);
    // An 80x20 bar turned 45 degrees: its far end is along the diagonal.
    expect(
      hitOverlay(const Offset(50 + 25, 50 + 25), [turned], oriented),
      turned,
    );
    expect(hitOverlay(const Offset(85, 50), [turned], oriented), isNull);
  });

  testWidgets('a filled shape is in the export', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit().withOverlay(box),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      expect(image.getPixel(50, 50).r, 255);
      expect(image.getPixel(150, 50).r, 0);
    });
  });

  testWidgets('a text frame is in the export at the crop', (tester) async {
    await tester.runAsync(() async {
      final out = await exportEdit(
        path,
        const MediaEdit(crop: Rect.fromLTRB(0.5, 0, 1, 1)).withOverlay(
          const TextOverlay(
            id: 1,
            center: Offset(0.75, 0.5),
            text: 'Hello',
            color: Color(0xFF00FF00),
            look: TextLook.frame,
            scale: 0.2,
          ),
        ),
        outputDirectory: dir.path,
      );
      final image = img.decodeImage(await File(out.path).readAsBytes())!;
      expect((out.width, out.height), (100, 100));
      // The frame is green just inside its top edge; the test font draws
      // the letters as boxes over the middle rows.
      expect(image.getPixel(50, 36).g, 255);
      expect(image.getPixel(50, 10).g, 0);
    });
  });
}
