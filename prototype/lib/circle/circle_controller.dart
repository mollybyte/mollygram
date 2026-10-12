import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player/video_player.dart';

const circleAsset = 'assets/circle_640.mp4';

/// Чем декодируется кружок: media_kit (libmpv) или системный AVFoundation
/// через video_player. Сравниваем оба на одном и том же ролике 640x640.
enum CircleBackend {
  mediaKit('media_kit'),
  avFoundation('AVFoundation');

  const CircleBackend(this.label);
  final String label;
}

abstract class _Backend {
  Future<void> init();
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Widget view();
}

class _MediaKitBackend implements _Backend {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);

  @override
  Future<void> init() async {
    await _player.setVolume(0);
    await _player.setPlaylistMode(PlaylistMode.single);
    await _player.open(Media('asset:///$circleAsset'), play: false);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> dispose() => _player.dispose();

  @override
  Widget view() => Video(
    controller: _video,
    controls: NoVideoControls,
    fit: BoxFit.cover,
    fill: Colors.transparent,
    wakelock: false,
    filterQuality: FilterQuality.medium,
  );
}

class _AvFoundationBackend implements _Backend {
  final VideoPlayerController _c = VideoPlayerController.asset(circleAsset);

  @override
  Future<void> init() async {
    await _c.initialize();
    await _c.setLooping(true);
    await _c.setVolume(0);
  }

  @override
  Future<void> play() => _c.play();

  @override
  Future<void> pause() => _c.pause();

  @override
  Future<void> dispose() => _c.dispose();

  @override
  Widget view() => FittedBox(
    fit: BoxFit.cover,
    clipBehavior: Clip.hardEdge,
    child: SizedBox(
      width: _c.value.size.width,
      height: _c.value.size.height,
      child: VideoPlayer(_c),
    ),
  );
}

/// Один плеер на всё окно: кружок в ленте и плавающий кружок показывают
/// одну и ту же текстуру.
class CircleController extends ChangeNotifier {
  CircleController({this.enabled = true});

  /// false в виджет-тестах: нативных плагинов там нет.
  final bool enabled;

  CircleBackend backend = CircleBackend.mediaKit;
  bool playing = false;
  bool ready = false;
  String? error;
  _Backend? _impl;
  int _inList = 0;
  bool _disposed = false;

  /// Кружок из ленты сейчас построен (виден или рядом с экраном).
  bool get inList => _inList > 0;

  Future<void> start() async {
    if (!enabled) return;
    try {
      final impl = backend == CircleBackend.mediaKit
          ? _MediaKitBackend()
          : _AvFoundationBackend();
      _impl = impl;
      await impl.init();
      if (_disposed || _impl != impl) return;
      ready = true;
      error = null;
      if (playing) await impl.play();
    } catch (e) {
      error = '$e';
    }
    _notify();
  }

  Future<void> setBackend(CircleBackend value) async {
    if (value == backend) return;
    final old = _impl;
    _impl = null;
    ready = false;
    backend = value;
    _notify();
    await old?.dispose();
    await start();
  }

  Future<void> setPlaying(bool value) async {
    playing = value;
    _notify();
    final impl = _impl;
    if (impl == null || !ready) return;
    value ? await impl.play() : await impl.pause();
  }

  Widget view() =>
      ready && _impl != null ? _impl!.view() : const SizedBox.expand();

  void attach() {
    _inList++;
    _notifyAfterFrame();
  }

  void detach() {
    _inList--;
    _notifyAfterFrame();
  }

  void _notifyAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _impl?.dispose();
    super.dispose();
  }
}
