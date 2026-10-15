import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Lets the editor decode its picture, which happens outside fake time.
Future<void> waitForPicture(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final done = find.byType(MgPrimaryButton);
    if (done.evaluate().isNotEmpty &&
        tester.widget<MgPrimaryButton>(done).onPressed != null) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

/// The icon button with [tooltip].
MgIconButton iconButton(WidgetTester tester, String tooltip) =>
    tester.widget<MgIconButton>(
      find.byWidgetPredicate((w) => w is MgIconButton && w.tooltip == tooltip),
    );

void main() {
  late Directory dir;
  late String path;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('media_editor_widget');
    path = '${dir.path}/photo.png';
    File(path).writeAsBytesSync(
      img.encodePng(
        img.Image(width: 64, height: 32)..clear(img.ColorRgb8(200, 30, 30)),
      ),
    );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  Future<MediaEditResult?> open(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    MgColors colors = MgColors.light,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    MediaEditResult? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildMgTheme(colors),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                result = await showMediaEditor(
                  context,
                  path: path,
                  outputDirectory: dir.path,
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    expect(closed, isFalse);
    return result;
  }

  testWidgets('shows the tools and cancels', (tester) async {
    await open(tester);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('Russian strings', (tester) async {
    await open(tester, locale: const Locale('ru'));
    expect(find.text('Готово'), findsOneWidget);
  });

  testWidgets('crop tool shows ratios and undo works', (tester) async {
    await open(tester, colors: MgColors.dark);
    await tester.tap(find.byTooltip('Crop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Square'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rotate'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // Escape leaves the crop tool first.
    expect(
      tester
          .widget<IgnorePointer>(
            find
                .ancestor(
                  of: find.text('Square'),
                  matching: find.byType(IgnorePointer),
                )
                .first,
          )
          .ignoring,
      isTrue,
    );
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('done without changes returns the original', (tester) async {
    MediaEditResult? result;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showMediaEditor(context, path: path),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.isEdited, isFalse);
    expect(result!.path, path);
  });

  testWidgets('dragging a corner and done writes a cropped file', (
    tester,
  ) async {
    MediaEditResult? result;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMediaEditor(
              context,
              path: path,
              outputDirectory: dir.path,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    await tester.tap(find.byTooltip('Crop'));
    await tester.pumpAndSettle();

    // The stage is the window minus 32 px around and 132 px at the bottom,
    // inset by 28 px in crop mode; the 2:1 picture fills its width.
    const stage = Rect.fromLTRB(
      32 + 28,
      32 + 28,
      1200 - 32 - 28,
      800 - 132 - 28,
    );
    final height = stage.width / 2;
    final top = stage.center.dy - height / 2;
    final gesture = await tester.startGesture(
      Offset(stage.right, top + height),
    );
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(Offset(-stage.width / 2 + 20, -height / 2));
    await gesture.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    for (var i = 0; i < 200 && result == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(result, isNotNull);
    expect(result!.isEdited, isTrue);
    expect(result!.originalPath, path);
    expect((result!.width, result!.height), (32, 16));
    expect(File(result!.path).existsSync(), isTrue);
  });

  testWidgets('drawing a line adds a stroke and undo removes it', (
    tester,
  ) async {
    MediaEditResult? result;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMediaEditor(
              context,
              path: path,
              outputDirectory: dir.path,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    await tester.tap(find.byTooltip('Draw'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Marker'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(200, 20));
    await gesture.moveBy(const Offset(200, -20));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    for (var i = 0; i < 200 && result == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(result, isNotNull);
    expect(result!.edit.strokes, hasLength(1));
    expect(result!.edit.strokes.single.tool, BrushTool.marker);
    expect(result!.isEdited, isTrue);
  });

  testWidgets('text, emoji and shapes are placed and transformed', (
    tester,
  ) async {
    MediaEditResult? result;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMediaEditor(
              context,
              path: path,
              outputDirectory: dir.path,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);

    // Text: the tool adds an empty text and focuses the field.
    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Hi');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frame'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsOneWidget);

    // Emoji.
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();

    // Shapes: add an ellipse, then drag it and turn it with the handle.
    await tester.tap(find.byTooltip('Shapes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ellipse'));
    await tester.pumpAndSettle();
    // The stage: the window minus 32 px around and 132 px at the bottom.
    const center = Offset(600, 350);
    final move = await tester.startGesture(center);
    await move.moveBy(const Offset(60, 40));
    await move.up();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    for (var i = 0; i < 200 && result == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(result, isNotNull);
    final overlays = result!.edit.overlays;
    expect(overlays, hasLength(3));
    expect((overlays[0] as TextOverlay).text, 'Hi');
    expect((overlays[0] as TextOverlay).look, TextLook.frame);
    expect((overlays[1] as EmojiOverlay).emoji, '🔥');
    final shape = overlays[2] as ShapeOverlay;
    expect(shape.kind, ShapeKind.ellipse);
    expect(shape.center.dx, greaterThan(0.5));
    expect(shape.center.dy, greaterThan(0.5));
  });

  testWidgets('an empty text goes away and Backspace deletes', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Text'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    // The empty text was dropped, so undo has nothing to do with it.
    expect(iconButton(tester, 'Undo').onPressed, isNull);
    await tester.tap(find.byTooltip('Emoji'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⭐'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(iconButton(tester, 'Redo').onPressed, isNotNull);
  });

  testWidgets('a look and a slider change the adjustments', (tester) async {
    MediaEditResult? result;
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showMediaEditor(
              context,
              path: path,
              outputDirectory: dir.path,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForPicture(tester);
    await tester.tap(find.byTooltip('Adjust'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vivid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vignette'));
    await tester.pumpAndSettle();
    // The adjust panel's slider is the one with change callbacks.
    final slider = find.byWidgetPredicate(
      (w) => w is Slider && w.onChangeEnd != null,
    );
    final drag = await tester.startGesture(tester.getCenter(slider));
    await drag.moveBy(const Offset(40, 0));
    await drag.up();
    await tester.pumpAndSettle();
    // Undo takes the slider move back in one step, redo brings it back.
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    for (var i = 0; i < 200 && result == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(result, isNotNull);
    final a = result!.edit.adjustments;
    expect(a.saturation, FilterPreset.vivid.look.saturation);
    expect(a.vignette, greaterThan(0.5));
    expect(a.preset, isNull);
  });
}
