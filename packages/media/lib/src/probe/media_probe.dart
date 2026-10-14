import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// The pixel size and length of a video file.
typedef MediaInfo = ({int width, int height, Duration duration});

/// Reads the size and length of the video or audio at [path] with libmpv,
/// without showing or playing it. Completes with null when the file can't
/// be opened in [timeout].
Future<MediaInfo?> probeMedia(
  String path, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final player = Player(
    configuration: const PlayerConfiguration(
      title: 'Mollygram probe',
      vo: 'null',
      muted: true,
    ),
  );
  try {
    await player.open(Media(Uri.file(path).toString()), play: false);
    final duration = player.state.duration > Duration.zero
        ? player.state.duration
        : await player.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(timeout, onTimeout: () => Duration.zero);
    // Audio has no picture: waiting for a size only costs the timeout once
    // the length is known.
    final width =
        player.state.width ??
        await player.stream.width
            .firstWhere((w) => w != null && w > 0)
            .timeout(
              duration > Duration.zero
                  ? const Duration(milliseconds: 300)
                  : timeout,
              onTimeout: () => 0,
            );
    final height = player.state.height ?? 0;
    return (width: width ?? 0, height: height, duration: duration);
  } on Object {
    return null;
  } finally {
    unawaited(player.dispose());
  }
}
