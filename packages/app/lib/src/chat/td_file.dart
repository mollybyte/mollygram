import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';

/// Rebuilds with the newest state of a TDLib file as it downloads.
///
/// With [download] set, the download starts as soon as the widget is
/// built, which in a lazy list means when the message scrolls into view.
/// With a [kind] as well, it starts only when the auto-download switch for
/// that kind is on; otherwise the file waits for a click.
class TdFileBuilder extends ConsumerStatefulWidget {
  const TdFileBuilder({
    super.key,
    required this.file,
    required this.builder,
    this.download = false,
    this.kind,
    this.priority = DownloadPriority.media,
  });

  final td.File file;
  final bool download;
  final MediaDownloadKind? kind;
  final int priority;
  final Widget Function(BuildContext context, td.File file) builder;

  @override
  ConsumerState<TdFileBuilder> createState() => _TdFileBuilderState();
}

class _TdFileBuilderState extends ConsumerState<TdFileBuilder> {
  late final FileController _files = ref
      .read(telegramSessionProvider)
      .requireValue
      .files;
  late td.File _file;
  StreamSubscription<td.File>? _changes;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(TdFileBuilder old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) {
      unawaited(_changes?.cancel());
      _watch();
    } else if (widget.download && !old.download) {
      _startDownload();
    }
  }

  void _watch() {
    _file = _files.latest(widget.file);
    _changes = _files.changesOf(widget.file.id).listen((file) {
      if (mounted) setState(() => _file = file);
    });
    if (widget.download) _startDownload();
  }

  void _startDownload() {
    final local = _file.local;
    if (local.isDownloadingCompleted ||
        local.isDownloadingActive ||
        !local.canBeDownloaded) {
      return;
    }
    final kind = widget.kind;
    final started = kind == null
        ? _files.download(_file.id, priority: widget.priority)
        : _files.autoDownload(_file.id, kind: kind, priority: widget.priority);
    unawaited(started.then<void>((_) {}, onError: (Object _) {}));
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _file);
}

/// A picture from TDLib: the blurred inline preview first, then [thumbnail]
/// when there is one, then the full [file] once it has downloaded.
class TdImage extends StatelessWidget {
  const TdImage({
    super.key,
    this.file,
    this.thumbnail,
    this.minithumbnail,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.download = true,
    this.kind,
    this.background = const Color(0x22000000),
  });

  final td.File? file;
  final td.File? thumbnail;
  final td.Minithumbnail? minithumbnail;
  final BoxFit fit;

  /// What [file] is for the auto-download switches; the previews always
  /// load. With a kind that is off, a download button sits on the preview.
  final MediaDownloadKind? kind;

  /// The width to decode at, in physical pixels; keeps big photos from
  /// being decoded at full size for a small bubble.
  final int? cacheWidth;
  final bool download;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget layer = ColoredBox(color: background);
    final mini = minithumbnail;
    if (mini != null) {
      layer = _Blurred(bytes: mini.data, fit: fit);
    }
    final thumbnail = this.thumbnail;
    if (thumbnail != null) {
      final below = layer;
      layer = TdFileBuilder(
        file: thumbnail,
        download: download,
        priority: DownloadPriority.preview,
        builder: (context, f) {
          final path = downloadedPath(f);
          if (path == null) return below;
          return _FileImage(path: path, fit: fit, below: below);
        },
      );
    }
    final file = this.file;
    if (file != null) {
      final below = layer;
      final kind = this.kind;
      layer = TdFileBuilder(
        file: file,
        download: download,
        kind: kind,
        builder: (context, f) {
          final path = downloadedPath(f);
          if (path == null) {
            if (kind == null || !download) return below;
            return TapToDownload(file: f, kind: kind, child: below);
          }
          return _FileImage(
            path: path,
            fit: fit,
            cacheWidth: cacheWidth,
            below: below,
          );
        },
      );
    }
    return layer;
  }
}

/// [child], the preview of a file whose kind does not download on its own,
/// with a download button in the middle until the download runs. Nothing
/// is added while the switch for [kind] is on or the file is on its way.
class TapToDownload extends ConsumerWidget {
  const TapToDownload({
    super.key,
    required this.file,
    required this.kind,
    required this.child,
  });

  final td.File file;
  final MediaDownloadKind kind;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.read(telegramSessionProvider).requireValue.files;
    final local = file.local;
    if (files.autoDownloadKinds.contains(kind) ||
        local.isDownloadingActive ||
        !local.canBeDownloaded) {
      return child;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Center(
          child: MediaActionButton(
            icon: MgIcons.download,
            size: 40,
            semanticLabel: AppLocalizations.of(context).download,
            onTap: () => unawaited(
              files
                  .download(file.id, priority: DownloadPriority.requested)
                  .then<void>((_) {}, onError: (Object _) {}),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileImage extends StatelessWidget {
  const _FileImage({
    required this.path,
    required this.fit,
    required this.below,
    this.cacheWidth,
  });

  final String path;
  final BoxFit fit;
  final int? cacheWidth;
  final Widget below;

  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: fit,
    cacheWidth: cacheWidth,
    gaplessPlayback: true,
    filterQuality: FilterQuality.medium,
    frameBuilder: (context, child, frame, synchronous) =>
        frame == null && !synchronous ? below : child,
    errorBuilder: (context, error, stack) => below,
  );
}

class _Blurred extends StatelessWidget {
  const _Blurred({required this.bytes, required this.fit});

  final Uint8List bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Image.memory(bytes, fit: fit, gaplessPlayback: true),
    ),
  );
}
