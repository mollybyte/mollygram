import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../session/providers.dart';
import '../settings/stickers/sticker_options.dart';
import 'describe.dart';
import 'media_providers.dart';
import 'media_viewer.dart';
import 'td_file.dart';

/// The largest box media takes in a bubble.
const double kMaxMediaWidth = 360;
const double kMaxMediaHeight = 420;

/// Scales [width] x [height] to fit the media box, keeping it from getting
/// too thin to tap.
Size fitMedia(
  int width,
  int height, {
  double maxWidth = kMaxMediaWidth,
  double maxHeight = kMaxMediaHeight,
  double minSide = 120,
}) {
  if (width <= 0 || height <= 0) return Size(maxWidth, maxWidth * 0.75);
  final scale = math.min(maxWidth / width, maxHeight / height);
  final w = (width * scale).clamp(minSide, maxWidth);
  final h = (height * scale).clamp(minSide * 0.6, maxHeight);
  return Size(w.toDouble(), h.toDouble());
}

/// The size of [photo] that fits a [side] px box best, or the largest one.
td.PhotoSize? photoSizeFor(td.Photo photo, double side) {
  final sizes = [...photo.sizes]..sort((a, b) => a.width.compareTo(b.width));
  if (sizes.isEmpty) return null;
  for (final size in sizes) {
    if (size.width >= side) return size;
  }
  return sizes.last;
}

/// A photo in a bubble or an album cell. Tapping it calls [onTap], which
/// opens the viewer; without it the photo opens on its own.
class PhotoContent extends StatelessWidget {
  const PhotoContent({
    super.key,
    required this.photo,
    required this.size,
    this.onTap,
  });

  final td.Photo photo;
  final Size size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final full = photoSizeFor(photo, size.width * dpr);
    final small = photo.sizes.isEmpty ? null : photo.sizes.first;
    return _Tappable(
      onTap:
          onTap ?? () => showMediaViewer(context, MediaViewerItem.photo(photo)),
      child: SizedBox.fromSize(
        size: size,
        child: TdImage(
          file: full?.photo,
          thumbnail: small != null && small != full ? small.photo : null,
          minithumbnail: photo.minithumbnail,
          cacheWidth: (size.width * dpr).round(),
          kind: MediaDownloadKind.photos,
        ),
      ),
    );
  }
}

/// A video: its cover, the length, and a play button; it plays in the
/// viewer.
class VideoContent extends StatelessWidget {
  const VideoContent({
    super.key,
    required this.video,
    required this.size,
    this.onTap,
  });

  final td.Video video;
  final Size size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return _Tappable(
      onTap:
          onTap ?? () => showMediaViewer(context, MediaViewerItem.video(video)),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TdImage(
              thumbnail: video.thumbnail?.file,
              minithumbnail: video.minithumbnail,
            ),
            Positioned(
              left: 8,
              top: 8,
              child: MediaPill(formatDuration(video.duration)),
            ),
            Center(
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.mediaPill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const MgIcon(
                  MgIcons.play,
                  size: 20,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A GIF: downloads on sight and loops without sound. Tapping it calls
/// [onTap], which opens it in the viewer.
class AnimationContent extends StatelessWidget {
  const AnimationContent({
    super.key,
    required this.animation,
    required this.size,
    this.onTap,
  });

  final td.Animation animation;
  final Size size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cover = TdImage(
      thumbnail: animation.thumbnail?.file,
      minithumbnail: animation.minithumbnail,
    );
    final body = SizedBox.fromSize(
      size: size,
      child: TdFileBuilder(
        file: animation.animation,
        download: true,
        kind: MediaDownloadKind.videos,
        builder: (context, file) {
          final path = downloadedPath(file);
          if (path == null) {
            return TapToDownload(
              file: file,
              kind: MediaDownloadKind.videos,
              child: cover,
            );
          }
          return LoopingVideo(path: path, placeholder: cover);
        },
      ),
    );
    final onTap = this.onTap;
    return onTap == null ? body : _Tappable(onTap: onTap, child: body);
  }
}

/// A sticker without a bubble: WebP, animated (TGS) or video (WebM).
/// With [animate] off, as in the sticker panel until the pointer is over
/// it, an animated sticker shows its still thumbnail.
class StickerContent extends StatelessWidget {
  const StickerContent({
    super.key,
    required this.sticker,
    this.side = defaultSide,
    this.animate = true,
    this.lazy = false,
  });

  final td.Sticker sticker;
  final double side;
  final bool animate;

  /// Whether an animated sticker that isn't playing stays its still (or
  /// nothing) rather than its first frame, so a grid of them doesn't
  /// decode every animation.
  final bool lazy;

  static const double defaultSide = 180;

  @override
  Widget build(BuildContext context) {
    final size = fitMedia(
      sticker.width,
      sticker.height,
      maxWidth: side,
      maxHeight: side,
      minSide: math.min(60, side),
    );
    final thumbnail = sticker.thumbnail;
    final still = thumbnail != null && _isStill(thumbnail.format)
        ? TdImage(
            thumbnail: thumbnail.file,
            fit: BoxFit.contain,
            background: const Color(0x00000000),
          )
        : const SizedBox.shrink();
    final Widget body = switch (sticker.format) {
      td.StickerFormatTgs() || td.StickerFormatWebm()
          when !animate && thumbnail != null && _isStill(thumbnail.format) =>
        still,
      td.StickerFormatWebm() when !animate => still,
      td.StickerFormatTgs() when !animate && lazy => still,
      td.StickerFormatWebp() => TdImage(
        file: sticker.sticker,
        thumbnail: thumbnail?.file,
        fit: BoxFit.contain,
        background: const Color(0x00000000),
        cacheWidth: (side * MediaQuery.devicePixelRatioOf(context)).round(),
      ),
      td.StickerFormatTgs() => TdFileBuilder(
        file: sticker.sticker,
        download: true,
        priority: DownloadPriority.preview,
        builder: (context, file) {
          final path = downloadedPath(file);
          if (path == null) return still;
          return _AnimatedSticker(path: path, animate: animate, still: still);
        },
      ),
      td.StickerFormatWebm() => TdFileBuilder(
        file: sticker.sticker,
        download: true,
        priority: DownloadPriority.preview,
        builder: (context, file) {
          final path = downloadedPath(file);
          if (path == null) return still;
          return LoopingVideo(
            path: path,
            placeholder: still,
            fit: BoxFit.contain,
          );
        },
      ),
    };
    return Semantics(
      label: sticker.emoji,
      image: true,
      child: SizedBox.fromSize(size: size, child: body),
    );
  }

  static bool _isStill(td.ThumbnailFormat format) => switch (format) {
    td.ThumbnailFormatWebp() ||
    td.ThumbnailFormatJpeg() ||
    td.ThumbnailFormatPng() => true,
    _ => false,
  };
}

/// A TGS sticker. It loops with "Loop animated stickers" on; with it off
/// it plays once each time [animate] turns on, so it replays on hover.
class _AnimatedSticker extends ConsumerStatefulWidget {
  const _AnimatedSticker({
    required this.path,
    required this.animate,
    required this.still,
  });

  final String path;
  final bool animate;
  final Widget still;

  @override
  ConsumerState<_AnimatedSticker> createState() => _AnimatedStickerState();
}

class _AnimatedStickerState extends ConsumerState<_AnimatedSticker>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  var _loaded = false;

  /// Loops, or with [restart] plays once more from the start and rests on
  /// the last frame; stops where it is when not animating.
  void _play({required bool loop, bool restart = false}) {
    if (!_loaded) return;
    if (!widget.animate) {
      _controller.stop();
    } else if (loop) {
      if (!_controller.isAnimating) unawaited(_controller.repeat());
    } else if (restart) {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void didUpdateWidget(_AnimatedSticker old) {
    super.didUpdateWidget(old);
    if (old.animate != widget.animate) {
      _play(loop: ref.read(loopStickersProvider), restart: widget.animate);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loopStickersProvider, (_, loop) {
      // A loop switched off finishes the round it is on.
      if (!loop && _controller.isAnimating) {
        unawaited(_controller.forward());
      } else {
        _play(loop: loop);
      }
    });
    return Lottie.file(
      File(widget.path),
      controller: _controller,
      decoder: LottieComposition.decodeGZip,
      fit: BoxFit.contain,
      frameRate: FrameRate.max,
      onLoaded: (composition) {
        _controller.duration = composition.duration;
        _loaded = true;
        _play(loop: ref.read(loopStickersProvider), restart: true);
      },
      errorBuilder: (context, error, stack) => widget.still,
    );
  }
}

/// A round video message. It plays muted as soon as it is on screen;
/// a tap turns the sound on, another one pauses.
class VideoNoteContent extends ConsumerStatefulWidget {
  const VideoNoteContent({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.videoNote,
    this.unread = false,
    this.meta,
  });

  final int chatId;
  final int messageId;
  final td.VideoNote videoNote;

  /// Nobody has watched it yet.
  final bool unread;

  /// The time and ticks, drawn over the circle.
  final Widget? meta;

  static const double side = 220;

  @override
  ConsumerState<VideoNoteContent> createState() => _VideoNoteContentState();
}

class _VideoNoteContentState extends ConsumerState<VideoNoteContent> {
  CirclePlayer? _player;
  String? _path;
  var _withSound = false;

  // Read up front: ref can't be used in dispose or after an await once the
  // widget has left the tree.
  late final CirclePlayerPool _pool;
  late final ConversationController _conversations;
  late final ValueNotifier<ActiveCircle?> _active;
  late final AudioTrackPlayer _audio;

  @override
  void initState() {
    super.initState();
    _pool = ref.read(circlePlayerPoolProvider);
    _conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    _active = ref.read(activeCircleProvider);
    _audio = ref.read(audioPlayerProvider);
    _active.addListener(_onActive);
  }

  bool get _isActive {
    final active = _active.value;
    return active != null &&
        active.chatId == widget.chatId &&
        active.messageId == widget.messageId;
  }

  /// The capsule's close button, or another circle taking over, silences
  /// this one again.
  void _onActive() {
    if (!_withSound || _isActive) return;
    final player = _player;
    if (player != null) {
      unawaited(player.setMuted(true));
      unawaited(player.setRate(1));
    }
    if (mounted) setState(() => _withSound = false);
  }

  void _attach(String path) {
    if (_path == path) return;
    _path = path;
    final player = _player ??= _pool.acquire(CircleQuality.standard.side);
    unawaited(player.open(CircleSource.file(path)));
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null) return;
    if (!_withSound) {
      setState(() => _withSound = true);
      // One sound at a time: a voice message stops, and the capsule moves
      // from it to this circle.
      await _audio.stop();
      _active.value = (
        chatId: widget.chatId,
        messageId: widget.messageId,
        player: player,
      );
      await player.setMuted(false);
      await player.play();
      unawaited(
        _conversations
            .openContent(widget.chatId, widget.messageId)
            .catchError((Object _) {}),
      );
      return;
    }
    if (player.playing.value) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  @override
  void dispose() {
    _active.removeListener(_onActive);
    if (_isActive) {
      // Listeners rebuild widgets, which is not allowed while the tree is
      // being taken apart.
      final active = _active;
      scheduleMicrotask(() => active.value = null);
    }
    final player = _player;
    if (player != null) {
      unawaited(_pool.release(player));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.videoNote;
    final cover = TdImage(
      thumbnail: note.thumbnail?.file,
      minithumbnail: note.minithumbnail,
    );
    return _Tappable(
      onTap: () => unawaited(_toggle()),
      child: SizedBox.square(
        dimension: VideoNoteContent.side,
        child: Stack(
          children: [
            TdFileBuilder(
              file: note.video,
              download: true,
              kind: MediaDownloadKind.videos,
              builder: (context, file) {
                final path = downloadedPath(file);
                if (path != null) _attach(path);
                return CircleVideo(
                  player: _player,
                  size: VideoNoteContent.side,
                  placeholder: cover,
                );
              },
            ),
            Positioned(
              left: 10,
              top: 12,
              child: MediaPill(
                formatDuration(note.duration),
                unread: widget.unread,
              ),
            ),
            if (widget.meta != null)
              Positioned(right: 10, bottom: 12, child: widget.meta!),
          ],
        ),
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(onTap: onTap, child: child),
  );
}
