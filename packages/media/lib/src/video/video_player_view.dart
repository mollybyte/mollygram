import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// A video with sound and playback controls, for the media viewer.
///
/// [path] may be a file that is still downloading: TDLib writes it from
/// the start, so playback can begin before the download ends.
class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key, required this.path, this.autoplay = true});

  final String path;
  final bool autoplay;

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(title: 'Mollygram video'),
  );
  late final VideoController _video = VideoController(_player);

  @override
  void initState() {
    super.initState();
    unawaited(
      _player.open(
        Media(Uri.file(widget.path).toString()),
        play: widget.autoplay,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialDesktopVideoControlsTheme(
    normal: const MaterialDesktopVideoControlsThemeData(
      seekBarPositionColor: Color(0xFFFFFFFF),
      seekBarThumbColor: Color(0xFFFFFFFF),
      hideMouseOnControlsRemoval: true,
    ),
    fullscreen: const MaterialDesktopVideoControlsThemeData(),
    child: Video(
      controller: _video,
      controls: MaterialDesktopVideoControls,
      fill: const Color(0x00000000),
    ),
  );
}
