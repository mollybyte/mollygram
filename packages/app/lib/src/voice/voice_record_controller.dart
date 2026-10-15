import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// Where a recording is.
enum RecordPhase {
  idle,

  /// Pressed; waiting for the microphone or camera.
  starting,

  /// Recording while the button is held.
  holding,

  /// Recording hands-free after a drag up to the lock.
  locked,

  /// Finishing the file before it goes out.
  sending,
}

/// What the record button records. A click switches, as in the official
/// apps.
enum RecordMode { voice, video }

/// A note shown next to the record button.
enum RecordHint {
  holdToRecordVoice,
  holdToRecordVideo,
  microphoneDenied,
  cameraDenied,
  failed,
}

/// The press, drag and release of the record button, as in the official
/// apps: hold to record, release to send, drag up to lock, drag away or
/// press Esc to cancel, click to switch between voice and video.
class VoiceRecordController extends ChangeNotifier {
  VoiceRecordController({
    required this.recorder,
    required this.onRecorded,
    this.videoRecorder,
    this.onRecordedVideo,
  });

  final VoiceRecorder recorder;

  /// Gets each finished voice message, to send it.
  final Future<void> Function(RecordedVoice voice) onRecorded;

  /// Null where video messages cannot be recorded; the click then only
  /// explains how to record.
  final VideoNoteRecorder? videoRecorder;
  final Future<void> Function(RecordedVideoNote note)? onRecordedVideo;

  /// How far up the pointer goes to lock, in logical pixels.
  static const lockDistance = 80.0;

  /// How far left or down the pointer goes to arm the cancel.
  static const cancelDistance = 120.0;

  /// Shorter recordings are dropped, as in the official apps: a click is
  /// not a message.
  static const minDuration = Duration(milliseconds: 700);

  RecordPhase _phase = RecordPhase.idle;
  RecordPhase get phase => _phase;

  RecordMode _mode = RecordMode.voice;
  RecordMode get mode => _mode;

  /// The mode of the recording going on, which a click cannot change.
  RecordMode? _recording;

  bool get isRecording =>
      _phase == RecordPhase.holding || _phase == RecordPhase.locked;

  /// Whether anything is going on, so the record button keeps its overlay.
  bool get isActive => _phase != RecordPhase.idle;

  bool get isVideo => (_recording ?? _mode) == RecordMode.video;

  VideoNotePreview? _preview;

  /// The camera while a video message records.
  VideoNotePreview? get preview => _preview;

  /// Whether the camera of the video message going on can be changed.
  bool get canSwitchCamera =>
      isVideo && isRecording && (_preview?.cameras ?? 0) > 1;

  bool _switching = false;

  /// Goes on recording with the next camera.
  Future<void> switchCamera() async {
    final video = videoRecorder;
    if (!canSwitchCamera || _switching || video == null) return;
    _switching = true;
    try {
      final preview = await video.switchCamera();
      if (preview != null && !_disposed && isRecording && isVideo) {
        _preview = preview;
        notifyListeners();
      }
    } finally {
      _switching = false;
    }
  }

  double _lockProgress = 0;

  /// 0 to 1: how far the pointer is toward the lock.
  double get lockProgress => _lockProgress;

  bool _cancelArmed = false;

  /// The pointer is far enough away that a release cancels.
  bool get cancelArmed => _cancelArmed;

  RecordHint? _hint;
  RecordHint? get hint => _hint;
  Timer? _hintTimer;

  /// Ends a video message at Telegram's limit.
  Timer? _limitTimer;

  bool _released = false;
  bool _disposed = false;

  /// The button went down and stayed down: start recording.
  Future<void> press() async {
    if (_phase != RecordPhase.idle) return;
    final mode = _mode;
    final video = mode == RecordMode.video ? videoRecorder : null;
    if (mode == RecordMode.video && video == null) return;
    _released = false;
    _recording = mode;
    _setHint(null);
    _set(RecordPhase.starting);
    final denied = video != null
        ? RecordHint.cameraDenied
        : RecordHint.microphoneDenied;
    try {
      final access = video != null
          ? await video.permission()
          : await recorder.permission();
      switch (access) {
        case MicrophonePermission.undetermined:
          // The system asks now; this press is lost to its dialog.
          await (video?.requestPermission() ?? recorder.requestPermission());
          return _set(RecordPhase.idle);
        case MicrophonePermission.denied:
          _set(RecordPhase.idle);
          return _setHint(denied);
        case MicrophonePermission.granted:
          break;
      }
      if (video != null) {
        final preview = await video.start();
        if (_disposed || _phase != RecordPhase.starting) {
          // Cancelled meanwhile.
          await video.cancel().catchError((Object _) {});
          return;
        }
        _preview = preview;
      } else {
        await recorder.start();
      }
    } on VoiceRecorderException catch (e) {
      if (_phase != RecordPhase.starting) return;
      _set(RecordPhase.idle);
      return _setHint(
        e.error == VoiceRecorderError.permissionDenied
            ? denied
            : RecordHint.failed,
      );
    }
    if (_disposed || _phase != RecordPhase.starting) return;
    if (_released) {
      await _discard();
      _set(RecordPhase.idle);
      return _setHint(_holdHint);
    }
    _lockProgress = 0;
    _cancelArmed = false;
    if (video != null) {
      _limitTimer = Timer(CircleQuality.maxDuration, () => unawaited(send()));
    }
    _set(RecordPhase.holding);
  }

  RecordHint get _holdHint =>
      isVideo ? RecordHint.holdToRecordVideo : RecordHint.holdToRecordVoice;

  /// A click too short to record: switches between voice and video where
  /// both work, and says how to record.
  void tap() {
    if (_phase != RecordPhase.idle) return;
    if (videoRecorder != null && onRecordedVideo != null) {
      _mode = _mode == RecordMode.voice ? RecordMode.video : RecordMode.voice;
    }
    _setHint(_holdHint);
  }

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
    _limitTimer?.cancel();
    if (isVideo) return _sendVideo();
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
      return _setHint(RecordHint.holdToRecordVoice);
    }
    await onRecorded(voice);
  }

  Future<void> _sendVideo() async {
    _set(RecordPhase.sending);
    final RecordedVideoNote note;
    try {
      note = await videoRecorder!.stop();
    } on Object {
      // Most often the camera had not sent a frame yet.
      _set(RecordPhase.idle);
      return _setHint(RecordHint.holdToRecordVideo);
    }
    _set(RecordPhase.idle);
    if (note.duration < minDuration) {
      unawaited(_delete(note.path));
      return _setHint(RecordHint.holdToRecordVideo);
    }
    await onRecordedVideo?.call(note);
  }

  Future<void> cancel() async {
    if (_phase == RecordPhase.idle || _phase == RecordPhase.sending) return;
    final wasStarting = _phase == RecordPhase.starting;
    final video = isVideo;
    _set(RecordPhase.idle);
    // A video start still waiting cleans up after itself in press().
    if (video && wasStarting) return;
    if (video) {
      await videoRecorder!.cancel().catchError((Object _) {});
    } else {
      await recorder.cancel();
    }
  }

  Future<void> _discard() async {
    if (isVideo) {
      await videoRecorder!.cancel().catchError((Object _) {});
    } else {
      await recorder.cancel();
    }
  }

  void dismissHint() => _setHint(null);

  void _set(RecordPhase phase) {
    if (_disposed) return;
    _phase = phase;
    if (phase == RecordPhase.idle) {
      _lockProgress = 0;
      _cancelArmed = false;
      _preview = null;
      _recording = null;
      _limitTimer?.cancel();
    }
    notifyListeners();
  }

  void _setHint(RecordHint? hint) {
    if (_disposed) return;
    _hintTimer?.cancel();
    _hint = hint;
    if (hint != null) {
      _hintTimer = Timer(
        hint == RecordHint.microphoneDenied || hint == RecordHint.cameraDenied
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
    _limitTimer?.cancel();
    if (_phase != RecordPhase.idle) unawaited(_discard());
    super.dispose();
  }
}
