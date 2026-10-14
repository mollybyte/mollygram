import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';

/// Loads and maintains conversation timelines from TDLib.
final class ConversationController {
  ConversationController(this._client, {ConversationStore? store})
    : store = store ?? ConversationStore();

  final td.TdClient _client;
  final ConversationStore store;
  final _changes = StreamController<void>.broadcast(sync: true);

  /// Messages that arrived while a chat's history was loading, by chat.
  final _arrivedDuringLoad = <int, Set<int>>{};

  /// Chats with a page of older history on its way.
  final _loadingOlder = <int>{};

  /// Replied-to messages requested from TDLib, by chat and message id.
  final _requested = <(int, int)>{};
  StreamSubscription<td.TdObject>? _subscription;

  Stream<void> get changes => _changes.stream;

  /// Subscribes to updates. Call it before sign-in, so the user and chat
  /// names TDLib sends early are kept for sender names.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
  }

  /// Loads the newest page of [chatId], replacing what was loaded before.
  ///
  /// TDLib answers the first request from its local database, which may
  /// hold only the last message, so older pages follow until the screen
  /// has [minimum] messages or the chat has no more.
  Future<void> loadHistory(int chatId, {int minimum = 30}) async {
    final arrived = _arrivedDuringLoad[chatId] ??= {};
    final td.Messages response;
    try {
      response = await _client.send(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: 0,
          offset: 0,
          limit: 50,
          onlyLocal: false,
        ),
      );
    } finally {
      _arrivedDuringLoad.remove(chatId);
    }
    // Updates kept coming while the request was in flight; a message they
    // added may be missing from the page, so it is kept.
    store.replaceHistory(chatId, [
      for (final message in response.messages) ConversationMessage(message),
    ], keep: arrived);
    if (response.messages.isEmpty) store.markReachedStart(chatId);
    _changes.add(null);
    while (!store.reachedStart(chatId) &&
        store.messagesFor(chatId).length < minimum) {
      if (!await loadOlder(chatId)) break;
    }
  }

  /// Loads the page before the oldest loaded message. Returns whether it
  /// added anything; false also while another page is on its way.
  Future<bool> loadOlder(int chatId) async {
    final oldest = store.oldestId(chatId);
    if (oldest == null || store.reachedStart(chatId)) return false;
    if (!_loadingOlder.add(chatId)) return false;
    try {
      final response = await _client.send(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: oldest,
          offset: 0,
          limit: 50,
          onlyLocal: false,
        ),
      );
      final added = store.addOlder(chatId, [
        for (final message in response.messages) ConversationMessage(message),
      ]);
      if (added == 0) store.markReachedStart(chatId);
      _changes.add(null);
      return added > 0;
    } finally {
      _loadingOlder.remove(chatId);
    }
  }

  /// Makes sure the message that [messageId] of [chatId] replies to is in
  /// the store, asking TDLib for it when it is outside the loaded timeline.
  /// When TDLib can't find it, the reply is marked as pointing nowhere
  /// ([ConversationStore.isMissing] for the reply's own id).
  Future<void> loadReplied(int chatId, int messageId) async {
    if (!_requested.add((chatId, messageId))) return;
    try {
      final message = await _client.send(
        td.GetRepliedMessage(chatId: chatId, messageId: messageId),
      );
      store.addReferenced(ConversationMessage(message));
    } on td.TdException {
      store.markMissing(chatId, messageId);
    }
    _changes.add(null);
  }

  /// Tells TDLib the user opened a voice or video message, which marks it
  /// as listened to for the sender.
  Future<void> openContent(int chatId, int messageId) async {
    await _client.send(
      td.OpenMessageContent(chatId: chatId, messageId: messageId),
    );
  }

  /// Adds the reaction, or takes it back when [chosen] is true.
  Future<void> toggleReaction(
    int chatId,
    int messageId,
    td.ReactionType reaction, {
    required bool chosen,
  }) async => chosen
      ? await _client.send(
          td.RemoveMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: reaction,
          ),
        )
      : await _client.send(
          td.AddMessageReaction(
            chatId: chatId,
            messageId: messageId,
            reactionType: reaction,
            isBig: false,
            updateRecentReactions: true,
          ),
        );

  /// Tells TDLib the chat is on screen. Supergroups and channels get all
  /// their updates only while open.
  Future<void> openChat(int chatId) async {
    await _client.send(td.OpenChat(chatId: chatId));
  }

  /// Tells TDLib the chat is no longer on screen.
  Future<void> closeChat(int chatId) async {
    await _client.send(td.CloseChat(chatId: chatId));
  }

  /// Marks messages the user has seen as read. TDLib clears the unread count
  /// and sends read receipts from this.
  Future<void> viewMessages(int chatId, List<int> messageIds) async {
    if (messageIds.isEmpty) return;
    await _client.send(
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
        final sender = MessageSenderId.user(user.id);
        store
          ..setUserName(user.id, _nameOf(user))
          ..setColor(sender, user.accentColorId)
          ..setPhoto(sender, user.profilePhoto?.small);
      case td.UpdateNewChat(:final chat):
        store
          ..setChatTitle(chat.id, chat.title)
          ..setColor(MessageSenderId.chat(chat.id), chat.accentColorId)
          ..setPhoto(MessageSenderId.chat(chat.id), chat.photo?.small)
          ..setReadInbox(chat.id, chat.lastReadInboxMessageId)
          ..setReadOutbox(chat.id, chat.lastReadOutboxMessageId)
          ..setChannel(chat.id, switch (chat.type) {
            td.ChatTypeSupergroup(:final isChannel) => isChannel,
            _ => false,
          });
      case td.UpdateChatReadInbox(:final chatId, :final lastReadInboxMessageId):
        store.setReadInbox(chatId, lastReadInboxMessageId);
        _changes.add(null);
      case td.UpdateChatReadOutbox(
        :final chatId,
        :final lastReadOutboxMessageId,
      ):
        store.setReadOutbox(chatId, lastReadOutboxMessageId);
        _changes.add(null);
      case td.UpdateChatTitle(:final chatId, :final title):
        store.setChatTitle(chatId, title);
      case td.UpdateChatPhoto(:final chatId, :final photo):
        store.setPhoto(MessageSenderId.chat(chatId), photo?.small);
      case td.UpdateChatAccentColors(:final chatId, :final accentColorId):
        store.setColor(MessageSenderId.chat(chatId), accentColorId);
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
        _patch(chatId, messageId, {'content': newContent.toJson()});
      case td.UpdateMessageEdited(
        :final chatId,
        :final messageId,
        :final editDate,
        :final replyMarkup,
      ):
        _patch(chatId, messageId, {
          'edit_date': editDate,
          'reply_markup': replyMarkup?.toJson(),
        });
      case td.UpdateMessageInteractionInfo(
        :final chatId,
        :final messageId,
        :final interactionInfo,
      ):
        _patch(chatId, messageId, {
          'interaction_info': interactionInfo?.toJson(),
        });
      case td.UpdateMessageIsPinned(
        :final chatId,
        :final messageId,
        :final isPinned,
      ):
        _patch(chatId, messageId, {'is_pinned': isPinned});
      case td.UpdateMessageContentOpened(:final chatId, :final messageId):
        final content = store.message(chatId, messageId)?.content;
        final opened = switch (content) {
          td.MessageVoiceNote() => {...content.toJson(), 'is_listened': true},
          td.MessageVideoNote() => {...content.toJson(), 'is_viewed': true},
          _ => null,
        };
        if (opened != null) _patch(chatId, messageId, {'content': opened});
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
    store.upsert(ConversationMessage(message));
    _changes.add(null);
  }

  void _patch(int chatId, int messageId, Map<String, Object?> fields) {
    if (store.patch(chatId, messageId, fields)) _changes.add(null);
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');
