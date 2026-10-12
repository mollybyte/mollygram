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

/// UI-ready metadata for a chat without message content or user profiles.
final class ChatListEntry {
  ChatListEntry({
    required this.id,
    required this.title,
    required this.unreadCount,
    required List<ChatListPosition> positions,
  }) : positions = List.unmodifiable(positions);

  final int id;
  final String title;
  final int unreadCount;
  final List<ChatListPosition> positions;

  ChatListPosition? positionFor(ChatListLocation list) {
    for (final position in positions) {
      if (position.list == list) return position;
    }
    return null;
  }

  ChatListEntry copyWith({
    String? title,
    int? unreadCount,
    List<ChatListPosition>? positions,
  }) => ChatListEntry(
    id: id,
    title: title ?? this.title,
    unreadCount: unreadCount ?? this.unreadCount,
    positions: positions ?? this.positions,
  );
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
/// TDLib defines ordering by `(position.order, chat.id)` descending, with
/// pinned chats first. This store makes that rule explicit rather than letting
/// each presentation layer implement its own sort.
final class ChatListStore {
  final _chats = <int, ChatListEntry>{};
  List<ChatFolder> _folders = const [];

  Iterable<ChatListEntry> get chats => _chats.values;
  List<ChatFolder> get folders => _folders;

  ChatListEntry? chat(int id) => _chats[id];

  void upsert(ChatListEntry chat) => _chats[chat.id] = chat;

  void updateTitle(int chatId, String title) {
    final chat = _chats[chatId];
    if (chat != null) _chats[chatId] = chat.copyWith(title: title);
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
      if (aPosition.isPinned != bPosition.isPinned) {
        return aPosition.isPinned ? -1 : 1;
      }
      final order = bPosition.order.compareTo(aPosition.order);
      return order != 0 ? order : b.id.compareTo(a.id);
    });
    return List.unmodifiable(result);
  }
}
