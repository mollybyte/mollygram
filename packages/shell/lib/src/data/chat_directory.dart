import 'package:flutter/foundation.dart';

import '../model/workspace.dart';

enum ChatKind { private, group, channel, bot, saved }

/// What the shell needs to know about a chat to show it in a tab or in the
/// palette. The chat layer maps its own models onto this.
@immutable
class ChatSummary {
  const ChatSummary({
    required this.id,
    required this.title,
    this.kind = ChatKind.private,
    this.username,
    this.unread = 0,
  });

  final ChatId id;
  final String title;
  final ChatKind kind;

  /// Public username without the `@`.
  final String? username;

  final int unread;
}

/// A message found by search.
@immutable
class MessageHit {
  const MessageHit({
    required this.chatId,
    required this.messageId,
    required this.text,
    required this.chatTitle,
    this.isFile = false,
  });

  final ChatId chatId;
  final int messageId;

  /// The message text, or the file name for documents.
  final String text;
  final String chatTitle;
  final bool isFile;
}

/// The chats the shell can open and search.
///
/// The shell depends only on this interface, so it works against
/// [MockChatDirectory] in tests and the TDLib-backed implementation in the
/// app.
///
/// A directory that is also a [Listenable] should notify when chats change
/// (a rename, a new unread count); the tab strip then shows the new titles.
abstract interface class ChatDirectory {
  /// A chat by id, or `null` if it is not known (yet).
  ChatSummary? chat(ChatId id);

  /// Recently opened chats, most recent first.
  List<ChatSummary> recentChats({int limit = 5});

  /// Chats and people whose name or username matches [query].
  Future<List<ChatSummary>> searchChats(String query, {int limit = 8});

  /// Messages containing [query], newest first.
  Future<List<MessageHit>> searchMessages(String query, {int limit = 8});
}

/// An in-memory [ChatDirectory] for tests and development builds.
class MockChatDirectory implements ChatDirectory {
  MockChatDirectory({List<ChatSummary>? chats, List<MessageHit>? messages})
    : _chats = chats ?? _defaultChats,
      _messages = messages ?? _defaultMessages;

  final List<ChatSummary> _chats;
  final List<MessageHit> _messages;

  static const _defaultChats = [
    ChatSummary(id: 1, title: 'Anna Morris', username: 'annam'),
    ChatSummary(id: 2, title: 'Product team', kind: ChatKind.group, unread: 3),
    ChatSummary(id: 3, title: 'Dad'),
    ChatSummary(id: 4, title: 'Saved Messages', kind: ChatKind.saved),
    ChatSummary(id: 5, title: 'Adam Lewis', username: 'adamlew'),
    ChatSummary(id: 6, title: 'Vicky Stone', username: 'vstone'),
    ChatSummary(
      id: 7,
      title: 'Flutter news',
      kind: ChatKind.channel,
      username: 'flutternews',
      unread: 12,
    ),
  ];

  static const _defaultMessages = [
    MessageHit(
      chatId: 4,
      messageId: 101,
      text: 'lease_agreement.pdf',
      chatTitle: 'Saved Messages',
      isFile: true,
    ),
    MessageHit(
      chatId: 1,
      messageId: 102,
      text: 'Bring that board game on Saturday',
      chatTitle: 'Anna Morris',
    ),
  ];

  @override
  ChatSummary? chat(ChatId id) {
    for (final c in _chats) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  List<ChatSummary> recentChats({int limit = 5}) => _chats.take(limit).toList();

  @override
  Future<List<ChatSummary>> searchChats(String query, {int limit = 8}) async {
    final q = query.toLowerCase();
    return _chats
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              (c.username?.toLowerCase().contains(q) ?? false),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<MessageHit>> searchMessages(String query, {int limit = 8}) async {
    final q = query.toLowerCase();
    return _messages
        .where((m) => m.text.toLowerCase().contains(q))
        .take(limit)
        .toList();
  }
}
