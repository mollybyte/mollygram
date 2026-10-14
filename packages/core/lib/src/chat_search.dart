import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A message found by [ChatSearch.messages].
final class FoundMessage {
  const FoundMessage({
    required this.chatId,
    required this.messageId,
    required this.text,
    required this.date,
    this.isFile = false,
  });

  final int chatId;
  final int messageId;

  /// The text or caption, or the file name for documents.
  final String text;

  /// Unix time in seconds.
  final int date;
  final bool isFile;
}

/// Global search over chats and messages, for the command palette.
///
/// TDLib sends `updateNewChat` for every chat before it returns its id, so
/// the chats found here are already in the chat list store.
final class ChatSearch {
  ChatSearch(this._client);

  final td.TdClient _client;

  /// Chat ids whose title or username matches [query]: the user's own chats
  /// and contacts first, then public chats from the server.
  Future<List<int>> chats(String query, {int limit = 8}) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final local = _client.send(td.SearchChats(query: text, limit: limit));
    final server = _client
        .send(td.SearchChatsOnServer(query: text, limit: limit))
        .then<td.Chats?>((chats) => chats)
        // Server search fails offline; the local results still count.
        .catchError((Object _) => null, test: (e) => e is td.TdException);
    final ids = <int>{...(await local).chatIds, ...?(await server)?.chatIds};
    return ids.take(limit).toList();
  }

  /// Messages in all chats that contain [query], newest first.
  Future<List<FoundMessage>> messages(String query, {int limit = 8}) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    final found = await _client.send(
      td.SearchMessages(
        query: text,
        offset: '',
        limit: limit,
        minDate: 0,
        maxDate: 0,
      ),
    );
    return [for (final message in found.messages) ?_foundFrom(message)]
        .take(limit)
        .toList();
  }
}

FoundMessage? _foundFrom(td.Message message) {
  final (text, isFile) = switch (message.content) {
    td.MessageText(:final text) => (text.text, false),
    td.MessageDocument(:final document, :final caption) => (
      caption.text.isEmpty ? document.fileName : caption.text,
      caption.text.isEmpty,
    ),
    td.MessagePhoto(:final caption) => (caption.text, false),
    td.MessageVideo(:final caption) => (caption.text, false),
    td.MessageAudio(:final caption) => (caption.text, false),
    td.MessageAnimation(:final caption) => (caption.text, false),
    td.MessageVoiceNote(:final caption) => (caption.text, false),
    _ => ('', false),
  };
  if (text.isEmpty) return null;
  return FoundMessage(
    chatId: message.chatId,
    messageId: message.id,
    text: text,
    date: message.date,
    isFile: isFile,
  );
}
