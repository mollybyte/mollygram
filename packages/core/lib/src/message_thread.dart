import 'dart:async';
import 'dart:collection';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';
import 'outgoing_file.dart';

/// Sends [files] into [chatId], the way the conversation controller does.
typedef FileSender = Future<List<td.Message>> Function(
  int chatId,
  List<OutgoingFile> files, {
  String caption,
  List<td.TextEntity> captionEntities,
  int? replyTo,
  int? threadId,
});

/// The comments under a channel post, or the replies to a message in a
/// group: the discussion chat, the thread's root and the messages under
/// it, kept current from TDLib's updates while the thread is open.
///
/// Made by `ConversationController.openThread`, which feeds it updates
/// until [dispose].
final class MessageThread {
  MessageThread(
    this._client,
    this._store, {
    required this.chatId,
    required this.threadId,
    required List<td.Message> roots,
    required this._replyCount,
    required this._onDispose,
    required this._sendFiles,
  }) {
    for (final root in roots) {
      final message = ConversationMessage(root);
      _messages[root.id] = message;
      _store.addReferenced(message);
    }
  }

  final td.TdClient _client;
  final ConversationStore _store;

  /// The chat the thread lives in: the channel's discussion group for a
  /// post, the group itself for a reply thread.
  final int chatId;

  /// The id of the thread's root in [chatId].
  final int threadId;

  final void Function(MessageThread) _onDispose;
  final FileSender _sendFiles;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Newest first, the root included.
  final _messages = SplayTreeMap<int, ConversationMessage>(
    (a, b) => b.compareTo(a),
  );
  int _replyCount;
  var _reachedStart = false;
  var _loadingOlder = false;
  var _disposed = false;

  Stream<void> get changes => _changes.stream;

  /// The root and the comments under it, newest first.
  List<ConversationMessage> get messages => List.unmodifiable(_messages.values);

  /// How many comments the thread has, as TDLib counts them.
  int get replyCount => _replyCount;

  bool get reachedStart => _reachedStart;

  /// Loads the newest page of comments.
  Future<void> load() async {
    final page = await _client.send(
      td.GetMessageThreadHistory(
        chatId: chatId,
        messageId: threadId,
        fromMessageId: 0,
        offset: 0,
        limit: 50,
      ),
    );
    if (_disposed) return;
    _addAll(page.messages);
    if (page.messages.length < 50) _reachedStart = true;
    _notify();
  }

  /// Loads the page before the oldest comment loaded, once.
  Future<void> loadOlder() async {
    if (_reachedStart || _loadingOlder) return;
    final oldest = _messages.keys.where((id) => id != threadId).lastOrNull;
    if (oldest == null) return;
    _loadingOlder = true;
    try {
      final page = await _client.send(
        td.GetMessageThreadHistory(
          chatId: chatId,
          messageId: threadId,
          fromMessageId: oldest,
          offset: 0,
          limit: 50,
        ),
      );
      if (_disposed) return;
      _addAll(page.messages);
      if (page.messages.isEmpty) _reachedStart = true;
      _notify();
    } finally {
      _loadingOlder = false;
    }
  }

  /// Sends [text] into the thread: as a reply to its root, or to the
  /// comment [replyTo], quoting [quote] of its text at [quotePosition]
  /// when one is given.
  Future<void> send(
    String text, {
    List<td.TextEntity> entities = const [],
    int? replyTo,
    String? quote,
    int quotePosition = 0,
  }) async {
    final message = await _client.send(
      td.SendMessage(
        chatId: chatId,
        topicId: td.MessageTopicThread(messageThreadId: threadId),
        replyTo: td.InputMessageReplyToMessage(
          messageId: replyTo ?? threadId,
          quote: quote == null || quote.isEmpty
              ? null
              : td.InputTextQuote(
                  text: td.FormattedText(text: quote, entities: const []),
                  position: quotePosition,
                ),
          checklistTaskId: 0,
          pollOptionId: '',
        ),
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: entities),
          clearDraft: false,
        ),
      ),
    );
    if (_disposed) return;
    _add(message);
    _notify();
  }

  /// Sends [files] into the thread, with [caption] on the first one, as
  /// a reply to the comment [replyTo] or to the root.
  Future<void> sendFiles(
    List<OutgoingFile> files, {
    String caption = '',
    List<td.TextEntity> captionEntities = const [],
    int? replyTo,
  }) async {
    final sent = await _sendFiles(
      chatId,
      files,
      caption: caption,
      captionEntities: captionEntities,
      replyTo: replyTo ?? threadId,
      threadId: threadId,
    );
    if (_disposed) return;
    sent.forEach(_add);
    _notify();
  }

  /// Marks comments [ids] as seen.
  Future<void> view(List<int> ids) => _client.send(
    td.ViewMessages(
      chatId: chatId,
      messageIds: ids,
      source: const td.MessageSourceMessageThreadHistory(),
      forceRead: false,
    ),
  );

  /// Applies a TDLib update to the thread's messages.
  void handle(td.TdObject update) {
    switch (update) {
      case td.UpdateNewMessage(:final message) when _inThread(message):
        _add(message);
        _replyCount++;
        _notify();
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId)
          when message.chatId == chatId:
      case td.UpdateMessageSendFailed(:final message, :final oldMessageId)
          when message.chatId == chatId:
        if (_messages.remove(oldMessageId) == null) return;
        _add(message);
        _notify();
      case td.UpdateMessageContent(
            :final chatId,
            :final messageId,
            :final newContent,
          )
          when chatId == this.chatId:
        _patch(messageId, {'content': newContent.toJson()});
      case td.UpdateMessageEdited(
            :final chatId,
            :final messageId,
            :final editDate,
            :final replyMarkup,
          )
          when chatId == this.chatId:
        _patch(messageId, {
          'edit_date': editDate,
          'reply_markup': replyMarkup?.toJson(),
        });
      case td.UpdateMessageInteractionInfo(
            :final chatId,
            :final messageId,
            :final interactionInfo,
          )
          when chatId == this.chatId:
        _patch(messageId, {'interaction_info': interactionInfo?.toJson()});
      case td.UpdateDeleteMessages(
            :final chatId,
            :final messageIds,
            :final isPermanent,
          )
          when chatId == this.chatId && isPermanent:
        var removed = 0;
        for (final id in messageIds) {
          if (id != threadId && _messages.remove(id) != null) removed++;
        }
        if (removed == 0) return;
        _replyCount -= removed;
        _notify();
    }
  }

  bool _inThread(td.Message message) =>
      message.chatId == chatId &&
      message.id != threadId &&
      switch (message.topicId) {
        td.MessageTopicThread(:final messageThreadId) =>
          messageThreadId == threadId,
        _ => false,
      };

  void _addAll(List<td.Message> messages) {
    for (final message in messages) {
      _add(message);
    }
  }

  void _add(td.Message message) {
    final conversation = ConversationMessage(message);
    _messages[message.id] = conversation;
    // Replies within the thread quote each other; the store resolves them.
    _store.addReferenced(conversation);
  }

  void _patch(int messageId, Map<String, Object?> fields) {
    final current = _messages[messageId];
    if (current == null) return;
    _add(td.Message.fromJson({...current.message.toJson(), ...fields}));
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Stops following updates; the thread is no longer shown.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose(this);
    unawaited(_changes.close());
  }
}
