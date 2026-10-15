import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// What a [VideoPlayback] is doing, for the viewer's own controls.
@immutable
final class VideoPlaybackState {
  const VideoPlaybackState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
    this.playing = false,
    this.completed = false,
    this.volume = 1,
    this.rate = 1,
    this.loop = false,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final bool playing;
  final bool completed;

  /// 0 to 1.
  final double volume;
  final double rate;
  final bool loop;

  VideoPlaybackState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
    bool? playing,
    bool? completed,
    double? volume,
    double? rate,
    bool? loop,
  }) => VideoPlaybackState(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
    playing: playing ?? this.playing,
    completed: completed ?? this.completed,
    volume: volume ?? this.volume,
    rate: rate ?? this.rate,
    loop: loop ?? this.loop,
  );
}

/// One video in the media viewer: libmpv without its own controls, so the
/// app draws controls that match the rest of it. [state] follows the
/// player; the setters change it.
///
/// The file may still be downloading: TDLib writes it from the start, so
/// playback can begin before the download ends.
final class VideoPlayback {
  VideoPlayback({bool loop = false, bool muted = false}) {
    _state.value = VideoPlaybackState(loop: loop, volume: muted ? 0 : 1);
    final stream = _player.stream;
    _subscriptions.addAll([
      stream.position.listen(
        (v) => _update(_state.value.copyWith(position: v)),
      ),
      stream.duration.listen(
        (v) => _update(_state.value.copyWith(duration: v)),
      ),
      stream.buffer.listen((v) => _update(_state.value.copyWith(buffered: v))),
      stream.playing.listen((v) => _update(_state.value.copyWith(playing: v))),
      stream.completed.listen(
        (v) => _update(_state.value.copyWith(completed: v)),
      ),
    ]);
  }

  final _player = Player(
    configuration: const PlayerConfiguration(title: 'Mollygram video'),
  );
  late final VideoController controller = VideoController(_player);
  final _state = ValueNotifier(const VideoPlaybackState());
  final _subscriptions = <StreamSubscription<Object?>>[];
  var _disposed = false;

  /// The command in flight, so that [dispose] waits for it: libmpv crashes
  /// in its core thread when the player is destroyed while `open` is still
  /// setting up the file and its property observers.
  Future<void> _busy = Future<void>.value();

  ValueListenable<VideoPlaybackState> get state => _state;

  void _update(VideoPlaybackState value) {
    if (!_disposed) _state.value = value;
  }

  /// Runs [command] after the previous one; errors stay with the caller.
  Future<void> _run(Future<void> Function() command) {
    if (_disposed) return Future<void>.value();
    final next = _busy.catchError((Object _) {}).then((_) => command());
    _busy = next.catchError((Object _) {});
    return next;
  }

  Future<void> open(String path, {bool autoplay = true}) => _run(() async {
    final current = _state.value;
    await _player.setPlaylistMode(
      current.loop ? PlaylistMode.single : PlaylistMode.none,
    );
    await _player.setVolume(current.volume * 100);
    if (_disposed) return;
    await _player.open(Media(Uri.file(path).toString()), play: autoplay);
  });

  Future<void> playOrPause() async {
    final current = _state.value;
    // At the end, play starts over, as in QuickTime.
    if (!current.playing && current.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.playOrPause();
  }

  Future<void> seek(Duration position) => _player.seek(position);

  /// Moves by [delta], within the video.
  Future<void> skip(Duration delta) {
    final current = _state.value;
    var target = current.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (current.duration > Duration.zero && target > current.duration) {
      target = current.duration;
    }
    return _player.seek(target);
  }

  Future<void> setRate(double rate) async {
    _update(_state.value.copyWith(rate: rate));
    await _player.setRate(rate);
  }

  Future<void> setVolume(double volume) async {
    final value = volume.clamp(0.0, 1.0);
    _update(_state.value.copyWith(volume: value));
    await _player.setVolume(value * 100);
  }

  Future<void> setLoop(bool loop) async {
    _update(_state.value.copyWith(loop: loop));
    await _player.setPlaylistMode(
      loop ? PlaylistMode.single : PlaylistMode.none,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _state.dispose();
    // An `open` still running must finish before the player goes away; a
    // timeout would not cancel it, only bring the crash back.
    await _busy;
    await _player.dispose();
  }
}

/// The picture of a [VideoPlayback], with no controls of its own.
class VideoSurface extends StatelessWidget {
  const VideoSurface({
    super.key,
    required this.playback,
    this.fit = BoxFit.contain,
  });

  final VideoPlayback playback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => Video(
    controller: playback.controller,
    controls: null,
    fit: fit,
    fill: const Color(0x00000000),
  );
}
