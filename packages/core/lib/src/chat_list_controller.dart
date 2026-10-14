import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'chat_list_store.dart';

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
  StreamSubscription<td.TdObject>? _subscription;

  /// Emits after an update changes [store].
  Stream<void> get changes => _changes.stream;

  /// Subscribes before requesting the first page, so no TDLib update is lost.
  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _client.updates.listen(_onUpdate);
    await loadMore();
  }

  /// Asks TDLib to emit the next page for [list].
  Future<void> loadMore([
    ChatListLocation list = const ChatListLocation.main(),
  ]) => _client.send(td.LoadChats(chatList: _toTdList(list), limit: 100));

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      case td.UpdateNewChat(:final chat):
        store.upsert(_entryFrom(chat));
      case td.UpdateChatTitle(:final chatId, :final title):
        store.updateTitle(chatId, title);
      case td.UpdateChatReadInbox(:final chatId, :final unreadCount):
        store.updateUnreadCount(chatId, unreadCount);
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

ChatListEntry _entryFrom(td.Chat chat) => ChatListEntry(
  id: chat.id,
  title: chat.title,
  unreadCount: chat.unreadCount,
  positions: _positionsFrom(chat.positions),
  lastMessage: _previewFrom(chat.lastMessage),
);

ChatPreview? _previewFrom(td.Message? message) {
  if (message == null) return null;
  final (kind, text) = switch (message.content) {
    td.MessageText(:final text) => (ChatPreviewKind.text, text.text),
    td.MessagePhoto(:final caption) => (ChatPreviewKind.photo, caption.text),
    td.MessageVideo(:final caption) => (ChatPreviewKind.video, caption.text),
    td.MessageVideoNote() => (ChatPreviewKind.videoNote, ''),
    td.MessageVoiceNote(:final caption) => (
      ChatPreviewKind.voiceNote,
      caption.text,
    ),
    td.MessageAudio(:final caption) => (ChatPreviewKind.audio, caption.text),
    td.MessageDocument(:final caption) => (
      ChatPreviewKind.document,
      caption.text,
    ),
    td.MessageSticker(:final sticker) => (
      ChatPreviewKind.sticker,
      sticker.emoji,
    ),
    td.MessageAnimation(:final caption) => (
      ChatPreviewKind.animation,
      caption.text,
    ),
    _ => (ChatPreviewKind.other, ''),
  };
  return ChatPreview(
    kind: kind,
    text: text,
    date: message.date,
    isOutgoing: message.isOutgoing,
  );
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
