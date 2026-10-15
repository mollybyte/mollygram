import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

import '../session/providers.dart';
import 'workspace_storage.dart';

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

/// Whether TDLib still has a chat; loads it when the list hasn't yet.
final chatLoaderProvider = Provider<Future<bool> Function(int chatId)>((ref) {
  final chatLists = ref.watch(telegramSessionProvider).requireValue.chatLists;
  return chatLists.loadChat;
});

/// The window layout: tabs, split panes and the focused chat.
///
/// The layout is saved as it changes and restored on the next launch,
/// without chats that are gone. Anything the user opens before the saved
/// layout is read wins over it.
final workspaceControllerProvider = Provider<WorkspaceController>((ref) {
  final directory = ref.watch(chatDirectoryProvider);
  final saver = ref.watch(workspaceSaverProvider);
  final loadChat = ref.watch(chatLoaderProvider);
  final controller = WorkspaceController();
  var disposed = false;
  var restoring = true;
  var applyingRestore = false;

  void onChange() {
    if (controller.value.focusedChat case final chat?) {
      directory.noteOpened(chat);
    }
    if (applyingRestore) return;
    // The user got there first: their layout is the one to keep.
    restoring = false;
    saver.schedule(controller.value.toJson());
  }

  Future<void> restore() async {
    final saved = Workspace.fromJson(await saver.read());
    final chats = {
      for (final tab in saved.tabs)
        for (final chat in tab.panes) ?chat,
    };
    final known = await Future.wait(chats.map(loadChat));
    if (disposed || !restoring) return;
    var workspace = saved;
    for (final (i, chat) in chats.indexed) {
      if (!known[i]) workspace = workspace.removeChat(chat);
    }
    applyingRestore = true;
    controller.value = workspace;
    applyingRestore = false;
    restoring = false;
  }

  controller.addListener(onChange);
  unawaited(restore().catchError((Object _) => restoring = false));
  ref.onDispose(() {
    disposed = true;
    unawaited(saver.flush());
    controller.dispose();
  });
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
    kind: switch (entry.type) {
      ChatType.basicGroup || ChatType.supergroup => ChatKind.group,
      ChatType.channel => ChatKind.channel,
      ChatType.private || ChatType.secret => ChatKind.private,
    },
    unread: entry.unreadCount,
  );
}
