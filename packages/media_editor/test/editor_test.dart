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
}
