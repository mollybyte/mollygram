import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where a video message comes from.
@immutable
class CircleSource {
  const CircleSource._(this.uri);

  /// A downloaded file on disk, which is what TDLib hands out.
  CircleSource.file(String path) : this._(Uri.file(path).toString());

  /// A Flutter asset (tests, the benchmark, onboarding).
  const CircleSource.asset(String key) : this._('asset:///$key');

  /// Anything libmpv can open directly.
  const CircleSource.uri(this.uri);

  final String uri;

  @override
  bool operator ==(Object other) => other is CircleSource && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() => 'CircleSource($uri)';
}

/// What a [CirclePlayer] is showing right now.
enum CircleStatus {
  /// Nothing is open. The view shows the placeholder.
  idle,

  /// A source is opening. The texture may still hold the previous video's
  /// last frame, so the view keeps showing the placeholder.
  loading,

  /// Frames of the current source are on screen.
  showing,

  /// The source failed to open or decode.
  failed,
}

/// A muted, looping player for one video message at a time.
///
/// The texture behind a player has a fixed [outputSide] and lives as long as
/// the player. Opening another source reuses it, which is much cheaper than
/// creating a player: see [CirclePlayerPool].
abstract class CirclePlayer {
  /// The side of the square texture the video is scaled into, in physical
  /// pixels.
  int get outputSide;

  /// The source opened last, or null when idle.
  CircleSource? get source;

  ValueListenable<CircleStatus> get status;

  /// Whether playback is running (also true while loading with autoplay).
  ValueListenable<bool> get playing;

  /// How far playback is, wrapping to zero when the loop restarts.
  ValueListenable<Duration> get position;

  /// The length of the open source; zero until it is known.
  ValueListenable<Duration> get duration;

  /// The playback speed, 1 by default.
  ValueListenable<double> get rate;

  Future<void> setRate(double rate);

  /// Opens [source] and, if [play] is true, starts it muted and looping.
  Future<void> open(CircleSource source, {bool play = true});

  Future<void> play();

  Future<void> pause();

  /// Sound is off in the list and turns on when the circle is expanded.
  Future<void> setMuted(bool muted);

  /// Unloads the source but keeps the texture, so the player can be reused.
  Future<void> stop();

  /// The video texture. It fills its parent; clipping is up to the caller.
  Widget buildTexture();

  /// Frees the decoder and the texture. The player cannot be used after.
  Future<void> dispose();
}
