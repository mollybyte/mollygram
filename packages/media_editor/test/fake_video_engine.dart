import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

/// A [VideoEngine] for tests: a 12 s, 640x360 "video" whose frames go
/// from dark to light with time, exported by copying the file.
final class FakeVideoEngine implements VideoEngine {
  FakeVideoEngine({
    this.duration = const Duration(seconds: 12),
    this.hasAudio = true,
  });

  final Duration duration;
  final bool hasAudio;

  /// The edit of the last [export] call.
  VideoEdit? exported;

  /// Times of the frames asked for the stage (large) and the timeline
  /// (small).
  final stageTimes = <Duration>[];
  final thumbTimes = <Duration>[];

  @override
  Future<VideoInfo> probe(String path) async =>
      (duration: duration, width: 640, height: 360, hasAudio: hasAudio);

  @override
  Future<Uint8List> frame(
    String path,
    Duration at, {
    int maxSide = 1280,
  }) async {
    (maxSide >= 640 ? stageTimes : thumbTimes).add(at);
    final f = duration == Duration.zero
        ? 0.0
        : at.inMicroseconds / duration.inMicroseconds;
    final width = maxSide >= 640 ? 640 : maxSide;
    final height = width * 360 ~/ 640;
    final image = img.Image(width: width, height: height)
      ..clear(
        img.ColorRgb8((40 + 180 * f).round(), 90, (200 - 150 * f).round()),
      );
    return img.encodePng(image);
  }

  @override
  Future<ExportedVideo> export(
    String path,
    VideoEdit edit, {
    String? outputDirectory,
  }) async {
    exported = edit;
    final dir = await Directory(outputDirectory ?? Directory.systemTemp.path)
        .createTemp('fake-video-');
    final out = File('${dir.path}/clip.mp4');
    await File(path).copy(out.path);
    final cover = File('${dir.path}/cover.jpg');
    await cover.writeAsBytes(img.encodeJpg(img.Image(width: 64, height: 36)));
    final thumb = File('${dir.path}/thumb.jpg');
    await thumb.writeAsBytes(img.encodeJpg(img.Image(width: 32, height: 18)));
    return (
      path: out.path,
      width: 640,
      height: 360,
      duration: edit.lengthIn(duration),
      coverPath: cover.path,
      thumbnailPath: thumb.path,
    );
  }
}
