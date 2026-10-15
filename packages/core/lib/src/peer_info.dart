import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// What an info panel describes.
enum PeerKind { user, bot, group, channel }

/// One of a profile's photos and when it was set, for the photo gallery.
typedef ProfilePhoto = ({td.Photo photo, int date});

/// A member's place in a group.
enum MemberRole { owner, admin, member }

/// One row of a group's member list.
final class PeerMember {
  const PeerMember({
    required this.userId,
    required this.name,
    required this.status,
    this.photo,
    this.role = MemberRole.member,
    this.isBot = false,
  });

  final int userId;
  final String name;
  final td.UserStatus status;
  final td.File? photo;
  final MemberRole role;
  final bool isBot;
}

/// Everything the info panel shows about a chat, assembled from the
/// chat, its user or group, and their full info.
final class PeerInfo {
  PeerInfo({
    required this.chatId,
    required this.kind,
    required this.title,
    this.photo,
    this.userId = 0,
    this.status,
    this.bio,
    this.usernames = const [],
    this.phone = '',
    String? formattedPhone,
    this.birthdate,
    this.description,
    this.inviteLink = '',
    this.memberCount = 0,
    this.members = const [],
    this.isMuted = false,
    this.isBlocked = false,
    this.isDeleted = false,
    this.isSelf = false,
  }) : formattedPhone = formattedPhone ?? (phone.isEmpty ? '' : '+$phone');

  final int chatId;
  final PeerKind kind;
  final String title;

  /// The big (640 px) profile or chat photo, if there is one.
  final td.File? photo;

  /// The user of a private chat; 0 for groups and channels.
  final int userId;
  final td.UserStatus? status;
  final td.FormattedText? bio;

  /// Active usernames, the editable one first, without the @.
  final List<String> usernames;

  /// Digits only, as TDLib gives them; empty when hidden.
  final String phone;

  /// [phone] with a plus and spaces by the rules of its country, such as
  /// `+7 900 123 4567`.
  final String formattedPhone;
  final td.Birthdate? birthdate;

  /// The group or channel description with its links found.
  final td.FormattedText? description;

  /// A t.me link: the public one for a group or channel with a username,
  /// otherwise the primary invite link when the user may see it.
  final String inviteLink;
  final int memberCount;

  /// The first page of members, most recently active first. Empty for
  /// channels and when the group hides its members.
  final List<PeerMember> members;
  final bool isMuted;
  final bool isBlocked;

  /// A deleted account: no actions apply to it.
  final bool isDeleted;

  /// The user's own chat, Saved Messages: nothing to block.
  final bool isSelf;

  bool get isUser => kind == PeerKind.user || kind == PeerKind.bot;
}

/// Loads and keeps current what the info panel shows about a chat.
///
/// The controller keeps the users, groups and full infos TDLib sends, so
/// statuses, notification settings and the block list change on screen as
/// soon as their update arrives. [load] asks TDLib for what is missing.
final class PeerInfoController {
  PeerInfoController(this._client);

  /// TDLib treats any mute longer than a year as forever.
  static const int muteForever = 0x7FFFFFFF;

  /// How many members the panel shows.
  static const int memberPageSize = 50;

  final td.TdClient _client;
  final _changes = StreamController<void>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;

  final _chats = <int, _ChatState>{};
  final _users = <int, td.User>{};
  final _statuses = <int, td.UserStatus>{};
  final _userFull = <int, td.UserFullInfo>{};
  final _basicGroups = <int, td.BasicGroup>{};
  final _basicFull = <int, td.BasicGroupFullInfo>{};
  final _supergroups = <int, td.Supergroup>{};
  final _superFull = <int, td.SupergroupFullInfo>{};
  final _scopes = <_Scope, td.ScopeNotificationSettings>{};
  final _members = <int, List<td.ChatMember>>{};
  final _entities = <String, td.FormattedText>{};
  final _phones = <String, String>{};

  /// Block states set from the panel, until TDLib sends a full info that
  /// has them.
  final _blocked = <int, bool>{};

  /// The signed-in user, from TDLib's `my_id` option.
  int? _myId;

  /// The signed-in user's id, once TDLib has sent it.
  int? get myId => _myId;

  /// Fires after anything [info] depends on has changed.
  Stream<void> get changes => _changes.stream;

  /// Subscribes to updates. Call it before sign-in, so the users and
  /// notification scopes TDLib sends at start are kept.
  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  /// What is known about [chatId] now, or null before its first [load].
  PeerInfo? info(int chatId) {
    final chat = _chats[chatId];
    if (chat == null) return null;
    final muted = _isMuted(chat);
    final blocked = chat.blockList is td.BlockListMain;
    switch (chat.type) {
      case td.ChatTypePrivate(:final userId) ||
          td.ChatTypeSecret(:final userId):
        final user = _users[userId];
        final full = _userFull[userId];
        return PeerInfo(
          chatId: chatId,
          kind: user?.type is td.UserTypeBot ? PeerKind.bot : PeerKind.user,
          title: chat.title,
          photo: user?.profilePhoto?.big ?? chat.photo?.big,
          userId: userId,
          status: _statuses[userId] ?? user?.status,
          bio: full?.bio,
          usernames: _activeUsernames(user?.usernames),
          phone: user?.phoneNumber ?? '',
          formattedPhone: _phones[user?.phoneNumber],
          birthdate: full?.birthdate,
          isMuted: muted,
          isBlocked:
              _blocked[userId] ??
              (blocked || full?.blockList is td.BlockListMain),
          isDeleted: user?.type is td.UserTypeDeleted,
          isSelf: userId == _myId,
        );
      case td.ChatTypeBasicGroup(:final basicGroupId):
        final full = _basicFull[basicGroupId];
        return PeerInfo(
          chatId: chatId,
          kind: PeerKind.group,
          title: chat.title,
          photo: chat.photo?.big,
          description: _describe(full?.description ?? ''),
          inviteLink: full?.inviteLink?.inviteLink ?? '',
          memberCount: _basicGroups[basicGroupId]?.memberCount ?? 0,
          members: _membersOf(chatId),
          isMuted: muted,
        );
      case td.ChatTypeSupergroup(:final supergroupId, :final isChannel):
        final group = _supergroups[supergroupId];
        final full = _superFull[supergroupId];
        final usernames = _activeUsernames(group?.usernames);
        return PeerInfo(
          chatId: chatId,
          kind: isChannel ? PeerKind.channel : PeerKind.group,
          title: chat.title,
          photo: chat.photo?.big,
          usernames: usernames,
          description: _describe(full?.description ?? ''),
          inviteLink: usernames.isNotEmpty
              ? 'https://t.me/${usernames.first}'
              : full?.inviteLink?.inviteLink ?? '',
          memberCount: full?.memberCount ?? group?.memberCount ?? 0,
          members: isChannel ? const [] : _membersOf(chatId),
          isMuted: muted,
        );
    }
  }

  /// Asks TDLib for the chat, its user or group, their full info and the
  /// first page of members.
  Future<void> load(int chatId) async {
    final chat = await _client.send(td.GetChat(chatId: chatId));
    _chats[chatId] = _ChatState(chat);
    final scope = _scopeOf(chat.type);
    final requests = <Future<void>>[
      if (!_scopes.containsKey(scope))
        _optional(() async {
          _scopes[scope] = await _client.send(
            td.GetScopeNotificationSettings(scope: scope.value),
          );
        }),
    ];
    switch (chat.type) {
      case td.ChatTypePrivate(:final userId) ||
          td.ChatTypeSecret(:final userId):
        requests.addAll([
          _optional(() async {
            final user = await _client.send(td.GetUser(userId: userId));
            _putUser(user);
            await _formatPhone(user.phoneNumber);
          }),
          _optional(() async {
            _userFull[userId] = await _client.send(
              td.GetUserFullInfo(userId: userId),
            );
          }),
        ]);
      case td.ChatTypeBasicGroup(:final basicGroupId):
        requests.addAll([
          _optional(() async {
            _basicGroups[basicGroupId] = await _client.send(
              td.GetBasicGroup(basicGroupId: basicGroupId),
            );
          }),
          _optional(() async {
            final full = await _client.send(
              td.GetBasicGroupFullInfo(basicGroupId: basicGroupId),
            );
            _basicFull[basicGroupId] = full;
            _members[chatId] = full.members;
            await _describeLater(full.description);
            await _loadUsers(full.members);
          }),
        ]);
      case td.ChatTypeSupergroup(:final supergroupId, :final isChannel):
        requests.addAll([
          _optional(() async {
            _supergroups[supergroupId] = await _client.send(
              td.GetSupergroup(supergroupId: supergroupId),
            );
          }),
          _optional(() async {
            final full = await _client.send(
              td.GetSupergroupFullInfo(supergroupId: supergroupId),
            );
            _superFull[supergroupId] = full;
            await _describeLater(full.description);
            if (isChannel || !full.canGetMembers) return;
            final page = await _client.send(
              td.GetSupergroupMembers(
                supergroupId: supergroupId,
                filter: const td.SupergroupMembersFilterRecent(),
                offset: 0,
                limit: memberPageSize,
              ),
            );
            _members[chatId] = page.members;
            await _loadUsers(page.members);
          }),
        ]);
    }
    await Future.wait(requests);
    _notify();
  }

  /// Mutes [chatId] forever, or unmutes it.
  Future<void> setMuted(int chatId, {required bool muted}) async {
    final chat = _chats[chatId];
    if (chat == null) return;
    final s = chat.notificationSettings;
    await _client.send(
      td.SetChatNotificationSettings(
        chatId: chatId,
        notificationSettings: td.ChatNotificationSettings(
          useDefaultMuteFor: false,
          muteFor: muted ? muteForever : 0,
          useDefaultSound: s.useDefaultSound,
          soundId: s.soundId,
          useDefaultShowPreview: s.useDefaultShowPreview,
          showPreview: s.showPreview,
          useDefaultMuteStories: s.useDefaultMuteStories,
          muteStories: s.muteStories,
          useDefaultStorySound: s.useDefaultStorySound,
          storySoundId: s.storySoundId,
          useDefaultShowStoryPoster: s.useDefaultShowStoryPoster,
          showStoryPoster: s.showStoryPoster,
          useDefaultDisablePinnedMessageNotifications:
              s.useDefaultDisablePinnedMessageNotifications,
          disablePinnedMessageNotifications:
              s.disablePinnedMessageNotifications,
          useDefaultDisableMentionNotifications:
              s.useDefaultDisableMentionNotifications,
          disableMentionNotifications: s.disableMentionNotifications,
        ),
      ),
    );
  }

  /// Blocks or unblocks the user of the private chat [chatId].
  Future<void> setBlocked(int chatId, {required bool blocked}) async {
    final userId = info(chatId)?.userId ?? 0;
    if (userId == 0) return;
    final list = blocked ? const td.BlockListMain() : null;
    await _client.send(
      td.SetMessageSenderBlockList(
        senderId: td.MessageSenderUser(userId: userId),
        blockList: list,
      ),
    );
    // TDLib confirms with updateChatBlockList, but not always with a new
    // full info. Until a fresh one arrives the panel shows what the user
    // chose, and keeps the bio and birthday it has.
    _chats[chatId]?.blockList = list;
    _blocked[userId] = blocked;
    _notify();
    await _optional(() async {
      _userFull[userId] = await _client.send(
        td.GetUserFullInfo(userId: userId),
      );
      _blocked.remove(userId);
      _notify();
    });
  }

  /// The private chat with [userId], created locally when there is none.
  Future<int> privateChatOf(int userId) async {
    final chat = await _client.send(
      td.CreatePrivateChat(userId: userId, force: false),
    );
    return chat.id;
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateOption(
        name: 'my_id',
        value: td.OptionValueInteger(:final value),
      ):
        _myId = value;
        _notify();
      case td.UpdateUser(:final user):
        _putUser(user);
        _notify();
      case td.UpdateUserStatus(:final userId, :final status):
        _statuses[userId] = status;
        _notify();
      case td.UpdateUserFullInfo(:final userId, :final userFullInfo):
        _userFull[userId] = userFullInfo;
        _blocked.remove(userId);
        _notify();
      case td.UpdateBasicGroup(:final basicGroup):
        _basicGroups[basicGroup.id] = basicGroup;
        _notify();
      case td.UpdateBasicGroupFullInfo(
        :final basicGroupId,
        :final basicGroupFullInfo,
      ):
        _basicFull[basicGroupId] = basicGroupFullInfo;
        for (final MapEntry(key: chatId, value: chat) in _chats.entries) {
          if (chat.type case td.ChatTypeBasicGroup(basicGroupId: final id)
              when id == basicGroupId) {
            _members[chatId] = basicGroupFullInfo.members;
          }
        }
        unawaited(_describeLater(basicGroupFullInfo.description).then(_done));
      case td.UpdateSupergroup(:final supergroup):
        _supergroups[supergroup.id] = supergroup;
        _notify();
      case td.UpdateSupergroupFullInfo(
        :final supergroupId,
        :final supergroupFullInfo,
      ):
        _superFull[supergroupId] = supergroupFullInfo;
        unawaited(_describeLater(supergroupFullInfo.description).then(_done));
      case td.UpdateChatTitle(:final chatId, :final title):
        _chats[chatId]?.title = title;
        _notify();
      case td.UpdateChatPhoto(:final chatId, :final photo):
        _chats[chatId]?.photo = photo;
        _notify();
      case td.UpdateChatNotificationSettings(
        :final chatId,
        :final notificationSettings,
      ):
        _chats[chatId]?.notificationSettings = notificationSettings;
        _notify();
      case td.UpdateChatBlockList(:final chatId, :final blockList):
        _chats[chatId]?.blockList = blockList;
        _notify();
      case td.UpdateScopeNotificationSettings(
        :final scope,
        :final notificationSettings,
      ):
        _scopes[_Scope.of(scope)] = notificationSettings;
        _notify();
      default:
        break;
    }
  }

  void _done(void _) => _notify();

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _putUser(td.User user) {
    _users[user.id] = user;
    _statuses.remove(user.id);
  }

  bool _isMuted(_ChatState chat) {
    final s = chat.notificationSettings;
    final muteFor = s.useDefaultMuteFor
        ? _scopes[_scopeOf(chat.type)]?.muteFor ?? 0
        : s.muteFor;
    return muteFor > 0;
  }

  /// Asks TDLib for the users of [members] it has not sent yet.
  Future<void> _loadUsers(List<td.ChatMember> members) async {
    await Future.wait([
      for (final member in members)
        if (member.memberId case td.MessageSenderUser(:final userId)
            when !_users.containsKey(userId))
          _optional(
            () async =>
                _putUser(await _client.send(td.GetUser(userId: userId))),
          ),
    ]);
  }

  List<PeerMember> _membersOf(int chatId) {
    final members = [
      for (final member in _members[chatId] ?? const <td.ChatMember>[])
        if (member.memberId case td.MessageSenderUser(:final userId))
          if (_users[userId] case final user?)
            PeerMember(
              userId: userId,
              name: userName(user),
              status: _statuses[userId] ?? user.status,
              photo: user.profilePhoto?.small,
              role: switch (member.status) {
                td.ChatMemberStatusCreator() => MemberRole.owner,
                td.ChatMemberStatusAdministrator() => MemberRole.admin,
                _ => MemberRole.member,
              },
              isBot: user.type is td.UserTypeBot,
            ),
    ];
    return sortByPresence(members);
  }

  td.FormattedText? _describe(String text) => text.isEmpty
      ? null
      : _entities[text] ?? td.FormattedText(text: text, entities: const []);

  Future<void> _formatPhone(String phone) async {
    if (phone.isEmpty || _phones.containsKey(phone)) return;
    final info = await _client.send(
      td.GetPhoneNumberInfo(phoneNumberPrefix: phone),
    );
    if (info.countryCallingCode.isEmpty) return;
    _phones[phone] = '+${info.countryCallingCode} ${info.formattedPhoneNumber}'
        .trim();
  }

  /// Finds the links, mentions and hashtags of a description once.
  Future<void> _describeLater(String text) async {
    if (text.isEmpty || _entities.containsKey(text)) return;
    await _optional(() async {
      final found = await _client.send(td.GetTextEntities(text: text));
      _entities[text] = td.FormattedText(text: text, entities: found.entities);
    });
  }

  /// Runs a request whose failure only leaves a row out of the panel.
  /// A closed client only means the panel is going away.
  static Future<void> _optional(Future<void> Function() request) =>
      request().catchError(
        (Object _) {},
        test: (error) => error is td.TdException || error is td.TdClientClosed,
      );
}

/// The part of a TDLib chat the panel uses, kept current by updates.
final class _ChatState {
  _ChatState(td.Chat chat)
    : type = chat.type,
      title = chat.title,
      photo = chat.photo,
      notificationSettings = chat.notificationSettings,
      blockList = chat.blockList;

  final td.ChatType type;
  String title;
  td.ChatPhotoInfo? photo;
  td.ChatNotificationSettings notificationSettings;
  td.BlockList? blockList;
}

/// Notification defaults apply per kind of chat.
enum _Scope {
  private(td.NotificationSettingsScopePrivateChats()),
  group(td.NotificationSettingsScopeGroupChats()),
  channel(td.NotificationSettingsScopeChannelChats());

  const _Scope(this.value);

  final td.NotificationSettingsScope value;

  static _Scope of(td.NotificationSettingsScope scope) => switch (scope) {
    td.NotificationSettingsScopePrivateChats() => private,
    td.NotificationSettingsScopeGroupChats() => group,
    td.NotificationSettingsScopeChannelChats() => channel,
  };
}

_Scope _scopeOf(td.ChatType type) => switch (type) {
  td.ChatTypePrivate() || td.ChatTypeSecret() => _Scope.private,
  td.ChatTypeBasicGroup() => _Scope.group,
  td.ChatTypeSupergroup(:final isChannel) =>
    isChannel ? _Scope.channel : _Scope.group,
};

List<String> _activeUsernames(td.Usernames? usernames) {
  if (usernames == null) return const [];
  final editable = usernames.editableUsername;
  return [
    if (usernames.activeUsernames.contains(editable)) editable,
    for (final name in usernames.activeUsernames)
      if (name != editable) name,
  ];
}

/// The name of [user] as TDLib's clients show it: first and last name.
String userName(td.User user) =>
    [user.firstName, user.lastName].where((s) => s.isNotEmpty).join(' ');

/// Orders members the way the official clients do: online first, then by
/// when they were last seen, then the ones whose time is hidden, from the
/// most to the least recent bucket. The sort is stable.
List<PeerMember> sortByPresence(List<PeerMember> members) {
  final indexed = members.indexed.toList();
  indexed.sort((a, b) {
    final byPresence = presenceRank(b.$2.status)
        .compareTo(presenceRank(a.$2.status));
    return byPresence != 0 ? byPresence : a.$1.compareTo(b.$1);
  });
  return [for (final (_, member) in indexed) member];
}

/// A number that grows with how recently [status] says the user was
/// online: an online user ranks above any time, a known time above the
/// hidden "recently", "within a week" and "within a month".
int presenceRank(td.UserStatus status) => switch (status) {
  td.UserStatusOnline() => 1 << 40,
  td.UserStatusOffline(:final wasOnline) => 4 + wasOnline,
  td.UserStatusRecently() => 3,
  td.UserStatusLastWeek() => 2,
  td.UserStatusLastMonth() => 1,
  td.UserStatusEmpty() => 0,
};
