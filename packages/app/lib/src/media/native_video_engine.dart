import 'package:flutter/services.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

/// The video editor's engine on macOS: AVFoundation behind the
/// `mollygram/video_edit` channel (VideoEditChannel.swift in the Runner).
///
/// Trimming and muting rewrite the container without re-encoding when the
/// source is already MPEG-4 friendly, so an export takes about as long as
/// copying the file; other sources are re-encoded to H.264.
final class NativeVideoEngine implements VideoEngine {
  const NativeVideoEngine([this._channel = const MethodChannel(_name)]);

  static const _name = 'mollygram/video_edit';

  final MethodChannel _channel;

  @override
  Future<VideoInfo> probe(String path) async {
    final map = await _call('probe', {'path': path});
    return (
      duration: Duration(milliseconds: map['durationMs'] as int),
      width: map['width'] as int,
      height: map['height'] as int,
      hasAudio: map['hasAudio'] as bool,
    );
  }

  @override
  Future<Uint8List> frame(
    String path,
    Duration at, {
    int maxSide = 1280,
  }) async {
    final bytes = await _channel.invokeMethod<Uint8List>('frame', {
      'path': path,
      'ms': at.inMilliseconds,
      'maxSide': maxSide,
    });
    if (bytes == null) throw const VideoEngineException('No frame.');
    return bytes;
  }

  @override
  Future<ExportedVideo> export(
    String path,
    VideoEdit edit, {
    String? outputDirectory,
  }) async {
    final map = await _call('export', {
      'path': path,
      'startMs': edit.start.inMilliseconds,
      'endMs': edit.end?.inMilliseconds,
      'muted': edit.muted,
      'coverMs': edit.cover?.inMilliseconds,
      'outputDirectory': outputDirectory,
    });
    return (
      path: map['path'] as String,
      width: map['width'] as int,
      height: map['height'] as int,
      duration: Duration(milliseconds: map['durationMs'] as int),
      coverPath: map['cover'] as String,
      thumbnailPath: map['thumbnail'] as String,
    );
  }

  Future<Map<Object?, Object?>> _call(
    String method,
    Map<String, Object?> arguments,
  ) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      method,
      arguments,
    );
    if (result == null) throw VideoEngineException('No result from $method.');
    return result;
  }
}

/// The native side could not read or write the video.
final class VideoEngineException implements Exception {
  const VideoEngineException(this.message);

  final String message;

  @override
  String toString() => 'VideoEngineException: $message';
}
