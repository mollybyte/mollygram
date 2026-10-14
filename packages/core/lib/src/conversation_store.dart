/// A presentation-ready message retained in a single conversation timeline.
final class ConversationMessage {
  const ConversationMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.date,
    required this.isOutgoing,
  });

  final int id;
  final int chatId;
  final String text;
  final int date;
  final bool isOutgoing;
}

/// Holds the loaded text-message timelines for chats.
///
/// TDLib sends history and live updates separately. Messages are keyed by
/// their per-chat IDs, so either source can safely replace an earlier value.
final class ConversationStore {
  final _byChat = <int, Map<int, ConversationMessage>>{};

  void replaceHistory(int chatId, List<ConversationMessage> messages) {
    _byChat[chatId] = {for (final message in messages) message.id: message};
  }

  void upsert(ConversationMessage message) {
    (_byChat[message.chatId] ??= {})[message.id] = message;
  }

  void updateText(int chatId, int messageId, String text) {
    final messages = _byChat[chatId];
    final message = messages?[messageId];
    if (message == null) return;
    messages![messageId] = ConversationMessage(
      id: message.id,
      chatId: message.chatId,
      text: text,
      date: message.date,
      isOutgoing: message.isOutgoing,
    );
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
}
