import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'chat_list_store.dart';

/// What a message is and its text or caption, for places that show a
/// message as text: chat-list rows, and bubbles until media rendering
/// arrives.
(ChatPreviewKind, String) summarizeContent(td.MessageContent content) =>
    switch (content) {
      td.MessageText(:final text) => (ChatPreviewKind.text, text.text),
      td.MessagePhoto(:final caption) => (ChatPreviewKind.photo, caption.text),
      td.MessageVideo(:final caption) => (ChatPreviewKind.video, caption.text),
      td.MessageVideoNote() => (ChatPreviewKind.videoNote, ''),
      td.MessageVoiceNote(:final caption) => (
        ChatPreviewKind.voiceNote,
        caption.text,
      ),
      td.MessageAudio(:final caption) => (ChatPreviewKind.audio, caption.text),
      td.MessageDocument(:final caption) => (
        ChatPreviewKind.document,
        caption.text,
      ),
      td.MessageSticker(:final sticker) => (
        ChatPreviewKind.sticker,
        sticker.emoji,
      ),
      td.MessageAnimation(:final caption) => (
        ChatPreviewKind.animation,
        caption.text,
      ),
      _ => (ChatPreviewKind.other, ''),
    };
