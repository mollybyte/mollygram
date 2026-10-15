import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_media/mollygram_media.dart' show AudioTrackPlayer;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import '../shared_media/message_jump.dart';
import 'describe.dart';
import 'file_content.dart';
import 'media_providers.dart';

/// The voice message or music file that is playing, as a glass capsule at
/// the right of the chat header, like the player bar of the official
/// client: play or pause, who sent it and what it is, the time, the speed
/// and a close button. The title shows the message in its chat. Nothing
/// is drawn while nothing is loaded.
class AudioPlayerCapsule extends ConsumerWidget {
  const AudioPlayerCapsule({super.key, required this.chatId});

  /// The chat this header belongs to.
  final int chatId;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    return ValueListenableBuilder(
      valueListenable: player.track,
      builder: (context, track, _) => AnimatedSwitcher(
        duration: _duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: track is AudioTrackKey
            ? _Capsule(
                key: ValueKey(track),
                track: track,
                player: player,
                currentChatId: chatId,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _Capsule extends ConsumerWidget {
  const _Capsule({
    super.key,
    required this.track,
    required this.player,
    required this.currentChatId,
  });

  final AudioTrackKey track;
  final AudioTrackPlayer player;
  final int currentChatId;

  void _show(WidgetRef ref) {
    ref
        .read(messageJumpProvider.notifier)
        .request(track.chatId, track.messageId);
    if (track.chatId != currentChatId) {
      ref.read(workspaceControllerProvider).open(track.chatId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final store = ref
        .watch(telegramSessionProvider)
        .asData
        ?.value
        .conversations
        .store;
    final message = store?.message(track.chatId, track.messageId);
    final content = message?.content;
    final (title, subtitle) = switch (content) {
      td.MessageAudio(:final audio) => (
        audio.title.isNotEmpty
            ? audio.title
            : audio.fileName.isNotEmpty
            ? audio.fileName
            : l10n.previewAudio,
        audio.performer.isNotEmpty ? audio.performer : l10n.previewAudio,
      ),
      _ => (
        message == null || store == null
            ? ref.watch(chatEntryProvider(track.chatId)).value?.title ?? ''
            : nameOfSender(l10n, store, message.sender),
        content == null
            ? l10n.previewVoiceNote
            : describeContent(l10n, content),
      ),
    };
    final tabular = const [FontFeature.tabularFigures()];
    return Glass(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      child: ListenableBuilder(
        listenable: Listenable.merge([
          player.playing,
          player.position,
          player.duration,
          player.rate,
        ]),
        builder: (context, _) {
          final playing = player.playing.value;
          final length = player.duration.value;
          final position = player.position.value;
          final rate = player.rate.value;
          const rates = AudioTrackPlayer.rates;
          final time = length > Duration.zero
              ? '${formatDuration(position.inSeconds)} / '
                    '${formatDuration(length.inSeconds)}'
              : formatDuration(position.inSeconds);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MgIconButton(
                icon: playing ? MgIcons.pause : MgIcons.play,
                tooltip: playing ? l10n.pause : l10n.play,
                onPressed: () =>
                    unawaited(playing ? player.pause() : player.resume()),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: l10n.showInChat,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _show(ref),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mgTextStyle(
                              c,
                              weight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mgTextStyle(
                              c,
                              size: MgType.caption,
                              color: c.fg2,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                time,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  color: c.fg2,
                ).copyWith(fontFeatures: tabular),
              ),
              const SizedBox(width: 8),
              SpeedButton(
                rate: rate,
                onTap: () => unawaited(
                  player.setRate(
                    rates[(rates.indexOf(rate) + 1) % rates.length],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              MgIconButton(
                icon: MgIcons.close,
                tooltip: l10n.close,
                onPressed: () => unawaited(player.stop()),
              ),
            ],
          );
        },
      ),
    );
  }
}
