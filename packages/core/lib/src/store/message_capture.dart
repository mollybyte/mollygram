import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'message_store.dart';

/// Opens the account's [MessageStore] the first time something is kept.
typedef MessageStoreOpener = Future<MessageStore> Function();

/// Keeps what TDLib forgets: messages deleted for everyone and earlier
/// versions of edited messages, each only while its switch is on.
///
/// TDLib cannot return a message once it is deleted, so the capture keeps
/// the messages the app has recently seen in memory, per chat: new ones
/// from `updateNewMessage` and loaded ones from any response that carries
/// messages (history, search, a single message), through
/// [td.TdClient.responses]. Only what is in that memory can be kept.
///
/// Not kept: messages deleted from this app (seen through
/// [td.TdClient.requests]), messages that delete themselves on a timer,
/// and deletions TDLib makes only in its cache.
final class MessageCapture {
  MessageCapture(
    this._client, {
    MessageStoreOpener? openStore,
    this.keepDeleted = false,
    this.keepEdits = false,
    DateTime Function()? now,
    this.messagesPerChat = 300,
    this.chats = 100,
  }) : _now = now ?? DateTime.now {
    _openStore = openStore;
    _subscriptions = [
      _client.updates.listen(_onUpdate),
      _client.responses.listen(_onResponse),
      _client.requests.listen(_onRequest),
    ];
  }

  final td.TdClient _client;
  final DateTime Function() _now;
  late final List<StreamSubscription<Object>> _subscriptions;

  /// How many recent messages are remembered per chat.
  final int messagesPerChat;

  /// How many chats are remembered; the least recently used goes first.
  final int chats;

  /// Recently seen messages: chat id → message id → message, both in the
  /// order they were last touched.
  final _recent = <int, Map<int, td.Message>>{};

  /// Content replaced by `updateMessageContent`, until `updateMessageEdited`
  /// says it was an edit (a poll's votes change content without one).
  final _replaced = <(int, int), (td.MessageContent, int)>{};

  /// Messages deleted from this app, and chats cleared from it with the
  /// time, so TDLib's updates for them are not kept as deleted by others.
  final _deletedHere = <(int, int)>{};
  final _clearedHere = <int, DateTime>{};

  MessageStoreOpener? _openStore;
  Future<MessageStore>? _store;
  Future<void> _writing = Future.value();

  /// Keep messages others delete for everyone.
  bool keepDeleted;

  /// Keep the earlier versions of edited messages.
  bool keepEdits;

  /// Sets how the store is opened, such as once the app knows the
  /// account's folder and key.
  set openStore(MessageStoreOpener? value) {
    _openStore = value;
    _store = null;
  }

  /// The store, opened on first use; null when there is no way to open it.
  Future<MessageStore>? get store {
    final open = _openStore;
    if (open == null) return null;
    return _store ??= open()..ignore();
  }

  /// Completes when everything kept so far is written.
  Future<void> flush() => _writing;

  /// The remembered message, or null.
  td.Message? recent(int chatId, int messageId) => _recent[chatId]?[messageId];

  void _remember(td.Message message) {
    final chat = _recent.remove(message.chatId) ?? <int, td.Message>{};
    _recent[message.chatId] = chat;
    chat
      ..remove(message.id)
      ..[message.id] = message;
    while (chat.length > messagesPerChat) {
      chat.remove(chat.keys.first);
    }
    while (_recent.length > chats) {
      _recent.remove(_recent.keys.first);
    }
  }

  void _onResponse(td.TdObject response) {
    switch (response) {
      case td.Message():
        _remember(response);
      case td.Messages(:final messages) ||
          td.FoundChatMessages(:final messages) ||
          td.FoundMessages(:final messages):
        messages.forEach(_remember);
      default:
    }
  }

  void _onRequest(td.TdFunction<td.TdObject> request) {
    switch (request) {
      case td.DeleteMessages(:final chatId, :final messageIds):
        for (final id in messageIds) {
          _deletedHere.add((chatId, id));
        }
      case td.DeleteChatHistory(:final chatId) ||
          td.DeleteChat(:final chatId) ||
          td.DeleteChatMessagesBySender(:final chatId) ||
          td.DeleteChatMessagesByDate(:final chatId):
        _clearedHere[chatId] = _now();
      default:
    }
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateNewMessage(:final message):
        _remember(message);
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId):
        _recent[message.chatId]?.remove(oldMessageId);
        _remember(message);
      case td.UpdateMessageContent(
        :final chatId,
        :final messageId,
        :final newContent,
      ):
        _onContent(chatId, messageId, newContent);
      case td.UpdateMessageEdited(
        :final chatId,
        :final messageId,
        :final editDate,
      ):
        _onEdited(chatId, messageId, editDate);
      case td.UpdateDeleteMessages(
        :final chatId,
        :final messageIds,
        :final isPermanent,
        :final fromCache,
      ):
        _onDeleted(chatId, messageIds, keep: isPermanent && !fromCache);
      default:
    }
  }

  void _onContent(int chatId, int messageId, td.MessageContent content) {
    final old = recent(chatId, messageId);
    if (old == null) return;
    final written = old.editDate > 0 ? old.editDate : old.date;
    // The first content of a run of changes is the one the edit replaced.
    _replaced.putIfAbsent((chatId, messageId), () => (old.content, written));
    _remember(_with(old, content: content));
  }

  void _onEdited(int chatId, int messageId, int editDate) {
    final replaced = _replaced.remove((chatId, messageId));
    final message = recent(chatId, messageId);
    if (message != null) _remember(_with(message, editDate: editDate));
    if (replaced == null || !keepEdits) return;
    final (content, written) = replaced;
    _write(
      (store) => store.edits.save(
        chatId: chatId,
        messageId: messageId,
        content: content,
        date: _time(written),
        replacedAt: _time(editDate),
      ),
    );
  }

  void _onDeleted(int chatId, List<int> messageIds, {required bool keep}) {
    final cleared = _clearedHere[chatId];
    final clearedHere =
        cleared != null &&
        _now().difference(cleared) < const Duration(minutes: 1);
    if (cleared != null && !clearedHere) _clearedHere.remove(chatId);
    final chat = _recent[chatId];
    for (final id in messageIds) {
      final message = chat?.remove(id);
      _replaced.remove((chatId, id));
      final here = _deletedHere.remove((chatId, id)) || clearedHere;
      if (message == null || !keep || here || !keepDeleted) continue;
      if (_deletesItself(message)) continue;
      final deletedAt = _now();
      _write((store) => store.deleted.save(message, deletedAt: deletedAt));
    }
  }

  /// Self-destructing and auto-deleting messages were meant to go.
  static bool _deletesItself(td.Message message) =>
      message.selfDestructType != null || message.autoDeleteIn > 0;

  void _write(Future<void> Function(MessageStore store) write) {
    final store = this.store;
    if (store == null) return;
    _writing = _writing.then((_) async {
      try {
        await write(await store);
      } on Object {
        // A store that can't be opened or written loses this message;
        // the next one tries again.
        _store = null;
      }
    });
  }

  static DateTime _time(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  static td.Message _with(
    td.Message message, {
    td.MessageContent? content,
    int? editDate,
  }) => td.Message.fromJson({
    ...message.toJson(),
    'content': ?content?.toJson(),
    'edit_date': ?editDate,
  });

  /// Stops following the client and closes the store.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _writing;
    final store = _store;
    _store = null;
    if (store != null) {
      try {
        await (await store).close();
      } on Object {
        // Never opened.
      }
    }
  }
}
