import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'td_file.dart';

/// A photo or video opened from a message.
sealed class MediaViewerItem {
  const MediaViewerItem();

  const factory MediaViewerItem.photo(td.Photo photo) = _PhotoItem;
  const factory MediaViewerItem.video(td.Video video) = _VideoItem;
}

final class _PhotoItem extends MediaViewerItem {
  const _PhotoItem(this.photo);
  final td.Photo photo;
}

final class _VideoItem extends MediaViewerItem {
  const _VideoItem(this.video);
  final td.Video video;
}

/// Opens [item] over the window on a dark backdrop. Escape, a click on the
/// backdrop or the close button closes it.
Future<void> showMediaViewer(BuildContext context, MediaViewerItem item) =>
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0xE6000000),
        transitionDuration: const Duration(milliseconds: 120),
        reverseTransitionDuration: const Duration(milliseconds: 100),
        pageBuilder: (context, animation, secondary) => _MediaViewer(item),
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

class _MediaViewer extends StatelessWidget {
  const _MediaViewer(this.item);

  final MediaViewerItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = switch (item) {
      _PhotoItem(:final photo) => _Photo(photo),
      _VideoItem(:final video) => _Video(video),
    };
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 56, 48, 48),
                child: Center(child: body),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: MediaActionButton(
                icon: MgIcons.close,
                size: 36,
                semanticLabel: l10n.close,
                background: const Color(0x33FFFFFF),
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo(this.photo);

  final td.Photo photo;

  @override
  Widget build(BuildContext context) {
    final sizes = [...photo.sizes]..sort((a, b) => a.width.compareTo(b.width));
    if (sizes.isEmpty) return const SizedBox.shrink();
    final largest = sizes.last;
    return InteractiveViewer(
      maxScale: 6,
      child: AspectRatio(
        aspectRatio: largest.width / math.max(1, largest.height),
        child: TdImage(
          file: largest.photo,
          thumbnail: sizes.length > 1 ? sizes[sizes.length - 2].photo : null,
          minithumbnail: photo.minithumbnail,
          fit: BoxFit.contain,
          background: const Color(0x00000000),
        ),
      ),
    );
  }
}

class _Video extends StatelessWidget {
  const _Video(this.video);

  final td.Video video;

  @override
  Widget build(BuildContext context) {
    final ratio = video.width > 0 && video.height > 0
        ? video.width / video.height
        : 16 / 9;
    final cover = TdImage(
      thumbnail: video.thumbnail?.file,
      minithumbnail: video.minithumbnail,
      fit: BoxFit.contain,
      background: const Color(0x00000000),
    );
    return AspectRatio(
      aspectRatio: ratio,
      child: TdFileBuilder(
        file: video.video,
        download: true,
        priority: DownloadPriority.requested,
        builder: (context, file) {
          final path = downloadedPath(file);
          if (path != null) return VideoPlayerView(path: path);
          final total = file.size > 0 ? file.size : file.expectedSize;
          final progress = total > 0 ? file.local.downloadedSize / total : null;
          return Stack(
            fit: StackFit.expand,
            children: [
              cover,
              Center(
                child: MediaActionButton(
                  icon: MgIcons.download,
                  size: 52,
                  progress: progress,
                  background: const Color(0x80000000),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
