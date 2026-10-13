import 'dart:async';

import 'circle_player.dart';

typedef CirclePlayerFactory = CirclePlayer Function(int outputSide);

/// Keeps video message players alive between circles.
///
/// Creating a player is expensive on every desktop backend: libmpv starts a
/// decoder, the video output creates a GL context and pixel buffers, and
/// the engine registers a new texture. In the prototype that showed up as
/// isolated frames of 25-27 ms right after a player was recreated. A
/// released player is stopped instead of disposed and handed out again for
/// the next circle, so scrolling through a chat never pays that cost twice.
class CirclePlayerPool {
  CirclePlayerPool({required this.create, this.maxIdle = 2})
    : assert(maxIdle >= 0);

  /// Makes a new player when no idle one fits.
  final CirclePlayerFactory create;

  /// How many stopped players to keep per output size. Telegram plays one
  /// circle at a time, so two cover the playing one and the next.
  final int maxIdle;

  final Map<int, List<CirclePlayer>> _idle = {};
  final Set<CirclePlayer> _busy = {};
  int _created = 0;
  bool _disposed = false;

  /// Players created over the pool's lifetime. Stays flat while players are
  /// being reused.
  int get created => _created;

  int get busyCount => _busy.length;

  int idleCount(int outputSide) => _idle[outputSide]?.length ?? 0;

  /// Returns an idle player of [outputSide], or creates one.
  CirclePlayer acquire(int outputSide) {
    if (_disposed) throw StateError('CirclePlayerPool is disposed');
    final idle = _idle[outputSide];
    final player = (idle != null && idle.isNotEmpty)
        ? idle.removeLast()
        : _make(outputSide);
    _busy.add(player);
    return player;
  }

  /// Creates players ahead of time, for example when a chat with circles
  /// opens, so the first tap does not pay for initialization either.
  void warmUp(int outputSide, {int count = 1}) {
    if (_disposed) return;
    final idle = _idle.putIfAbsent(outputSide, () => []);
    while (idle.length < count && idle.length < maxIdle) {
      idle.add(_make(outputSide));
    }
  }

  /// Stops [player] and keeps it for reuse, or disposes it when the pool
  /// already holds [maxIdle] players of its size.
  Future<void> release(CirclePlayer player) async {
    if (!_busy.remove(player)) return;
    // Stop before handing the player out again, so a stop still in flight
    // cannot cancel the next circle's open().
    if (!_disposed) await player.stop();
    final idle = _idle.putIfAbsent(player.outputSide, () => []);
    if (_disposed || idle.length >= maxIdle) {
      await player.dispose();
      return;
    }
    idle.add(player);
  }

  CirclePlayer _make(int outputSide) {
    _created++;
    return create(outputSide);
  }

  /// Disposes idle players. Busy ones are disposed when released.
  Future<void> dispose() async {
    _disposed = true;
    final idle = [for (final l in _idle.values) ...l];
    _idle.clear();
    await Future.wait([for (final p in idle) p.dispose()]);
  }
}
