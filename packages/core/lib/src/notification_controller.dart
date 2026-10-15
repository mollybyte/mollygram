import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'chat_list_store.dart';
import 'message_content.dart';

/// One message notification, ready to be shown by the system.
final class MessageNotification {
  const MessageNotification({
    required this.groupId,
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.date,
    required this.chatTitle,
    required this.kind,
    required this.text,
    this.senderName,
    this.isMention = false,
    this.showPreview = true,
    this.playSound = true,
    this.canReply = true,
    this.photoPath,
    this.isEdit = false,
  });

  /// TDLib's notification group: all notifications of one chat (or of its
  /// mentions) share it.
  final int groupId;

  /// TDLib's notification id.
  final int id;
  final int chatId;
  final int messageId;

  /// Unix time of the message.
  final int date;
  final String chatTitle;

  /// Who wrote the message in a group; null in private chats and channels.
  final String? senderName;
  final ChatPreviewKind kind;

  /// The text or caption.
  final String text;

  /// The notification is about a mention or a reply to the user.
  final bool isMention;

  /// Whether the chat's notification settings allow showing the text. A
  /// secret chat never does.
  final bool showPreview;

  /// False for silent messages and chats whose sound is off, including
  /// mentions in muted chats.
  final bool playSound;

  /// False in channels, where only admins post.
  final bool canReply;

  /// The chat photo on disk, when TDLib has it.
  final String? photoPath;

  /// The message was edited: the shown notification is replaced quietly.
  final bool isEdit;

  /// Identifies the notification across TDLib updates and the system.
  String get key => notificationKey(groupId, id);

  static String notificationKey(int groupId, int id) => '$groupId:$id';
}

/// What changed in the set of notifications that should be on screen.
sealed class NotificationEvent {
  const NotificationEvent();
}

/// Show [notification], or replace the one with the same key.
final class NotificationPosted extends NotificationEvent {
  const NotificationPosted(this.notification);

  final MessageNotification notification;
}

/// Take these notifications away: they were read, deleted or pushed out.
final class NotificationsRemoved extends NotificationEvent {
  const NotificationsRemoved(this.keys);

  final List<String> keys;
}

/// TDLib's full list after a start: anything else still on screen is stale.
final class NotificationsSynced extends NotificationEvent {
  const NotificationsSynced(this.keys);

  final Set<String> keys;
}

/// Unread counters of the main chat list, for the dock badge.
final class UnreadCounts {
  const UnreadCounts({
    this.chats = 0,
    this.unmutedChats = 0,
    this.messages = 0,
    this.unmutedMessages = 0,
  });

  final int chats;
  final int unmutedChats;
  final int messages;
  final int unmutedMessages;

  UnreadCounts copyWith({
    int? chats,
    int? unmutedChats,
    int? messages,
    int? unmutedMessages,
  }) => UnreadCounts(
    chats: chats ?? this.chats,
    unmutedChats: unmutedChats ?? this.unmutedChats,
    messages: messages ?? this.messages,
    unmutedMessages: unmutedMessages ?? this.unmutedMessages,
  );

  @override
  bool operator ==(Object other) =>
      other is UnreadCounts &&
      other.chats == chats &&
      other.unmutedChats == unmutedChats &&
      other.messages == messages &&
      other.unmutedMessages == unmutedMessages;

  @override
  int get hashCode =>
      Object.hash(chats, unmutedChats, messages, unmutedMessages);
}

/// Follows TDLib's notification groups and turns them into
/// [MessageNotification]s, the way TDLib-based clients do: TDLib decides
/// what deserves a notification (per-chat and per-scope mute, mention
/// rules, messages read elsewhere), the client only shows and hides them.
///
/// TDLib keeps notifications off until [setEnabled] raises
/// `notification_group_count_max` above zero.
final class NotificationController {
  NotificationController(this._client, {Duration? photoTimeout})
    : _photoTimeout = photoTimeout ?? const Duration(seconds: 2);

  final td.TdClient _client;
  final Duration _photoTimeout;
  final _events = StreamController<NotificationEvent>.broadcast(sync: true);
  final _unread = StreamController<UnreadCounts>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;

  final _chats = <int, _ChatInfo>{};
  final _users = <int, String>{};
  final _files = <int, String>{};

  /// Message ids by notification id, per group, as TDLib last described
  /// them.
  final _groups = <int, Map<int, int>>{};

  /// The chat of each group.
  final _groupChats = <int, int>{};

  /// Events are handled one at a time, so a notification still waiting for
  /// its chat photo can't be overtaken by its own removal.
  var _queue = Future<void>.value();
  var _counts = const UnreadCounts();

  /// The most groups TDLib keeps at once, and notifications per group.
  static const maxGroups = 25;
  static const maxGroupSize = 10;

  Stream<NotificationEvent> get events => _events.stream;

  /// The latest counters and every change after.
  UnreadCounts get unreadCounts => _counts;
  Stream<UnreadCounts> get unreadChanges => _unread.stream;

  /// Subscribes to updates. Call before authorization, so the chats and
  /// users TDLib sends at startup are known when a notification arrives.
  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  /// Turns TDLib's notifications on or off. Off removes every group, which
  /// arrives as removals.
  Future<void> setEnabled(bool enabled) async {
    await _client.send(
      td.SetOption(
        name: 'notification_group_size_max',
        value: const td.OptionValueInteger(value: maxGroupSize),
      ),
    );
    await _client.send(
      td.SetOption(
        name: 'notification_group_count_max',
        value: td.OptionValueInteger(value: enabled ? maxGroups : 0),
      ),
    );
  }

  /// Marks the chat read up to [messageId], or to the newest notified
  /// message of the chat when that is later.
  Future<void> markRead(int chatId, int messageId) async {
    await _client.send(
      td.ViewMessages(
        chatId: chatId,
        messageIds: [_newestNotified(chatId, messageId)],
        source: const td.MessageSourceNotification(),
        forceRead: true,
      ),
    );
  }

  /// Sends [text] from a notification's reply field. In groups it replies
  /// to the message, as the official client does; in private chats it is a
  /// plain message. The chat is marked read.
  Future<void> reply(int chatId, int messageId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final isPrivate = _chats[chatId]?.isPrivate ?? false;
    await _client.send(
      td.SendMessage(
        chatId: chatId,
        replyTo: isPrivate
            ? null
            : td.InputMessageReplyToMessage(
                messageId: messageId,
                checklistTaskId: 0,
                pollOptionId: '',
              ),
        inputMessageContent: td.InputMessageText(
          text: td.FormattedText(text: trimmed, entities: const []),
          clearDraft: false,
        ),
      ),
    );
    await markRead(chatId, messageId);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _queue;
    await _events.close();
    await _unread.close();
  }

  int _newestNotified(int chatId, int messageId) {
    var newest = messageId;
    for (final group in _groupsOf(chatId)) {
      for (final id in group.values) {
        if (id > newest) newest = id;
      }
    }
    return newest;
  }

  Iterable<Map<int, int>> _groupsOf(int chatId) sync* {
    for (final MapEntry(:key, :value) in _groups.entries) {
      if (_groupChats[key] == chatId) yield value;
    }
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      case td.UpdateNewChat(:final chat):
        _chats[chat.id] = _ChatInfo(
          title: chat.title,
          type: chat.type,
          photo: chat.photo?.small,
        );
      case td.UpdateChatTitle(:final chatId, :final title):
        _chats[chatId]?.title = title;
      case td.UpdateChatPhoto(:final chatId, :final photo):
        _chats[chatId]?.photo = photo?.small;
      case td.UpdateUser(:final user):
        _users[user.id] = _fullName(user.firstName, user.lastName);
      case td.UpdateFile(:final file) when file.local.isDownloadingCompleted:
        _files[file.id] = file.local.path;
      case td.UpdateUnreadChatCount(
        chatList: td.ChatListMain(),
        :final unreadCount,
        :final unreadUnmutedCount,
      ):
        _setCounts(
          _counts.copyWith(
            chats: unreadCount,
            unmutedChats: unreadUnmutedCount,
          ),
        );
      case td.UpdateUnreadMessageCount(
        chatList: td.ChatListMain(),
        :final unreadCount,
        :final unreadUnmutedCount,
      ):
        _setCounts(
          _counts.copyWith(
            messages: unreadCount,
            unmutedMessages: unreadUnmutedCount,
          ),
        );
      case td.UpdateActiveNotifications(:final groups):
        _enqueue(() => _onActive(groups));
      case td.UpdateNotificationGroup():
        _enqueue(() => _onGroup(object));
      case td.UpdateNotification(
        :final notificationGroupId,
        :final notification,
      ):
        _enqueue(() => _onEdited(notificationGroupId, notification));
      default:
    }
  }

  void _setCounts(UnreadCounts counts) {
    if (counts == _counts) return;
    _counts = counts;
    if (!_unread.isClosed) _unread.add(counts);
  }

  void _enqueue(Future<void> Function() handle) {
    _queue = _queue.then((_) => handle()).catchError((Object _) {});
  }

  void _emit(NotificationEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  Future<void> _onActive(List<td.NotificationGroup> groups) async {
    _groups.clear();
    _groupChats.clear();
    final keys = <String>{};
    for (final group in groups) {
      _groupChats[group.id] = group.chatId;
      final ids = _groups[group.id] = {};
      for (final notification in group.notifications) {
        if (_messageOf(notification) case final message?) {
          ids[notification.id] = message.id;
          keys.add(
            MessageNotification.notificationKey(group.id, notification.id),
          );
        }
      }
    }
    // What is still on screen from the last run stays; it isn't posted
    // again, so a restart doesn't replay old banners.
    _emit(NotificationsSynced(keys));
  }

  Future<void> _onGroup(td.UpdateNotificationGroup update) async {
    final groupId = update.notificationGroupId;
    _groupChats[groupId] = update.chatId;
    final ids = _groups[groupId] ??= {};
    if (update.removedNotificationIds.isNotEmpty) {
      for (final id in update.removedNotificationIds) {
        ids.remove(id);
      }
      _emit(
        NotificationsRemoved([
          for (final id in update.removedNotificationIds)
            MessageNotification.notificationKey(groupId, id),
        ]),
      );
    }
    if (update.totalCount == 0 && update.addedNotifications.isEmpty) {
      _groups.remove(groupId);
      _groupChats.remove(groupId);
      return;
    }
    final isMention = update.type is td.NotificationGroupTypeMentions;
    for (final notification in update.addedNotifications) {
      final message = _messageOf(notification);
      if (message == null) continue;
      ids[notification.id] = message.id;
      final built = await _build(
        groupId: groupId,
        notification: notification,
        message: message,
        isMention: isMention,
        playSound: update.notificationSoundId != 0 && !notification.isSilent,
      );
      // Read or deleted while the photo was loading.
      if (!(_groups[groupId]?.containsKey(notification.id) ?? false)) continue;
      _emit(NotificationPosted(built));
    }
  }

  Future<void> _onEdited(int groupId, td.Notification notification) async {
    final message = _messageOf(notification);
    final ids = _groups[groupId];
    if (message == null || ids == null || !ids.containsKey(notification.id)) {
      return;
    }
    final built = await _build(
      groupId: groupId,
      notification: notification,
      message: message,
      isMention: false,
      playSound: false,
      isEdit: true,
    );
    if (!(_groups[groupId]?.containsKey(notification.id) ?? false)) return;
    _emit(NotificationPosted(built));
  }

  Future<MessageNotification> _build({
    required int groupId,
    required td.Notification notification,
    required td.Message message,
    required bool isMention,
    required bool playSound,
    bool isEdit = false,
  }) async {
    final chat = _chats[message.chatId];
    final type = notification.type as td.NotificationTypeNewMessage;
    final (kind, text) = summarizeContent(message.content);
    return MessageNotification(
      groupId: groupId,
      id: notification.id,
      chatId: message.chatId,
      messageId: message.id,
      date: message.date,
      chatTitle: chat?.title ?? '',
      senderName: chat != null && chat.isGroup ? _senderName(message) : null,
      kind: kind,
      text: text,
      isMention: isMention,
      showPreview: type.showPreview && !(chat?.isSecret ?? false),
      playSound: playSound,
      canReply: !(chat?.isChannel ?? false),
      photoPath: await _photoPath(chat?.photo),
      isEdit: isEdit,
    );
  }

  String? _senderName(td.Message message) => switch (message.senderId) {
    td.MessageSenderUser(:final userId) => _users[userId],
    // A group posting as itself (an anonymous admin) has no separate name.
    td.MessageSenderChat(:final chatId) when chatId != message.chatId =>
      _chats[chatId]?.title,
    _ => null,
  };

  Future<String?> _photoPath(td.File? photo) async {
    if (photo == null) return null;
    if (photo.local.isDownloadingCompleted) return photo.local.path;
    if (_files[photo.id] case final path?) return path;
    if (!photo.local.canBeDownloaded) return null;
    try {
      final file = await _client
          .send(
            td.DownloadFile(
              fileId: photo.id,
              priority: 32,
              offset: 0,
              limit: 0,
              synchronous: true,
            ),
          )
          .timeout(_photoTimeout);
      if (!file.local.isDownloadingCompleted) return null;
      return _files[file.id] = file.local.path;
    } on Object {
      // No photo is better than a late notification.
      return null;
    }
  }

  static td.Message? _messageOf(td.Notification notification) =>
      switch (notification.type) {
        td.NotificationTypeNewMessage(:final message) => message,
        _ => null,
      };

  static String _fullName(String first, String last) =>
      last.isEmpty ? first : (first.isEmpty ? last : '$first $last');
}

final class _ChatInfo {
  _ChatInfo({required this.title, required this.type, this.photo});

  String title;
  final td.ChatType type;
  td.File? photo;

  bool get isPrivate => type is td.ChatTypePrivate || type is td.ChatTypeSecret;
  bool get isSecret => type is td.ChatTypeSecret;
  bool get isChannel => switch (type) {
    td.ChatTypeSupergroup(:final isChannel) => isChannel,
    _ => false,
  };
  bool get isGroup => switch (type) {
    td.ChatTypeBasicGroup() => true,
    td.ChatTypeSupergroup(:final isChannel) => !isChannel,
    _ => false,
  };
}
