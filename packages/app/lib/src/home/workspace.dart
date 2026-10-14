import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

import '../session/providers.dart';

/// The chats the shell can open and search, backed by the session.
final chatDirectoryProvider = Provider<TelegramChatDirectory>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final directory = TelegramChatDirectory(
    session.chatLists.store,
    session.search,
    changes: session.chatLists.changes,
  );
  ref.onDispose(directory.dispose);
  return directory;
});

/// The window layout: tabs, split panes and the focused chat. A new
/// session (another account) starts with an empty window.
final workspaceControllerProvider = Provider<WorkspaceController>((ref) {
  final directory = ref.watch(chatDirectoryProvider);
  final controller = WorkspaceController();
  void noteFocused() {
    if (controller.value.focusedChat case final chat?) {
      directory.noteOpened(chat);
    }
  }

  controller.addListener(noteFocused);
  ref.onDispose(controller.dispose);
  return controller;
});

/// [ChatDirectory] over TDLib: titles from the chat list store, search
/// through TDLib's own chat and message search. Notifies when the store
/// changes, so tab titles follow renames.
class TelegramChatDirectory extends ChangeNotifier implements ChatDirectory {
  TelegramChatDirectory(this._store, this._search, {Stream<void>? changes}) {
    _changes = changes?.listen((_) => notifyListeners());
  }

  final ChatListStore _store;
  final ChatSearch _search;
  StreamSubscription<void>? _changes;

  /// Chats focused in this session, most recent first.
  final _recent = <int>[];

  static const _maxRecent = 20;

  /// Moves [chat] to the front of [recentChats].
  void noteOpened(int chat) {
    if (_recent.firstOrNull == chat) return;
    _recent
      ..remove(chat)
      ..insert(0, chat);
    if (_recent.length > _maxRecent) _recent.removeLast();
  }

  @override
  ChatSummary? chat(ChatId id) => switch (_store.chat(id)) {
    final entry? => _summary(entry),
    null => null,
  };

  /// Chats opened here first, then the top of the main list, as in the
  /// official client's empty search.
  @override
  List<ChatSummary> recentChats({int limit = 5}) {
    final ids = <int>{
      ..._recent,
      for (final entry in _store.chatsFor(const ChatListLocation.main()))
        entry.id,
    };
    return [for (final id in ids) ?chat(id)].take(limit).toList();
  }

  @override
  Future<List<ChatSummary>> searchChats(String query, {int limit = 8}) async {
    final ids = await _search.chats(query, limit: limit);
    return [for (final id in ids) ?chat(id)];
  }

  @override
  Future<List<MessageHit>> searchMessages(String query, {int limit = 8}) async {
    final found = await _search.messages(query, limit: limit);
    return [
      for (final message in found)
        MessageHit(
          chatId: message.chatId,
          messageId: message.messageId,
          text: message.text,
          chatTitle: _store.chat(message.chatId)?.title ?? '',
          isFile: message.isFile,
        ),
    ];
  }

  @override
  void dispose() {
    unawaited(_changes?.cancel());
    super.dispose();
  }

  static ChatSummary _summary(ChatListEntry entry) => ChatSummary(
    id: entry.id,
    title: entry.title,
    kind: entry.isGroup ? ChatKind.group : ChatKind.private,
    unread: entry.unreadCount,
  );
}
