import 'package:flutter/foundation.dart';

const _keep = Object();

/// What is done to a video before it is sent: the kept range, whether the
/// sound goes, and the frame shown before it plays.
///
/// Times are positions in the original file, so the edit never depends on
/// an earlier export.
@immutable
final class VideoEdit {
  const VideoEdit({
    this.start = Duration.zero,
    this.end,
    this.muted = false,
    this.cover,
  });

  /// Where the kept part starts.
  final Duration start;

  /// Where the kept part ends; null keeps the video to its end.
  final Duration? end;

  /// Whether the sound is dropped.
  final bool muted;

  /// The frame shown before the video plays; null leaves it to the first
  /// kept frame.
  final Duration? cover;

  bool get isIdentity =>
      start == Duration.zero && end == null && !muted && cover == null;

  /// Whether the kept part is shorter than the video.
  bool get isTrimmed => start > Duration.zero || end != null;

  /// Where the kept part ends in a video [duration] long.
  Duration endIn(Duration duration) {
    final end = this.end;
    return end == null || end > duration ? duration : end;
  }

  /// How long the kept part of a video [duration] long is.
  Duration lengthIn(Duration duration) {
    final length = endIn(duration) - start;
    return length < Duration.zero ? Duration.zero : length;
  }

  /// The cover frame's position in a video [duration] long: [cover] when
  /// it is inside the kept part, the start otherwise.
  Duration coverIn(Duration duration) {
    final cover = this.cover;
    if (cover == null || cover < start || cover > endIn(duration)) {
      return start;
    }
    return cover;
  }

  VideoEdit copyWith({
    Duration? start,
    Object? end = _keep,
    bool? muted,
    Object? cover = _keep,
  }) => VideoEdit(
    start: start ?? this.start,
    end: identical(end, _keep) ? this.end : end as Duration?,
    muted: muted ?? this.muted,
    cover: identical(cover, _keep) ? this.cover : cover as Duration?,
  );

  @override
  bool operator ==(Object other) =>
      other is VideoEdit &&
      other.start == start &&
      other.end == end &&
      other.muted == muted &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(start, end, muted, cover);

  @override
  String toString() =>
      'VideoEdit(start $start, end $end, muted $muted, cover $cover)';
}
