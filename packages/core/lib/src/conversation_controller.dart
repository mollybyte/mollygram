import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';
import 'message_content.dart';

/// Loads and maintains message timelines from TDLib.
///
/// Media is kept as its kind and caption only; its rendering and
/// upload/download lifecycle belong to the media stage.
final class ConversationController {
  ConversationController(this._client, {ConversationStore? store})
    : store = store ?? ConversationStore();

  final td.TdClient _client;
  final ConversationStore store;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Messages that arrived while a chat's history was loading, by chat.
  final _arrivedDuringLoad = <int, Set<int>>{};

  /// The oldest message id loaded per chat, and chats whose history ended.
  final _oldestLoaded = <int, int>{};
  final _historyEnd = <int>{};
  final _loadingOlder = <int, Future<void>>{};
  StreamSubscription<td.TdObject>? _subscription;

  Stream<void> get changes => _changes.stream;

  /// Subscribes to updates. Call it before sign-in, so the user and chat
  /// names TDLib sends early are kept for sender names.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
  }

  /// Loads the newest messages of [chatId], replacing what was loaded.
  ///
  /// TDLib often answers the first request with only a message or two
  /// while it fetches the rest, so older pages are asked for until the
  /// screen has [fill] messages or the history ends.
  Future<void> loadHistory(int chatId, {int fill = 40}) async {
    _oldestLoaded.remove(chatId);
    _historyEnd.remove(chatId);
    final arrived = _arrivedDuringLoad[chatId] ??= {};
    final List<td.Message> page;
    try {
      page = await _historyPage(chatId, fromMessageId: 0);
    } finally {
      _arrivedDuringLoad.remove(chatId);
    }
    // Updates kept coming while the request was in flight; a message they
    // added may be missing from the page, so it is kept.
    store.replaceHistory(chatId, [
      for (final message in page) _messageFrom(message),
    ], keep: arrived);
    _changes.add(null);
    // A few pages at most, so a slow server doesn't keep the chat loading.
    for (var i = 0; i < 5; i++) {
      if (!hasOlder(chatId) || store.messagesFor(chatId).length >= fill) break;
      await loadOlder(chatId);
    }
  }

  /// Whether TDLib may have messages older than the loaded ones.
  bool hasOlder(int chatId) => !_historyEnd.contains(chatId);

  /// Loads the page before the oldest loaded message. Calls made while a
  /// page is loading share it.
  Future<void> loadOlder(int chatId) {
    if (!hasOlder(chatId)) return Future.value();
    return _loadingOlder[chatId] ??= _loadOlderPage(chatId).whenComplete(() {
      _loadingOlder.remove(chatId);
    });
  }

  Future<void> _loadOlderPage(int chatId) async {
    final oldest = _oldestLoaded[chatId];
    if (oldest == null) return;
    final page = await _historyPage(chatId, fromMessageId: oldest);
    for (final message in page) {
      store.upsert(_messageFrom(message));
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// One `getChatHistory` page; tracks the oldest message seen (of any
  /// kind, so pages of media don't stall paging) and the end of history.
  Future<List<td.Message>> _historyPage(
    int chatId, {
    required int fromMessageId,
  }) async {
    final response = await _client.send(
      td.GetChatHistory(
        chatId: chatId,
        fromMessageId: fromMessageId,
        offset: 0,
        limit: 100,
        onlyLocal: false,
      ),
    );
    final messages = response.messages;
    var oldest = _oldestLoaded[chatId];
    final before = oldest;
    for (final message in messages) {
      if (oldest == null || message.id < oldest) oldest = message.id;
    }
    // An empty page, or one with nothing older, means the history ended.
    if (oldest == null || oldest == before) {
      _historyEnd.add(chatId);
    } else {
      _oldestLoaded[chatId] = oldest;
    }
    return messages;
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
      // Sender names on screen follow renames. updateUser also comes for
      // status and other changes, so only a new name is announced.
      case td.UpdateUser(:final user):
        if (store.setUserName(user.id, _nameOf(user))) _changes.add(null);
      case td.UpdateNewChat(:final chat):
        if (store.setChatTitle(chat.id, chat.title)) _changes.add(null);
      case td.UpdateChatTitle(:final chatId, :final title):
        if (store.setChatTitle(chatId, title)) _changes.add(null);
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
        final (kind, text) = summarizeContent(newContent);
        store.updateContent(chatId, messageId, kind, text);
        _changes.add(null);
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
    _arrivedDuringLoad[message.chatId]?.add(message.id);
    store.upsert(_messageFrom(message));
    _changes.add(null);
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');

ConversationMessage _messageFrom(td.Message message) {
  final (kind, text) = summarizeContent(message.content);
  return ConversationMessage(
    id: message.id,
    chatId: message.chatId,
    kind: kind,
    text: text,
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
