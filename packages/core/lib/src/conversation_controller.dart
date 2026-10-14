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
  StreamSubscription<td.TdObject>? _subscription;

  Stream<void> get changes => _changes.stream;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
  }

  Future<void> loadHistory(int chatId, {int fromMessageId = 0}) async {
    final response = await _client.send(
      td.GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: 100,
        onlyLocal: false,
      ),
    );
    store.replaceHistory(chatId, [
      for (final message in response.messages) ?_textMessageFrom(message),
    ]);
    _changes.add(null);
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
      case td.UpdateNewMessage(:final message):
        _add(message);
      // A sent message first arrives with a temporary id; TDLib then replaces
      // it with the server one, so the pending copy must go.
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId):
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
      case td.UpdateDeleteMessages(
        :final chatId,
        :final messageIds,
        :final isPermanent,
      ):
        if (!isPermanent) return;
        store.remove(chatId, messageIds);
        _changes.add(null);
      default:
        return;
    }
  }

  void _add(td.Message message) {
    final text = _textMessageFrom(message);
    if (text == null) return;
    store.upsert(text);
    _changes.add(null);
  }
}

ConversationMessage? _textMessageFrom(td.Message message) {
  final content = message.content;
  if (content is! td.MessageText) return null;
  return ConversationMessage(
    id: message.id,
    chatId: message.chatId,
    text: content.text.text,
    date: message.date,
    isOutgoing: message.isOutgoing,
  );
}
