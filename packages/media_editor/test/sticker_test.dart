import 'dart:io';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_media_editor/src/ui/overlay_panels.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'editor_test.dart' show waitForPicture;

/// Lets a sticker file be read and decoded, which happens outside fake
/// time.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  late Directory dir;
  late String path;
  late String sticker;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_sticker');
    path = '${dir.path}/p.png';
    File(path).writeAsBytesSync(
      img.encodePng(
        img.Image(width: 200, height: 100)..clear(img.ColorRgb8(0, 0, 0)),
      ),
    );
    // A 2:1 green sticker.
    sticker = '${dir.path}/s.png';
    File(sticker).writeAsBytesSync(
      img.encodePng(
        img.Image(width: 40, height: 20)..clear(img.ColorRgb8(0, 255, 0)),
      ),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'an image overlay is sized by its aspect and turns with the picture',
    () {
      const overlay = ImageOverlay(
        id: 1,
        center: Offset(0.5, 0.5),
        path: '/s.png',
        aspect: 2,
        scale: 0.4,
      );
      expect(overlaySize(overlay, const Size(200, 100)), const Size(40, 20));
      final turned = const MediaEdit().withOverlay(overlay).rotatedLeft();
      expect(turned.overlays.single, isA<ImageOverlay>());
      expect((turned.overlays.single as ImageOverlay).path, '/s.png');
      expect(
        hitOverlay(const Offset(100, 50), [overlay], const Size(200, 100)),
        overlay,
      );
      expect(
        hitOverlay(const Offset(10, 10), [overlay], const Size(200, 100)),
        isNull,
      );
    },
  );

  testWidgets('a sticker is in the export, a missing file is skipped', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final edit = const MediaEdit()
          .withOverlay(
            ImageOverlay(
              id: 1,
              center: const Offset(0.25, 0.5),
              path: sticker,
              aspect: 2,
              scale: 0.4,
            ),
          )
          .withOverlay(
            const ImageOverlay(
              id: 2,
              center: Offset(0.75, 0.5),
              path: '/nowhere/missing.png',
              aspect: 2,
              scale: 0.4,
            ),
          );
      final out = await exportEdit(path, edit, outputDirectory: dir.path);
      final image = img.decodePng(await File(out.path).readAsBytes())!;
      // The sticker is 40x20 at (50, 50): green inside, black outside.
      expect(image.getPixel(50, 50).g, greaterThan(200));
      expect(image.getPixel(50, 50).r, lessThan(50));
      expect(image.getPixel(150, 50).g, lessThan(50));
      expect(image.getPixel(10, 10).g, lessThan(50));
    });
  });

  testWidgets('the sticker tool opens the picker and places the pick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MediaEditResult? result;
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMediaEditor(
              context,
              path: path,
              outputDirectory: dir.path,
              stickerPicker: (context) async {
                opened++;
                return opened == 1
                    ? StickerFilePick(sticker)
                    : const EmojiPick('🙂');
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    expect(find.byTooltip('Stickers'), findsOneWidget);

    // Picking the tool opens the picker at once.
    await tester.tap(find.byTooltip('Stickers'));
    await tester.pump();
    await settle(tester);
    expect(opened, 1);
    expect(find.text('Add sticker'), findsOneWidget);
    // The panel shows the selected sticker's size.
    expect(
      tester.widget<StickerPanel>(find.byType(StickerPanel)).overlay,
      isNotNull,
    );

    await tester.tap(find.text('Add sticker'));
    await settle(tester);
    expect(opened, 2);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(result, isNotNull);
    expect(result!.edit.overlays, hasLength(2));
    final placed = result!.edit.overlays.first as ImageOverlay;
    expect(placed.path, sticker);
    expect(placed.aspect, 2);
    expect(result!.edit.overlays.last, isA<EmojiOverlay>());
    expect(result!.isEdited, isTrue);
    // File reads need real time.
    await tester.runAsync(() async {
      final image = img.decodePng(await File(result!.path).readAsBytes())!;
      expect(image.getPixel(100, 50).g, greaterThan(200));
    });
  });

  testWidgets('without a picker there is no sticker tool', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMediaEditor(context, path: path),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    expect(find.byTooltip('Stickers'), findsNothing);
  });
}
