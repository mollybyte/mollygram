import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart' show AudioTrackPlayer;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import '../session/providers.dart';
import 'media_providers.dart';

/// The message to play once [messageId] of [messages] finishes: the next
/// newer voice message after a voice message, or the next music file after
/// music, as in Telegram. Null when there is none, or when the finished
/// message is not in [messages].
ConversationMessage? nextAudioTrack(
  List<ConversationMessage> messages,
  int messageId,
) {
  ConversationMessage? finished;
  for (final m in messages) {
    if (m.id == messageId) finished = m;
  }
  if (finished == null) return null;
  final voice = finished.content is td.MessageVoiceNote;
  ConversationMessage? next;
  for (final m in messages) {
    if (m.id <= messageId) continue;
    if (next != null && m.id >= next.id) continue;
    if ((m.content is td.MessageVoiceNote) == voice &&
        audioFileOf(m.content) != null) {
      next = m;
    }
  }
  return next;
}

/// The playable file of a voice message or a music file.
td.File? audioFileOf(td.MessageContent content) => switch (content) {
  td.MessageVoiceNote(:final voiceNote) => voiceNote.voice,
  td.MessageAudio(:final audio) => audio.audio,
  _ => null,
};

/// Wires [player] so that a finished voice message or music file goes on to
/// the next one of the chat, downloading it first when needed.
void continueAudioPlayback(Ref ref, AudioTrackPlayer player) {
  player.onCompleted = (key) {
    if (key case AudioTrackKey()) unawaited(_playNext(ref, player, key));
  };
}

Future<void> _playNext(
  Ref ref,
  AudioTrackPlayer player,
  AudioTrackKey finished,
) async {
  final session = ref.read(telegramSessionProvider).asData?.value;
  if (session == null) return;
  final next = nextAudioTrack(
    session.conversations.store.messagesFor(finished.chatId),
    finished.messageId,
  );
  if (next == null) return;
  await playAudioMessage(
    session,
    player,
    finished.chatId,
    next,
    onlyWhenIdle: true,
  );
}

/// Plays [message], a voice message or music file of [chatId], on [player],
/// downloading it first when needed, and tells Telegram it was opened. With
/// [onlyWhenIdle], nothing plays if the user started something else while
/// the file downloaded.
Future<void> playAudioMessage(
  TelegramSession session,
  AudioTrackPlayer player,
  int chatId,
  ConversationMessage message, {
  bool onlyWhenIdle = false,
}) async {
  final file = audioFileOf(message.content);
  if (file == null) return;
  var path = downloadedPath(file);
  if (path == null) {
    try {
      path = downloadedPath(await session.files.downloadNow(file.id));
    } on Object {
      return;
    }
  }
  if (path == null || (onlyWhenIdle && player.track.value != null)) return;
  await player.play((chatId: chatId, messageId: message.id), path);
  unawaited(
    session.conversations
        .openContent(chatId, message.id)
        .catchError((Object _) {}),
  );
}
