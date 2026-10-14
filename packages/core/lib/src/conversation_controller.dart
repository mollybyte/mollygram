import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';

/// Loads and maintains text-message timelines from TDLib.
///
/// Media messages are deliberately ignored here; their specialized rendering
/// and upload/download lifecycle belong to the media stage.
final class ConversationController {
  ConversationController(this._client, {ConversationStore? store})
    : store = store ?? ConversationStore();

  final td.TdClient _client;
  final ConversationStore store;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Messages that arrived while a chat's history was loading, by chat.
  final _arrivedDuringLoad = <int, Set<int>>{};
  StreamSubscription<td.TdObject>? _subscription;

  Stream<void> get changes => _changes.stream;

  /// Subscribes to updates. Call it before sign-in, so the user and chat
  /// names TDLib sends early are kept for sender names.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
  }

  Future<void> loadHistory(int chatId, {int fromMessageId = 0}) async {
    final arrived = _arrivedDuringLoad[chatId] ??= {};
    final td.Messages response;
    try {
      response = await _client.send(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: fromMessageId,
          offset: 0,
          limit: 100,
          onlyLocal: false,
        ),
      );
    } finally {
      _arrivedDuringLoad.remove(chatId);
    }
    // Updates kept coming while the request was in flight; a message they
    // added may be missing from the page, so it is kept.
    store.replaceHistory(chatId, [
      for (final message in response.messages) ?_textMessageFrom(message),
    ], keep: arrived);
    _changes.add(null);
  }

  /// Tells TDLib the chat is on screen. Supergroups and channels get all
  /// their updates only while open.
  Future<void> openChat(int chatId) =>
      _client.send(td.OpenChat(chatId: chatId));

  /// Tells TDLib the chat is no longer on screen.
  Future<void> closeChat(int chatId) =>
      _client.send(td.CloseChat(chatId: chatId));

  /// Marks messages the user has seen as read. TDLib clears the unread count
  /// and sends read receipts from this.
  Future<void> viewMessages(int chatId, List<int> messageIds) {
    if (messageIds.isEmpty) return Future.value();
    return _client.send(
      td.ViewMessages(
        chatId: chatId,
        messageIds: messageIds,
        source: const td.MessageSourceChatHistory(),
        forceRead: false,
      ),
    );
  }

  Future<void> sendText(int chatId, String text) async {
    if (text.trim().isEmpty) {
      throw ArgumentError.value(
        text,
        'text',
        'Message text must not be empty.',
      );
    }
    final message = await _client.send(
      td.SendMessage(
        chatId: chatId,
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: const []),
          clearDraft: true,
        ),
      ),
    );
    _add(message);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      case td.UpdateUser(:final user):
        store.setUserName(user.id, _nameOf(user));
      case td.UpdateNewChat(:final chat):
        store.setChatTitle(chat.id, chat.title);
      case td.UpdateChatTitle(:final chatId, :final title):
        store.setChatTitle(chatId, title);
      case td.UpdateNewMessage(:final message):
        _add(message);
      // A sent message first arrives with a temporary id; TDLib then replaces
      // it with the server one, so the pending copy must go. A rejected
      // message comes back the same way, marked as failed.
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId):
      case td.UpdateMessageSendFailed(:final message, :final oldMessageId):
        store.remove(message.chatId, [oldMessageId]);
        _add(message);
      case td.UpdateMessageContent(
        :final chatId,
        :final messageId,
        :final newContent,
      ):
        if (newContent is td.MessageText) {
          store.updateText(chatId, messageId, newContent.text.text);
          _changes.add(null);
        }
      // Not permanent means the messages became inaccessible, which hides
      // them all the same. Only an eviction from TDLib's cache leaves them,
      // since they still exist and the open timeline keeps its copy.
      case td.UpdateDeleteMessages(
        :final chatId,
        :final messageIds,
        :final fromCache,
      ):
        if (fromCache) return;
        store.remove(chatId, messageIds);
        _changes.add(null);
      default:
        return;
    }
  }

  void _add(td.Message message) {
    final text = _textMessageFrom(message);
    if (text == null) return;
    _arrivedDuringLoad[message.chatId]?.add(message.id);
    store.upsert(text);
    _changes.add(null);
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');

ConversationMessage? _textMessageFrom(td.Message message) {
  final content = message.content;
  if (content is! td.MessageText) return null;
  return ConversationMessage(
    id: message.id,
    chatId: message.chatId,
    text: content.text.text,
    date: message.date,
    isOutgoing: message.isOutgoing,
    sender: switch (message.senderId) {
      td.MessageSenderUser(:final userId) => MessageSenderId.user(userId),
      td.MessageSenderChat(:final chatId) => MessageSenderId.chat(chatId),
    },
    sendState: switch (message.sendingState) {
      td.MessageSendingStatePending() => MessageSendState.pending,
      td.MessageSendingStateFailed() => MessageSendState.failed,
      null => MessageSendState.sent,
    },
  );
}
