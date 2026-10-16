import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart' show AudioTrackPlayer;
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

DownloadsController _downloadsOf(WidgetRef ref) =>
    ref.read(telegramSessionProvider).requireValue.downloads;

/// A file in a bubble: the round button (download, cancel, open), the name
/// and the size or the download progress.
class DocumentContent extends ConsumerWidget {
  const DocumentContent({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.document,
    this.meta,
  });

  final int chatId;
  final int messageId;
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
              // A click is a download the user asked for: it goes on the
              // downloads list, where it can be paused and found again.
              unawaited(
                _downloadsOf(ref)
                    .add(file.id, chatId: chatId, messageId: messageId)
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

/// A voice message: play button, waveform and length, and a button that
/// asks Telegram for its transcript and shows it under the row, as the
/// official client does.
class VoiceNoteContent extends ConsumerStatefulWidget {
  const VoiceNoteContent({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.voiceNote,
    this.unread = false,
    this.meta,
  });

  final int chatId;
  final int messageId;
  final td.VoiceNote voiceNote;

  /// Nobody has played it yet: the receiver, or for our own the recipient.
  final bool unread;
  final Widget? meta;

  @override
  ConsumerState<VoiceNoteContent> createState() => _VoiceNoteContentState();
}

class _VoiceNoteContentState extends ConsumerState<VoiceNoteContent> {
  /// Whether the transcript is shown; a message that already carries one
  /// starts with it folded, like a new one.
  var _open = false;

  void _toggle() {
    setState(() => _open = !_open);
    if (_open && widget.voiceNote.speechRecognitionResult == null) {
      final session = ref.read(telegramSessionProvider).asData?.value;
      if (session == null) return;
      unawaited(
        session.conversations
            .recognizeSpeech(widget.chatId, widget.messageId)
            .catchError((Object _) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final voiceNote = widget.voiceNote;
    final samples = decodeWaveform(voiceNote.waveform);
    final row = _AudioTrack(
      chatId: widget.chatId,
      messageId: widget.messageId,
      file: voiceNote.voice,
      duration: voiceNote.duration,
      builder: (context, button, progress, time, controls) => _FileRow(
        button: button,
        titleWidget: _Scrubber(
          onSeek: controls?.seek,
          child: VoiceWaveform(
            samples: samples,
            progress: progress,
            color: c.accent,
          ),
        ),
        subtitle: time,
        subtitleTrailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (controls != null) ...[
              SpeedButton(rate: controls.rate, onTap: controls.nextRate),
              const SizedBox(width: 4),
            ],
            _TranscribeButton(
              tooltip: _open ? l10n.hideTranscript : l10n.transcribe,
              open: _open,
              onTap: _toggle,
            ),
          ],
        ),
        meta: widget.meta,
        unread: widget.unread,
      ),
    );
    if (!_open) return row;
    final result = voiceNote.speechRecognitionResult;
    final (text, muted) = switch (result) {
      td.SpeechRecognitionResultText(:final text) => (text, false),
      td.SpeechRecognitionResultPending(:final partialText) => (
        partialText.isEmpty ? l10n.transcribing : '$partialText…',
        true,
      ),
      td.SpeechRecognitionResultError() => (l10n.transcriptionFailed, true),
      null => (l10n.transcribing, true),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Text(
              text,
              key: ValueKey(text),
              style: mgTextStyle(c, color: muted ? c.fg2 : c.fg),
            ),
          ),
        ),
      ],
    );
  }
}

/// The small "transcribe" button next to the voice message's time, filled
/// with the accent while the transcript is shown.
class _TranscribeButton extends StatelessWidget {
  const _TranscribeButton({
    required this.tooltip,
    required this.open,
    required this.onTap,
  });

  final String tooltip;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: open ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: MgIcon(MgIcons.translate, size: 11, color: c.accent),
          ),
        ),
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
      builder: (context, button, progress, time, _) => _FileRow(
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
    _TrackControls? controls,
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
              player.rate,
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
                // Read before any await: the row may scroll away meanwhile.
                final files = _filesOf(ref);
                final downloads = _downloadsOf(ref);
                final conversations = ref
                    .read(telegramSessionProvider)
                    .requireValue
                    .conversations;
                var path = downloadedPath(file);
                if (path == null) {
                  if (state == _FileState.downloading) {
                    return files.cancel(file.id).catchError((Object _) {});
                  }
                  try {
                    await downloads.add(
                      file.id,
                      chatId: chatId,
                      messageId: messageId,
                    );
                    path = downloadedPath(await files.downloadNow(file.id));
                  } on Object {
                    return;
                  }
                }
                if (path == null) return;
                await player.play(_key, path);
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
              final rate = player.rate.value;
              const rates = AudioTrackPlayer.rates;
              return builder(
                context,
                button,
                progress,
                time,
                current
                    ? (
                        seek: (fraction) => unawaited(
                          player.seek(
                            Duration(
                              milliseconds: (length.inMilliseconds * fraction)
                                  .round(),
                            ),
                          ),
                        ),
                        rate: rate,
                        nextRate: () => unawaited(
                          player.setRate(
                            rates[(rates.indexOf(rate) + 1) % rates.length],
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

/// What a loaded track offers: seeking to a fraction, and the speed.
typedef _TrackControls = ({
  ValueChanged<double> seek,
  double rate,
  VoidCallback nextRate,
});

/// Lets a click or drag on the waveform move the playing voice message.
class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.child, this.onSeek});

  final Widget child;

  /// Null while the message is not playing: the waveform is just a picture.
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final seek = onSeek;
    if (seek == null) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        void at(Offset local) =>
            seek((local.dx / constraints.maxWidth).clamp(0.0, 1.0).toDouble());
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => at(d.localPosition),
            onHorizontalDragStart: (d) => at(d.localPosition),
            onHorizontalDragUpdate: (d) => at(d.localPosition),
            child: child,
          ),
        );
      },
    );
  }
}

/// `1×`, `1.5×`, `2×`: a click steps the playback speed.
/// "1×", "1.5×", "2×": the playback speed, tinted when it is not 1×.
class SpeedButton extends StatelessWidget {
  const SpeedButton({super.key, required this.rate, required this.onTap});

  final double rate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final label = rate == rate.roundToDouble() ? '${rate.round()}×' : '$rate×';
    final fast = rate != 1;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: fast ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: mgTextStyle(
              c,
              size: MgType.meta,
              weight: FontWeight.w600,
              color: c.accent,
              height: 1.3,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
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
    this.subtitleTrailing,
    this.meta,
    this.onTap,
    this.unread = false,
  });

  final Widget button;
  final String? title;
  final Widget? titleWidget;
  final String subtitle;

  /// Right after the subtitle, such as the speed of a playing voice.
  final Widget? subtitleTrailing;
  final Widget? meta;
  final VoidCallback? onTap;

  /// A dot after the subtitle: a voice message nobody has played yet.
  final bool unread;

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
                  Flexible(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MessageMeta.styleOf(c),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: MgUnreadDot(unread: unread, color: c.accent),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: subtitleTrailing == null
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: subtitleTrailing,
                          ),
                  ),
                  const Spacer(),
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
