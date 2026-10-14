import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A muted video that starts on its own and loops: GIFs (which Telegram
/// sends as MP4) and video stickers.
///
/// [placeholder] (usually the thumbnail) stays on top until the first
/// frame is drawn, so the bubble never flashes black.
class LoopingVideo extends StatefulWidget {
  const LoopingVideo({
    super.key,
    required this.path,
    this.placeholder,
    this.fit = BoxFit.cover,
  });

  /// A downloaded file.
  final String path;
  final Widget? placeholder;
  final BoxFit fit;

  @override
  State<LoopingVideo> createState() => _LoopingVideoState();
}

class _LoopingVideoState extends State<LoopingVideo> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Mollygram animation',
      muted: true,
      bufferSize: 4 * 1024 * 1024,
    ),
  );
  late final VideoController _video = VideoController(_player);
  StreamSubscription<Duration>? _position;
  var _showing = false;
  var _disposed = false;

  @override
  void initState() {
    super.initState();
    _position = _player.stream.position.listen((position) {
      if (_showing || position <= Duration.zero || !mounted) return;
      setState(() => _showing = true);
    });
    unawaited(_open());
  }

  /// Fast scrolling can dispose the widget between these steps; the rest
  /// is skipped then, and a call already racing the dispose is ignored.
  Future<void> _open() async {
    try {
      await _player.setPlaylistMode(PlaylistMode.single);
      if (_disposed) return;
      await _player.setVolume(0);
      if (_disposed) return;
      await _player.open(Media(Uri.file(widget.path).toString()));
    } on Object {
      if (!_disposed) rethrow;
    }
  }

  @override
  void didUpdateWidget(LoopingVideo old) {
    super.didUpdateWidget(old);
    if (old.path == widget.path) return;
    _showing = false;
    unawaited(_open());
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_position?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Video(
        controller: _video,
        controls: null,
        fit: widget.fit,
        fill: const Color(0x00000000),
        wakelock: false,
      ),
      if (!_showing && widget.placeholder != null) widget.placeholder!,
    ],
  );
}
