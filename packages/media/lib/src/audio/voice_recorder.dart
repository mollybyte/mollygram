import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ogg_opus_writer.dart';
import 'voice_waveform.dart';

/// Whether the app may use the microphone.
enum MicrophonePermission { granted, denied, undetermined }

/// Why a recording could not start.
enum VoiceRecorderError { permissionDenied, unavailable }

class VoiceRecorderException implements Exception {
  const VoiceRecorderException(this.error, [this.message]);

  final VoiceRecorderError error;
  final String? message;

  @override
  String toString() => 'VoiceRecorderException($error, $message)';
}

/// A batch of encoded audio from the capture: 20 ms Opus packets, and the
/// peak (0 to 1) of each 20 ms of input.
typedef OpusBatch = ({List<Uint8List> packets, List<double> peaks});

/// The microphone and Opus encoder: native code on each platform.
abstract interface class OpusCapture {
  Future<MicrophonePermission> permission();

  /// Asks the system; completes with whether access was given.
  Future<bool> requestPermission();

  /// Starts capturing and completes with the encoder's pre-skip. Batches
  /// go to [onData] until [stop] or [cancel].
  Future<int> start(void Function(OpusBatch batch) onData);

  /// Stops and delivers the rest of the audio to `onData` before it
  /// completes with the number of 48 kHz samples captured.
  Future<int> stop();

  /// Stops and drops what was not delivered.
  Future<void> cancel();
}

/// [OpusCapture] over the `mollygram/voice_capture` channel
/// (macos/Runner/VoiceCaptureChannel.swift).
class MethodChannelOpusCapture implements OpusCapture {
  MethodChannelOpusCapture([
    this._channel = const MethodChannel('mollygram/voice_capture'),
  ]);

  final MethodChannel _channel;
  void Function(OpusBatch batch)? _onData;

  @override
  Future<MicrophonePermission> permission() async {
    try {
      return switch (await _channel.invokeMethod<String>('permission')) {
        'granted' => MicrophonePermission.granted,
        'undetermined' => MicrophonePermission.undetermined,
        _ => MicrophonePermission.denied,
      };
    } on MissingPluginException {
      throw const VoiceRecorderException(VoiceRecorderError.unavailable);
    }
  }

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<int> start(void Function(OpusBatch batch) onData) async {
    _onData = onData;
    _channel.setMethodCallHandler(_handle);
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('start');
      return (info?['preSkip'] as int?) ?? 312;
    } on PlatformException catch (e) {
      _detach();
      throw VoiceRecorderException(VoiceRecorderError.unavailable, e.message);
    } on MissingPluginException {
      _detach();
      throw const VoiceRecorderException(VoiceRecorderError.unavailable);
    }
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'data') return null;
    final args = call.arguments as Map<Object?, Object?>;
    _onData?.call((
      packets: [
        for (final p in args['packets']! as List<Object?>) p! as Uint8List,
      ],
      peaks: [
        for (final p in args['peaks']! as List<Object?>) (p! as num).toDouble(),
      ],
    ));
    return null;
  }

  @override
  Future<int> stop() async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('stop');
      return (info?['samples'] as int?) ?? 0;
    } finally {
      _detach();
    }
  }

  @override
  Future<void> cancel() async {
    _detach();
    await _channel.invokeMethod<void>('cancel');
  }

  void _detach() {
    _onData = null;
    _channel.setMethodCallHandler(null);
  }
}

/// A finished voice message, ready to send.
@immutable
class RecordedVoice {
  const RecordedVoice({
    required this.path,
    required this.duration,
    required this.waveform,
  });

  /// An Ogg Opus file.
  final String path;
  final Duration duration;

  /// Telegram's packed 5-bit waveform.
  final Uint8List waveform;
}

/// Records one voice message at a time into an Ogg Opus file.
///
/// Listen to it for [peaks] as they arrive, to draw a live meter.
class VoiceRecorder extends ChangeNotifier {
  VoiceRecorder({required this.directory, OpusCapture? capture})
    : _capture = capture ?? MethodChannelOpusCapture();

  /// Where recordings are written.
  final Future<String> Function() directory;
  final OpusCapture _capture;

  OggOpusWriter? _writer;
  String? _path;
  final List<double> _peaks = [];
  bool _active = false;

  /// Bumped by every reset, so a start that was cancelled while it waited
  /// on the system cleans up after itself.
  int _generation = 0;

  /// One peak (0 to 1) per 20 ms of the recording so far.
  List<double> get peaks => _peaks;

  bool get isRecording => _active;

  /// How long the recording is, from the audio captured so far.
  Duration get captured => Duration(milliseconds: _peaks.length * 20);

  Future<MicrophonePermission> permission() => _capture.permission();

  Future<bool> requestPermission() => _capture.requestPermission();

  /// Starts a recording. Throws [VoiceRecorderException] when the
  /// microphone cannot be used.
  Future<void> start() async {
    if (_active) throw StateError('Already recording.');
    _active = true;
    _peaks.clear();
    final generation = ++_generation;
    try {
      final dir = await directory();
      final path =
          '$dir${Platform.pathSeparator}voice_'
          '${DateTime.now().millisecondsSinceEpoch}.ogg';
      final pending = <OpusBatch>[];
      var opened = false;
      void onData(OpusBatch batch) {
        if (!opened) return pending.add(batch);
        _take(batch);
      }

      final preSkip = await _capture.start(onData);
      final writer = await OggOpusWriter.open(path, preSkip: preSkip);
      if (generation != _generation) {
        // Cancelled meanwhile.
        await _capture.cancel().catchError((Object _) {});
        await writer.close();
        await _delete(path);
        return;
      }
      _writer = writer;
      _path = path;
      opened = true;
      pending.forEach(_take);
    } on Object {
      if (generation == _generation) {
        _active = false;
        _writer = null;
        _path = null;
      }
      rethrow;
    }
    notifyListeners();
  }

  void _take(OpusBatch batch) {
    final writer = _writer;
    if (writer == null) return;
    batch.packets.forEach(writer.add);
    _peaks.addAll(batch.peaks);
    notifyListeners();
  }

  /// Finishes the recording and completes with it.
  Future<RecordedVoice> stop() async {
    final writer = _writer;
    final path = _path;
    if (!_active || writer == null || path == null) {
      throw StateError('Not recording.');
    }
    try {
      final samples = await _capture.stop();
      await writer.close(inputSamples: samples);
      final ms = samples > 0
          ? samples * 1000 ~/ 48000
          : writer.packetCount * 20;
      return RecordedVoice(
        path: path,
        duration: Duration(milliseconds: ms),
        waveform: packWaveform(_peaks),
      );
    } finally {
      _reset();
    }
  }

  /// Drops the recording and deletes its file.
  Future<void> cancel() async {
    final writer = _writer;
    final path = _path;
    if (!_active) return;
    _reset();
    try {
      await _capture.cancel();
    } on Object {
      // The capture is gone either way.
    }
    await writer?.close();
    if (path != null) await _delete(path);
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  void _reset() {
    _generation++;
    _active = false;
    _writer = null;
    _path = null;
    notifyListeners();
  }
}
