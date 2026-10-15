import 'dart:async';
import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'chat_list_store.dart';
import 'message_content.dart';

/// Keeps [ChatListStore] synchronized with TDLib's incremental chat updates.
///
/// TDLib requires callers to load chats with `loadChats` and retain subsequent
/// updates. This controller follows that protocol and deliberately doesn't use
/// `getChats`, whose result is only informational.
final class ChatListController {
  ChatListController(this._client, {ChatListStore? store})
    : store = store ?? ChatListStore();

  final td.TdClient _client;
  final ChatListStore store;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _loading = <ChatListLocation, Future<void>>{};
  final _exhausted = <ChatListLocation>{};
  final _notificationSettings = <int, td.ChatNotificationSettings>{};
  StreamSubscription<td.TdObject>? _subscription;
  var _started = false;

  /// Emits after an update changes [store].
  Stream<void> get changes => _changes.stream;

  /// Starts following updates without loading chats, so settings TDLib
  /// sends right after sign-in (default mute, unread counters) are kept.
  void listen() => _subscription ??= _client.updates.listen(_onUpdate);

  /// Subscribes before requesting the first page, so no TDLib update is lost.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    listen();
    await loadMore();
  }

  /// Whether TDLib may have more chats for [list] than it has sent so far.
  bool hasMore([ChatListLocation list = const ChatListLocation.main()]) =>
      !_exhausted.contains(list);

  /// Asks TDLib to emit the next page for [list].
  ///
  /// A page can be shorter than the limit before the end, so callers keep
  /// asking while [hasMore] is true (the sidebar does as it is scrolled).
  /// TDLib answers 404 once every chat is loaded. Calls made while a page is
  /// loading share it.
  Future<void> loadMore([
    ChatListLocation list = const ChatListLocation.main(),
  ]) {
    if (_exhausted.contains(list)) return Future.value();
    return _loading[list] ??= _loadPage(list).whenComplete(() {
      _loading.remove(list);
    });
  }

  /// Asks TDLib for one chat, such as a chat restored from a saved window
  /// layout before the list has loaded it. TDLib sends `updateNewChat`
  /// first, so the chat is in [store] once this returns true. Returns false
  /// when the chat no longer exists or is not accessible.
  Future<bool> loadChat(int chatId) async {
    try {
      await _client.send(td.GetChat(chatId: chatId));
      return true;
    } on td.TdException {
      return false;
    }
  }

  Future<void> _loadPage(ChatListLocation list) async {
    try {
      await _client.send(td.LoadChats(chatList: _toTdList(list), limit: 100));
    } on td.TdException catch (error) {
      if (error.code != 404) rethrow;
      _exhausted.add(list);
    }
    // The page itself arrives as updates; this lets a list that still
    // ends on screen ask for the next one.
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Mute for this long; anything over a year means forever to TDLib.
  static const muteForever = Duration(days: 366 * 5);

  /// Pins or unpins [chatId] at the top of [list].
  Future<void> setPinned(int chatId, ChatListLocation list, bool pinned) =>
      _client.send(
        td.ToggleChatIsPinned(
          chatList: _toTdList(list) ?? const td.ChatListMain(),
          chatId: chatId,
          isPinned: pinned,
        ),
      );

  /// Mutes [chatId] for [duration], or unmutes it when [duration] is null.
  ///
  /// The chat stops following the default for its scope either way, so
  /// unmuting works in a scope that is muted by default.
  Future<void> setMuted(int chatId, Duration? duration) async {
    final current = _notificationSettings[chatId];
    if (current == null) return;
    final muteFor = duration == null
        ? 0
        : duration.inSeconds.clamp(1, muteForever.inSeconds);
    await _client.send(
      td.SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: _withMuteFor(current, muteFor),
      ),
    );
  }

  /// Moves [chatId] to the archive, or back to the main list.
  Future<void> setArchived(int chatId, bool archived) => _client.send(
    td.AddChatToList(
      chatId: chatId,
      chatList: archived ? const td.ChatListArchive() : const td.ChatListMain(),
    ),
  );

  /// Reads everything in [chatId] without opening it: the messages, the
  /// mentions and reactions, and the user's own unread mark.
  Future<void> markAsRead(int chatId) async {
    final chat = store.chat(chatId);
    if (chat == null) return;
    await Future.wait([
      if (chat.lastMessage case final last? when last.messageId != 0)
        _client.send(
          td.ViewMessages(
            chatId: chatId,
            messageIds: [last.messageId],
            source: const td.MessageSourceChatList(),
            forceRead: true,
          ),
        ),
      if (chat.unreadMentionCount > 0)
        _client.send(td.ReadAllChatMentions(chatId: chatId)),
      if (chat.unreadReactionCount > 0)
        _client.send(td.ReadAllChatReactions(chatId: chatId)),
      if (chat.isMarkedAsUnread)
        _client.send(
          td.ToggleChatIsMarkedAsUnread(
            chatId: chatId,
            isMarkedAsUnread: false,
          ),
        ),
    ]);
  }

  /// Reads every chat in [list], such as the whole archive.
  Future<void> markListAsRead(ChatListLocation list) => _client.send(
    td.ReadChatList(chatList: _toTdList(list) ?? const td.ChatListMain()),
  );

  Future<void> markAsUnread(int chatId) => _client.send(
    td.ToggleChatIsMarkedAsUnread(chatId: chatId, isMarkedAsUnread: true),
  );

  /// Deletes the messages of [chatId] but keeps the chat; [forEveryone]
  /// deletes them for the other side too where allowed.
  Future<void> clearHistory(int chatId, {bool forEveryone = false}) =>
      _client.send(
        td.DeleteChatHistory(
          chatId: chatId,
          removeFromChatList: false,
          revoke: forEveryone,
        ),
      );

  /// Removes [chatId] from the list: deletes a private chat (for both
  /// sides when [forEveryone]), closes a secret chat, or leaves a group or
  /// channel.
  Future<void> deleteChat(int chatId, {bool forEveryone = false}) async {
    final chat = store.chat(chatId);
    if (chat == null) return;
    switch (chat.type) {
      case ChatType.private:
        break;
      case ChatType.secret:
        await _client.send(td.CloseSecretChat(secretChatId: chat.secretChatId));
      case ChatType.basicGroup:
        // A basic group stays in the list after leaving until its history
        // is deleted too.
        await _client.send(td.LeaveChat(chatId: chatId));
      case ChatType.supergroup || ChatType.channel:
        await _client.send(td.LeaveChat(chatId: chatId));
        return;
    }
    await _client.send(
      td.DeleteChatHistory(
        chatId: chatId,
        removeFromChatList: true,
        revoke: forEveryone && chat.canDeleteForAll,
      ),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      case td.UpdateNewChat(:final chat):
        _notificationSettings[chat.id] = chat.notificationSettings;
        store.upsert(_entryFrom(chat));
      case td.UpdateChatNotificationSettings(
        :final chatId,
        :final notificationSettings,
      ):
        _notificationSettings[chatId] = notificationSettings;
        store.update(
          chatId,
          (chat) =>
              chat.copyWith(muteFor: () => _muteFor(notificationSettings)),
        );
      case td.UpdateScopeNotificationSettings(
        :final scope,
        :final notificationSettings,
      ):
        store.updateScopeMuted(switch (scope) {
          td.NotificationSettingsScopePrivateChats() =>
            NotificationScope.privateChats,
          td.NotificationSettingsScopeGroupChats() => NotificationScope.groups,
          td.NotificationSettingsScopeChannelChats() =>
            NotificationScope.channels,
        }, notificationSettings.muteFor > 0);
      case td.UpdateChatIsMarkedAsUnread(
        :final chatId,
        :final isMarkedAsUnread,
      ):
        store.update(
          chatId,
          (chat) => chat.copyWith(isMarkedAsUnread: isMarkedAsUnread),
        );
      case td.UpdateChatUnreadMentionCount(
            :final chatId,
            :final unreadMentionCount,
          ) ||
          td.UpdateMessageMentionRead(:final chatId, :final unreadMentionCount):
        store.update(
          chatId,
          (chat) => chat.copyWith(unreadMentionCount: unreadMentionCount),
        );
      case td.UpdateChatUnreadReactionCount(
            :final chatId,
            :final unreadReactionCount,
          ) ||
          td.UpdateMessageUnreadReactions(
            :final chatId,
            :final unreadReactionCount,
          ):
        store.update(
          chatId,
          (chat) => chat.copyWith(unreadReactionCount: unreadReactionCount),
        );
      case td.UpdateUnreadChatCount(
        :final chatList,
        :final unreadCount,
        :final unreadUnmutedCount,
      ):
        store.updateUnreadChats(
          _locationFrom(chatList),
          UnreadChatCount(
            unread: unreadCount,
            unreadUnmuted: unreadUnmutedCount,
          ),
        );
      case td.UpdateChatTitle(:final chatId, :final title):
        store.updateTitle(chatId, title);
      case td.UpdateChatPhoto(:final chatId, :final photo):
        store.updatePhoto(chatId, photo);
      case td.UpdateChatReadInbox(:final chatId, :final unreadCount):
        store.updateUnreadCount(chatId, unreadCount);
      case td.UpdateChatReadOutbox(
        :final chatId,
        :final lastReadOutboxMessageId,
      ):
        store.update(
          chatId,
          (chat) =>
              chat.copyWith(lastReadOutboxMessageId: lastReadOutboxMessageId),
        );
      case td.UpdateChatLastMessage(
        :final chatId,
        :final lastMessage,
        :final positions,
      ):
        store.updateLastMessage(
          chatId,
          _previewFrom(lastMessage),
          _positionsFrom(positions),
        );
      // A draft change can move a chat and is sent instead of
      // updateChatPosition, so its positions are applied too.
      case td.UpdateChatDraftMessage(
        :final chatId,
        :final draftMessage,
        :final positions,
      ):
        store.updateDraft(
          chatId,
          _draftFrom(draftMessage),
          _positionsFrom(positions),
        );
      case td.UpdateChatPosition(:final chatId, :final position):
        store.updatePosition(chatId, _positionFrom(position));
      case td.UpdateChatRemovedFromList(:final chatId, :final chatList):
        store.removeFromList(chatId, _locationFrom(chatList));
      case td.UpdateChatFolders(:final chatFolders):
        store.replaceFolders([
          for (final folder in chatFolders)
            ChatFolder(
              id: folder.id,
              title: folder.name.text.text,
              iconName: folder.icon.name,
            ),
        ]);
      default:
        return;
    }
    _changes.add(null);
  }
}

ChatListEntry _entryFrom(td.Chat chat) {
  final (type, peerId, secretChatId) = switch (chat.type) {
    td.ChatTypePrivate(:final userId) => (ChatType.private, userId, 0),
    td.ChatTypeSecret(:final userId, :final secretChatId) => (
      ChatType.secret,
      userId,
      secretChatId,
    ),
    td.ChatTypeBasicGroup(:final basicGroupId) => (
      ChatType.basicGroup,
      basicGroupId,
      0,
    ),
    td.ChatTypeSupergroup(:final supergroupId, :final isChannel) => (
      isChannel ? ChatType.channel : ChatType.supergroup,
      supergroupId,
      0,
    ),
  };
  return ChatListEntry(
    id: chat.id,
    title: chat.title,
    type: type,
    peerId: peerId,
    secretChatId: secretChatId,
    unreadCount: chat.unreadCount,
    unreadMentionCount: chat.unreadMentionCount,
    unreadReactionCount: chat.unreadReactionCount,
    isMarkedAsUnread: chat.isMarkedAsUnread,
    muteFor: _muteFor(chat.notificationSettings),
    canDeleteForAll: chat.canBeDeletedForAllUsers,
    canDeleteOnlyForSelf: chat.canBeDeletedOnlyForSelf,
    photo: chat.photo,
    positions: _positionsFrom(chat.positions),
    lastMessage: _previewFrom(chat.lastMessage),
    draft: _draftFrom(chat.draftMessage),
    lastReadOutboxMessageId: chat.lastReadOutboxMessageId,
  );
}

int? _muteFor(td.ChatNotificationSettings settings) =>
    settings.useDefaultMuteFor ? null : settings.muteFor;

td.ChatNotificationSettings _withMuteFor(
  td.ChatNotificationSettings s,
  int muteFor,
) => td.ChatNotificationSettings(
  useDefaultMuteFor: false,
  muteFor: muteFor,
  useDefaultSound: s.useDefaultSound,
  soundId: s.soundId,
  useDefaultShowPreview: s.useDefaultShowPreview,
  showPreview: s.showPreview,
  useDefaultMuteStories: s.useDefaultMuteStories,
  muteStories: s.muteStories,
  useDefaultStorySound: s.useDefaultStorySound,
  storySoundId: s.storySoundId,
  useDefaultShowStoryPoster: s.useDefaultShowStoryPoster,
  showStoryPoster: s.showStoryPoster,
  useDefaultDisablePinnedMessageNotifications:
      s.useDefaultDisablePinnedMessageNotifications,
  disablePinnedMessageNotifications: s.disablePinnedMessageNotifications,
  useDefaultDisableMentionNotifications:
      s.useDefaultDisableMentionNotifications,
  disableMentionNotifications: s.disableMentionNotifications,
);

ChatDraft? _draftFrom(td.DraftMessage? draft) {
  if (draft == null) return null;
  final (text, kind) = switch (draft.content) {
    td.DraftMessageContentText(:final text) => (
      text.text,
      ChatPreviewKind.text,
    ),
    td.DraftMessageContentVoiceNote() => ('', ChatPreviewKind.voiceNote),
    td.DraftMessageContentVideoNote() => ('', ChatPreviewKind.videoNote),
    _ => ('', ChatPreviewKind.other),
  };
  return ChatDraft(text: text, date: draft.date, kind: kind);
}

ChatPreview? _previewFrom(td.Message? message) {
  if (message == null) return null;
  final (kind, text) = summarizeContent(message.content);
  return ChatPreview(
    messageId: message.id,
    kind: kind,
    text: text,
    date: message.date,
    isOutgoing: message.isOutgoing,
    senderUserId: switch (message.senderId) {
      td.MessageSenderUser(:final userId) => userId,
      td.MessageSenderChat() => 0,
    },
    senderChatId: switch (message.senderId) {
      td.MessageSenderChat(:final chatId) => chatId,
      td.MessageSenderUser() => 0,
    },
    thumbnail: _thumbnailOf(message.content),
    sendState: switch (message.sendingState) {
      td.MessageSendingStatePending() => PreviewSendState.sending,
      td.MessageSendingStateFailed() => PreviewSendState.failed,
      null => PreviewSendState.sent,
    },
    fileName: switch (message.content) {
      td.MessageDocument(:final document) => document.fileName,
      td.MessageAudio(:final audio) =>
        audio.title.isNotEmpty && audio.performer.isNotEmpty
            ? '${audio.performer} – ${audio.title}'
            : audio.title.isNotEmpty
            ? audio.title
            : audio.fileName,
      _ => '',
    },
    topicId: switch (message.topicId) {
      td.MessageTopicForum(:final forumTopicId) => forumTopicId,
      _ => 0,
    },
  );
}

/// The minithumbnail a chat-list row shows beside the text: photos,
/// videos, GIFs, round videos and documents that have one. Media behind a
/// spoiler or in a self-destructing message keep their secret.
Uint8List? _thumbnailOf(td.MessageContent content) {
  final mini = switch (content) {
    td.MessagePhoto(:final photo, hasSpoiler: false, isSecret: false) =>
      photo.minithumbnail,
    td.MessageVideo(:final video, hasSpoiler: false, isSecret: false) =>
      video.minithumbnail,
    td.MessageAnimation(:final animation, hasSpoiler: false, isSecret: false) =>
      animation.minithumbnail,
    td.MessageVideoNote(:final videoNote, isSecret: false) =>
      videoNote.minithumbnail,
    td.MessageDocument(:final document) => document.minithumbnail,
    _ => null,
  };
  return mini?.data;
}

List<ChatListPosition> _positionsFrom(List<td.ChatPosition> positions) => [
  for (final position in positions) _positionFrom(position),
];

ChatListPosition _positionFrom(td.ChatPosition position) => ChatListPosition(
  list: _locationFrom(position.list),
  order: position.order,
  isPinned: position.isPinned,
);

ChatListLocation _locationFrom(td.ChatList list) => switch (list) {
  td.ChatListMain() => const ChatListLocation.main(),
  td.ChatListArchive() => const ChatListLocation.archive(),
  td.ChatListFolder(:final chatFolderId) => ChatListLocation.folder(
    chatFolderId,
  ),
};

td.ChatList? _toTdList(ChatListLocation list) => switch (list.folderId) {
  null => null,
  -1 => const td.ChatListArchive(),
  final id => td.ChatListFolder(chatFolderId: id),
};
