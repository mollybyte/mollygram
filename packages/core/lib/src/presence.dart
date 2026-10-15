import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'chat_list_store.dart';

/// When a user was last seen, as far as their privacy settings tell.
sealed class UserPresence {
  const UserPresence();
}

final class PresenceOnline extends UserPresence {
  const PresenceOnline(this.expires);

  /// When the online status runs out unless renewed.
  final DateTime expires;
}

final class PresenceOffline extends UserPresence {
  const PresenceOffline(this.wasOnline);

  final DateTime wasOnline;
}

/// The exact time is hidden; the user was online within a day or so.
final class PresenceRecently extends UserPresence {
  const PresenceRecently();
}

final class PresenceLastWeek extends UserPresence {
  const PresenceLastWeek();
}

final class PresenceLastMonth extends UserPresence {
  const PresenceLastMonth();
}

/// Never shown, or not for a long time.
final class PresenceLongAgo extends UserPresence {
  const PresenceLongAgo();
}

/// What someone in a chat is doing right now, from `updateChatAction`.
enum ChatActivity {
  typing,
  recordingVoice,
  recordingVideoNote,
  recordingVideo,
  sendingPhoto,
  sendingVideo,
  sendingVoice,
  sendingVideoNote,
  sendingFile,
  choosingSticker,
  choosingLocation,
  choosingContact,
  playingGame,
  watchingAnimations,
}

/// One person (or a chat posting as itself) doing [activity].
final class ChatActor {
  const ChatActor({required this.name, required this.activity});

  /// The first name of a user, or the title of a chat.
  final String name;
  final ChatActivity activity;

  @override
  bool operator ==(Object other) =>
      other is ChatActor && other.name == name && other.activity == activity;

  @override
  int get hashCode => Object.hash(name, activity);
}

/// The status line under a chat's name, without what people are doing.
sealed class ChatStatus {
  const ChatStatus();
}

/// Nothing to say, as for Saved Messages.
final class ChatStatusNone extends ChatStatus {
  const ChatStatusNone();

  @override
  bool operator ==(Object other) => other is ChatStatusNone;

  @override
  int get hashCode => 0;
}

final class ChatStatusUser extends ChatStatus {
  const ChatStatusUser(this.presence);

  final UserPresence presence;

  bool isOnline(DateTime now) => switch (presence) {
    PresenceOnline(:final expires) => expires.isAfter(now),
    _ => false,
  };

  @override
  bool operator ==(Object other) =>
      other is ChatStatusUser && _samePresence(other.presence, presence);

  @override
  int get hashCode => presence.runtimeType.hashCode;
}

final class ChatStatusBot extends ChatStatus {
  const ChatStatusBot();

  @override
  bool operator ==(Object other) => other is ChatStatusBot;

  @override
  int get hashCode => 1;
}

/// Telegram's own notifications account (777000).
final class ChatStatusService extends ChatStatus {
  const ChatStatusService();

  @override
  bool operator ==(Object other) => other is ChatStatusService;

  @override
  int get hashCode => 2;
}

final class ChatStatusGroup extends ChatStatus {
  const ChatStatusGroup({required this.members, required this.online});

  /// 0 while unknown.
  final int members;

  /// Members online right now, known for open chats only.
  final int online;

  @override
  bool operator ==(Object other) =>
      other is ChatStatusGroup &&
      other.members == members &&
      other.online == online;

  @override
  int get hashCode => Object.hash(members, online);
}

final class ChatStatusChannel extends ChatStatus {
  const ChatStatusChannel({required this.subscribers});

  /// 0 while unknown.
  final int subscribers;

  @override
  bool operator ==(Object other) =>
      other is ChatStatusChannel && other.subscribers == subscribers;

  @override
  int get hashCode => subscribers.hashCode;
}

bool _samePresence(UserPresence a, UserPresence b) => switch ((a, b)) {
  (PresenceOnline(expires: final x), PresenceOnline(expires: final y)) =>
    x == y,
  (PresenceOffline(wasOnline: final x), PresenceOffline(wasOnline: final y)) =>
    x == y,
  _ => a.runtimeType == b.runtimeType,
};

final class _User {
  _User(
    this.firstName,
    this.presence, {
    required this.kind,
    this.photo,
    this.verified = false,
  });

  String firstName;
  UserPresence presence;
  _UserKind kind;
  td.ProfilePhoto? photo;
  bool verified;
}

enum _UserKind { regular, bot, deleted }

/// Online statuses, member counts and what people are doing in chats,
/// kept from TDLib updates for the chat header and the chat list.
final class PresenceController {
  PresenceController(this._client, {String Function(int chatId)? chatTitle})
    : _chatTitle = chatTitle ?? ((_) => '');

  /// Telegram's service notifications account.
  static const serviceUserId = 777000;

  final td.TdClient _client;
  final String Function(int chatId) _chatTitle;
  final _changes = StreamController<void>.broadcast(sync: true);
  final _users = <int, _User>{};
  final _basicGroupMembers = <int, int>{};
  final _supergroupMembers = <int, int>{};
  final _onlineMembers = <int, int>{};
  final _verifiedSupergroups = <int>{};
  final _requestedFullInfo = <int>{};

  /// Per chat, who is doing what, in the order they started.
  final _activity = <int, Map<_SenderKey, ChatActivity>>{};
  StreamSubscription<td.TdObject>? _subscription;

  /// The signed-in user, from the `my_id` option; 0 until TDLib sends it.
  int myId = 0;

  bool _isMe(int userId) => myId != 0 && userId == myId;

  /// Emits after an update changes what this controller reports.
  Stream<void> get changes => _changes.stream;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  /// The presence of a user, or null when TDLib hasn't sent the user.
  UserPresence? presenceOf(int userId) => _users[userId]?.presence;

  /// Whether a private chat's user is online at [now].
  bool isOnline(ChatListEntry chat, DateTime now) {
    if (!chat.type.isPrivate || _isMe(chat.peerId)) return false;
    final user = _users[chat.peerId];
    if (user == null || user.kind != _UserKind.regular) return false;
    return ChatStatusUser(user.presence).isOnline(now);
  }

  /// The status line of [chat], without activity.
  ChatStatus statusOf(ChatListEntry chat) {
    switch (chat.type) {
      case ChatType.private || ChatType.secret:
        if (_isMe(chat.peerId)) return const ChatStatusNone();
        if (chat.peerId == serviceUserId) return const ChatStatusService();
        final user = _users[chat.peerId];
        if (user == null) return const ChatStatusNone();
        return switch (user.kind) {
          _UserKind.bot => const ChatStatusBot(),
          _UserKind.deleted => const ChatStatusNone(),
          _UserKind.regular => ChatStatusUser(user.presence),
        };
      case ChatType.basicGroup:
        return ChatStatusGroup(
          members: _basicGroupMembers[chat.peerId] ?? 0,
          online: _onlineMembers[chat.id] ?? 0,
        );
      case ChatType.supergroup:
        return ChatStatusGroup(
          members: _supergroupMembers[chat.peerId] ?? 0,
          online: _onlineMembers[chat.id] ?? 0,
        );
      case ChatType.channel:
        return ChatStatusChannel(
          subscribers: _supergroupMembers[chat.peerId] ?? 0,
        );
    }
  }

  /// Who is doing something in [chatId] right now, earliest first. The
  /// signed-in user's own actions from other devices are left out.
  List<ChatActor> activityIn(int chatId) {
    final actions = _activity[chatId];
    if (actions == null || actions.isEmpty) return const [];
    return [
      for (final MapEntry(key: sender, value: activity) in actions.entries)
        ChatActor(name: _nameOf(sender), activity: activity),
    ];
  }

  /// Asks TDLib for a supergroup's member count when it isn't known yet,
  /// as it often isn't until the full info is loaded.
  Future<void> loadMemberCount(ChatListEntry chat) async {
    if (chat.type != ChatType.supergroup && chat.type != ChatType.channel) {
      return;
    }
    if ((_supergroupMembers[chat.peerId] ?? 0) > 0) return;
    if (!_requestedFullInfo.add(chat.peerId)) return;
    try {
      final info = await _client.send(
        td.GetSupergroupFullInfo(supergroupId: chat.peerId),
      );
      _setSupergroupMembers(chat.peerId, info.memberCount);
    } on td.TdException {
      _requestedFullInfo.remove(chat.peerId);
    }
  }

  /// The first name of [userId] (the last name when there is none), as a
  /// group's chat-list row names who wrote last; empty when unknown.
  String firstNameOf(int userId) => _users[userId]?.firstName ?? '';

  /// The profile photo of [userId], for the sender's small avatar in the
  /// chat list; null when they have none or are unknown.
  td.ProfilePhoto? photoOf(int userId) => _users[userId]?.photo;

  /// Whether Telegram verified the user, group or channel behind [chat].
  bool isVerified(ChatListEntry chat) => switch (chat.type) {
    ChatType.private => _users[chat.peerId]?.verified ?? false,
    ChatType.supergroup ||
    ChatType.channel => _verifiedSupergroups.contains(chat.peerId),
    _ => false,
  };

  String _nameOf(_SenderKey sender) => sender.isChat
      ? _chatTitle(sender.id)
      : (_users[sender.id]?.firstName ?? '');

  void _setSupergroupMembers(int supergroupId, int count) {
    if (count <= 0 || _supergroupMembers[supergroupId] == count) return;
    _supergroupMembers[supergroupId] = count;
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _onUpdate(td.TdObject object) {
    switch (object) {
      case td.UpdateOption(
            :final name,
            value: td.OptionValueInteger(:final value),
          )
          when name == 'my_id':
        myId = value;
      case td.UpdateUser(:final user):
        _users[user.id] = _User(
          user.firstName.isEmpty ? user.lastName : user.firstName,
          _presenceFrom(user.status),
          kind: switch (user.type) {
            td.UserTypeBot() => _UserKind.bot,
            td.UserTypeDeleted() => _UserKind.deleted,
            _ => _UserKind.regular,
          },
          photo: user.profilePhoto,
          verified: user.verificationStatus?.isVerified ?? false,
        );
      case td.UpdateUserStatus(:final userId, :final status):
        final user = _users[userId];
        if (user == null) return;
        user.presence = _presenceFrom(status);
      case td.UpdateBasicGroup(:final basicGroup):
        if (_basicGroupMembers[basicGroup.id] == basicGroup.memberCount) {
          return;
        }
        _basicGroupMembers[basicGroup.id] = basicGroup.memberCount;
      case td.UpdateSupergroup(:final supergroup):
        final verified = supergroup.verificationStatus?.isVerified ?? false;
        if (verified != _verifiedSupergroups.contains(supergroup.id)) {
          verified
              ? _verifiedSupergroups.add(supergroup.id)
              : _verifiedSupergroups.remove(supergroup.id);
          _setSupergroupMembers(supergroup.id, supergroup.memberCount);
          _emit();
          return;
        }
        _setSupergroupMembers(supergroup.id, supergroup.memberCount);
        return;
      case td.UpdateSupergroupFullInfo(
        :final supergroupId,
        :final supergroupFullInfo,
      ):
        _setSupergroupMembers(supergroupId, supergroupFullInfo.memberCount);
        return;
      case td.UpdateChatOnlineMemberCount(
        :final chatId,
        :final onlineMemberCount,
      ):
        _onlineMembers[chatId] = onlineMemberCount;
      case td.UpdateChatAction(:final chatId, :final senderId, :final action):
        final sender = switch (senderId) {
          td.MessageSenderUser(:final userId) => _SenderKey(userId, false),
          td.MessageSenderChat(:final chatId) => _SenderKey(chatId, true),
        };
        if (!sender.isChat && _isMe(sender.id)) return;
        final activity = _activityFrom(action);
        final actions = _activity.putIfAbsent(chatId, () => {});
        if (activity == null) {
          if (actions.remove(sender) == null) return;
          if (actions.isEmpty) _activity.remove(chatId);
        } else {
          if (actions[sender] == activity) return;
          actions[sender] = activity;
        }
      default:
        return;
    }
    _emit();
  }
}

final class _SenderKey {
  const _SenderKey(this.id, this.isChat);

  final int id;
  final bool isChat;

  @override
  bool operator ==(Object other) =>
      other is _SenderKey && other.id == id && other.isChat == isChat;

  @override
  int get hashCode => Object.hash(id, isChat);
}

UserPresence _presenceFrom(td.UserStatus status) => switch (status) {
  td.UserStatusOnline(:final expires) => PresenceOnline(_time(expires)),
  td.UserStatusOffline(:final wasOnline) => PresenceOffline(_time(wasOnline)),
  td.UserStatusRecently() => const PresenceRecently(),
  td.UserStatusLastWeek() => const PresenceLastWeek(),
  td.UserStatusLastMonth() => const PresenceLastMonth(),
  td.UserStatusEmpty() => const PresenceLongAgo(),
};

DateTime _time(int unixSeconds) =>
    DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);

ChatActivity? _activityFrom(td.ChatAction action) => switch (action) {
  td.ChatActionTyping() => ChatActivity.typing,
  td.ChatActionRecordingVoiceNote() => ChatActivity.recordingVoice,
  td.ChatActionRecordingVideoNote() => ChatActivity.recordingVideoNote,
  td.ChatActionRecordingVideo() => ChatActivity.recordingVideo,
  td.ChatActionUploadingPhoto() => ChatActivity.sendingPhoto,
  td.ChatActionUploadingVideo() => ChatActivity.sendingVideo,
  td.ChatActionUploadingVoiceNote() => ChatActivity.sendingVoice,
  td.ChatActionUploadingVideoNote() => ChatActivity.sendingVideoNote,
  td.ChatActionUploadingDocument() => ChatActivity.sendingFile,
  td.ChatActionChoosingSticker() => ChatActivity.choosingSticker,
  td.ChatActionChoosingLocation() => ChatActivity.choosingLocation,
  td.ChatActionChoosingContact() => ChatActivity.choosingContact,
  td.ChatActionStartPlayingGame() => ChatActivity.playingGame,
  td.ChatActionWatchingAnimations() => ChatActivity.watchingAnimations,
  td.ChatActionCancel() => null,
};
