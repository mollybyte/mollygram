import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The chats the user's Saved Messages came from, as TDLib groups them:
/// own notes, a hidden author and one topic per source chat, pinned ones
/// first, then newest activity first. TDLib hands the topics over
/// through `updateSavedMessagesTopic` once [load] asks for them, and
/// keeps them current the same way.
///
/// Made by `ConversationController.openSavedTopics`, which feeds it
/// updates until [dispose].
final class SavedTopicList {
  SavedTopicList(this._client, {required this._onDispose});

  final td.TdClient _client;
  final void Function(SavedTopicList) _onDispose;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _topics = <int, td.SavedMessagesTopic>{};
  var _reachedEnd = false;
  var _loading = false;
  var _disposed = false;

  static const _page = 100;

  Stream<void> get changes => _changes.stream;

  /// Pinned topics first, then by TDLib's order, newest activity first.
  List<td.SavedMessagesTopic> get topics {
    final list = _topics.values.toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.order.compareTo(a.order);
      });
    return list;
  }

  bool get reachedEnd => _reachedEnd;

  /// Asks TDLib for the first page of topics; they arrive as updates.
  Future<void> load() => _load();

  /// Asks for the page after the last one, once.
  Future<void> loadMore() => _load();

  Future<void> _load() async {
    if (_loading || _reachedEnd) return;
    _loading = true;
    try {
      await _client.send(const td.LoadSavedMessagesTopics(limit: _page));
    } on td.TdException catch (e) {
      // 404: every topic has been loaded.
      if (e.code != 404) rethrow;
      _reachedEnd = true;
      _notify();
    } finally {
      _loading = false;
    }
  }

  /// Applies a TDLib update to the topics.
  void handle(td.TdObject update) {
    if (update case td.UpdateSavedMessagesTopic(:final topic)) {
      _topics[topic.id] = topic;
      _notify();
    }
  }

  /// Forgets topic [topicId], once its history was deleted.
  void remove(int topicId) {
    if (_topics.remove(topicId) != null) _notify();
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose(this);
    unawaited(_changes.close());
  }
}
