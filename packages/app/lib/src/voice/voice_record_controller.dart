import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// Where a voice recording is.
enum RecordPhase {
  idle,

  /// Pressed; waiting for the microphone.
  starting,

  /// Recording while the button is held.
  holding,

  /// Recording hands-free after a drag up to the lock.
  locked,

  /// Finishing the file before it goes out.
  sending,
}

/// A note shown next to the record button.
enum RecordHint { holdToRecord, microphoneDenied, failed }

/// The press, drag and release of the record button, as in the official
/// apps: hold to record, release to send, drag up to lock, drag away or
/// press Esc to cancel.
class VoiceRecordController extends ChangeNotifier {
  VoiceRecordController({required this.recorder, required this.onRecorded});

  final VoiceRecorder recorder;

  /// Gets each finished recording, to send it.
  final Future<void> Function(RecordedVoice voice) onRecorded;

  /// How far up the pointer goes to lock, in logical pixels.
  static const lockDistance = 80.0;

  /// How far left or down the pointer goes to arm the cancel.
  static const cancelDistance = 120.0;

  /// Shorter recordings are dropped, as in the official apps: a click is
  /// not a message.
  static const minDuration = Duration(milliseconds: 700);

  RecordPhase _phase = RecordPhase.idle;
  RecordPhase get phase => _phase;

  bool get isRecording =>
      _phase == RecordPhase.holding || _phase == RecordPhase.locked;

  /// Whether anything is going on, so the record button keeps its overlay.
  bool get isActive => _phase != RecordPhase.idle;

  double _lockProgress = 0;

  /// 0 to 1: how far the pointer is toward the lock.
  double get lockProgress => _lockProgress;

  bool _cancelArmed = false;

  /// The pointer is far enough away that a release cancels.
  bool get cancelArmed => _cancelArmed;

  RecordHint? _hint;
  RecordHint? get hint => _hint;
  Timer? _hintTimer;

  bool _released = false;
  bool _disposed = false;

  /// The button went down and stayed down: start recording.
  Future<void> press() async {
    if (_phase != RecordPhase.idle) return;
    _released = false;
    _setHint(null);
    _set(RecordPhase.starting);
    try {
      switch (await recorder.permission()) {
        case MicrophonePermission.undetermined:
          // The system asks now; this press is lost to its dialog.
          await recorder.requestPermission();
          return _set(RecordPhase.idle);
        case MicrophonePermission.denied:
          _set(RecordPhase.idle);
          return _setHint(RecordHint.microphoneDenied);
        case MicrophonePermission.granted:
          break;
      }
      await recorder.start();
    } on VoiceRecorderException catch (e) {
      if (_phase != RecordPhase.starting) return;
      _set(RecordPhase.idle);
      return _setHint(
        e.error == VoiceRecorderError.permissionDenied
            ? RecordHint.microphoneDenied
            : RecordHint.failed,
      );
    }
    if (_disposed || _phase != RecordPhase.starting) return;
    if (_released) {
      await recorder.cancel();
      _set(RecordPhase.idle);
      return _setHint(RecordHint.holdToRecord);
    }
    _lockProgress = 0;
    _cancelArmed = false;
    _set(RecordPhase.holding);
  }

  /// A click too short to record.
  void tap() => _setHint(RecordHint.holdToRecord);

  /// The pointer moved by [offset] from where it went down.
  void drag(Offset offset) {
    if (_phase != RecordPhase.holding) return;
    _lockProgress = (-offset.dy / lockDistance).clamp(0.0, 1.0);
    _cancelArmed =
        offset.dx < -cancelDistance || offset.dy > cancelDistance / 2;
    if (_lockProgress >= 1) return lock();
    notifyListeners();
  }

  /// Keeps recording without the button held.
  void lock() {
    if (_phase != RecordPhase.holding) return;
    _lockProgress = 1;
    _cancelArmed = false;
    _set(RecordPhase.locked);
  }

  /// The button came up.
  Future<void> release() async {
    switch (_phase) {
      case RecordPhase.starting:
        _released = true;
      case RecordPhase.holding:
        await (_cancelArmed ? cancel() : send());
      default:
        break;
    }
  }

  Future<void> send() async {
    if (!isRecording) return;
    _set(RecordPhase.sending);
    final RecordedVoice voice;
    try {
      voice = await recorder.stop();
    } on Object {
      _set(RecordPhase.idle);
      return _setHint(RecordHint.failed);
    }
    _set(RecordPhase.idle);
    if (voice.duration < minDuration) {
      unawaited(_delete(voice.path));
      return _setHint(RecordHint.holdToRecord);
    }
    await onRecorded(voice);
  }

  Future<void> cancel() async {
    if (_phase == RecordPhase.idle || _phase == RecordPhase.sending) return;
    _set(RecordPhase.idle);
    await recorder.cancel();
  }

  void dismissHint() => _setHint(null);

  void _set(RecordPhase phase) {
    if (_disposed) return;
    _phase = phase;
    if (phase == RecordPhase.idle) {
      _lockProgress = 0;
      _cancelArmed = false;
    }
    notifyListeners();
  }

  void _setHint(RecordHint? hint) {
    if (_disposed) return;
    _hintTimer?.cancel();
    _hint = hint;
    if (hint != null) {
      _hintTimer = Timer(
        hint == RecordHint.microphoneDenied
            ? const Duration(seconds: 6)
            : const Duration(milliseconds: 2500),
        () => _setHint(null),
      );
    }
    notifyListeners();
  }

  static Future<void> _delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _hintTimer?.cancel();
    if (_phase != RecordPhase.idle) unawaited(recorder.cancel());
    super.dispose();
  }
}
