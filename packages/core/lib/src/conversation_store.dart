/// Who sent a message: a user, or a chat (a channel, or a group posting
/// anonymously).
final class MessageSenderId {
  const MessageSenderId.user(this.id) : isChat = false;
  const MessageSenderId.chat(this.id) : isChat = true;

  final int id;
  final bool isChat;

  @override
  bool operator ==(Object other) =>
      other is MessageSenderId && other.id == id && other.isChat == isChat;

  @override
  int get hashCode => Object.hash(id, isChat);
}

/// Where an outgoing message is on its way to the server.
enum MessageSendState {
  /// On the server; incoming messages are always here.
  sent,

  /// Waiting to be sent.
  pending,

  /// The server rejected it.
  failed,
}

/// A presentation-ready message retained in a single conversation timeline.
final class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.date,
    required this.isOutgoing,
    this.sender,
    this.sendState = MessageSendState.sent,
  });

  final int id;
  final int chatId;
  final String text;
  final int date;
  final bool isOutgoing;

  /// Who sent the message, when TDLib said so.
  final MessageSenderId? sender;
  final MessageSendState sendState;

  ConversationMessage copyWith({String? text}) => ConversationMessage(
    id: id,
    chatId: chatId,
    text: text ?? this.text,
    date: date,
    isOutgoing: isOutgoing,
    sender: sender,
    sendState: sendState,
  );
}

/// Holds the loaded text-message timelines for chats, and the names of the
/// people and chats that sent them.
///
/// TDLib sends history and live updates separately. Messages are keyed by
/// their per-chat IDs, so either source can safely replace an earlier value.
final class ConversationStore {
  final _byChat = <int, Map<int, ConversationMessage>>{};
  final _userNames = <int, String>{};
  final _chatTitles = <int, String>{};

  /// Replaces the timeline of [chatId] with [messages], keeping the ones in
  /// [keep] that are still present (messages that arrived while the history
  /// was loading).
  void replaceHistory(
    int chatId,
    List<ConversationMessage> messages, {
    Set<int> keep = const {},
  }) {
    final previous = _byChat[chatId] ?? const {};
    _byChat[chatId] = {
      for (final id in keep) id: ?previous[id],
      for (final message in messages) message.id: message,
    };
  }

  void upsert(ConversationMessage message) {
    (_byChat[message.chatId] ??= {})[message.id] = message;
  }

  void updateText(int chatId, int messageId, String text) {
    final messages = _byChat[chatId];
    final message = messages?[messageId];
    if (message == null) return;
    messages![messageId] = message.copyWith(text: text);
  }

  void remove(int chatId, Iterable<int> messageIds) {
    final messages = _byChat[chatId];
    if (messages == null) return;
    for (final id in messageIds) {
      messages.remove(id);
    }
  }

  List<ConversationMessage> messagesFor(int chatId) {
    final messages = _byChat[chatId]?.values.toList() ?? [];
    messages.sort((a, b) => b.id.compareTo(a.id));
    return List.unmodifiable(messages);
  }

  void setUserName(int userId, String name) => _userNames[userId] = name;

  void setChatTitle(int chatId, String title) => _chatTitles[chatId] = title;

  /// The display name of [sender], or null while TDLib hasn't sent it.
  String? nameOf(MessageSenderId sender) =>
      sender.isChat ? _chatTitles[sender.id] : _userNames[sender.id];
}
