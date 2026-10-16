import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';
import 'forum_topics.dart';
import 'message_thread.dart';
import 'outgoing_file.dart';
import 'peer_info.dart';
import 'saved_tags.dart';
import 'saved_topics.dart';
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

  /// The comment threads open on screen, fed every update.
  final _threads = <MessageThread>{};

  /// The forum topic lists open on screen, fed every update.
  final _topicLists = <ForumTopicList>{};
  final _savedLists = <SavedTopicList>{};
  final _savedTagLists = <SavedTags>{};
  int? _myId;

  /// The signed-in user's id, once TDLib has said it.
  int? get myId => _myId;

  /// Whether [chatId] is the user's Saved Messages.
  bool isSavedMessages(int chatId) =>
      _myId != null && store.privateUserIdOf(chatId) == _myId;
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
      var added = 0;
      // TDLib can answer a first request with nothing while it fetches the
      // page from the server; only a second empty answer is the start.
      for (var attempt = 0; attempt < 2 && added == 0; attempt++) {
        final response = await _client.send(
          td.GetChatHistory(
            chatId: chatId,
            fromMessageId: oldest,
            offset: 0,
            limit: 50,
            onlyLocal: false,
          ),
        );
        added = store.addOlder(chatId, [
          for (final message in response.messages) ConversationMessage(message),
        ]);
      }
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
    // With receipts hidden the request never reaches TDLib, so nothing
    // would tell us the message was played; mark it here the way the
    // update would, for the timeline and for any open thread.
    _onUpdate(
      td.UpdateMessageContentOpened(chatId: chatId, messageId: messageId),
    );
  }

  /// Adds the reaction, or takes it back when [chosen] is true.
  /// Votes in the poll of message [messageId] for [optionIds]; an empty
  /// list takes the vote back.
  Future<void> votePoll(int chatId, int messageId, List<int> optionIds) =>
      _client.send(
        td.SetPollAnswer(
          chatId: chatId,
          messageId: messageId,
          optionIds: optionIds,
        ),
      );

  /// Marks task [taskId] of the checklist in message [messageId] as done,
  /// or as not done again.
  Future<void> markChecklistTask(
    int chatId,
    int messageId,
    int taskId, {
    required bool done,
  }) => _client.send(
    td.MarkChecklistTasksAsDone(
      chatId: chatId,
      messageId: messageId,
      markedAsDoneTaskIds: done ? [taskId] : const [],
      markedAsNotDoneTaskIds: done ? const [] : [taskId],
    ),
  );

  /// The identities the user may post as in [chatId]: their own account
  /// and the channels they own, each with whether Premium is needed.
  Future<List<td.ChatMessageSender>> availableSenders(int chatId) async =>
      (await _client.send(td.GetChatAvailableMessageSenders(chatId: chatId)))
          .senders;

  /// Posts as [sender] in [chatId] from now on; TDLib confirms with
  /// `updateChatMessageSender`.
  Future<void> setMessageSender(int chatId, td.MessageSender sender) => _client
      .send(td.SetChatMessageSender(chatId: chatId, messageSenderId: sender));

  /// Asks Telegram to transcribe a voice message; the text arrives in the
  /// message's content as `speechRecognitionResult` (Premium, with a few
  /// free trials).
  Future<void> recognizeSpeech(int chatId, int messageId) =>
      _client.send(td.RecognizeSpeech(chatId: chatId, messageId: messageId));

  /// Presses a bot's inline button that carries [data]: the bot's answer,
  /// a notification or a URL to open, or nothing.
  Future<td.CallbackQueryAnswer> callbackQuery(
    int chatId,
    int messageId,
    Uint8List data,
  ) => _client.send(
    td.GetCallbackQueryAnswer(
      chatId: chatId,
      messageId: messageId,
      payload: td.CallbackQueryPayloadData(data: data),
    ),
  );

  /// Loads message [messageId] of [chatId] when it isn't in the store
  /// yet, such as the one whose keyboard the chat shows.
  Future<void> loadMessage(int chatId, int messageId) async {
    if (store.message(chatId, messageId) != null) return;
    if (!_requested.add((chatId, messageId))) return;
    try {
      final message = await _client.send(
        td.GetMessage(chatId: chatId, messageId: messageId),
      );
      store.addReferenced(ConversationMessage(message));
      _notify();
    } on td.TdException {
      _requested.remove((chatId, messageId));
    }
  }

  /// Closes the poll of message [messageId] for good.
  Future<void> stopPoll(int chatId, int messageId) =>
      _client.send(td.StopPoll(chatId: chatId, messageId: messageId));

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
    // The slowmode of a supergroup and the commands of the chat's bots
    // come with its full info; TDLib sends changes on its own once it has
    // been asked.
    try {
      if (store.supergroupIdOf(chatId) case final supergroupId?) {
        final full = await _client.send(
          td.GetSupergroupFullInfo(supergroupId: supergroupId),
        );
        store.setSlowMode(
          supergroupId,
          delay: full.slowModeDelay,
          expiresIn: full.slowModeDelayExpiresIn,
        );
        _setBotCommands(chatId, full.botCommands);
        _notify();
      } else if (store.basicGroupIdOf(chatId) case final basicGroupId?) {
        final full = await _client.send(
          td.GetBasicGroupFullInfo(basicGroupId: basicGroupId),
        );
        if (_setBotCommands(chatId, full.botCommands)) _notify();
      } else if (store.privateUserIdOf(chatId) case final userId?) {
        final user = await _client.send(td.GetUser(userId: userId));
        if (store.setBot(userId, user.type is td.UserTypeBot)) _notify();
        if (user.type is! td.UserTypeBot) return;
        final full = await _client.send(td.GetUserFullInfo(userId: userId));
        if (_setBotInfo(chatId, userId, full.botInfo)) _notify();
      }
    } on Object {
      // Without the full info the chat still works; slowmode shows up on
      // the first send and the bot's commands can still be typed.
    }
  }

  /// Stores what a bot's full info says about its commands and menu
  /// button; true when either changed.
  bool _setBotInfo(int? chatId, int userId, td.BotInfo? info) {
    if (chatId == null) return false;
    final commands = _setBotCommands(chatId, [
      if (info != null)
        td.BotCommands(botUserId: userId, commands: info.commands),
    ]);
    final menu = switch (info) {
      null => null,
      td.BotInfo(menuButton: null) => const BotMenu(text: '', url: ''),
      td.BotInfo(menuButton: final button?) => BotMenu(
        text: button.text,
        url: button.url,
      ),
    };
    return store.setBotMenu(chatId, menu) || commands;
  }

  /// Stores the commands of [chatId]'s bots from [sets]; true when they
  /// changed. Ephemeral commands, meant for one message, are left out.
  bool _setBotCommands(int? chatId, List<td.BotCommands> sets) {
    if (chatId == null) return false;
    return store.setBotCommands(chatId, [
      for (final set in sets)
        for (final command in set.commands)
          if (!command.isEphemeral)
            BotCommand(
              botUserId: set.botUserId,
              command: command.command,
              description: command.description,
            ),
    ]);
  }

  /// The address of a bot's Web App at [url], signed for this user, with
  /// the app's [theme] when one is given.
  Future<String> webAppUrl(
    int botUserId,
    String url, {
    td.ThemeParameters? theme,
  }) async {
    final result = await _client.send(
      td.GetWebAppUrl(
        botUserId: botUserId,
        url: url,
        parameters: td.WebAppOpenParameters(
          theme: theme,
          applicationName: 'mollygram',
        ),
      ),
    );
    return result.url;
  }

  /// Presses Start in a chat with a bot, which sends /start.
  Future<void> sendBotStart(int chatId, int botUserId) async {
    _add(
      await _client.send(
        td.SendBotStartMessage(
          botUserId: botUserId,
          chatId: chatId,
          parameter: '',
        ),
      ),
    );
  }

  /// Saves what the user has typed in [chatId] as its draft, so the other
  /// devices show it too: [text] with its formatting and the message it
  /// answers. Without text or a reply the draft is cleared. Nothing goes
  /// out when the draft TDLib has already reads the same.
  Future<void> saveDraft(
    int chatId, {
    td.FormattedText? text,
    int? replyTo,
    td.LinkPreviewOptions? linkPreviewOptions,
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
              linkPreviewOptions: linkPreviewOptions,
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
    final (aText, aPreview) = switch (a.content) {
      td.DraftMessageContentText(:final text, :final linkPreviewOptions) => (
        text,
        linkPreviewOptions,
      ),
      _ => (null, null),
    };
    final (bText, bPreview) = switch (b.content) {
      td.DraftMessageContentText(:final text, :final linkPreviewOptions) => (
        text,
        linkPreviewOptions,
      ),
      _ => (null, null),
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
        aText?.entities.length != bText?.entities.length ||
        jsonEncode(aPreview?.toJson()) != jsonEncode(bPreview?.toJson());
  }

  /// The preview Telegram would attach to [text], for the first link in
  /// it, under [options] when they are given; null when there is no link
  /// or the site gives nothing to show.
  Future<td.LinkPreview?> linkPreview(
    td.FormattedText text, {
    td.LinkPreviewOptions? options,
  }) async {
    try {
      return await _client.send(
        td.GetLinkPreview(text: text, linkPreviewOptions: options),
      );
    } on td.TdException {
      return null;
    }
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
  /// that is given. [linkPreviewOptions] shape the preview of a link in
  /// the text, or drop it; null leaves it to Telegram's defaults. [silent]
  /// sends without a sound on the other side; [schedule] sends later, and
  /// the message then lives in the chat's scheduled list, not its history.
  Future<void> sendText(
    int chatId,
    String text, {
    int? replyTo,
    List<td.TextEntity> entities = const [],
    String? quote,
    int quotePosition = 0,
    td.LinkPreviewOptions? linkPreviewOptions,
    bool silent = false,
    td.MessageSchedulingState? schedule,
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
        options: sendOptions(silent: silent, schedule: schedule),
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: text, entities: entities),
          linkPreviewOptions: linkPreviewOptions,
          clearDraft: true,
        ),
      ),
    );
    _add(message);
  }

  /// The messages of [chatId] waiting to be sent later, soonest first.
  Future<List<ConversationMessage>> scheduledMessages(int chatId) async {
    final found = await _client.send(
      td.GetChatScheduledMessages(chatId: chatId),
    );
    return [
      for (final message in found.messages.reversed)
        ConversationMessage(message),
    ];
  }

  /// Sends scheduled message [messageId] of [chatId] right away.
  Future<void> sendScheduledNow(int chatId, int messageId) =>
      _reschedule(chatId, messageId, null);

  /// Moves scheduled message [messageId] of [chatId] to [when].
  Future<void> reschedule(int chatId, int messageId, DateTime when) =>
      _reschedule(
        chatId,
        messageId,
        td.MessageSchedulingStateSendAtDate(
          sendDate: when.millisecondsSinceEpoch ~/ 1000,
          repeatPeriod: 0,
        ),
      );

  Future<void> _reschedule(
    int chatId,
    int messageId,
    td.MessageSchedulingState? state,
  ) async {
    await _client.send(
      td.EditMessageSchedulingState(
        chatId: chatId,
        messageId: messageId,
        schedulingState: state,
      ),
    );
    store.bumpScheduled(chatId);
    _notify();
  }

  /// Deletes scheduled messages of [chatId] before they go out.
  Future<void> deleteScheduled(int chatId, List<int> messageIds) async {
    await _client.send(
      td.DeleteMessages(chatId: chatId, messageIds: messageIds, revoke: true),
    );
    store.bumpScheduled(chatId);
    _notify();
  }

  /// The send options for a silent or scheduled message; null for the
  /// defaults, so a plain message carries none.
  static td.MessageSendOptions? sendOptions({
    bool silent = false,
    td.MessageSchedulingState? schedule,
  }) {
    if (!silent && schedule == null) return null;
    return td.MessageSendOptions(
      disableNotification: silent,
      fromBackground: false,
      protectContent: false,
      allowPaidBroadcast: false,
      paidMessageStarCount: 0,
      updateOrderOfInstalledStickerSets: false,
      schedulingState: schedule,
      effectId: 0,
      sendingId: 0,
      onlyPreview: false,
    );
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
  /// Sends a GIF the user has saved, by its file, as the panel's GIF tab
  /// picks it.
  Future<void> sendAnimation(
    int chatId,
    td.Animation animation, {
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
          inputMessageContent: td.InputMessageAnimation(
            animation: td.InputAnimation(
              animation: td.InputFileId(id: animation.animation.id),
              addedStickerFileIds: const [],
              duration: animation.duration,
              width: animation.width,
              height: animation.height,
            ),
            showCaptionAboveMedia: false,
            hasSpoiler: false,
          ),
        ),
      ),
    );
  }

  /// The inline bot behind [username] (without the @): null when there is
  /// no such user, or it is not a bot that answers inline queries.
  Future<td.User?> inlineBot(String username) async {
    final td.Chat chat;
    try {
      chat = await _client.send(td.SearchPublicChat(username: username));
    } on Object {
      return null;
    }
    if (chat.type case td.ChatTypePrivate(:final userId)) {
      final user = await _client.send(td.GetUser(userId: userId));
      if (user.type case td.UserTypeBot(isInline: true)) return user;
    }
    return null;
  }

  /// The text that starts an inline query to bot [botUserId]: its
  /// username and [query], as a switch-to-inline button asks for; null
  /// when the bot has no username.
  Future<String?> switchInlineText(int botUserId, String query) async {
    final td.User user;
    try {
      user = await _client.send(td.GetUser(userId: botUserId));
    } on td.TdException {
      return null;
    }
    final usernames = user.usernames;
    final username = usernames == null
        ? ''
        : usernames.editableUsername.isNotEmpty
        ? usernames.editableUsername
        : usernames.activeUsernames.firstOrNull ?? '';
    if (username.isEmpty) return null;
    return '@$username $query';
  }

  /// The signed-in user.
  Future<td.User> me() => _client.send(const td.GetMe());

  /// Answers a bot's request for users, from the button [buttonId] of
  /// [messageId] in [chatId], with [userIds].
  Future<void> shareUsersWithBot(
    int chatId,
    int messageId,
    int buttonId,
    List<int> userIds,
  ) => _client.send(
    td.ShareUsersWithBot(
      source: td.KeyboardButtonSourceMessage(
        chatId: chatId,
        messageId: messageId,
      ),
      buttonId: buttonId,
      sharedUserIds: userIds,
      onlyCheck: false,
    ),
  );

  /// Answers a bot's request for a chat, from the button [buttonId] of
  /// [messageId] in [chatId], with [sharedChatId].
  Future<void> shareChatWithBot(
    int chatId,
    int messageId,
    int buttonId,
    int sharedChatId,
  ) => _client.send(
    td.ShareChatWithBot(
      source: td.KeyboardButtonSourceMessage(
        chatId: chatId,
        messageId: messageId,
      ),
      buttonId: buttonId,
      sharedChatId: sharedChatId,
      onlyCheck: false,
    ),
  );

  /// Asks inline bot [botUserId] for its results to [query], as the
  /// composer shows them while the user types `@bot query`; [offset] is
  /// the previous answer's `nextOffset` for the following page.
  Future<td.InlineQueryResults> inlineResults(
    int chatId,
    int botUserId,
    String query, {
    String offset = '',
  }) => _client.send(
    td.GetInlineQueryResults(
      botUserId: botUserId,
      chatId: chatId,
      query: query,
      offset: offset,
    ),
  );

  /// Sends result [resultId] of inline query [queryId], "via" the bot.
  Future<void> sendInlineResult(
    int chatId, {
    required int queryId,
    required String resultId,
    int? replyTo,
  }) async {
    _add(
      await _client.send(
        td.SendInlineQueryResultMessage(
          chatId: chatId,
          replyTo: replyTo == null
              ? null
              : td.InputMessageReplyToMessage(
                  messageId: replyTo,
                  checklistTaskId: 0,
                  pollOptionId: '',
                ),
          queryId: queryId,
          resultId: resultId,
          hideViaBot: false,
        ),
      ),
    );
  }

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

  /// Sends a poll or quiz the user composed.
  Future<void> sendPoll(
    int chatId,
    td.InputMessagePoll poll, {
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
          inputMessageContent: poll,
        ),
      ),
    );
  }

  /// Opens the comments of [messageId] in [chatId]: for a channel post,
  /// the thread in its discussion group. The thread follows updates until
  /// it is disposed; its first page still has to be loaded.
  Future<MessageThread> openThread(int chatId, int messageId) async {
    final info = await _client.send(
      td.GetMessageThread(chatId: chatId, messageId: messageId),
    );
    final thread = MessageThread(
      _client,
      store,
      chatId: info.chatId,
      threadId: info.messageThreadId,
      roots: info.messages,
      replyCount: info.replyInfo?.replyCount ?? 0,
      onDispose: _threads.remove,
      sendFiles: sendFiles,
    );
    _threads.add(thread);
    return thread;
  }

  /// The sponsored messages Telegram asks to show in channel [chatId];
  /// empty for other chats and when there are none.
  Future<List<td.SponsoredMessage>> sponsoredMessages(int chatId) async {
    try {
      final answer = await _client.send(
        td.GetChatSponsoredMessages(chatId: chatId),
      );
      return answer.messages;
    } on td.TdException {
      return const [];
    }
  }

  /// Tells TDLib that sponsored message [messageId] of [chatId] was fully
  /// shown, so the sponsor's view counts.
  Future<void> viewSponsored(int chatId, int messageId) => _client.send(
    td.ViewMessages(
      chatId: chatId,
      messageIds: [messageId],
      source: const td.MessageSourceChatHistory(),
      forceRead: false,
    ),
  );

  /// Tells TDLib that the user clicked sponsored message [messageId].
  Future<void> clickSponsored(int chatId, int messageId) => _client.send(
    td.ClickChatSponsoredMessage(
      chatId: chatId,
      messageId: messageId,
      isMediaClick: false,
      fromFullscreen: false,
    ),
  );

  /// The topics of forum [chatId], kept current until disposed; the
  /// first page still has to be loaded.
  /// The topics of Saved Messages, fed updates until disposed.
  SavedTopicList openSavedTopics() {
    final list = SavedTopicList(_client, onDispose: _savedLists.remove);
    _savedLists.add(list);
    return list;
  }

  /// Opens Saved Messages [topic] in [chatId] as a thread of its own.
  Future<MessageThread> openSavedTopic(
    int chatId,
    td.SavedMessagesTopic topic,
  ) async {
    final thread = MessageThread(
      _client,
      store,
      chatId: chatId,
      threadId: topic.id,
      savedTopic: topic,
      roots: const [],
      replyCount: 0,
      onDispose: _threads.remove,
      sendFiles: sendFiles,
    );
    _threads.add(thread);
    return thread;
  }

  /// The tags on Saved Messages, fed updates until disposed; they still
  /// have to be loaded.
  SavedTags openSavedTags() {
    final tags = SavedTags(_client, onDispose: _savedTagLists.remove);
    _savedTagLists.add(tags);
    return tags;
  }

  /// Opens the Saved Messages that carry [tag] in [chatId] as a thread of
  /// its own.
  Future<MessageThread> openSavedTag(int chatId, td.ReactionType tag) async {
    final thread = MessageThread(
      _client,
      store,
      chatId: chatId,
      threadId: 0,
      savedTag: tag,
      roots: const [],
      replyCount: 0,
      onDispose: _threads.remove,
      sendFiles: sendFiles,
    );
    _threads.add(thread);
    return thread;
  }

  /// Pins or unpins Saved Messages topic [topicId].
  Future<void> setSavedTopicPinned(int topicId, bool pinned) => _client.send(
    td.ToggleSavedMessagesTopicIsPinned(
      savedMessagesTopicId: topicId,
      isPinned: pinned,
    ),
  );

  /// Deletes every saved message of topic [topicId].
  Future<void> deleteSavedTopic(int topicId) => _client.send(
    td.DeleteSavedMessagesTopicHistory(savedMessagesTopicId: topicId),
  );

  ForumTopicList openTopics(int chatId) {
    final list = ForumTopicList(
      _client,
      chatId: chatId,
      onDispose: _topicLists.remove,
    );
    _topicLists.add(list);
    return list;
  }

  /// The colours Telegram gives topics without a custom emoji.
  static const topicColors = [
    0x6FB9F0,
    0xFFD67E,
    0xCB86DB,
    0x8EEE98,
    0xFF93B2,
    0xFB6F5F,
  ];

  /// Starts a topic called [name] in forum [chatId], in one of Telegram's
  /// topic colours.
  Future<td.ForumTopicInfo> createTopic(
    int chatId,
    String name, {
    int? color,
    int customEmojiId = 0,
  }) => _client.send(
    td.CreateForumTopic(
      chatId: chatId,
      name: name,
      isNameImplicit: false,
      icon: td.ForumTopicIcon(
        color: color ?? topicColors[name.hashCode.abs() % topicColors.length],
        customEmojiId: customEmojiId,
      ),
    ),
  );

  /// The custom emoji anyone may put on a topic, from TDLib.
  Future<List<td.Sticker>> topicDefaultIcons() async =>
      (await _client.send(const td.GetForumTopicDefaultIcons())).stickers;

  /// Renames topic [forumTopicId] of forum [chatId] and, when
  /// [customEmojiId] is given, puts that custom emoji on it (0 for the
  /// coloured tile instead).
  Future<void> editTopic(
    int chatId,
    int forumTopicId, {
    required String name,
    int? customEmojiId,
  }) => _client.send(
    td.EditForumTopic(
      chatId: chatId,
      forumTopicId: forumTopicId,
      name: name,
      editIconCustomEmoji: customEmojiId != null,
      iconCustomEmojiId: customEmojiId ?? 0,
    ),
  );

  /// Closes or reopens topic [forumTopicId] of forum [chatId].
  Future<void> setTopicClosed(int chatId, int forumTopicId, bool closed) =>
      _client.send(
        td.ToggleForumTopicIsClosed(
          chatId: chatId,
          forumTopicId: forumTopicId,
          isClosed: closed,
        ),
      );

  /// Pins or unpins topic [forumTopicId] of forum [chatId].
  Future<void> setTopicPinned(int chatId, int forumTopicId, bool pinned) =>
      _client.send(
        td.ToggleForumTopicIsPinned(
          chatId: chatId,
          forumTopicId: forumTopicId,
          isPinned: pinned,
        ),
      );

  /// Deletes topic [forumTopicId] of forum [chatId] with its messages.
  Future<void> deleteTopic(int chatId, int forumTopicId) => _client.send(
    td.DeleteForumTopic(chatId: chatId, forumTopicId: forumTopicId),
  );

  /// The name and icon of topic [forumTopicId] of forum [chatId], as the
  /// chat list shows it beside the forum's last message.
  Future<td.ForumTopicInfo> topicInfo(int chatId, int forumTopicId) async =>
      (await _client.send(
        td.GetForumTopic(chatId: chatId, forumTopicId: forumTopicId),
      )).info;

  /// Topic [forumTopicId] of forum [chatId] as a thread: its messages,
  /// kept current until it is disposed; its first page still has to be
  /// loaded.
  Future<MessageThread> openTopic(int chatId, int forumTopicId) async {
    final topic = await _client.send(
      td.GetForumTopic(chatId: chatId, forumTopicId: forumTopicId),
    );
    final thread = MessageThread(
      _client,
      store,
      chatId: chatId,
      threadId: forumTopicId,
      forumTopic: topic.info,
      roots: const [],
      replyCount: 0,
      onDispose: _threads.remove,
      sendFiles: sendFiles,
    );
    _threads.add(thread);
    return thread;
  }

  /// Who voted for option [optionId] (its index) of the poll in
  /// [messageId], newest first, up to [limit] of them. Only for polls
  /// that are not anonymous.
  Future<List<MessageSenderId>> pollVoters(
    int chatId,
    int messageId,
    int optionId, {
    int limit = 50,
  }) async {
    final voters = await _client.send(
      td.GetPollVoters(
        chatId: chatId,
        messageId: messageId,
        optionId: optionId,
        offset: 0,
        limit: limit,
      ),
    );
    return [
      for (final voter in voters.voters) MessageSenderId.of(voter.voterId),
    ];
  }

  /// Sends [contact] as a message, as a reply to [replyTo] when given.
  Future<void> sendContact(
    int chatId,
    td.Contact contact, {
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
          inputMessageContent: td.InputMessageContact(contact: contact),
        ),
      ),
    );
  }

  /// The groups the user and [userId] are both in, as the info panel
  /// lists them.
  Future<List<td.Chat>> groupsInCommon(int userId) async {
    final chats = await _client.send(
      td.GetGroupsInCommon(userId: userId, offsetChatId: 0, limit: 100),
    );
    return Future.wait([
      for (final id in chats.chatIds) _client.send(td.GetChat(chatId: id)),
    ]);
  }

  /// The photos of a profile, newest first: a user's profile photos, or
  /// the photos a group or channel has had, from its photo-change
  /// messages. [userId] names the user of a private chat.
  Future<List<ProfilePhoto>> profilePhotos(int chatId, {int userId = 0}) async {
    if (userId != 0) {
      final photos = await _client.send(
        td.GetUserProfilePhotos(userId: userId, offset: 0, limit: 100),
      );
      return [
        for (final photo in photos.photos)
          (photo: _photoOf(photo), date: photo.addedDate),
      ];
    }
    final found = await _client.send(
      td.SearchChatMessages(
        chatId: chatId,
        query: '',
        fromMessageId: 0,
        offset: 0,
        limit: 100,
        filter: const td.SearchMessagesFilterChatPhoto(),
      ),
    );
    return [
      for (final message in found.messages)
        if (message.content case td.MessageChatChangePhoto(:final photo))
          (photo: _photoOf(photo), date: message.date),
    ];
  }

  static td.Photo _photoOf(td.ChatPhoto photo) => td.Photo(
    hasStickers: false,
    minithumbnail: photo.minithumbnail,
    sizes: photo.sizes,
  );

  /// Sends a place as a message, as a reply to [replyTo] when given.
  Future<void> sendLocation(int chatId, td.Location location, {int? replyTo}) =>
      _sendPlace(
        chatId,
        td.InputMessageLocation(location: location),
        replyTo: replyTo,
      );

  /// Sends a venue, a place with a name and an address, as a message.
  Future<void> sendVenue(int chatId, td.Venue venue, {int? replyTo}) =>
      _sendPlace(chatId, td.InputMessageVenue(venue: venue), replyTo: replyTo);

  Future<void> _sendPlace(
    int chatId,
    td.InputMessageContent content, {
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
          inputMessageContent: content,
        ),
      ),
    );
  }

  td.User? _venueBot;

  /// The inline bot Telegram names for venue search (the
  /// `venue_search_bot_username` option, Foursquare unless told
  /// otherwise); null when it can't be reached.
  Future<td.User?> venueBot() async {
    if (_venueBot case final bot?) return bot;
    var username = 'foursquare';
    try {
      final option = await _client.send(
        const td.GetOption(name: 'venue_search_bot_username'),
      );
      if (option is td.OptionValueString && option.value.isNotEmpty) {
        username = option.value;
      }
    } on Object {
      // Keep the default bot.
    }
    return _venueBot = await inlineBot(username);
  }

  /// Venues matching [query] around [near], from the venue bot, for the
  /// location sheet; empty when there is no bot or nothing matches.
  Future<List<td.Venue>> searchVenues(
    int chatId,
    String query,
    td.Location near,
  ) async {
    final bot = await venueBot();
    if (bot == null) return const [];
    final results = await _client.send(
      td.GetInlineQueryResults(
        botUserId: bot.id,
        chatId: chatId,
        userLocation: near,
        query: query,
        offset: '',
      ),
    );
    return [
      for (final result in results.results)
        if (result is td.InlineQueryResultVenue) result.venue,
    ];
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
  Future<List<td.Message>> sendFiles(
    int chatId,
    List<OutgoingFile> files, {
    String caption = '',
    List<td.TextEntity> captionEntities = const [],
    int? replyTo,
    int? threadId,
    bool forumTopic = false,
    bool savedTopic = false,
    bool silent = false,
    td.MessageSchedulingState? schedule,
  }) async {
    final topic = threadId == null
        ? null
        : savedTopic
        ? td.MessageTopicSavedMessages(savedMessagesTopicId: threadId)
        : forumTopic
        ? td.MessageTopicForum(forumTopicId: threadId)
        : td.MessageTopicThread(messageThreadId: threadId);
    final options = sendOptions(silent: silent, schedule: schedule);
    final sent = <td.Message>[];
    // A caption longer than the server takes goes first as its own
    // message, as the official apps do.
    if (caption.trim().isNotEmpty && caption.length > await _captionLimit()) {
      sent.add(
        await _client.send(
          td.SendMessage(
            chatId: chatId,
            topicId: topic,
            replyTo: replyTo == null
                ? null
                : td.InputMessageReplyToMessage(
                    messageId: replyTo,
                    checklistTaskId: 0,
                    pollOptionId: '',
                  ),
            options: options,
            inputMessageContent: td.InputMessageText(
              text: td.FormattedText(text: caption, entities: captionEntities),
              clearDraft: false,
            ),
          ),
        ),
      );
      _add(sent.last);
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
        sent.add(
          await _client.send(
            td.SendMessage(
              chatId: chatId,
              topicId: topic,
              replyTo: reply,
              options: options,
              inputMessageContent: contents.single,
            ),
          ),
        );
        _add(sent.last);
      } else {
        final album = await _client.send(
          td.SendMessageAlbum(
            chatId: chatId,
            topicId: topic,
            replyTo: reply,
            options: options,
            inputMessageContents: contents,
          ),
        );
        album.messages.forEach(_add);
        sent.addAll(album.messages);
      }
    }
    return sent;
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
  /// The emoji reactions a message menu offers first, free ones only;
  /// custom emoji reactions come with [quickReactionTypes].
  Future<List<String>> quickReactions(
    int chatId,
    int messageId, {
    int limit = 8,
  }) async => _emojiOf(
    await _reactions(chatId, messageId, limit: limit, emojiOnly: true),
  );

  /// Every emoji reaction the user may put on a message, the ones offered
  /// first coming first, for the full picker; custom emoji reactions come
  /// with [allReactionTypes].
  Future<List<String>> allReactions(int chatId, int messageId) async =>
      _emojiOf(
        await _reactions(chatId, messageId, limit: null, emojiOnly: true),
      );

  /// The reactions a message menu offers first: emoji and custom emoji,
  /// free ones only, up to [limit].
  Future<List<td.ReactionType>> quickReactionTypes(
    int chatId,
    int messageId, {
    int limit = 8,
  }) => _reactions(chatId, messageId, limit: limit);

  /// Every reaction the user may put on a message, emoji and custom emoji,
  /// the ones offered first coming first.
  Future<List<td.ReactionType>> allReactionTypes(int chatId, int messageId) =>
      _reactions(chatId, messageId, limit: null);

  static List<String> _emojiOf(List<td.ReactionType> types) => [
    for (final type in types)
      if (type case td.ReactionTypeEmoji(:final emoji)) emoji,
  ];

  /// With [emojiOnly], custom emoji neither count nor show.
  Future<List<td.ReactionType>> _reactions(
    int chatId,
    int messageId, {
    required int? limit,
    bool emojiOnly = false,
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
    final types = <td.ReactionType>[];
    final seen = <Object>{};
    for (final reaction in [
      ...available.topReactions,
      ...available.recentReactions,
      ...available.popularReactions,
    ]) {
      if (types.length == limit) break;
      if (reaction.needsPremium) continue;
      final Object key;
      switch (reaction.type) {
        case td.ReactionTypeEmoji(:final emoji):
          key = emoji;
        case td.ReactionTypeCustomEmoji(:final customEmojiId) when !emojiOnly:
          key = customEmojiId;
        case _:
          continue;
      }
      if (seen.add(key)) types.add(reaction.type);
    }
    return types;
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
  Future<String> translate(int chatId, int messageId, String to) async =>
      (await translateFormatted(chatId, messageId, to)).text;

  /// Like [translate], keeping the entities, so links and formatting
  /// survive in the translation.
  Future<td.FormattedText> translateFormatted(
    int chatId,
    int messageId,
    String to,
  ) => _client.send(
    td.TranslateMessageText(
      chatId: chatId,
      messageId: messageId,
      toLanguageCode: to,
      tone: '',
    ),
  );

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
    for (final thread in _threads.toList()) {
      thread.handle(object);
    }
    for (final list in _topicLists.toList()) {
      list.handle(object);
    }
    for (final list in _savedLists.toList()) {
      list.handle(object);
    }
    for (final tags in _savedTagLists.toList()) {
      tags.handle(object);
    }
    switch (object) {
      case td.UpdateOption(
        name: 'my_id',
        value: td.OptionValueInteger(:final value),
      ):
        _myId = value;
      // Sender names and avatars on screen follow their changes.
      case td.UpdateUser(:final user):
        final sender = MessageSenderId.user(user.id);
        // updateUser also comes for status and other changes, so only a new
        // name, colour or photo is announced.
        final color = store.setColor(sender, user.accentColorId);
        final photo = store.setPhoto(sender, user.profilePhoto?.small);
        final name = store.setUserName(user.id, _nameOf(user));
        final bot = store.setBot(user.id, user.type is td.UserTypeBot);
        if (color || photo || name || bot) _notify();
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
          ..setHasScheduled(chat.id, chat.hasScheduledMessages)
          ..setReplyMarkupMessageId(chat.id, chat.replyMarkupMessageId)
          ..setChannel(chat.id, switch (chat.type) {
            td.ChatTypeSupergroup(:final isChannel) => isChannel,
            _ => false,
          })
          ..setChatType(chat.id, chat.type)
          ..setPermissions(chat.id, chat.permissions)
          ..setMessageSender(chat.id, chat.messageSenderId)
          ..setDraft(chat.id, chat.draftMessage)
          ..setMuteFor(chat.id, chat.notificationSettings.muteFor);
      case td.UpdateChatDraftMessage(:final chatId, :final draftMessage):
        if (store.setDraft(chatId, draftMessage)) _notify();
      case td.UpdateChatPermissions(:final chatId, :final permissions):
        if (store.setPermissions(chatId, permissions)) _notify();
      case td.UpdateChatMessageSender(:final chatId, :final messageSenderId):
        if (store.setMessageSender(chatId, messageSenderId)) _notify();
      case td.UpdateSupergroupFullInfo(
        :final supergroupId,
        :final supergroupFullInfo,
      ):
        store.setSlowMode(
          supergroupId,
          delay: supergroupFullInfo.slowModeDelay,
          expiresIn: supergroupFullInfo.slowModeDelayExpiresIn,
        );
        _setBotCommands(
          store.chatOfSupergroup(supergroupId),
          supergroupFullInfo.botCommands,
        );
        _notify();
      case td.UpdateBasicGroupFullInfo(
        :final basicGroupId,
        :final basicGroupFullInfo,
      ):
        if (_setBotCommands(
          store.chatOfBasicGroup(basicGroupId),
          basicGroupFullInfo.botCommands,
        )) {
          _notify();
        }
      case td.UpdateUserFullInfo(:final userId, :final userFullInfo):
        if (_setBotInfo(
          store.chatOfPrivateUser(userId),
          userId,
          userFullInfo.botInfo,
        )) {
          _notify();
        }
      case td.UpdateSupergroup(:final supergroup):
        final forum = store.setForum(supergroup.id, supergroup.isForum);
        if (store.setSupergroupStatus(supergroup.id, supergroup.status) !=
                null ||
            forum) {
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
        // The row keeps the key of the temporary message, so the timeline
        // swaps the ids under the same widgets instead of redrawing it.
        final pending = store.message(message.chatId, oldMessageId);
        store.remove(message.chatId, [oldMessageId]);
        _add(message, stableId: pending?.keyId ?? oldMessageId);
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
      case td.UpdateChatReplyMarkup(:final chatId, :final replyMarkupMessage):
        if (replyMarkupMessage != null) {
          store.addReferenced(ConversationMessage(replyMarkupMessage));
        }
        store.setReplyMarkupMessageId(chatId, replyMarkupMessage?.id ?? 0);
        _notify();
      case td.UpdatePoll(:final poll):
        if (store.patchPoll(poll)) _notify();
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
        store
          ..remove(chatId, messageIds)
          // Scheduled messages go the same way; a view of them reloads.
          ..bumpScheduled(chatId);
        _notify();
      case td.UpdateChatHasScheduledMessages(
        :final chatId,
        :final hasScheduledMessages,
      ):
        if (store.setHasScheduled(chatId, hasScheduledMessages)) _notify();
      default:
        return;
    }
  }

  void _add(td.Message message, {int? stableId}) {
    final chatId = message.chatId;
    // A scheduled message waits in the chat's scheduled list, not here.
    if (message.schedulingState != null) {
      store.bumpScheduled(chatId);
      _notify();
      return;
    }
    _arrivedDuringLoad[chatId]?.add(message.id);
    // A window around an older message has a gap after it; what arrives
    // beyond the gap waits for the newer pages.
    final newest = store.newestId(chatId);
    if (!store.reachedEnd(chatId) && newest != null && message.id > newest) {
      return;
    }
    store.upsert(ConversationMessage(message, stableId: stableId));
    _notify();
  }

  void _patch(int chatId, int messageId, Map<String, Object?> fields) {
    if (store.patch(chatId, messageId, fields)) _notify();
  }
}

String _nameOf(td.User user) =>
    [user.firstName, user.lastName].where((part) => part.isNotEmpty).join(' ');
