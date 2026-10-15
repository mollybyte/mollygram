import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_adjust');
    path = '${dir.path}/p.png';
    // A mid grey picture with a red square in the middle.
    final image = img.Image(width: 200, height: 100)
      ..clear(img.ColorRgb8(128, 128, 128));
    img.fillRect(
      image,
      x1: 90,
      y1: 40,
      x2: 110,
      y2: 60,
      color: img.ColorRgb8(200, 60, 60),
    );
    File(path).writeAsBytesSync(img.encodePng(image));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<img.Image> export(Adjustments a) async {
    final out = await exportEdit(
      path,
      MediaEdit(adjustments: a),
      outputDirectory: dir.path,
    );
    return img.decodeImage(await File(out.path).readAsBytes())!;
  }

  test('identity and presets', () {
    expect(const Adjustments().isIdentity, isTrue);
    expect(const Adjustments().preset, FilterPreset.original);
    expect(FilterPreset.vivid.look.preset, FilterPreset.vivid);
    expect(const Adjustments(brightness: 0.1).preset, isNull);
    expect(
      const Adjustments().set(Adjustment.warmth, 0.5),
      const Adjustments(warmth: 0.5),
    );
    expect(
      const MediaEdit(adjustments: Adjustments(fade: 0.2)).isIdentity,
      isFalse,
    );
  });

  test('the identity matrix leaves colours alone', () {
    final m = const Adjustments().colorMatrix;
    expect(m[0], 1);
    expect(m[4], 0);
    expect(m[6], 1);
    expect(m[12], 1);
  });

  testWidgets('brightness and saturation change the pixels', (tester) async {
    await tester.runAsync(() async {
      final bright = await export(const Adjustments(brightness: 0.5));
      expect(bright.getPixel(20, 20).r, greaterThan(128));
      final dark = await export(const Adjustments(brightness: -0.5));
      expect(dark.getPixel(20, 20).r, lessThan(128));

      final mono = await export(const Adjustments(saturation: -1));
      final p = mono.getPixel(100, 50);
      expect((p.r - p.g).abs(), lessThan(3));
      expect((p.g - p.b).abs(), lessThan(3));

      final warm = await export(const Adjustments(warmth: 1));
      final w = warm.getPixel(20, 20);
      expect(w.r, greaterThan(w.b));
    });
  });

  testWidgets('contrast keeps mid grey and the vignette darkens corners', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final contrast = await export(const Adjustments(contrast: 0.8));
      expect((contrast.getPixel(20, 20).r - 128).abs(), lessThan(4));
      final vignette = await export(const Adjustments(vignette: 1));
      expect(vignette.getPixel(2, 2).r, lessThan(60));
      expect((vignette.getPixel(100, 50).r - 200).abs(), lessThan(12));
    });
  });
}
