import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/mollygram_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('mollygram/video_note_capture');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'permission' => 'undetermined',
            'start' => {'textureId': 3, 'width': 1280, 'height': 720},
            'stop' => {'path': '/v/a.mp4', 'durationMs': 61200},
            _ => null,
          };
        });
  });

  test('records a square of the chosen side and caps the length', () async {
    final recorder = VideoNoteRecorder(
      directory: () async => '/v',
      quality: CircleQuality.p512,
    );
    expect(await recorder.permission(), MicrophonePermission.undetermined);
    final preview = await recorder.start();
    expect(preview.textureId, 3);
    expect(calls.last.arguments, containsPair('side', 512));
    expect(
      (calls.last.arguments as Map)['path'],
      matches(RegExp(r'^/v/video_\d+\.mp4$')),
    );
    final note = await recorder.stop();
    expect(note.path, '/v/a.mp4');
    expect(note.side, 512);
    expect(note.duration, const Duration(seconds: 60));
  });

  test('a failed start says the camera is unavailable', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => throw PlatformException(code: 'unavailable'),
        );
    final recorder = VideoNoteRecorder(directory: () async => '/v');
    expect(
      recorder.start(),
      throwsA(
        isA<VoiceRecorderException>().having(
          (e) => e.error,
          'error',
          VoiceRecorderError.unavailable,
        ),
      ),
    );
  });

  test('a switched camera is used for the next recording', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'start' => {'textureId': 3, 'width': 1280, 'height': 720},
            'switchCamera' => {
              'textureId': 3,
              'width': 1920,
              'height': 1080,
              'camera': 'iphone',
              'cameras': 2,
              'mirrored': false,
            },
            _ => null,
          };
        });
    VideoNoteRecorder.debugForgetCamera();
    final recorder = VideoNoteRecorder(directory: () async => '/v');
    final first = await recorder.start();
    expect(first.cameras, 1);
    expect(first.mirrored, isTrue);
    expect(calls.last.arguments, isNot(contains('camera')));
    final switched = await recorder.switchCamera();
    expect(switched!.width, 1920);
    expect(switched.cameras, 2);
    expect(switched.mirrored, isFalse);
    // Remembered by the next recorder too, as a new chat makes one.
    await VideoNoteRecorder(directory: () async => '/v').start();
    expect(calls.last.arguments, containsPair('camera', 'iphone'));
  });
}
