import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/voice/voice_record_composer.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

class FakeCapture implements OpusCapture {
  MicrophonePermission access = MicrophonePermission.granted;
  void Function(OpusBatch batch)? onData;
  bool started = false;
  bool cancelled = false;
  int samples = 0;

  /// Feeds [ms] of audio with a rising and falling voice.
  void speak(int ms) {
    final count = ms ~/ 20;
    final start = samples ~/ 960;
    onData!((
      packets: [for (var i = 0; i < count; i++) Uint8List(40)],
      peaks: [
        for (var i = 0; i < count; i++)
          0.05 + 0.6 * math.sin((start + i) / 7).abs(),
      ],
    ));
    samples += count * 960;
  }

  @override
  Future<MicrophonePermission> permission() async => access;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> start(void Function(OpusBatch batch) onData) async {
    this.onData = onData;
    started = true;
    return 312;
  }

  @override
  Future<int> stop() async => samples;

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  late Directory dir;
  late FakeCapture capture;
  late List<RecordedVoice> sent;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('voice');
    capture = FakeCapture();
    sent = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Widget host({MgColors colors = MgColors.light}) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMgTheme(colors),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: VoiceRecordComposer(
              recorder: VoiceRecorder(
                directory: () async => dir.path,
                capture: capture,
              ),
              onRecorded: (voice) async => sent.add(voice),
              builder: (context, button, bar) => Composer(
                labels: const ComposerLabels(
                  hint: 'Message',
                  attach: 'Attach',
                  emoji: 'Emoji',
                  record: 'Record',
                  send: 'Send',
                ),
                recordButton: button,
                replacement: bar,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Finder mic() =>
      find.byWidgetPredicate((w) => w is MgIcon && w.icon == MgIcons.mic).first;

  /// Lets the real file work of the recorder finish; widget tests run on
  /// a fake clock.
  Future<void> io(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  Future<TestGesture> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(tester.getCenter(mic()));
    await tester.pump(const Duration(milliseconds: 200));
    await io(tester);
    return gesture;
  }

  testWidgets('hold records and release sends', (tester) async {
    await tester.pumpWidget(host());
    final gesture = await hold(tester);
    expect(capture.started, isTrue);
    expect(find.text('0:00,00'), findsOneWidget);

    capture.speak(1500);
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('0:01,'), findsOneWidget);

    await gesture.up();
    await io(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent, hasLength(1));
    expect(sent.single.duration, const Duration(milliseconds: 1500));
    expect(File(sent.single.path).existsSync(), isTrue);
    expect(find.textContaining('0:01,'), findsNothing);
  });

  testWidgets('a click shows how to record instead', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(mic());
    await tester.pump(const Duration(milliseconds: 300));
    expect(capture.started, isFalse);
    expect(find.text('Hold to record a voice message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hold to record a voice message'), findsNothing);
  });

  testWidgets('a very short recording is dropped', (tester) async {
    await tester.pumpWidget(host());
    final gesture = await hold(tester);
    capture.speak(300);
    await gesture.up();
    await io(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent, isEmpty);
    expect(find.text('Hold to record a voice message'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('dragging away cancels on release', (tester) async {
    await tester.pumpWidget(host());
    final gesture = await hold(tester);
    capture.speak(1000);
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Release to cancel'), findsOneWidget);
    await gesture.up();
    await io(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(sent, isEmpty);
    expect(capture.cancelled, isTrue);
    expect(dir.listSync(), isEmpty);
  });

  testWidgets('dragging up locks; the circle sends, Esc cancels', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    var gesture = await hold(tester);
    capture.speak(1000);
    await gesture.moveBy(const Offset(0, -90));
    await gesture.up();
    await io(tester);
    await tester.pump(const Duration(milliseconds: 400));
    // Still recording with the button up.
    expect(find.byTooltip('Delete recording'), findsOneWidget);
    capture.speak(500);
    await tester.tap(
      find.byWidgetPredicate((w) => w is MgIcon && w.icon == MgIcons.send),
    );
    await io(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sent, hasLength(1));

    gesture = await hold(tester);
    capture.speak(1000);
    await gesture.moveBy(const Offset(0, -90));
    await gesture.up();
    await io(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await io(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sent, hasLength(1));
    expect(capture.cancelled, isTrue);
  });

  testWidgets('without microphone access it says where to allow it', (
    tester,
  ) async {
    capture.access = MicrophonePermission.denied;
    await tester.pumpWidget(host());
    final gesture = await hold(tester);
    await gesture.up();
    await io(tester);
    await tester.pump(const Duration(milliseconds: 300));
    expect(capture.started, isFalse);
    expect(find.text('Open System Settings'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
  });

  test('recording time shows hundredths', () {
    expect(
      formatRecordingTime(const Duration(minutes: 1, milliseconds: 7456)),
      '1:07,45',
    );
  });

  for (final (name, colors) in [
    ('light', MgColors.light),
    ('dark', MgColors.dark),
  ]) {
    testWidgets('recording $name', skip: !Platform.isLinux, (tester) async {
      tester.view.physicalSize = const Size(620, 260);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(colors: colors));
      final gesture = await hold(tester);
      for (var i = 0; i < 40; i++) {
        capture.speak(60);
        await tester.pump(const Duration(milliseconds: 60));
      }
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/voice_recording_$name.png'),
      );
      await gesture.up();
      await io(tester);
      await tester.pump(const Duration(milliseconds: 400));
    });
  }
}
