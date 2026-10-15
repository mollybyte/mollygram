import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_media_editor/src/ui/filmstrip.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'fake_video_engine.dart';

/// Lets the editor probe the video and decode its frames, which happens
/// outside fake time.
Future<void> waitForFrames(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
    final done = find.byType(MgPrimaryButton);
    final strip = find.byType(Filmstrip);
    if (done.evaluate().isNotEmpty &&
        tester.widget<MgPrimaryButton>(done).onPressed != null &&
        strip.evaluate().isNotEmpty &&
        tester.widget<Filmstrip>(strip).frames.every((f) => f != null)) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;
  late String path;
  late FakeVideoEngine engine;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('video_editor_widget');
    path = '${dir.path}/clip.mp4';
    File(path).writeAsBytesSync(List.filled(64, 7));
    engine = FakeVideoEngine();
  });

  tearDown(() => dir.deleteSync(recursive: true));

  /// Opens the editor and returns a getter for the result.
  Future<VideoEditResult? Function()> show(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    VideoEdit initial = const VideoEdit(),
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    VideoEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ru')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildMgTheme(MgColors.light),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => result = await showVideoEditor(
                context,
                path: path,
                engine: engine,
                initial: initial,
                outputDirectory: dir.path,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await waitForFrames(tester);
    return () => result;
  }

  testWidgets('shows the timeline, cancels', (tester) async {
    final result = await show(tester);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('0:00.0 – 0:12.0'), findsOneWidget);
    expect(find.text('12.0 s'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('Russian strings', (tester) async {
    await show(tester, locale: const Locale('ru'));
    expect(find.text('Готово'), findsOneWidget);
    expect(find.text('12.0 с'), findsOneWidget);
    expect(find.byTooltip('Без звука'), findsOneWidget);
  });

  testWidgets('done without changes returns the original', (tester) async {
    final result = await show(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result(), isNotNull);
    expect(result()!.isEdited, isFalse);
    expect(result()!.path, path);
    expect(result()!.duration, const Duration(seconds: 12));
    expect(engine.exported, isNull);
  });

  testWidgets('trimming the end exports the kept part', (tester) async {
    final result = await show(tester);
    final strip = tester.getRect(find.byType(Filmstrip));
    final y = strip.center.dy;
    // The end handle sits just right of the track.
    final gesture = await tester.startGesture(Offset(strip.right - 7, y));
    await tester.pump();
    await gesture.moveBy(const Offset(-93, 0));
    await tester.pump();
    await gesture.up();
    await waitForFrames(tester);
    // 93 px of a 372 px track is a quarter: 3 s off a 12 s video.
    final end = tester.widget<Filmstrip>(find.byType(Filmstrip)).end;
    expect(end.inMilliseconds, closeTo(9000, 150));
    expect(find.textContaining('0:00.0 – 0:09'), findsOneWidget);
    // The frame on the stage followed the handle.
    expect(engine.stageTimes.last, end);

    await tester.tap(find.text('Done'));
    await waitForFrames(tester);
    expect(engine.exported, isNotNull);
    expect(engine.exported!.end, end);
    expect(engine.exported!.start, Duration.zero);
    expect(result()!.isEdited, isTrue);
    expect(result()!.coverPath, isNull);
    expect(result()!.thumbnailPath, isNotNull);
    expect(File(result()!.path).existsSync(), isTrue);
  });

  testWidgets('scrubbing, mute and cover', (tester) async {
    final result = await show(tester);
    final strip = tester.getRect(find.byType(Filmstrip));
    // Click in the middle of the track: the playhead goes to 6 s.
    await tester.tapAt(Offset(strip.center.dx, strip.center.dy));
    await waitForFrames(tester);
    expect(engine.stageTimes.last.inMilliseconds, closeTo(6000, 100));

    await tester.tap(find.byTooltip('Use as cover'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cover frame'), findsOneWidget);

    await tester.tap(find.byTooltip('Mute'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unmute'), findsOneWidget);
    // M toggles it back and forth.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mute'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await waitForFrames(tester);
    final edit = engine.exported!;
    expect(edit.muted, isTrue);
    expect(edit.cover!.inMilliseconds, closeTo(6000, 100));
    expect(edit.isTrimmed, isFalse);
    expect(result()!.coverPath, isNotNull);
    expect(result()!.edit, edit);
  });

  testWidgets('an earlier edit is restored', (tester) async {
    await show(
      tester,
      initial: const VideoEdit(
        start: Duration(seconds: 2),
        end: Duration(seconds: 5),
        muted: true,
      ),
    );
    expect(find.text('0:02.0 – 0:05.0'), findsOneWidget);
    expect(find.text('3.0 s'), findsOneWidget);
    expect(find.byTooltip('Unmute'), findsOneWidget);
    // The stage opens on the first kept frame.
    expect(engine.stageTimes.first, const Duration(seconds: 2));
  });

  testWidgets('no mute without sound', (tester) async {
    engine = FakeVideoEngine(hasAudio: false);
    await show(tester);
    expect(
      tester
          .widget<MgIconButton>(
            find.byWidgetPredicate(
              (w) => w is MgIconButton && w.tooltip == 'Mute',
            ),
          )
          .onPressed,
      isNull,
    );
  });
}
