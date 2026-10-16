import 'dart:async';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart' show AudioTrackPlayer;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import '../shared_media/message_jump.dart';
import 'describe.dart';
import 'file_content.dart';
import 'media_providers.dart';
import 'message_tile.dart' show SenderAvatar;
import 'voice_autoplay.dart';

/// The voice message or music file that is playing, as a glass capsule at
/// the right of the chat header, like the player bar of the official
/// client: play or pause, who sent it and what it is, the time, the speed
/// and a close button. The title shows the message in its chat. Nothing
/// is drawn while nothing is loaded. A video circle that plays with sound
/// takes the same place, with its own capsule.
class AudioPlayerCapsule extends ConsumerWidget {
  const AudioPlayerCapsule({super.key, required this.chatId});

  /// The chat this header belongs to.
  final int chatId;

  static const _duration = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerProvider);
    final active = ref.watch(activeCircleProvider);
    // One switcher for both, so a handoff between a voice message and a
    // circle never lays out two full capsules at once.
    return ListenableBuilder(
      listenable: Listenable.merge([player.track, active]),
      builder: (context, _) {
        final track = player.track.value;
        final circle = active.value;
        return AnimatedSwitcher(
          duration: _duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerRight,
            children: [...previous, ?current],
          ),
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
          child: circle != null
              ? _CircleCapsule(
                  key: ValueKey((circle.chatId, circle.messageId)),
                  circle: circle,
                  active: active,
                  currentChatId: chatId,
                )
              : track is AudioTrackKey
              ? _Capsule(
                  key: ValueKey(track),
                  track: track,
                  player: player,
                  currentChatId: chatId,
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class _CircleCapsule extends ConsumerWidget {
  const _CircleCapsule({
    super.key,
    required this.circle,
    required this.active,
    required this.currentChatId,
  });

  final ActiveCircle circle;
  final ValueNotifier<ActiveCircle?> active;
  final int currentChatId;

  void _show(WidgetRef ref) {
    ref
        .read(messageJumpProvider.notifier)
        .request(circle.chatId, circle.messageId);
    if (circle.chatId != currentChatId) {
      ref.read(workspaceControllerProvider).open(circle.chatId);
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
    final message = store?.message(circle.chatId, circle.messageId);
    final title = message == null || store == null
        ? ref.watch(chatEntryProvider(circle.chatId)).value?.title ?? ''
        : nameOfSender(l10n, store, message.sender);
    final player = circle.player;
    final tabular = const [FontFeature.tabularFigures()];
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(5),
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
          final rate = player.rate.value;
          const rates = AudioTrackPlayer.rates;
          final time = length > Duration.zero
              ? '${formatDuration(player.position.value.inSeconds)} / '
                    '${formatDuration(length.inSeconds)}'
              : formatDuration(player.position.value.inSeconds);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MgIconButton(
                icon: playing ? MgIcons.pause : MgIcons.play,
                tooltip: playing ? l10n.pause : l10n.play,
                onPressed: () =>
                    unawaited(playing ? player.pause() : player.play()),
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
                            l10n.previewVideoNote,
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
              const SizedBox(width: 2),
              MgIconButton(
                icon: MgIcons.close,
                tooltip: l10n.close,
                onPressed: () => active.value = null,
              ),
            ],
          );
        },
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

  /// The chat's voice messages, or its music, under the list button; a
  /// click plays that one.
  Future<void> _showPlaylist(BuildContext context, WidgetRef ref) async {
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    final box = context.findRenderObject() as RenderBox;
    final position = box.localToGlobal(Offset(0, box.size.height + 8));
    final store = session.conversations.store;
    final current = store.message(track.chatId, track.messageId);
    final voice = current?.content is! td.MessageAudio;
    final tracks = [
      for (final m in store.messagesFor(track.chatId))
        if ((m.content is td.MessageVoiceNote) == voice &&
            audioFileOf(m.content) != null)
          m,
    ]..sort((a, b) => a.id.compareTo(b.id));
    if (tracks.isEmpty) return;
    await showMgPopover(
      context,
      position: position,
      child: _Playlist(
        tracks: tracks,
        store: store,
        currentId: track.messageId,
        onPick: (message) =>
            unawaited(playAudioMessage(session, player, track.chatId, message)),
      ),
    );
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
              const SizedBox(width: 2),
              Builder(
                builder: (context) => MgIconButton(
                  icon: MgIcons.list,
                  tooltip: l10n.playlist,
                  onPressed: () => unawaited(_showPlaylist(context, ref)),
                ),
              ),
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

/// The chat's voice messages or music in order, oldest first, in a glass
/// panel: who sent each (or its title), how long it is, the one playing in
/// the accent.
class _Playlist extends StatelessWidget {
  const _Playlist({
    required this.tracks,
    required this.store,
    required this.currentId,
    required this.onPick,
  });

  final List<ConversationMessage> tracks;
  final ConversationStore store;
  final int currentId;
  final void Function(ConversationMessage message) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Glass(
        radius: 12,
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
              child: Text(
                l10n.playlist,
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  weight: FontWeight.w600,
                  color: c.fg2,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final message in tracks)
                    _PlaylistRow(
                      message: message,
                      store: store,
                      current: message.id == currentId,
                      onTap: () {
                        Navigator.of(context).maybePop();
                        if (message.id != currentId) onPick(message);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistRow extends StatefulWidget {
  const _PlaylistRow({
    required this.message,
    required this.store,
    required this.current,
    required this.onTap,
  });

  final ConversationMessage message;
  final ConversationStore store;
  final bool current;
  final VoidCallback onTap;

  @override
  State<_PlaylistRow> createState() => _PlaylistRowState();
}

class _PlaylistRowState extends State<_PlaylistRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final message = widget.message;
    final sender = nameOfSender(l10n, widget.store, message.sender);
    final (title, subtitle, seconds) = switch (message.content) {
      td.MessageAudio(:final audio) => (
        audio.title.isNotEmpty
            ? audio.title
            : audio.fileName.isNotEmpty
            ? audio.fileName
            : l10n.previewAudio,
        audio.performer.isNotEmpty ? audio.performer : sender,
        audio.duration,
      ),
      td.MessageVoiceNote(:final voiceNote) => (
        sender,
        formatChatTime(
          message.date,
          Localizations.localeOf(context).toString(),
        ),
        voiceNote.duration,
      ),
      _ => (sender, '', 0),
    };
    final color = widget.current ? c.accent : c.fg;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: _hover ? c.hover : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 26,
                  child: SenderAvatar(
                    name: sender,
                    photo: widget.store.photoOf(message.sender),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: mgTextStyle(
                        c,
                        weight: widget.current
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: color,
                        height: 1.2,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
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
              const SizedBox(width: 10),
              Text(
                formatDuration(seconds),
                style: mgTextStyle(
                  c,
                  size: MgType.caption,
                  color: widget.current ? c.accent : c.fg2,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
