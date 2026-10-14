import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'describe.dart';
import 'media_providers.dart';
import 'td_file.dart';

/// Decodes Telegram's waveform: 5-bit samples packed little-endian.
List<int> decodeWaveform(Uint8List data) {
  final count = data.length * 8 ~/ 5;
  return [
    for (var i = 0; i < count; i++)
      () {
        final bit = i * 5;
        final byte = bit >> 3;
        final shift = bit & 7;
        final low = data[byte];
        final high = byte + 1 < data.length ? data[byte + 1] : 0;
        return ((low | (high << 8)) >> shift) & 31;
      }(),
  ];
}

/// Downloaded, downloading, or neither: what the round button of a file
/// does.
enum _FileState { remote, downloading, local }

_FileState _stateOf(td.File file) {
  if (downloadedPath(file) != null) return _FileState.local;
  if (file.local.isDownloadingActive) return _FileState.downloading;
  return _FileState.remote;
}

double? _progressOf(td.File file) {
  final total = file.size > 0 ? file.size : file.expectedSize;
  if (total <= 0) return null;
  return (file.local.downloadedSize / total).clamp(0, 1).toDouble();
}

FileController _filesOf(WidgetRef ref) =>
    ref.read(telegramSessionProvider).requireValue.files;

/// A file in a bubble: the round button (download, cancel, open), the name
/// and the size or the download progress.
class DocumentContent extends ConsumerWidget {
  const DocumentContent({super.key, required this.document, this.meta});

  final td.Document document;

  /// The time and ticks, drawn at the end of the size line.
  final Widget? meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return TdFileBuilder(
      file: document.document,
      builder: (context, file) {
        final state = _stateOf(file);
        final size = file.size > 0 ? file.size : file.expectedSize;
        final subtitle = switch (state) {
          _FileState.downloading => l10n.fileProgress(
            formatFileSize(l10n, file.local.downloadedSize, locale),
            formatFileSize(l10n, size, locale),
          ),
          _ => formatFileSize(l10n, size, locale),
        };
        void onTap() {
          final files = _filesOf(ref);
          switch (state) {
            case _FileState.remote:
              unawaited(
                files
                    .download(file.id, priority: DownloadPriority.requested)
                    .then<void>((_) {}, onError: (Object _) {}),
              );
            case _FileState.downloading:
              unawaited(files.cancel(file.id).catchError((Object _) {}));
            case _FileState.local:
              unawaited(launchUrl(Uri.file(file.local.path)));
          }
        }

        return _FileRow(
          button: MediaActionButton(
            icon: switch (state) {
              _FileState.remote => MgIcons.download,
              _FileState.downloading => MgIcons.close,
              _FileState.local => MgIcons.file,
            },
            size: 42,
            progress: state == _FileState.downloading
                ? _progressOf(file)
                : null,
            semanticLabel: switch (state) {
              _FileState.remote => l10n.download,
              _FileState.downloading => l10n.cancelDownload,
              _FileState.local => l10n.openFile,
            },
            onTap: onTap,
          ),
          title: document.fileName.isEmpty
              ? l10n.previewDocument
              : document.fileName,
          subtitle: subtitle,
          meta: meta,
          onTap: onTap,
        );
      },
    );
  }
}

/// A voice message: play button, waveform and length.
class VoiceNoteContent extends ConsumerWidget {
  const VoiceNoteContent({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.voiceNote,
    this.meta,
  });

  final int chatId;
  final int messageId;
  final td.VoiceNote voiceNote;
  final Widget? meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final samples = decodeWaveform(voiceNote.waveform);
    return _AudioTrack(
      chatId: chatId,
      messageId: messageId,
      file: voiceNote.voice,
      duration: voiceNote.duration,
      builder: (context, button, progress, time) => _FileRow(
        button: button,
        titleWidget: VoiceWaveform(
          samples: samples,
          progress: progress,
          color: c.accent,
        ),
        subtitle: time,
        meta: meta,
      ),
    );
  }
}

/// A music file: play button, title and performer.
class AudioContent extends ConsumerWidget {
  const AudioContent({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.audio,
    this.meta,
  });

  final int chatId;
  final int messageId;
  final td.Audio audio;
  final Widget? meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final title = audio.title.isNotEmpty
        ? audio.title
        : audio.fileName.isNotEmpty
        ? audio.fileName
        : l10n.previewAudio;
    return _AudioTrack(
      chatId: chatId,
      messageId: messageId,
      file: audio.audio,
      duration: audio.duration,
      builder: (context, button, progress, time) => _FileRow(
        button: button,
        title: title,
        subtitle: audio.performer.isEmpty ? time : '${audio.performer} · $time',
        meta: meta,
      ),
    );
  }
}

/// Shared by voice and music: downloads the file on the first tap, then
/// plays it through the app's one audio player.
class _AudioTrack extends ConsumerWidget {
  const _AudioTrack({
    required this.chatId,
    required this.messageId,
    required this.file,
    required this.duration,
    required this.builder,
  });

  final int chatId;
  final int messageId;
  final td.File file;
  final int duration;
  final Widget Function(
    BuildContext context,
    Widget button,
    double progress,
    String time,
  )
  builder;

  AudioTrackKey get _key => (chatId: chatId, messageId: messageId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final player = ref.watch(audioPlayerProvider);
    return TdFileBuilder(
      file: file,
      builder: (context, file) => ValueListenableBuilder(
        valueListenable: player.track,
        builder: (context, track, _) {
          final current = track == _key;
          return ListenableBuilder(
            listenable: Listenable.merge([
              player.playing,
              player.position,
              player.duration,
            ]),
            builder: (context, _) {
              final playing = current && player.playing.value;
              final length = current && player.duration.value > Duration.zero
                  ? player.duration.value
                  : Duration(seconds: duration);
              final position = current ? player.position.value : Duration.zero;
              final progress = length.inMilliseconds == 0
                  ? 0.0
                  : (position.inMilliseconds / length.inMilliseconds)
                        .clamp(0, 1)
                        .toDouble();
              final time = formatDuration(
                current ? position.inSeconds : length.inSeconds,
              );
              final state = _stateOf(file);
              Future<void> onTap() async {
                if (playing) return player.pause();
                final files = _filesOf(ref);
                var path = downloadedPath(file);
                if (path == null) {
                  if (state == _FileState.downloading) {
                    return files.cancel(file.id).catchError((Object _) {});
                  }
                  try {
                    path = downloadedPath(await files.downloadNow(file.id));
                  } on Object {
                    return;
                  }
                }
                if (path == null) return;
                await player.play(_key, path);
                final conversations = ref
                    .read(telegramSessionProvider)
                    .requireValue
                    .conversations;
                unawaited(
                  conversations
                      .openContent(chatId, messageId)
                      .catchError((Object _) {}),
                );
              }

              final button = MediaActionButton(
                icon: state == _FileState.downloading
                    ? MgIcons.close
                    : playing
                    ? MgIcons.pause
                    : MgIcons.play,
                size: 40,
                progress: state == _FileState.downloading
                    ? _progressOf(file)
                    : null,
                semanticLabel: playing ? l10n.pause : l10n.play,
                onTap: () => unawaited(onTap()),
              );
              return builder(context, button, progress, time);
            },
          );
        },
      ),
    );
  }
}

/// The layout of files and audio: a round button, then two lines.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.button,
    required this.subtitle,
    this.title,
    this.titleWidget,
    this.meta,
    this.onTap,
  });

  final Widget button;
  final String? title;
  final Widget? titleWidget;
  final String subtitle;
  final Widget? meta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final row = Row(
      children: [
        button,
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget ??
                  Text(
                    title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mgTextStyle(c, weight: FontWeight.w500),
                  ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MessageMeta.styleOf(c),
                    ),
                  ),
                  if (meta != null) ...[const SizedBox(width: 8), meta!],
                ],
              ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}
