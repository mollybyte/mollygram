import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/chat/voice_autoplay.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

void main() {
  // Newest first, as the store hands them out.
  final messages = [
    _message(9, _voice(90)),
    _message(8, _text('Thanks')),
    _message(7, _music(70)),
    _message(6, _voice(60)),
    _message(5, _text('Hi')),
    _message(4, _voice(40)),
    _message(3, _music(30)),
    _message(2, _voice(20)),
  ];

  test('goes on to the next newer voice message, skipping the rest', () {
    expect(nextAudioTrack(messages, 2)?.id, 4);
    expect(nextAudioTrack(messages, 4)?.id, 6);
    expect(nextAudioTrack(messages, 6)?.id, 9);
  });

  test('music goes on to music', () {
    expect(nextAudioTrack(messages, 3)?.id, 7);
  });

  test('stops at the newest one', () {
    expect(nextAudioTrack(messages, 9), isNull);
    expect(nextAudioTrack(messages, 7), isNull);
  });

  test('plays nothing after a message that is not loaded', () {
    expect(nextAudioTrack(messages, 1), isNull);
    expect(nextAudioTrack(const <ConversationMessage>[], 2), isNull);
  });

  test('knows the file of voice and music', () {
    expect(audioFileOf(_voice(1))?.id, 1);
    expect(audioFileOf(_music(2))?.id, 2);
    expect(audioFileOf(_text('x')), isNull);
  });
}

td.MessageContent _text(String text) => td.MessageText(
  text: td.FormattedText(text: text, entities: const []),
);

td.MessageContent _voice(int fileId) => td.MessageVoiceNote(
  voiceNote: td.VoiceNote(
    duration: 3,
    waveform: Uint8List(0),
    mimeType: 'audio/ogg',
    voice: _file(fileId),
  ),
  caption: const td.FormattedText(text: '', entities: []),
  isListened: false,
);

td.MessageContent _music(int fileId) => td.MessageAudio(
  audio: td.Audio(
    duration: 180,
    title: 'Song',
    performer: '',
    fileName: 'song.mp3',
    mimeType: 'audio/mpeg',
    externalAlbumCovers: const [],
    audio: _file(fileId),
  ),
  caption: const td.FormattedText(text: '', entities: []),
);

td.File _file(int id) => td.File(
  id: id,
  size: 100,
  expectedSize: 100,
  local: const td.LocalFile(
    path: '',
    canBeDownloaded: true,
    canBeDeleted: false,
    isDownloadingActive: false,
    isDownloadingCompleted: false,
    downloadOffset: 0,
    downloadedPrefixSize: 0,
    downloadedSize: 0,
  ),
  remote: td.RemoteFile(
    id: 'r$id',
    uniqueId: 'u$id',
    isUploadingActive: false,
    isUploadingCompleted: true,
    uploadedSize: 100,
  ),
);

ConversationMessage _message(int id, td.MessageContent content) =>
    ConversationMessage(
      td.Message(
        id: id,
        senderId: const td.MessageSenderUser(userId: 2),
        chatId: 7,
        isOutgoing: false,
        isPinned: false,
        isFromOffline: false,
        canBeSaved: true,
        hasTimestampedMedia: false,
        isChannelPost: false,
        isPaidStarSuggestedPost: false,
        isPaidGramSuggestedPost: false,
        containsUnreadMention: false,
        containsUnreadPollVotes: false,
        date: 1700000000 + id,
        editDate: 0,
        unreadReactions: const [],
        selfDestructIn: 0,
        autoDeleteIn: 0,
        viaBotUserId: 0,
        senderBusinessBotUserId: 0,
        senderBoostCount: 0,
        senderTag: '',
        paidMessageStarCount: 0,
        authorSignature: '',
        mediaAlbumId: 0,
        effectId: 0,
        summaryLanguageCode: '',
        content: content,
        ephemeralMessageId: 0,
        chatInstance: 0,
      ),
    );
