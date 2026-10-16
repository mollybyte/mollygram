import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'circle_player.dart';
import 'circle_quality.dart';

/// A [CirclePlayer] on media_kit (libmpv, VideoToolbox on macOS).
///
/// The texture size is fixed at [outputSide]. Without a fixed size the
/// texture follows the video, so every source of a different size would
/// reallocate the pixel buffers behind it.
class MediaKitCirclePlayer implements CirclePlayer {
  MediaKitCirclePlayer({this.outputSide = 640})
    : assert(outputSide > 0 && outputSide <= CircleQuality.p640.side) {
    _subscriptions = [
      _player.stream.position.listen(_onPosition),
      _player.stream.playing.listen((v) => _playing.value = v),
      _player.stream.duration.listen((v) => _duration.value = v),
      _player.stream.rate.listen((v) => _rate.value = v),
      _player.stream.error.listen(_onError),
    ];
    _ready = _init();
  }

  @override
  final int outputSide;

  // Circles are at most 60 s and a few megabytes, so a small demuxer cache
  // is enough.
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Mollygram video message',
      muted: true,
      bufferSize: 8 * 1024 * 1024,
    ),
  );
  late final VideoController _video = VideoController(
    _player,
    configuration: VideoControllerConfiguration(
      width: outputSide,
      height: outputSide,
    ),
  );
  late final List<StreamSubscription<Object?>> _subscriptions;
  late final Future<void> _ready;

  final _status = ValueNotifier(CircleStatus.idle);
  final _playing = ValueNotifier(false);
  final _position = ValueNotifier(Duration.zero);
  final _duration = ValueNotifier(Duration.zero);
  final _rate = ValueNotifier(1.0);
  CircleSource? _source;

  // Position events count only after the current open() returned; until then
  // they may belong to the previous source.
  bool _waitingForFrames = false;
  int _generation = 0;
  bool _disposed = false;

  Future<void> _init() async {
    await _player.setPlaylistMode(PlaylistMode.single);
    await _player.setVolume(0);
  }

  @override
  CircleSource? get source => _source;

  @override
  ValueListenable<CircleStatus> get status => _status;

  @override
  ValueListenable<bool> get playing => _playing;

  @override
  ValueListenable<Duration> get position => _position;

  @override
  ValueListenable<Duration> get duration => _duration;

  @override
  ValueListenable<double> get rate => _rate;

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> open(CircleSource source, {bool play = true}) async {
    final generation = ++_generation;
    _source = source;
    _waitingForFrames = false;
    _status.value = CircleStatus.loading;
    _duration.value = Duration.zero;
    _position.value = Duration.zero;
    await _ready;
    if (_disposed || generation != _generation) return;
    await _player.open(Media(source.uri), play: play);
    if (_disposed || generation != _generation) return;
    _waitingForFrames = true;
  }

  void _onPosition(Duration position) {
    _position.value = position;
    if (!_waitingForFrames || position <= Duration.zero) return;
    _waitingForFrames = false;
    final generation = _generation;
    // The position runs slightly ahead of the texture; give the frame one
    // vsync to reach the screen before the placeholder goes away.
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      if (_disposed || generation != _generation) return;
      _status.value = CircleStatus.showing;
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  void _onError(String error) {
    if (_status.value != CircleStatus.loading) return;
    debugPrint('Circle player: $error');
    _waitingForFrames = false;
    _status.value = CircleStatus.failed;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 100);

  @override
  Future<void> stop() async {
    _generation++;
    _source = null;
    _waitingForFrames = false;
    _status.value = CircleStatus.idle;
    await _player.stop();
    await _player.setVolume(0);
    await _player.setRate(1);
    _position.value = Duration.zero;
    _duration.value = Duration.zero;
  }

  @override
  Widget buildTexture() => Video(
    controller: _video,
    controls: null,
    fit: BoxFit.cover,
    fill: const Color(0x00000000),
    wakelock: false,
    filterQuality: FilterQuality.medium,
  );

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _status.dispose();
    _playing.dispose();
    _position.dispose();
    _duration.dispose();
    _rate.dispose();
    await _player.dispose();
  }
}
