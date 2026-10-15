import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'conversation_store.dart';

/// The tabs of a chat's shared media.
enum SharedMediaKind {
  /// Photos and videos.
  media,
  files,
  links,
  voice,
  music;

  td.SearchMessagesFilter get filter => switch (this) {
    media => const td.SearchMessagesFilterPhotoAndVideo(),
    files => const td.SearchMessagesFilterDocument(),
    links => const td.SearchMessagesFilterUrl(),
    voice => const td.SearchMessagesFilterVoiceNote(),
    music => const td.SearchMessagesFilterAudio(),
  };
}

/// One page of messages found in a chat, newest first.
final class ChatSearchPage {
  const ChatSearchPage({
    required this.messages,
    required this.totalCount,
    required this.nextFromMessageId,
  });

  final List<ConversationMessage> messages;

  /// TDLib's estimate of all matches; -1 when it does not know.
  final int totalCount;

  /// Where the next, older page starts; 0 when this was the last one.
  final int nextFromMessageId;

  bool get hasMore => nextFromMessageId != 0;
}

/// Searches inside one chat (`searchChatMessages`): by text for ⌘F, and by
/// kind for the shared media tabs.
final class ChatSearchController {
  ChatSearchController(this._client);

  final td.TdClient _client;

  /// Messages of [chatId] older than [fromMessageId] (0: from the newest)
  /// that contain [query], are of [kind] and, with [senderUserId], come
  /// from that user.
  Future<ChatSearchPage> search(
    int chatId, {
    String query = '',
    SharedMediaKind? kind,
    int? senderUserId,
    int fromMessageId = 0,
    int limit = 50,
  }) async {
    final found = await _client.send(
      td.SearchChatMessages(
        chatId: chatId,
        query: query,
        senderId: senderUserId == null
            ? null
            : td.MessageSenderUser(userId: senderUserId),
        fromMessageId: fromMessageId,
        offset: 0,
        limit: limit,
        filter: kind?.filter,
      ),
    );
    return ChatSearchPage(
      messages: [
        for (final message in found.messages) ConversationMessage(message),
      ],
      totalCount: found.totalCount,
      nextFromMessageId: found.nextFromMessageId,
    );
  }

  /// A text search in [chatId] to step through, newest result first.
  ChatSearchResults find(int chatId, String query, {int? senderUserId}) =>
      ChatSearchResults._(
        (from) => search(
          chatId,
          query: query,
          senderUserId: senderUserId,
          fromMessageId: from,
          limit: 30,
        ),
      );

  /// Every message of [kind] in [chatId], page by page.
  SharedMediaList sharedMedia(int chatId, SharedMediaKind kind) =>
      SharedMediaList._(
        (from) => search(chatId, kind: kind, fromMessageId: from),
      );
}

typedef _PageLoader = Future<ChatSearchPage> Function(int fromMessageId);

/// The results of one search in a chat, for the "3 of 12" counter and its
/// arrows. Results are ordered newest first: [older] moves up the chat,
/// [newer] back down. Pages load as the arrows reach the end.
final class ChatSearchResults {
  ChatSearchResults._(this._load);

  final _PageLoader _load;
  final _ids = <int>[];
  var _total = 0;
  var _next = 0;
  var _started = false;
  int? _index;
  Future<void>? _loading;

  /// Matches TDLib counts, at least the ones already loaded.
  int get count => _total > _ids.length ? _total : _ids.length;

  /// The result on screen, 0 for the newest; null when there is none.
  int? get index => _index;

  /// The message of the result on screen.
  int? get messageId => _index == null ? null : _ids[_index!];

  bool get hasOlder =>
      _index != null && (_index! + 1 < _ids.length || _next != 0);

  bool get hasNewer => _index != null && _index! > 0;

  /// Loads the first page and moves to the newest result. Returns its
  /// message, or null when nothing matches.
  Future<int?> start() async {
    if (!_started) {
      _started = true;
      await _loadPage();
    }
    _index = _ids.isEmpty ? null : 0;
    return messageId;
  }

  /// Moves to the next older result, loading a page when needed. Returns
  /// the message to show, or null when this is the oldest. Presses that
  /// come while a page loads are taken one after another.
  Future<int?> older() {
    final step = _steps.then((_) => _older());
    _steps = step.then((_) {}, onError: (Object _) {});
    return step;
  }

  Future<void> _steps = Future.value();

  Future<int?> _older() async {
    final index = _index;
    if (index == null) return null;
    if (index + 1 >= _ids.length) {
      if (_next == 0) return null;
      await _loadPage();
      if (index + 1 >= _ids.length) return null;
    }
    _index = index + 1;
    return messageId;
  }

  /// Moves to the next newer result; null when this is the newest.
  int? newer() {
    final index = _index;
    if (index == null || index == 0) return null;
    _index = index - 1;
    return messageId;
  }

  /// One page at a time, even when the arrow is pressed again meanwhile.
  Future<void> _loadPage() => _loading ??= () async {
    try {
      final page = await _load(_next);
      for (final message in page.messages) {
        if (!_ids.contains(message.id)) _ids.add(message.id);
      }
      _total = page.totalCount;
      _next = page.nextFromMessageId;
    } finally {
      _loading = null;
    }
  }();
}

/// The messages of one shared media tab, newest first, loaded a page at a
/// time as the list is scrolled.
final class SharedMediaList {
  SharedMediaList._(this._load);

  final _PageLoader _load;
  final _messages = <ConversationMessage>[];
  var _next = 0;
  var _total = -1;
  var _done = false;
  Future<bool>? _loading;

  List<ConversationMessage> get messages => List.unmodifiable(_messages);

  /// TDLib's count of all messages of the kind; -1 until a page is in.
  int get totalCount => _total;

  /// Whether every message is loaded.
  bool get isComplete => _done;

  /// Loads the next older page. Returns whether anything was added.
  Future<bool> loadMore() {
    if (_done) return Future.value(false);
    return _loading ??= () async {
      try {
        final page = await _load(_next);
        final before = _messages.length;
        final known = {for (final m in _messages) m.id};
        _messages.addAll([
          for (final m in page.messages)
            if (known.add(m.id)) m,
        ]);
        _total = page.totalCount;
        _next = page.nextFromMessageId;
        _done = !page.hasMore;
        return _messages.length > before;
      } finally {
        _loading = null;
      }
    }();
  }
}
