import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A chat-list identity used by TDLib for the main list, archive, or a folder.
final class ChatListLocation {
  const ChatListLocation._(this.folderId);

  const ChatListLocation.main() : this._(null);
  const ChatListLocation.archive() : this._(-1);
  const ChatListLocation.folder(int id) : this._(id);

  /// `null` is the main list; `-1` is the archive; other values are folders.
  final int? folderId;

  bool get isMain => folderId == null;
  bool get isArchive => folderId == -1;
  bool get isFolder => folderId != null && folderId! >= 0;

  @override
  bool operator ==(Object other) =>
      other is ChatListLocation && other.folderId == folderId;

  @override
  int get hashCode => folderId.hashCode;
}

/// A single TDLib position of a chat within one chat list.
final class ChatListPosition {
  const ChatListPosition({
    required this.list,
    required this.order,
    required this.isPinned,
  });

  final ChatListLocation list;
  final int order;
  final bool isPinned;
}

/// What the last message is, so the UI can label media in its own language.
enum ChatPreviewKind {
  text,
  photo,
  video,
  videoNote,
  voiceNote,
  audio,
  document,
  sticker,
  animation,
  other,
}

/// The last message of a chat, reduced to what a chat-list row shows.
final class ChatPreview {
  const ChatPreview({
    this.messageId = 0,
    required this.kind,
    required this.text,
    required this.date,
    required this.isOutgoing,
    this.senderUserId = 0,
    this.senderChatId = 0,
    this.thumbnail,
    this.sendState = PreviewSendState.sent,
    this.fileName = '',
    this.topicId = 0,
  });

  /// The message, for reading the chat up to it; 0 when unknown.
  final int messageId;
  final ChatPreviewKind kind;

  /// Message text or media caption; empty when there is none.
  final String text;

  /// Unix time in seconds.
  final int date;
  final bool isOutgoing;

  /// The user who sent it; 0 when a chat sent it (see [senderChatId]).
  final int senderUserId;

  /// The chat that sent it, such as a channel posting in its discussion
  /// group or an anonymous admin; 0 when a user sent it.
  final int senderChatId;

  /// A tiny JPEG of the photo, video or GIF, for a thumbnail beside the
  /// text; null for other messages and for media behind a spoiler.
  final Uint8List? thumbnail;

  /// Whether an outgoing message is still on its way or failed.
  final PreviewSendState sendState;

  /// What a file or a song is called, shown in place of its kind: the
  /// file's name, or "Performer – Title"; empty for other messages.
  final String fileName;

  /// The forum topic the message is in; 0 outside forums.
  final int topicId;
}

/// Where an outgoing last message is: on its way, failed, or with the
/// server (read or not is decided by the chat's read-outbox mark).
enum PreviewSendState { sending, failed, sent }

/// The unsent draft of a chat, as the chat list shows it.
final class ChatDraft {
  const ChatDraft({
    required this.text,
    required this.date,
    this.kind = ChatPreviewKind.text,
  });

  /// What the draft holds when it is not text, such as a voice note.
  final ChatPreviewKind kind;

  /// The draft's text; empty for a draft that is only a reply.
  final String text;

  /// Unix time in seconds.
  final int date;
}

/// What kind of chat a chat-list entry is.
enum ChatType {
  /// A one-to-one chat with a user or a bot, including Saved Messages.
  private,

  /// An end-to-end encrypted chat with a user.
  secret,

  basicGroup,
  supergroup,
  channel;

  bool get isGroup => this == basicGroup || this == supergroup;
  bool get isPrivate => this == private || this == secret;

  /// The default notification settings the chat follows.
  NotificationScope get scope => switch (this) {
    private || secret => NotificationScope.privateChats,
    basicGroup || supergroup => NotificationScope.groups,
    channel => NotificationScope.channels,
  };
}

/// The groups of chats that share default notification settings.
enum NotificationScope { privateChats, groups, channels }

/// UI-ready metadata for a chat without message content or user profiles.
final class ChatListEntry {
  ChatListEntry({
    required this.id,
    required this.title,
    required this.unreadCount,
    required List<ChatListPosition> positions,
    this.lastMessage,
    this.draft,
    this.type = ChatType.private,
    this.peerId = 0,
    this.secretChatId = 0,
    this.unreadMentionCount = 0,
    this.unreadReactionCount = 0,
    this.isMarkedAsUnread = false,
    this.muteFor,
    this.mutedByDefault = false,
    this.canDeleteForAll = false,
    this.canDeleteOnlyForSelf = false,
    this.photo,
    this.lastReadOutboxMessageId = 0,
  }) : positions = List.unmodifiable(positions);

  final int id;
  final String title;

  /// The chat photo (a 160 px `small` file and a blurred minithumbnail), or
  /// null when the chat has none and a monogram stands in.
  final td.ChatPhotoInfo? photo;
  final ChatType type;

  /// The user of a private or secret chat, or the basic group or
  /// supergroup behind a group or channel.
  final int peerId;

  /// The secret chat behind a [ChatType.secret] chat; 0 otherwise.
  final int secretChatId;
  final int unreadCount;
  final int unreadMentionCount;
  final int unreadReactionCount;

  /// The user marked the chat as unread from the context menu.
  final bool isMarkedAsUnread;

  /// Seconds left before notifications come back, as set for this chat;
  /// null when the chat follows the default for its [NotificationScope].
  final int? muteFor;

  /// Whether the default for this chat's scope is muted.
  final bool mutedByDefault;

  /// The history can be deleted for everyone, or only for the user.
  final bool canDeleteForAll;
  final bool canDeleteOnlyForSelf;
  final List<ChatListPosition> positions;
  final ChatPreview? lastMessage;

  /// The unsent draft, shown in place of [lastMessage].
  final ChatDraft? draft;

  /// The newest outgoing message the other side has read.
  final int lastReadOutboxMessageId;

  /// The user's own last message has been read: two ticks in the list.
  bool get lastMessageRead => switch (lastMessage) {
    final last? when last.isOutgoing && last.messageId != 0 =>
      last.messageId <= lastReadOutboxMessageId,
    _ => false,
  };

  /// A basic group or a supergroup that is not a channel: incoming messages
  /// come from different people, so they show the sender's name.
  bool get isGroup => type.isGroup;

  bool get isMuted => muteFor == null ? mutedByDefault : muteFor! > 0;

  /// Shown as unread in the list: unread messages or the user's own mark.
  bool get isUnread => unreadCount > 0 || isMarkedAsUnread;

  ChatListPosition? positionFor(ChatListLocation list) {
    for (final position in positions) {
      if (position.list == list) return position;
    }
    return null;
  }

  bool isPinnedIn(ChatListLocation list) =>
      positionFor(list)?.isPinned ?? false;

  bool get isArchived => positionFor(const ChatListLocation.archive()) != null;

  ChatListEntry copyWith({
    String? title,
    int? unreadCount,
    int? unreadMentionCount,
    int? unreadReactionCount,
    bool? isMarkedAsUnread,
    int? Function()? muteFor,
    bool? mutedByDefault,
    bool? canDeleteForAll,
    bool? canDeleteOnlyForSelf,
    List<ChatListPosition>? positions,
    ChatPreview? Function()? lastMessage,
    td.ChatPhotoInfo? Function()? photo,
    ChatDraft? Function()? draft,
    int? lastReadOutboxMessageId,
  }) => ChatListEntry(
    id: id,
    title: title ?? this.title,
    type: type,
    photo: photo == null ? this.photo : photo(),
    peerId: peerId,
    secretChatId: secretChatId,
    unreadCount: unreadCount ?? this.unreadCount,
    unreadMentionCount: unreadMentionCount ?? this.unreadMentionCount,
    unreadReactionCount: unreadReactionCount ?? this.unreadReactionCount,
    isMarkedAsUnread: isMarkedAsUnread ?? this.isMarkedAsUnread,
    muteFor: muteFor == null ? this.muteFor : muteFor(),
    mutedByDefault: mutedByDefault ?? this.mutedByDefault,
    canDeleteForAll: canDeleteForAll ?? this.canDeleteForAll,
    canDeleteOnlyForSelf: canDeleteOnlyForSelf ?? this.canDeleteOnlyForSelf,
    positions: positions ?? this.positions,
    lastMessage: lastMessage == null ? this.lastMessage : lastMessage(),
    draft: draft == null ? this.draft : draft(),
    lastReadOutboxMessageId:
        lastReadOutboxMessageId ?? this.lastReadOutboxMessageId,
  );
}

/// How many chats of a list are unread, from `updateUnreadChatCount`.
final class UnreadChatCount {
  const UnreadChatCount({required this.unread, required this.unreadUnmuted});

  static const zero = UnreadChatCount(unread: 0, unreadUnmuted: 0);

  /// Unread chats, including those marked as unread.
  final int unread;

  /// Of them, the chats that are not muted.
  final int unreadUnmuted;
}

/// Basic folder metadata supplied by TDLib's `updateChatFolders` update.
final class ChatFolder {
  const ChatFolder({
    required this.id,
    required this.title,
    required this.iconName,
  });

  final int id;
  final String title;
  final String iconName;
}

/// In-memory projection of TDLib's chat-list updates.
///
/// TDLib defines ordering by `(position.order, chat.id)` descending and
/// nothing else: pinned chats already have the largest orders. This store
/// makes that rule explicit rather than letting each presentation layer
/// implement its own sort.
final class ChatListStore {
  final _chats = <int, ChatListEntry>{};
  final _scopeMuted = <NotificationScope, bool>{};
  final _unreadChats = <ChatListLocation, UnreadChatCount>{};
  List<ChatFolder> _folders = const [];

  Iterable<ChatListEntry> get chats => _chats.values;
  List<ChatFolder> get folders => _folders;

  ChatListEntry? chat(int id) => _chats[id];

  void upsert(ChatListEntry chat) => _chats[chat.id] = chat.copyWith(
    mutedByDefault: _scopeMuted[chat.type.scope] ?? chat.mutedByDefault,
  );

  /// Applies a change to one chat, if the store has it.
  void update(int chatId, ChatListEntry Function(ChatListEntry chat) change) {
    final chat = _chats[chatId];
    if (chat != null) _chats[chatId] = change(chat);
  }

  /// Sets whether chats of [scope] that follow the default are muted.
  void updateScopeMuted(NotificationScope scope, bool muted) {
    _scopeMuted[scope] = muted;
    for (final chat in _chats.values.toList()) {
      if (chat.type.scope == scope && chat.mutedByDefault != muted) {
        _chats[chat.id] = chat.copyWith(mutedByDefault: muted);
      }
    }
  }

  /// Unread chats in [list], as TDLib counts them; zero until it says.
  UnreadChatCount unreadChatsIn(ChatListLocation list) =>
      _unreadChats[list] ?? UnreadChatCount.zero;

  void updateUnreadChats(ChatListLocation list, UnreadChatCount count) =>
      _unreadChats[list] = count;

  void updateTitle(int chatId, String title) {
    final chat = _chats[chatId];
    if (chat != null) _chats[chatId] = chat.copyWith(title: title);
  }

  void updatePhoto(int chatId, td.ChatPhotoInfo? photo) {
    final chat = _chats[chatId];
    if (chat != null) _chats[chatId] = chat.copyWith(photo: () => photo);
  }

  void updateUnreadCount(int chatId, int unreadCount) {
    final chat = _chats[chatId];
    if (chat != null) {
      _chats[chatId] = chat.copyWith(unreadCount: unreadCount);
    }
  }

  void replacePositions(int chatId, List<ChatListPosition> positions) {
    final chat = _chats[chatId];
    if (chat != null) _chats[chatId] = chat.copyWith(positions: positions);
  }

  /// A draft change comes with the chat's positions, as it can move it.
  void updateDraft(
    int chatId,
    ChatDraft? draft,
    List<ChatListPosition> positions,
  ) {
    final chat = _chats[chatId];
    if (chat == null) return;
    // TDLib may send an old draft after the user has changed it; a draft
    // older than the one shown is stale.
    final shown = chat.draft;
    if (draft != null && shown != null && draft.date < shown.date) {
      _chats[chatId] = chat.copyWith(positions: positions);
      return;
    }
    _chats[chatId] = chat.copyWith(positions: positions, draft: () => draft);
  }

  void updateLastMessage(
    int chatId,
    ChatPreview? lastMessage,
    List<ChatListPosition> positions,
  ) {
    final chat = _chats[chatId];
    if (chat == null) return;
    _chats[chatId] = chat.copyWith(
      positions: positions,
      lastMessage: () => lastMessage,
    );
  }

  void updatePosition(int chatId, ChatListPosition position) {
    final chat = _chats[chatId];
    if (chat == null) return;
    final positions = [
      for (final existing in chat.positions)
        if (existing.list != position.list) existing,
      if (position.order != 0) position,
    ];
    _chats[chatId] = chat.copyWith(positions: positions);
  }

  void removeFromList(int chatId, ChatListLocation list) {
    final chat = _chats[chatId];
    if (chat == null) return;
    _chats[chatId] = chat.copyWith(
      positions: [
        for (final position in chat.positions)
          if (position.list != list) position,
      ],
    );
  }

  void replaceFolders(List<ChatFolder> folders) {
    _folders = List.unmodifiable(folders);
  }

  List<ChatListEntry> chatsFor(ChatListLocation list) {
    final result = [
      for (final chat in _chats.values)
        if (chat.positionFor(list) case final position? when position.order > 0)
          chat,
    ];
    result.sort((a, b) {
      final aPosition = a.positionFor(list)!;
      final bPosition = b.positionFor(list)!;
      final order = bPosition.order.compareTo(aPosition.order);
      return order != 0 ? order : b.id.compareTo(a.id);
    });
    return List.unmodifiable(result);
  }
}
