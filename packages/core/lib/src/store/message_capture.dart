import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'message_store.dart';

/// Opens the account's [MessageStore] the first time something is kept.
typedef MessageStoreOpener = Future<MessageStore> Function();

/// Keeps what TDLib forgets: messages deleted for everyone and earlier
/// versions of edited messages, each only while its switch is on. With
/// both switches off it does nothing at all.
///
/// TDLib cannot return a message once it is deleted, so the capture keeps
/// the messages the app has recently seen in memory, per chat: new ones
/// from `updateNewMessage` and loaded ones from any response that carries
/// messages (history, search in a chat, a single message), through
/// [td.TdClient.responses]. Only what is in that memory can be kept.
///
/// Not kept: messages deleted from this app (seen through
/// [td.TdClient.requests]), the user's own messages in private and secret
/// chats (deleted from another of their devices), scheduled messages,
/// messages that delete themselves on a timer, and deletions TDLib makes
/// only in its cache.
final class MessageCapture {
  MessageCapture(
    this._client, {
    this._openStore,
    this._keepDeleted = false,
    this._keepEdits = false,
    DateTime Function()? now,
    this.messagesPerChat = 100,
    this.chats = 100,
    this.retryDelay = const Duration(milliseconds: 500),
  }) : _now = now ?? DateTime.now {
    _subscriptions = [
      _client.updates.listen(_onUpdate),
      _client.responses.listen(_onResponse),
      _client.requests.listen(_onRequest),
    ];
  }

  final td.TdClient _client;
  final MessageStoreOpener? _openStore;
  final DateTime Function() _now;
  late final List<StreamSubscription<Object>> _subscriptions;

  /// How many recent messages are remembered per chat.
  final int messagesPerChat;

  /// How many chats are remembered; the least recently used goes first.
  final int chats;

  /// The wait before writing again after a failed write; it doubles for
  /// the next try.
  final Duration retryDelay;

  /// How long a deletion asked for here covers TDLib's updates for it.
  static const hereWindow = Duration(minutes: 1);

  static const _maxDeletedHere = 1000;
  static const _maxHereRules = 50;
  static const _attempts = 3;

  /// Recently seen messages: chat id → message id → message, both in the
  /// order they were last touched.
  final _recent = <int, Map<int, _Seen>>{};

  /// Content replaced by `updateMessageContent`, until `updateMessageEdited`
  /// says it was an edit (a poll's votes change content without one).
  final _replaced = <(int, int), (td.MessageContent, int)>{};

  /// Messages deleted from this app, oldest first.
  final _deletedHere = <(int, int)>{};

  /// Bulk deletions asked for here: which messages they cover, and when.
  final _hereRules = <(DateTime, bool Function(td.Message))>[];

  final _changes = StreamController<void>.broadcast();
  Future<MessageStore>? _store;
  Future<void> _writing = Future.value();
  Object? _failure;
  bool _keepDeleted;
  bool _keepEdits;
  var _disposed = false;

  /// Keep messages others delete for everyone.
  bool get keepDeleted => _keepDeleted;
  set keepDeleted(bool value) {
    _keepDeleted = value;
    _forgetWhenIdle();
  }

  /// Keep the earlier versions of edited messages.
  bool get keepEdits => _keepEdits;
  set keepEdits(bool value) {
    _keepEdits = value;
    _forgetWhenIdle();
  }

  bool get _active => _keepDeleted || _keepEdits;

  /// Fires after something was written, or a write failed.
  Stream<void> get changes => _changes.stream;

  /// Why the last write failed, until one succeeds; a [StoreKeyLost] here
  /// means the store has to be reset.
  Object? get failure => _failure;

  /// The store, opened on first use; null when there is no way to open
  /// it. A store that failed to open is tried again on the next call.
  Future<MessageStore>? get store {
    final open = _openStore;
    if (open == null || _disposed) return null;
    return _store ??= open()
      ..then<void>((_) {}, onError: (Object _) => _store = null).ignore();
  }

  /// Completes when everything kept so far is written.
  Future<void> flush() => _writing;

  /// Closes the store, such as before its file is deleted; the next write
  /// opens it again.
  Future<void> closeStore() async {
    await _writing;
    await _close();
    _failure = null;
  }

  /// The remembered message, as it is now, or null.
  td.Message? recent(int chatId, int messageId) =>
      _recent[chatId]?[messageId]?.current;

  void _forgetWhenIdle() {
    if (_active) return;
    _recent.clear();
    _replaced.clear();
    _deletedHere.clear();
    _hereRules.clear();
  }

  /// Remembers [message]. A chat that is not remembered yet is only added
  /// when [promote]; so is the chat moved to the front.
  void _remember(td.Message message, {bool promote = true}) {
    var chat = _recent[message.chatId];
    if (chat == null) {
      if (!promote) return;
      chat = _recent[message.chatId] = {};
    } else if (promote) {
      _recent
        ..remove(message.chatId)
        ..[message.chatId] = chat;
    }
    chat
      ..remove(message.id)
      ..[message.id] = _Seen(message);
    while (chat.length > messagesPerChat) {
      final oldest = chat.keys.first;
      chat.remove(oldest);
      _replaced.remove((message.chatId, oldest));
    }
    while (_recent.length > chats) {
      final oldest = _recent.keys.first;
      _recent.remove(oldest);
      _replaced.removeWhere((key, _) => key.$1 == oldest);
    }
  }

  void _onResponse(td.TdObject response) {
    if (!_active) return;
    switch (response) {
      case td.Message():
        _remember(response);
      case td.Messages(:final messages) ||
          td.FoundChatMessages(:final messages):
        messages.forEach(_remember);
      case td.FoundMessages(:final messages):
        // Search across chats: only chats already remembered, so a search
        // does not push out the chats the user has open.
        for (final message in messages) {
          _remember(message, promote: false);
        }
      default:
    }
  }

  void _onRequest(td.TdFunction<td.TdObject> request) {
    if (!_active) return;
    bool Function(td.Message)? rule;
    switch (request) {
      case td.DeleteMessages(:final chatId, :final messageIds):
        for (final id in messageIds) {
          _deletedHere.add((chatId, id));
        }
        while (_deletedHere.length > _maxDeletedHere) {
          _deletedHere.remove(_deletedHere.first);
        }
      case td.DeleteChatHistory(:final chatId) || td.DeleteChat(:final chatId):
        rule = (m) => m.chatId == chatId;
      case td.DeleteChatMessagesBySender(:final chatId, :final senderId):
        final sender = _senderKey(senderId);
        rule = (m) => m.chatId == chatId && _senderKey(m.senderId) == sender;
      case td.DeleteChatMessagesByDate(
        :final chatId,
        :final minDate,
        :final maxDate,
      ):
        rule = (m) => m.chatId == chatId && _within(m, minDate, maxDate);
      case td.DeleteForumTopic(:final chatId, :final forumTopicId):
        rule = (m) =>
            m.chatId == chatId &&
            m.topicId is td.MessageTopicForum &&
            (m.topicId! as td.MessageTopicForum).forumTopicId == forumTopicId;
      case td.DeleteSavedMessagesTopicHistory(:final savedMessagesTopicId):
        rule = (m) => _savedTopic(m) == savedMessagesTopicId;
      case td.DeleteSavedMessagesTopicMessagesByDate(
        :final savedMessagesTopicId,
        :final minDate,
        :final maxDate,
      ):
        rule = (m) =>
            _savedTopic(m) == savedMessagesTopicId &&
            _within(m, minDate, maxDate);
      case td.DeleteDirectMessagesChatTopicHistory(
        :final chatId,
        :final topicId,
      ):
        rule = (m) => m.chatId == chatId && _directTopic(m) == topicId;
      case td.DeleteDirectMessagesChatTopicMessagesByDate(
        :final chatId,
        :final topicId,
        :final minDate,
        :final maxDate,
      ):
        rule = (m) =>
            m.chatId == chatId &&
            _directTopic(m) == topicId &&
            _within(m, minDate, maxDate);
      default:
    }
    if (rule == null) return;
    _hereRules.add((_now(), rule));
    if (_hereRules.length > _maxHereRules) _hereRules.removeAt(0);
  }

  void _onUpdate(td.TdObject update) {
    if (!_active) return;
    switch (update) {
      case td.UpdateNewMessage(:final message):
        _remember(message);
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId) ||
          td.UpdateMessageSendFailed(:final message, :final oldMessageId):
        _recent[message.chatId]?.remove(oldMessageId);
        _replaced.remove((message.chatId, oldMessageId));
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
    final seen = _recent[chatId]?[messageId];
    if (seen == null) return;
    // A content change without an edit (poll votes) is not a version:
    // only the latest content counts as the one an edit replaces.
    _replaced[(chatId, messageId)] = (seen.content, seen.writtenAt);
    seen.content = content;
  }

  void _onEdited(int chatId, int messageId, int editDate) {
    final replaced = _replaced.remove((chatId, messageId));
    final seen = _recent[chatId]?[messageId];
    if (seen == null || replaced == null) return;
    final (content, written) = replaced;
    // The replaced content is the latest content before this edit only
    // when nothing but non-edits changed it since it was written.
    seen.editDate = editDate;
    if (!_keepEdits) return;
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
    final now = _now();
    _hereRules.removeWhere((rule) => now.difference(rule.$1) >= hereWindow);
    final chat = _recent[chatId];
    final kept = <td.Message>[];
    for (final id in messageIds) {
      final seen = chat?.remove(id);
      _replaced.remove((chatId, id));
      final here = _deletedHere.remove((chatId, id));
      if (seen == null || !keep || here || !_keepDeleted) continue;
      final message = seen.current;
      if (_hereRules.any((rule) => rule.$2(message))) continue;
      if (_notKept(message)) continue;
      kept.add(message);
    }
    if (kept.isEmpty) return;
    _write((store) => store.deleted.saveAll(kept, deletedAt: now));
  }

  /// Messages that were meant to go, or that the user deleted elsewhere.
  static bool _notKept(td.Message message) =>
      message.selfDestructType != null ||
      message.autoDeleteIn > 0 ||
      message.schedulingState != null ||
      message.sendingState != null ||
      (message.isOutgoing && _privateOrSecret(message.chatId));

  /// TDLib's chat ids: users (private chats) are positive, secret chats sit
  /// in a range of their own (see TDLib's DialogId).
  static bool _privateOrSecret(int chatId) =>
      chatId > 0 || (chatId >= -2002147483648 && chatId <= -1997852516353);

  static int _senderKey(td.MessageSender sender) => switch (sender) {
    td.MessageSenderUser(:final userId) => userId,
    td.MessageSenderChat(:final chatId) => chatId,
  };

  static bool _within(td.Message m, int minDate, int maxDate) =>
      m.date >= minDate && m.date <= maxDate;

  static int? _savedTopic(td.Message m) => switch (m.topicId) {
    td.MessageTopicSavedMessages(:final savedMessagesTopicId) =>
      savedMessagesTopicId,
    _ => null,
  };

  static int? _directTopic(td.Message m) => switch (m.topicId) {
    td.MessageTopicDirectMessages(:final directMessagesChatTopicId) =>
      directMessagesChatTopicId,
    _ => null,
  };

  void _write(Future<void> Function(MessageStore store) write) {
    if (_openStore == null) return;
    _writing = _writing.then((_) => _attempt(write));
  }

  /// Writes, closing the store and trying again after a failure, up to
  /// three times. A lost key is not retried: it needs a reset.
  Future<void> _attempt(Future<void> Function(MessageStore store) write) async {
    for (var attempt = 0; attempt < _attempts && !_disposed; attempt++) {
      if (attempt > 0) await Future<void>.delayed(retryDelay * (1 << attempt));
      final store = this.store;
      if (store == null) return;
      try {
        await write(await store);
        _failure = null;
        _notify();
        return;
      } on StoreKeyLost catch (error) {
        _failure = error;
        _notify();
        return;
      } on Object catch (error) {
        _failure = error;
        await _close();
      }
    }
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _close() async {
    final store = _store;
    _store = null;
    if (store == null) return;
    try {
      await (await store).close();
    } on Object {
      // Never opened.
    }
  }

  static DateTime _time(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  /// Stops following the client and closes the store.
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _writing;
    _disposed = true;
    await _close();
    await _changes.close();
  }
}

/// A remembered message. Content and edit date follow updates without
/// rebuilding the message; [current] builds it only when it is kept.
final class _Seen {
  _Seen(this.message) : content = message.content, editDate = message.editDate;

  final td.Message message;
  td.MessageContent content;
  int editDate;

  /// When the current content was written: its edit, or the message.
  int get writtenAt => editDate > 0 ? editDate : message.date;

  td.Message get current =>
      identical(content, message.content) && editDate == message.editDate
      ? message
      : td.Message.fromJson({
          ...message.toJson(),
          'content': content.toJson(),
          'edit_date': editDate,
        });
}
