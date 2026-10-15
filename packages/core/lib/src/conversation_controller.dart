import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';
import 'outgoing_file.dart';
import 'text_edit.dart';

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
    _notify();
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
      _notify();
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
    } on td.TdException catch (error) {
      if (error.code == 404) {
        store.markMissing(chatId, messageId);
      } else {
        // A network error or a flood wait: let a later build ask again.
        _requested.remove((chatId, messageId));
        return;
      }
    }
    _notify();
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

  /// Sends [text], as a reply to [replyTo] when it is set.
  Future<void> sendText(int chatId, String text, {int? replyTo}) async {
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
        replyTo: replyTo == null
            ? null
            : td.InputMessageReplyToMessage(
                messageId: replyTo,
                checklistTaskId: 0,
                pollOptionId: '',
              ),
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: const []),
          clearDraft: true,
        ),
      ),
    );
    _add(message);
  }

  /// Photos and videos of a chat around [fromMessageId], for the media
  /// viewer: up to [newer] after it, the message itself when it is one,
  /// and older ones up to [limit] in all. Oldest first.
  Future<List<ConversationMessage>> mediaAround(
    int chatId,
    int fromMessageId, {
    int newer = 0,
    int limit = 30,
  }) async {
    final found = await _client.send(
      td.SearchChatMessages(
        chatId: chatId,
        query: '',
        fromMessageId: fromMessageId,
        offset: -newer,
        limit: limit,
        filter: const td.SearchMessagesFilterPhotoAndVideo(),
      ),
    );
    return [
      for (final message in found.messages.reversed)
        ConversationMessage(message),
    ];
  }

  /// Sends [sticker] on its own, as a reply to [replyTo] when given.
  /// TDLib moves it to the front of the recent stickers.
  Future<void> sendSticker(
    int chatId,
    td.Sticker sticker, {
    int? replyTo,
  }) async {
    _add(
      await _client.send(
        td.SendMessage(
          chatId: chatId,
          replyTo: replyTo == null
              ? null
              : td.InputMessageReplyToMessage(
                  messageId: replyTo,
                  checklistTaskId: 0,
                  pollOptionId: '',
                ),
          inputMessageContent: td.InputMessageSticker(
            sticker: td.InputSticker(
              sticker: td.InputFileId(id: sticker.sticker.id),
              width: sticker.width,
              height: sticker.height,
            ),
            emoji: sticker.emoji,
          ),
        ),
      ),
    );
  }

  int? _captionMax;

  /// The longest caption the server takes, 1024 when TDLib can't say.
  Future<int> _captionLimit() async {
    if (_captionMax case final max?) return max;
    try {
      final option = await _client.send(
        const td.GetOption(name: 'message_caption_length_max'),
      );
      if (option is td.OptionValueInteger && option.value > 0) {
        return _captionMax = option.value;
      }
    } on Object {
      // Fall through to the default.
    }
    return 1024;
  }

  /// Sends local files, grouped into albums as [groupForSending] does.
  /// [caption] goes under the first file, and the first message answers
  /// [replyTo] when it is set.
  Future<void> sendFiles(
    int chatId,
    List<OutgoingFile> files, {
    String caption = '',
    int? replyTo,
  }) async {
    // A caption longer than the server takes goes first as its own
    // message, as the official apps do.
    if (caption.trim().isNotEmpty && caption.length > await _captionLimit()) {
      await sendText(chatId, caption, replyTo: replyTo);
      caption = '';
      replyTo = null;
    }
    var first = true;
    for (final group in groupForSending(files)) {
      final reply = first && replyTo != null
          ? td.InputMessageReplyToMessage(
              messageId: replyTo,
              checklistTaskId: 0,
              pollOptionId: '',
            )
          : null;
      final contents = [
        for (final (i, file) in group.indexed)
          inputContentOf(
            file,
            caption: first && i == 0 && caption.trim().isNotEmpty
                ? td.FormattedText(text: caption, entities: const [])
                : null,
          ),
      ];
      first = false;
      if (contents.length == 1) {
        _add(
          await _client.send(
            td.SendMessage(
              chatId: chatId,
              replyTo: reply,
              inputMessageContent: contents.single,
            ),
          ),
        );
      } else {
        final sent = await _client.send(
          td.SendMessageAlbum(
            chatId: chatId,
            replyTo: reply,
            inputMessageContents: contents,
          ),
        );
        sent.messages.forEach(_add);
      }
    }
  }

  /// Replaces the text of a text message, or the caption of a media one,
  /// keeping the formatting of the parts that did not change. The new
  /// version arrives through updateMessageContent.
  Future<void> editText(int chatId, int messageId, String text) async {
    final content = store.message(chatId, messageId)?.content;
    final current = content == null ? null : captionOf(content);
    final formatted = td.FormattedText(
      text: text,
      entities: current == null
          ? const []
          : carryEntities(current.text, text, current.entities),
    );
    if (content == null || content is td.MessageText) {
      await _client.send(
        td.EditMessageText(
          chatId: chatId,
          messageId: messageId,
          inputMessageContent: td.InputMessageText(
            text: formatted,
            linkPreviewOptions: switch (content) {
              td.MessageText(:final linkPreviewOptions) => linkPreviewOptions,
              _ => null,
            },
            clearDraft: false,
          ),
        ),
      );
    } else {
      await _client.send(
        td.EditMessageCaption(
          chatId: chatId,
          messageId: messageId,
          caption: formatted,
          showCaptionAboveMedia: switch (content) {
            td.MessagePhoto(:final showCaptionAboveMedia) ||
            td.MessageVideo(:final showCaptionAboveMedia) ||
            td.MessageAnimation(
              :final showCaptionAboveMedia,
            ) => showCaptionAboveMedia,
            _ => false,
          },
        ),
      );
    }
  }

  /// Deletes messages for the user, and for everyone when [revoke] is set.
  /// They leave the timeline through updateDeleteMessages.
  Future<void> deleteMessages(
    int chatId,
    List<int> messageIds, {
    required bool revoke,
  }) async {
    if (messageIds.isEmpty) return;
    await _client.send(
      td.DeleteMessages(chatId: chatId, messageIds: messageIds, revoke: revoke),
    );
  }

  /// Forwards messages of [fromChatId] to [toChatId].
  Future<void> forwardMessages(
    int toChatId,
    int fromChatId,
    List<int> messageIds,
  ) async {
    if (messageIds.isEmpty) return;
    await _client.send(
      td.ForwardMessages(
        chatId: toChatId,
        fromChatId: fromChatId,
        messageIds: messageIds,
        sendCopy: false,
        removeCaption: false,
      ),
    );
  }

  /// What the user may do with a message: reply, edit, delete, forward.
  Future<td.MessageProperties> propertiesOf(int chatId, int messageId) =>
      _client.send(
        td.GetMessageProperties(chatId: chatId, messageId: messageId),
      );

  /// The emoji reactions offered first for a message, at most [limit].
  /// Custom emoji reactions are left out until the app draws them.
  Future<List<String>> quickReactions(
    int chatId,
    int messageId, {
    int limit = 8,
  }) async {
    final available = await _client.send(
      td.GetMessageAvailableReactions(
        chatId: chatId,
        messageId: messageId,
        // TDLib accepts rows of 5 to 25.
        rowSize: limit.clamp(5, 25),
      ),
    );
    // The user can't react here, for example without Premium in a chat
    // that only allows paid reactions.
    if (available.unavailabilityReason != null) return const [];
    final emoji = <String>[];
    for (final reaction in [
      ...available.topReactions,
      ...available.recentReactions,
      ...available.popularReactions,
    ]) {
      if (emoji.length == limit) break;
      if (reaction.needsPremium) continue;
      if (reaction.type case td.ReactionTypeEmoji(emoji: final value)) {
        if (!emoji.contains(value)) emoji.add(value);
      }
    }
    return emoji;
  }

  /// A t.me link to the message, for public chats and channels.
  Future<String> linkOf(int chatId, int messageId) async {
    final link = await _client.send(
      td.GetMessageLink(
        chatId: chatId,
        messageId: messageId,
        mediaTimestamp: 0,
        checklistTaskId: 0,
        pollOptionId: '',
        forAlbum: false,
        inMessageThread: false,
      ),
    );
    return link.link;
  }

  /// Announces a change, unless the controller is already closed: a reply
  /// can land after the session started shutting down.
  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      // Sender names and avatars on screen follow their changes.
      case td.UpdateUser(:final user):
        final sender = MessageSenderId.user(user.id);
        // updateUser also comes for status and other changes, so only a new
        // name, colour or photo is announced.
        final color = store.setColor(sender, user.accentColorId);
        final photo = store.setPhoto(sender, user.profilePhoto?.small);
        final name = store.setUserName(user.id, _nameOf(user));
        if (color || photo || name) _notify();
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
        _notify();
      case td.UpdateChatReadOutbox(
        :final chatId,
        :final lastReadOutboxMessageId,
      ):
        store.setReadOutbox(chatId, lastReadOutboxMessageId);
        _notify();
      case td.UpdateChatTitle(:final chatId, :final title):
        if (store.setChatTitle(chatId, title)) _notify();
      case td.UpdateChatPhoto(:final chatId, :final photo):
        if (store.setPhoto(MessageSenderId.chat(chatId), photo?.small)) {
          _notify();
        }
      case td.UpdateChatAccentColors(:final chatId, :final accentColorId):
        if (store.setColor(MessageSenderId.chat(chatId), accentColorId)) {
          _notify();
        }
      case td.UpdateMessageEphemeralContent(
        :final chatId,
        :final messageId,
        :final ephemeralContent,
      ):
        _patch(chatId, messageId, {
          'ephemeral_content': ephemeralContent?.toJson(),
        });
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
        _notify();
      default:
        return;
    }
  }

  void _add(td.Message message) {
    _arrivedDuringLoad[message.chatId]?.add(message.id);
    store.upsert(ConversationMessage(message));
    _notify();
  }

  void _patch(int chatId, int messageId, Map<String, Object?> fields) {
    if (store.patch(chatId, messageId, fields)) _notify();
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');
