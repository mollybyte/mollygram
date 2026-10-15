import 'dart:typed_data';

import '../model/video_edit.dart';

/// What a video file holds.
typedef VideoInfo = ({Duration duration, int width, int height, bool hasAudio});

/// A video written by [VideoEngine.export].
typedef ExportedVideo = ({
  String path,
  int width,
  int height,
  Duration duration,

  /// A JPEG of the cover frame, large enough to show in a chat.
  String coverPath,

  /// A small JPEG of the cover frame, at most 320 px a side, for the
  /// message thumbnail.
  String thumbnailPath,
});

/// Reads and writes video files for [showVideoEditor].
///
/// The editor itself only draws frames, so the platform-specific work
/// (decoding, trimming, muting) lives behind this interface. The app
/// provides one; tests use a fake.
abstract interface class VideoEngine {
  /// The size, length and sound of the video at [path].
  Future<VideoInfo> probe(String path);

  /// The frame at [at], encoded as JPEG or PNG, no larger than [maxSide]
  /// on its long side and oriented the way it plays.
  Future<Uint8List> frame(String path, Duration at, {int maxSide = 1280});

  /// Applies [edit] to the video at [path] and writes the result, with its
  /// cover frame, into a new folder under [outputDirectory] (the system
  /// temp folder by default).
  Future<ExportedVideo> export(
    String path,
    VideoEdit edit, {
    String? outputDirectory,
  });
}
