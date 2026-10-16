import 'package:flutter/widgets.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// A [CirclePlayer] without native code, recording what was asked of it.
class FakeCirclePlayer implements CirclePlayer {
  FakeCirclePlayer(this.outputSide);

  @override
  final int outputSide;

  final List<String> calls = [];
  bool disposed = false;

  @override
  CircleSource? source;

  @override
  final ValueNotifier<CircleStatus> status = ValueNotifier(CircleStatus.idle);

  @override
  final ValueNotifier<bool> playing = ValueNotifier(false);

  @override
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);

  @override
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);

  @override
  final ValueNotifier<double> rate = ValueNotifier(1);

  @override
  Future<void> setRate(double value) async => rate.value = value;

  @override
  Future<void> open(CircleSource source, {bool play = true}) async {
    calls.add('open ${source.uri}');
    this.source = source;
    status.value = CircleStatus.loading;
    playing.value = play;
  }

  /// What the real player does once frames of the source reach the screen.
  void showFrames() => status.value = CircleStatus.showing;

  @override
  Future<void> play() async => playing.value = true;

  @override
  Future<void> pause() async => playing.value = false;

  @override
  Future<void> setMuted(bool muted) async => calls.add('muted $muted');

  @override
  Future<void> stop() async {
    calls.add('stop');
    source = null;
    status.value = CircleStatus.idle;
    playing.value = false;
  }

  @override
  Widget buildTexture() =>
      const ColoredBox(key: ValueKey('texture'), color: Color(0xFF000000));

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    disposed = true;
  }
}
