import 'dart:async';
import 'dart:typed_data';

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

  /// Chats with a page of newer history on its way.
  final _loadingNewer = <int>{};

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
  /// With [atUnread] and unread messages in the chat, it loads the page
  /// around the last read message instead, where the official apps open a
  /// chat.
  ///
  /// TDLib answers the first request from its local database, which may
  /// hold only the last message, so older pages follow until the screen
  /// has [minimum] messages or the chat has no more.
  Future<void> loadHistory(
    int chatId, {
    int minimum = 30,
    bool atUnread = true,
  }) async {
    final read = store.lastReadInbox(chatId);
    final last = store.lastMessageId(chatId);
    if (atUnread && store.unreadCount(chatId) > 0 && read != 0 && last > read) {
      return loadAround(chatId, read, newer: 40, minimum: minimum);
    }
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
    await _fillOlder(chatId, minimum);
  }

  /// Replaces the timeline of [chatId] with the messages around
  /// [messageId]: up to [newer] after it, the message itself and older ones
  /// up to a page in all. Newer pages then load with [loadNewer].
  Future<void> loadAround(
    int chatId,
    int messageId, {
    int newer = 25,
    int minimum = 30,
  }) async {
    final response = await _client.send(
      td.GetChatHistory(
        chatId: chatId,
        fromMessageId: messageId,
        offset: -newer,
        limit: 50,
        onlyLocal: false,
      ),
    );
    store.replaceHistory(chatId, [
      for (final message in response.messages) ConversationMessage(message),
    ], latest: false);
    if (response.messages.isEmpty) {
      store
        ..markReachedStart(chatId)
        ..markReachedEnd(chatId);
    }
    _notify();
    await _fillOlder(chatId, minimum);
  }

  Future<void> _fillOlder(int chatId, int minimum) async {
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

  /// Loads the page after the newest loaded message, while the timeline
  /// stops short of the chat's last message. Returns whether it added
  /// anything; false also while another page is on its way.
  Future<bool> loadNewer(int chatId) async {
    final newest = store.newestId(chatId);
    if (newest == null || store.reachedEnd(chatId)) return false;
    if (!_loadingNewer.add(chatId)) return false;
    try {
      final response = await _client.send(
        td.GetChatHistory(
          chatId: chatId,
          fromMessageId: newest,
          offset: -49,
          limit: 50,
          onlyLocal: false,
        ),
      );
      final added = store.addNewer(chatId, [
        for (final message in response.messages)
          if (message.id > newest) ConversationMessage(message),
      ]);
      if (added == 0) store.markReachedEnd(chatId);
      _notify();
      return added > 0;
    } finally {
      _loadingNewer.remove(chatId);
    }
  }

  /// Joins the group or channel [chatId]. The chat may need approval, in
  /// which case the request is sent and the user stays out for now.
  Future<void> joinChat(int chatId) async {
    await _client.send(td.JoinChat(chatId: chatId));
  }

  /// Mutes the notifications of [chatId] for good, or unmutes them.
  Future<void> setMuted(int chatId, {required bool muted}) async {
    await _client.send(
      td.SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: td.ChatNotificationSettings(
          useDefaultMuteFor: !muted,
          // TDLib's "forever".
          muteFor: muted ? 2147483647 : 0,
          useDefaultSound: true,
          soundId: 0,
          useDefaultShowPreview: true,
          showPreview: true,
          useDefaultMuteStories: true,
          muteStories: false,
          useDefaultStorySound: true,
          storySoundId: 0,
          useDefaultShowStoryPoster: true,
          showStoryPoster: true,
          useDefaultDisablePinnedMessageNotifications: true,
          disablePinnedMessageNotifications: false,
          useDefaultDisableMentionNotifications: true,
          disableMentionNotifications: false,
        ),
      ),
    );
  }

  /// Loads the pinned messages of [chatId] for the bar under the header.
  Future<void> loadPinned(int chatId) async {
    final found = await _client.send(
      td.SearchChatMessages(
        chatId: chatId,
        query: '',
        fromMessageId: 0,
        offset: 0,
        limit: 100,
        filter: const td.SearchMessagesFilterPinned(),
      ),
    );
    for (final message in found.messages) {
      if (!store.contains(chatId, message.id)) {
        store.addReferenced(ConversationMessage(message));
      }
    }
    store.setPinned(chatId, [for (final m in found.messages) m.id]);
    _notify();
  }

  /// Who saw [messageId] of [chatId], in a small group; TDLib keeps the
  /// list only for recent messages.
  Future<List<td.MessageViewer>> viewers(int chatId, int messageId) async {
    final viewers = await _client.send(
      td.GetMessageViewers(chatId: chatId, messageId: messageId),
    );
    return viewers.viewers;
  }

  /// Who reacted to [messageId] of [chatId], newest first, up to [limit].
  Future<List<td.AddedReaction>> addedReactions(
    int chatId,
    int messageId, {
    int limit = 100,
  }) async {
    final added = await _client.send(
      td.GetMessageAddedReactions(
        chatId: chatId,
        messageId: messageId,
        offset: '',
        limit: limit,
      ),
    );
    return added.reactions;
  }

  /// When the other side read [messageId] of [chatId], in a private chat.
  Future<td.MessageReadDate> readDate(int chatId, int messageId) =>
      _client.send(td.GetMessageReadDate(chatId: chatId, messageId: messageId));

  /// Reports [messageIds] of [chatId] to the moderators. The first call
  /// goes out with no option and comes back with the reasons to choose
  /// from; each later call carries the chosen [optionId], and [text] once
  /// the server asks for details.
  Future<td.ReportChatResult> report(
    int chatId,
    List<int> messageIds, {
    Uint8List? optionId,
    String text = '',
  }) => _client.send(
    td.ReportChat(
      chatId: chatId,
      optionId: optionId ?? Uint8List(0),
      messageIds: messageIds,
      text: text,
    ),
  );

  /// Unpins every message of [chatId].
  Future<void> unpinAll(int chatId) async {
    await _client.send(td.UnpinAllChatMessages(chatId: chatId));
    store.setPinned(chatId, const []);
    _notify();
  }

  /// Pins [messageId] for everyone in the chat, or [onlyForSelf] in a
  /// private chat, and unpins it when [pinned] is false.
  Future<void> setPinned(
    int chatId,
    int messageId, {
    required bool pinned,
    bool onlyForSelf = false,
  }) async {
    if (pinned) {
      await _client.send(
        td.PinChatMessage(
          chatId: chatId,
          messageId: messageId,
          disableNotification: false,
          onlyForSelf: onlyForSelf,
        ),
      );
    } else {
      await _client.send(
        td.UnpinChatMessage(chatId: chatId, messageId: messageId),
      );
    }
  }

  /// The oldest unread message of [chatId] that mentions the user, or with
  /// [reactions] the oldest of theirs with a reaction they haven't seen.
  /// Viewing it marks it read.
  Future<ConversationMessage?> firstUnread(
    int chatId, {
    bool reactions = false,
  }) async {
    final found = await _client.send(
      td.SearchChatMessages(
        chatId: chatId,
        query: '',
        fromMessageId: 0,
        offset: 0,
        limit: 100,
        filter: reactions
            ? const td.SearchMessagesFilterUnreadReaction()
            : const td.SearchMessagesFilterUnreadMention(),
      ),
    );
    // Newest first.
    return found.messages.isEmpty
        ? null
        : ConversationMessage(found.messages.last);
  }

  /// The last message of [chatId] sent on [day] or before it, for a jump
  /// to a date; null when the chat has nothing that old.
  Future<ConversationMessage?> messageByDate(int chatId, DateTime day) async {
    final end = DateTime(day.year, day.month, day.day + 1);
    try {
      final message = await _client.send(
        td.GetChatMessageByDate(
          chatId: chatId,
          date: end.millisecondsSinceEpoch ~/ 1000 - 1,
        ),
      );
      return ConversationMessage(message);
    } on td.TdException catch (error) {
      if (error.code == 404) return null;
      rethrow;
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
    // The slowmode of a supergroup comes with its full info; TDLib sends
    // changes on its own once it has been asked.
    final supergroupId = store.supergroupIdOf(chatId);
    if (supergroupId == null) return;
    try {
      final full = await _client.send(
        td.GetSupergroupFullInfo(supergroupId: supergroupId),
      );
      store.setSlowMode(
        supergroupId,
        delay: full.slowModeDelay,
        expiresIn: full.slowModeDelayExpiresIn,
      );
      _notify();
    } on Object {
      // Without the full info the chat still works; slowmode shows up on
      // the first send.
    }
  }

  /// Saves what the user has typed in [chatId] as its draft, so the other
  /// devices show it too: [text] with its formatting and the message it
  /// answers. Without text or a reply the draft is cleared. Nothing goes
  /// out when the draft TDLib has already reads the same.
  Future<void> saveDraft(
    int chatId, {
    td.FormattedText? text,
    int? replyTo,
  }) async {
    final draft = text == null && replyTo == null
        ? null
        : td.DraftMessage(
            replyTo: replyTo == null
                ? null
                : td.InputMessageReplyToMessage(
                    messageId: replyTo,
                    checklistTaskId: 0,
                    pollOptionId: '',
                  ),
            date: 0,
            content: td.DraftMessageContentText(
              text: text ?? const td.FormattedText(text: '', entities: []),
            ),
            effectId: 0,
          );
    if (!_draftDiffers(store.draft(chatId), draft)) return;
    store.setDraft(chatId, draft);
    await _client.send(
      td.SetChatDraftMessage(chatId: chatId, draftMessage: draft),
    );
  }

  static bool _draftDiffers(td.DraftMessage? a, td.DraftMessage? b) {
    if (a == null || b == null) return (a == null) != (b == null);
    final aText = switch (a.content) {
      td.DraftMessageContentText(:final text) => text,
      _ => null,
    };
    final bText = switch (b.content) {
      td.DraftMessageContentText(:final text) => text,
      _ => null,
    };
    final aReply = switch (a.replyTo) {
      td.InputMessageReplyToMessage(:final messageId) => messageId,
      _ => null,
    };
    final bReply = switch (b.replyTo) {
      td.InputMessageReplyToMessage(:final messageId) => messageId,
      _ => null,
    };
    return aReply != bReply ||
        aText?.text != bText?.text ||
        aText?.entities.length != bText?.entities.length;
  }

  /// Remembers that TDLib refused a message for [seconds] under slowmode,
  /// so the composer can count down.
  void noteSlowModeWait(int chatId, int seconds) {
    final supergroupId = store.supergroupIdOf(chatId);
    if (supergroupId == null) return;
    final delay = store.slowModeDelay(chatId);
    store.setSlowMode(
      supergroupId,
      delay: delay > 0 ? delay : seconds,
      expiresIn: seconds.toDouble(),
    );
    _notify();
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

  /// Sends [text] with its formatting [entities], as a reply to [replyTo]
  /// when it is set, quoting [quote] of its text at [quotePosition] when
  /// that is given.
  Future<void> sendText(
    int chatId,
    String text, {
    int? replyTo,
    List<td.TextEntity> entities = const [],
    String? quote,
    int quotePosition = 0,
  }) async {
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

  /// Sends a recorded voice message: an Ogg Opus file at [path] with its
  /// length and Telegram's packed 5-bit [waveform].
  Future<void> sendVoiceNote(
    int chatId, {
    required String path,
    required Duration duration,
    required Uint8List waveform,
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
          inputMessageContent: td.InputMessageVoiceNote(
            voiceNote: td.InputVoiceNote(
              voiceNote: td.InputFileLocal(path: path),
              // Rounded up, as the official apps do: 0.4 s shows as 0:01.
              duration: (duration.inMilliseconds / 1000).ceil(),
              waveform: waveform,
            ),
          ),
        ),
      ),
    );
  }

  /// Sends a recorded video message: a square MP4 at [path], [side]
  /// pixels wide and at most 60 seconds long.
  Future<void> sendVideoNote(
    int chatId, {
    required String path,
    required Duration duration,
    required int side,
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
          inputMessageContent: td.InputMessageVideoNote(
            videoNote: td.InputVideoNote(
              videoNote: td.InputFileLocal(path: path),
              duration: (duration.inMilliseconds / 1000).ceil(),
              length: side,
            ),
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
  /// [caption], formatted by [captionEntities], goes under the first
  /// file, and the first message answers [replyTo] when it is set.
  Future<void> sendFiles(
    int chatId,
    List<OutgoingFile> files, {
    String caption = '',
    List<td.TextEntity> captionEntities = const [],
    int? replyTo,
  }) async {
    // A caption longer than the server takes goes first as its own
    // message, as the official apps do.
    if (caption.trim().isNotEmpty && caption.length > await _captionLimit()) {
      await sendText(
        chatId,
        caption,
        replyTo: replyTo,
        entities: captionEntities,
      );
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
                ? td.FormattedText(text: caption, entities: captionEntities)
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
  ///
  /// With [entities] the new text gets exactly that formatting, as the
  /// composer shows it; without, the old formatting is carried over.
  Future<void> editText(
    int chatId,
    int messageId,
    String text, {
    List<td.TextEntity>? entities,
  }) async {
    final content = store.message(chatId, messageId)?.content;
    final current = content == null ? null : captionOf(content);
    final formatted = td.FormattedText(
      text: text,
      entities: current == null
          ? entities ?? const []
          : entities == null
          ? carryEntities(current.text, text, current.entities)
          : keepHiddenEntities(current.text, text, current.entities, entities),
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
    List<int> messageIds, {
    bool hideSender = false,
    bool hideCaptions = false,
  }) async {
    if (messageIds.isEmpty) return;
    await _client.send(
      td.ForwardMessages(
        chatId: toChatId,
        fromChatId: fromChatId,
        messageIds: messageIds,
        // Sent as copies, the messages carry no "forwarded from".
        sendCopy: hideSender,
        removeCaption: hideSender && hideCaptions,
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
  }) => _emojiReactions(chatId, messageId, limit: limit);

  /// Every emoji reaction the user may put on a message, the ones offered
  /// first coming first, for the full picker.
  Future<List<String>> allReactions(int chatId, int messageId) =>
      _emojiReactions(chatId, messageId, limit: null);

  Future<List<String>> _emojiReactions(
    int chatId,
    int messageId, {
    required int? limit,
  }) async {
    final available = await _client.send(
      td.GetMessageAvailableReactions(
        chatId: chatId,
        messageId: messageId,
        // TDLib accepts rows of 5 to 25.
        rowSize: (limit ?? 25).clamp(5, 25),
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

  /// The message's text translated into [to] by Telegram, free of Premium
  /// when asked for one message at a time.
  Future<String> translate(int chatId, int messageId, String to) async {
    final text = await _client.send(
      td.TranslateMessageText(
        chatId: chatId,
        messageId: messageId,
        toLanguageCode: to,
        tone: '',
      ),
    );
    return text.text;
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
          ..setLastMessageId(chat.id, chat.lastMessage?.id ?? 0)
          ..setUnreadCount(chat.id, chat.unreadCount)
          ..setUnreadMentionCount(chat.id, chat.unreadMentionCount)
          ..setUnreadReactionCount(chat.id, chat.unreadReactionCount)
          ..setChannel(chat.id, switch (chat.type) {
            td.ChatTypeSupergroup(:final isChannel) => isChannel,
            _ => false,
          })
          ..setChatType(chat.id, chat.type)
          ..setPermissions(chat.id, chat.permissions)
          ..setDraft(chat.id, chat.draftMessage)
          ..setMuteFor(chat.id, chat.notificationSettings.muteFor);
      case td.UpdateChatDraftMessage(:final chatId, :final draftMessage):
        if (store.setDraft(chatId, draftMessage)) _notify();
      case td.UpdateChatPermissions(:final chatId, :final permissions):
        if (store.setPermissions(chatId, permissions)) _notify();
      case td.UpdateSupergroupFullInfo(
        :final supergroupId,
        :final supergroupFullInfo,
      ):
        store.setSlowMode(
          supergroupId,
          delay: supergroupFullInfo.slowModeDelay,
          expiresIn: supergroupFullInfo.slowModeDelayExpiresIn,
        );
        _notify();
      case td.UpdateSupergroup(:final supergroup):
        if (store.setSupergroupStatus(supergroup.id, supergroup.status) !=
            null) {
          _notify();
        }
      case td.UpdateBasicGroup(:final basicGroup):
        if (store.setBasicGroupStatus(basicGroup.id, basicGroup.status) !=
            null) {
          _notify();
        }
      case td.UpdateChatNotificationSettings(
        :final chatId,
        :final notificationSettings,
      ):
        if (store.setMuteFor(chatId, notificationSettings.muteFor)) {
          _notify();
        }
      case td.UpdateChatReadInbox(
        :final chatId,
        :final lastReadInboxMessageId,
        :final unreadCount,
      ):
        store
          ..setReadInbox(chatId, lastReadInboxMessageId)
          ..setUnreadCount(chatId, unreadCount);
        _notify();
      case td.UpdateChatLastMessage(:final chatId, :final lastMessage):
        store.setLastMessageId(chatId, lastMessage?.id ?? 0);
      case td.UpdateChatUnreadMentionCount(
        :final chatId,
        :final unreadMentionCount,
      ):
      case td.UpdateMessageMentionRead(
        :final chatId,
        :final unreadMentionCount,
      ):
        if (store.setUnreadMentionCount(chatId, unreadMentionCount)) _notify();
      case td.UpdateChatUnreadReactionCount(
        :final chatId,
        :final unreadReactionCount,
      ):
        if (store.setUnreadReactionCount(chatId, unreadReactionCount)) {
          _notify();
        }
      case td.UpdateMessageUnreadReactions(
        :final chatId,
        :final messageId,
        :final unreadReactions,
        :final unreadReactionCount,
      ):
        final count = store.setUnreadReactionCount(chatId, unreadReactionCount);
        final patched = store.patch(chatId, messageId, {
          'unread_reactions': [for (final r in unreadReactions) r.toJson()],
        });
        if (count || patched) _notify();
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
        if (!store.hasPinned(chatId)) return;
        if (isPinned && store.message(chatId, messageId) == null) {
          // Pinned from another device, outside the loaded timeline: the
          // bar needs its text, so the list is fetched again.
          unawaited(loadPinned(chatId).catchError((Object _) {}));
          return;
        }
        if (store.markPinned(chatId, messageId, pinned: isPinned)) _notify();
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
    final chatId = message.chatId;
    _arrivedDuringLoad[chatId]?.add(message.id);
    // A window around an older message has a gap after it; what arrives
    // beyond the gap waits for the newer pages.
    final newest = store.newestId(chatId);
    if (!store.reachedEnd(chatId) && newest != null && message.id > newest) {
      return;
    }
    store.upsert(ConversationMessage(message));
    _notify();
  }

  void _patch(int chatId, int messageId, Map<String, Object?> fields) {
    if (store.patch(chatId, messageId, fields)) _notify();
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');
