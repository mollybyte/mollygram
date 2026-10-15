import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Plays one voice message or audio file at a time.
///
/// The app keeps a single instance, so starting a track stops the one that
/// was playing, as in Telegram.
///
/// libmpv is started on the first [play], so a chat without audio never
/// pays for it.
class AudioTrackPlayer {
  Player? _instance;
  final _subscriptions = <StreamSubscription<Object?>>[];

  Player get _player => _instance ??= _create();

  Player _create() {
    final player = Player(
      configuration: const PlayerConfiguration(
        title: 'Mollygram audio',
        vo: 'null',
      ),
    );
    _subscriptions.addAll([
      player.stream.position.listen((v) => _position.value = v),
      player.stream.duration.listen((v) => _duration.value = v),
      player.stream.playing.listen((v) => _playing.value = v),
      player.stream.completed.listen((done) {
        if (done) _onCompleted();
      }),
    ]);
    return player;
  }

  final _track = ValueNotifier<Object?>(null);
  final _position = ValueNotifier(Duration.zero);
  final _duration = ValueNotifier(Duration.zero);
  final _playing = ValueNotifier(false);
  final _rate = ValueNotifier(1.0);

  /// The key of the track that is loaded, as given to [play]; null when
  /// nothing is.
  ValueListenable<Object?> get track => _track;
  ValueListenable<Duration> get position => _position;
  ValueListenable<Duration> get duration => _duration;
  ValueListenable<bool> get playing => _playing;

  /// The playback speed; it carries over to the next track, as in
  /// Telegram.
  ValueListenable<double> get rate => _rate;

  /// The speeds a click on the speed button steps through.
  static const rates = [1.0, 1.5, 2.0];

  Future<void> setRate(double rate) async {
    _rate.value = rate;
    await _instance?.setRate(rate);
  }

  /// Plays the file at [path], identified by [key]. Playing the loaded
  /// track again resumes it.
  Future<void> play(Object key, String path) async {
    if (_track.value == key) return _player.play();
    _track.value = key;
    _position.value = Duration.zero;
    _duration.value = Duration.zero;
    await _player.open(Media(Uri.file(path).toString()));
    if (_rate.value != 1) await _player.setRate(_rate.value);
  }

  Future<void> pause() async => _instance?.pause();

  Future<void> seek(Duration position) async => _instance?.seek(position);

  /// Unloads the track.
  Future<void> stop() async {
    _track.value = null;
    _position.value = Duration.zero;
    await _instance?.stop();
  }

  void _onCompleted() {
    _track.value = null;
    _position.value = Duration.zero;
    _playing.value = false;
  }

  Future<void> dispose() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    await _instance?.dispose();
    _track.dispose();
    _position.dispose();
    _duration.dispose();
    _playing.dispose();
    _rate.dispose();
  }
}
