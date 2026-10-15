import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The topics of a forum group, kept current from TDLib's updates while
/// the list is on screen: pinned ones first, then newest activity first.
///
/// Made by `ConversationController.openTopics`, which feeds it updates
/// until [dispose].
final class ForumTopicList {
  ForumTopicList(
    this._client, {
    required this.chatId,
    required this._onDispose,
  });

  final td.TdClient _client;
  final int chatId;
  final void Function(ForumTopicList) _onDispose;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _topics = <int, td.ForumTopic>{};
  var _reachedEnd = false;
  var _loading = false;
  var _disposed = false;
  var _offsetDate = 0;
  var _offsetMessageId = 0;
  var _offsetTopicId = 0;

  static const _page = 100;

  Stream<void> get changes => _changes.stream;

  /// Pinned topics first, then by TDLib's order, newest activity first.
  List<td.ForumTopic> get topics {
    final list = _topics.values.toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.order.compareTo(a.order);
      });
    return list;
  }

  bool get reachedEnd => _reachedEnd;

  /// Loads the first page of topics.
  Future<void> load() => _load(first: true);

  /// Loads the page after the last one, once.
  Future<void> loadMore() => _load(first: false);

  Future<void> _load({required bool first}) async {
    if (_loading || (!first && _reachedEnd)) return;
    _loading = true;
    try {
      final page = await _client.send(
        td.GetForumTopics(
          chatId: chatId,
          query: '',
          offsetDate: first ? 0 : _offsetDate,
          offsetMessageId: first ? 0 : _offsetMessageId,
          offsetForumTopicId: first ? 0 : _offsetTopicId,
          limit: _page,
        ),
      );
      if (_disposed) return;
      for (final topic in page.topics) {
        _topics[topic.info.forumTopicId] = topic;
      }
      _offsetDate = page.nextOffsetDate;
      _offsetMessageId = page.nextOffsetMessageId;
      _offsetTopicId = page.nextOffsetForumTopicId;
      if (page.topics.length < _page || page.nextOffsetForumTopicId == 0) {
        _reachedEnd = true;
      }
      _notify();
    } finally {
      _loading = false;
    }
  }

  /// Applies a TDLib update to the topics.
  void handle(td.TdObject update) {
    switch (update) {
      case td.UpdateForumTopicInfo(:final info) when info.chatId == chatId:
        if (_topics.containsKey(info.forumTopicId)) {
          _patch(info.forumTopicId, {'info': info.toJson()});
        } else {
          // A topic just made, here or elsewhere: fetch the rest of it.
          unawaited(_fetch(info.forumTopicId));
        }
      case td.UpdateForumTopic(
            :final chatId,
            :final forumTopicId,
            :final isPinned,
            :final lastReadInboxMessageId,
            :final lastReadOutboxMessageId,
            :final unreadMentionCount,
            :final unreadReactionCount,
            :final notificationSettings,
          )
          when chatId == this.chatId:
        final topic = _topics[forumTopicId];
        if (topic == null) return;
        final lastId = topic.lastMessage?.id ?? 0;
        _patch(forumTopicId, {
          'is_pinned': isPinned,
          'last_read_inbox_message_id': lastReadInboxMessageId,
          'last_read_outbox_message_id': lastReadOutboxMessageId,
          'unread_mention_count': unreadMentionCount,
          'unread_reaction_count': unreadReactionCount,
          'notification_settings': notificationSettings.toJson(),
          if (lastReadInboxMessageId >= lastId) 'unread_count': 0,
        });
      case td.UpdateNewMessage(:final message)
          when message.chatId == chatId && _topicOf(message) != null:
        final id = _topicOf(message)!;
        final topic = _topics[id];
        if (topic == null) return;
        _patch(id, {
          'last_message': message.toJson(),
          'order': _topOrder() + 1,
          if (!message.isOutgoing) 'unread_count': topic.unreadCount + 1,
        });
      case td.UpdateMessageSendSucceeded(:final message, :final oldMessageId)
          when message.chatId == chatId:
        final id = _topicOf(message);
        if (id == null || _topics[id]?.lastMessage?.id != oldMessageId) return;
        _patch(id, {'last_message': message.toJson()});
      case td.UpdateMessageContent(
            :final chatId,
            :final messageId,
            :final newContent,
          )
          when chatId == this.chatId:
        for (final topic in _topics.values) {
          if (topic.lastMessage?.id != messageId) continue;
          _patch(topic.info.forumTopicId, {
            'last_message': {
              ...topic.lastMessage!.toJson(),
              'content': newContent.toJson(),
            },
          });
          return;
        }
    }
  }

  Future<void> _fetch(int topicId) async {
    final td.ForumTopic topic;
    try {
      topic = await _client.send(
        td.GetForumTopic(chatId: chatId, forumTopicId: topicId),
      );
    } on Object {
      return;
    }
    if (_disposed) return;
    _topics[topicId] = topic;
    _notify();
  }

  /// Forgets topic [topicId], once it was deleted.
  void remove(int topicId) {
    if (_topics.remove(topicId) != null) _notify();
  }

  static int? _topicOf(td.Message message) => switch (message.topicId) {
    td.MessageTopicForum(:final forumTopicId) => forumTopicId,
    _ => null,
  };

  int _topOrder() =>
      _topics.values.fold(0, (top, t) => t.order > top ? t.order : top);

  void _patch(int topicId, Map<String, Object?> fields) {
    final current = _topics[topicId];
    if (current == null) return;
    _topics[topicId] = td.ForumTopic.fromJson({...current.toJson(), ...fields});
    _notify();
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
