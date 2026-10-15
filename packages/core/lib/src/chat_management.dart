import 'dart:async';
import 'dart:convert';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'peer_info.dart';

/// What the signed-in user may do in a group or channel.
final class ChatRights {
  const ChatRights({
    this.isMember = true,
    this.isOwner = false,
    this.isAdmin = false,
    this.isChannel = false,
    this.isSupergroup = false,
    this.canChangeInfo = false,
    this.canInviteUsers = false,
    this.canRestrictMembers = false,
    this.canPromoteMembers = false,
    this.canDeleteChat = false,
    this.isForum = false,
    this.adminRights,
  });

  /// A private chat, or a group the user is not in.
  static const none = ChatRights(isMember: false);

  final bool isMember;
  final bool isOwner;
  final bool isAdmin;
  final bool isChannel;

  /// A supergroup or a channel; restrictions exist only there.
  final bool isSupergroup;
  final bool canChangeInfo;
  final bool canInviteUsers;
  final bool canRestrictMembers;
  final bool canPromoteMembers;

  /// The owner may delete the chat for everyone.
  final bool canDeleteChat;

  /// A supergroup with topics, where managing topics is a right.
  final bool isForum;

  /// The user's own administrator rights; an administrator can only give
  /// rights they hold. Null for the owner, who holds them all, and for
  /// everyone who is not an administrator.
  final td.ChatAdministratorRights? adminRights;

  /// Invite links need an administrator with the invite right.
  bool get canManageLinks => (isOwner || isAdmin) && canInviteUsers;
}

/// One row of the members section, with what the user may do to it.
final class ManagedMember {
  const ManagedMember({
    required this.userId,
    required this.name,
    required this.status,
    required this.role,
    this.photo,
    this.isBot = false,
    this.isSelf = false,
    this.adminRights,
    this.permissions,
    this.tag = '',
    this.canPromote = false,
    this.canRestrict = false,
    this.canRemove = false,
  });

  final int userId;
  final String name;
  final td.UserStatus status;
  final MemberRole role;
  final td.File? photo;
  final bool isBot;
  final bool isSelf;

  /// An administrator's rights, to start the rights sheet from.
  final td.ChatAdministratorRights? adminRights;

  /// A restricted member's permissions.
  final td.ChatPermissions? permissions;

  /// An administrator's title, shown in place of "admin"; empty for
  /// the usual one.
  final String tag;

  /// May make an administrator, or edit and dismiss one.
  final bool canPromote;
  final bool canRestrict;
  final bool canRemove;
}

/// A page of members: [hasMore] while [nextOffset] gives more.
final class MemberPage {
  const MemberPage(this.members, {this.hasMore = false, this.nextOffset = 0});

  final List<ManagedMember> members;
  final bool hasMore;
  final int nextOffset;
}

/// How a group or channel is set up, for the owner and administrators:
/// what everyone may do, who may join and what new members see.
final class ChatSettings {
  const ChatSettings({
    required this.chatId,
    required this.isChannel,
    required this.isSupergroup,
    required this.isForum,
    required this.username,
    required this.permissions,
    required this.slowModeDelay,
    required this.isAllHistoryAvailable,
    required this.canToggleHistory,
    required this.joinByRequest,
    required this.linkedChatId,
    required this.linkedChatTitle,
    required this.bannedCount,
    required this.restrictedCount,
    required this.reactions,
    required this.canGetEventLog,
  });

  final int chatId;
  final bool isChannel;
  final bool isSupergroup;
  final bool isForum;

  /// The public username, empty for a private chat.
  final String username;
  bool get isPublic => username.isNotEmpty;

  /// What every member may do.
  final td.ChatPermissions permissions;

  /// Seconds between messages of one member; 0 when off.
  final int slowModeDelay;

  /// Whether new members see the messages from before they joined.
  final bool isAllHistoryAvailable;

  /// History can be hidden only in a private group without topics or a
  /// linked channel.
  final bool canToggleHistory;

  /// Whether everyone who joins has to be approved.
  final bool joinByRequest;

  /// A channel's discussion group, or a group's channel; 0 for none.
  final int linkedChatId;
  final String linkedChatTitle;
  final int bannedCount;
  final int restrictedCount;
  final td.ChatAvailableReactions reactions;

  /// Recent actions exist only in supergroups and channels.
  final bool canGetEventLog;
}

/// A user banned from a chat or restricted in it.
final class RemovedMember {
  const RemovedMember({
    required this.userId,
    required this.name,
    required this.isBanned,
    this.photo,
    this.permissions,
    this.until,
  });

  final int userId;
  final String name;
  final td.File? photo;

  /// Banned, rather than restricted.
  final bool isBanned;

  /// What a restricted member may still do.
  final td.ChatPermissions? permissions;

  /// When the ban or restriction ends; null for good.
  final DateTime? until;
}

/// Someone asking to join by a link that needs approval.
final class JoinRequest {
  const JoinRequest({
    required this.userId,
    required this.name,
    required this.date,
    this.bio = '',
    this.photo,
  });

  final int userId;
  final String name;
  final DateTime date;
  final String bio;
  final td.File? photo;
}

/// One entry of the recent actions of a group or channel.
final class AdminLogEntry {
  const AdminLogEntry({
    required this.id,
    required this.date,
    required this.actorName,
    required this.action,
    this.actorPhoto,
    this.subjectName,
  });

  final int id;
  final DateTime date;

  /// Who did it.
  final String actorName;
  final td.File? actorPhoto;
  final td.ChatEventAction action;

  /// Whom it was done to, for actions about a member.
  final String? subjectName;
}

/// Whether a username may be taken for a chat.
enum UsernameCheck { ok, invalid, occupied, purchasable, tooMany }

/// Reactions commonly allowed when the server has not said which exist.
const defaultEmojiReactions = [
  '👍',
  '👎',
  '❤',
  '🔥',
  '🥰',
  '👏',
  '😁',
  '🤔',
  '🤯',
  '😱',
  '🤬',
  '😢',
  '🎉',
  '🤩',
  '🤮',
  '💩',
  '🙏',
  '👌',
  '🕊',
  '🤡',
  '🥱',
  '🥴',
  '😍',
  '🐳',
];

/// Creates, edits and moderates groups and channels: their members and
/// administrators, title, description and photo, invite links, leaving
/// and deleting.
final class ChatManagement {
  ChatManagement(this._client);

  static const int pageSize = 50;

  final td.TdClient _client;
  final _changes = StreamController<int>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  int? _myId;

  /// The chat whose members or invite links changed, from this app or
  /// from another one.
  Stream<int> get changes => _changes.stream;

  /// Which chat each group is, from the chats asked about, so that
  /// updates about a group reach the right chat.
  final _chatOfBasicGroup = <int, int>{};
  final _chatOfSupergroup = <int, int>{};

  /// The user's own status in each group, to tell a change of it from
  /// the other updates about the group, such as its member count.
  final _ownStatus = <String, String>{};

  /// What [members] learned about a chat for the pages after the first.
  final _pageContext = <int, (td.Chat, ChatRights)>{};

  /// The reactions the server allows, from the first update about them.
  List<String> _activeReactions = defaultEmojiReactions;

  /// The emoji a chat may allow as reactions.
  List<String> get activeReactions => _activeReactions;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  /// Members, administrators and the user's own rights change with these
  /// updates, from this app or from another device.
  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateChatMember(:final chatId) ||
          td.UpdateChatPermissions(:final chatId):
        _notify(chatId);
      case td.UpdateBasicGroup(:final basicGroup):
        _statusChanged(
          _chatOfBasicGroup[basicGroup.id],
          'b${basicGroup.id}',
          basicGroup.status,
        );
      case td.UpdateSupergroup(:final supergroup):
        _statusChanged(
          _chatOfSupergroup[supergroup.id],
          's${supergroup.id}',
          supergroup.status,
        );
      case td.UpdateBasicGroupFullInfo(:final basicGroupId):
        if (_chatOfBasicGroup[basicGroupId] case final chatId?) {
          _notify(chatId);
        }
      case td.UpdateSupergroupFullInfo(:final supergroupId):
        if (_chatOfSupergroup[supergroupId] case final chatId?) {
          _notify(chatId);
        }
      case td.UpdateActiveEmojiReactions(:final emojis):
        if (emojis.isNotEmpty) _activeReactions = emojis;
      case td.UpdateChatAvailableReactions(:final chatId) ||
          td.UpdateChatPendingJoinRequests(:final chatId):
        _notify(chatId);
      default:
        break;
    }
  }

  void _statusChanged(int? chatId, String key, td.ChatMemberStatus status) {
    final encoded = jsonEncode(status.toJson());
    final before = _ownStatus[key];
    _ownStatus[key] = encoded;
    if (chatId != null && before != null && before != encoded) {
      _notify(chatId);
    }
  }

  /// What the user may do in [chatId].
  Future<ChatRights> rights(int chatId) async =>
      _rightsIn(await _client.send(td.GetChat(chatId: chatId)));

  Future<ChatRights> _rightsIn(td.Chat chat) async {
    final (status, isChannel, isSupergroup, isForum) = switch (chat.type) {
      td.ChatTypeBasicGroup(:final basicGroupId) => (
        await _basicGroupStatus(chat.id, basicGroupId),
        false,
        false,
        false,
      ),
      td.ChatTypeSupergroup(:final supergroupId, :final isChannel) =>
        await _supergroupStatus(chat.id, supergroupId, isChannel),
      _ => (null, false, false, false),
    };
    final everyone = chat.permissions;
    return switch (status) {
      td.ChatMemberStatusCreator(:final isMember) => ChatRights(
        isMember: isMember,
        isOwner: true,
        isChannel: isChannel,
        isSupergroup: isSupergroup,
        isForum: isForum,
        canChangeInfo: true,
        canInviteUsers: true,
        canRestrictMembers: true,
        canPromoteMembers: true,
        canDeleteChat: chat.canBeDeletedForAllUsers,
      ),
      td.ChatMemberStatusAdministrator(:final rights) => ChatRights(
        isAdmin: true,
        isChannel: isChannel,
        isSupergroup: isSupergroup,
        isForum: isForum,
        canChangeInfo: rights.canChangeInfo,
        canInviteUsers: rights.canInviteUsers,
        canRestrictMembers: rights.canRestrictMembers,
        canPromoteMembers: rights.canPromoteMembers,
        adminRights: rights,
      ),
      td.ChatMemberStatusMember() => ChatRights(
        isChannel: isChannel,
        isSupergroup: isSupergroup,
        isForum: isForum,
        canChangeInfo: !isChannel && everyone.canChangeInfo,
        canInviteUsers: !isChannel && everyone.canInviteUsers,
      ),
      td.ChatMemberStatusRestricted(:final isMember, :final permissions) =>
        ChatRights(
          isMember: isMember,
          isChannel: isChannel,
          isSupergroup: isSupergroup,
          isForum: isForum,
          canChangeInfo: permissions.canChangeInfo,
          canInviteUsers: permissions.canInviteUsers,
        ),
      _ => ChatRights(
        isMember: false,
        isChannel: isChannel,
        isSupergroup: isSupergroup,
      ),
    };
  }

  Future<td.ChatMemberStatus> _basicGroupStatus(int chatId, int id) async {
    _chatOfBasicGroup[id] = chatId;
    final status = (await _client.send(td.GetBasicGroup(basicGroupId: id)))
        .status;
    _ownStatus['b$id'] = jsonEncode(status.toJson());
    return status;
  }

  Future<(td.ChatMemberStatus, bool, bool, bool)> _supergroupStatus(
    int chatId,
    int id,
    bool isChannel,
  ) async {
    _chatOfSupergroup[id] = chatId;
    final group = await _client.send(td.GetSupergroup(supergroupId: id));
    _ownStatus['s$id'] = jsonEncode(group.status.toJson());
    return (group.status, isChannel, true, group.isForum);
  }

  /// A page of the members of [chatId]. The first page without a [query]
  /// starts with the owner and the administrators; the rest follow online
  /// first. A basic group comes whole in one page.
  Future<MemberPage> members(
    int chatId, {
    String query = '',
    int offset = 0,
    int limit = pageSize,
  }) async {
    final myId = await _me();
    // The pages after the first reuse what the first one learned.
    final known = offset > 0 ? _pageContext[chatId] : null;
    final td.Chat chat;
    final ChatRights rights;
    if (known != null) {
      (chat, rights) = known;
    } else {
      chat = await _client.send(td.GetChat(chatId: chatId));
      rights = await _rightsIn(chat);
      _pageContext[chatId] = (chat, rights);
    }
    switch (chat.type) {
      case td.ChatTypeBasicGroup(:final basicGroupId):
        final full = await _client.send(
          td.GetBasicGroupFullInfo(basicGroupId: basicGroupId),
        );
        final all = await _manage(full.members, rights, myId);
        final needle = query.trim().toLowerCase();
        return MemberPage(
          _ordered([
            for (final member in all)
              if (member.name.toLowerCase().contains(needle)) member,
          ]),
        );
      case td.ChatTypeSupergroup(:final supergroupId):
        final search = query.trim();
        final requests = [
          td.GetSupergroupMembers(
            supergroupId: supergroupId,
            filter: search.isEmpty
                ? const td.SupergroupMembersFilterRecent()
                : td.SupergroupMembersFilterSearch(query: search),
            offset: offset,
            limit: limit,
          ),
          if (search.isEmpty && offset == 0)
            td.GetSupergroupMembers(
              supergroupId: supergroupId,
              filter: const td.SupergroupMembersFilterAdministrators(),
              offset: 0,
              limit: 200,
            ),
        ];
        final found = await Future.wait(requests.map(_client.send));
        final page = found.first;
        final admins = found.length > 1
            ? found.last.members
            : const <td.ChatMember>[];
        final adminIds = {for (final m in admins) _userOf(m)};
        final managed = await _manage(
          [
            ...admins,
            for (final m in page.members)
              if (!adminIds.contains(_userOf(m))) m,
          ],
          rights,
          myId,
        );
        final next = offset + page.members.length;
        return MemberPage(
          _ordered(managed),
          hasMore: page.members.length == limit && next < page.totalCount,
          nextOffset: next,
        );
      default:
        return const MemberPage([]);
    }
  }

  /// Makes [userId] an administrator of [chatId] with [rights], or
  /// changes the rights of one.
  Future<void> promote(
    int chatId,
    int userId,
    td.ChatAdministratorRights rights,
  ) => _setStatus(
    chatId,
    userId,
    td.ChatMemberStatusAdministrator(canBeEdited: true, rights: rights),
  );

  /// Makes an administrator a plain member again, or lifts restrictions.
  Future<void> demote(int chatId, int userId) => _setStatus(
    chatId,
    userId,
    const td.ChatMemberStatusMember(memberUntilDate: 0),
  );

  /// Limits what [userId] may do in the supergroup [chatId], for good.
  Future<void> restrict(
    int chatId,
    int userId,
    td.ChatPermissions permissions,
  ) => _setStatus(
    chatId,
    userId,
    td.ChatMemberStatusRestricted(
      isMember: true,
      restrictedUntilDate: 0,
      permissions: permissions,
    ),
  );

  /// Removes [userId] from [chatId]. In a supergroup or channel they can't
  /// come back by a link until an administrator lets them.
  Future<void> remove(int chatId, int userId) async {
    await _client.send(
      td.BanChatMember(
        chatId: chatId,
        memberId: td.MessageSenderUser(userId: userId),
        bannedUntilDate: 0,
        revokeMessages: false,
      ),
    );
    _notify(chatId);
  }

  Future<void> setTitle(int chatId, String title) =>
      _client.send(td.SetChatTitle(chatId: chatId, title: title.trim()));

  Future<void> setDescription(int chatId, String description) => _client.send(
    td.SetChatDescription(chatId: chatId, description: description.trim()),
  );

  /// Sets the photo of [chatId] from the image at [path], or removes it
  /// when [path] is null.
  Future<void> setPhoto(int chatId, String? path) => _client.send(
    td.SetChatPhoto(
      chatId: chatId,
      photo: path == null
          ? null
          : td.InputChatPhotoStatic(photo: td.InputFileLocal(path: path)),
    ),
  );

  /// The user's own links to [chatId] that still work, the primary first.
  Future<List<td.ChatInviteLink>> inviteLinks(int chatId) async {
    final links = await _client.send(
      td.GetChatInviteLinks(
        chatId: chatId,
        creatorUserId: await _me(),
        isRevoked: false,
        offsetDate: 0,
        offsetInviteLink: '',
        limit: 100,
      ),
    );
    return [
      ...links.inviteLinks.where((l) => l.isPrimary),
      ...links.inviteLinks.where((l) => !l.isPrimary),
    ];
  }

  /// A new additional link. A link that asks to join can't have a member
  /// limit, so [memberLimit] is dropped for it.
  Future<td.ChatInviteLink> createLink(
    int chatId, {
    String name = '',
    DateTime? expiresAt,
    int memberLimit = 0,
    bool joinRequests = false,
  }) async {
    final link = await _client.send(
      td.CreateChatInviteLink(
        chatId: chatId,
        // Telegram takes names of up to 32 characters.
        name: String.fromCharCodes(name.trim().runes.take(32)),
        expirationDate: expiresAt == null
            ? 0
            : expiresAt.millisecondsSinceEpoch ~/ 1000,
        memberLimit: joinRequests ? 0 : memberLimit,
        createsJoinRequest: joinRequests,
      ),
    );
    _notify(chatId);
    return link;
  }

  /// Stops [link] working. The primary link is replaced by a new one.
  Future<void> revokeLink(int chatId, td.ChatInviteLink link) async {
    if (link.isPrimary) {
      await _client.send(td.ReplacePrimaryChatInviteLink(chatId: chatId));
    } else {
      await _client.send(
        td.RevokeChatInviteLink(chatId: chatId, inviteLink: link.inviteLink),
      );
    }
    _notify(chatId);
  }

  /// Makes a primary link when the chat has none yet.
  Future<void> createPrimaryLink(int chatId) async {
    await _client.send(td.ReplacePrimaryChatInviteLink(chatId: chatId));
    _notify(chatId);
  }

  Future<void> leave(int chatId) => _client.send(td.LeaveChat(chatId: chatId));

  /// Deletes [chatId] for all its members; only its owner may.
  Future<void> deleteChat(int chatId) =>
      _client.send(td.DeleteChat(chatId: chatId));

  /// Creates a group of the user and [userIds]. Returns its chat and
  /// the users whose privacy settings kept them out of it.
  Future<({int chatId, List<int> notAdded})> createGroup(
    String title,
    List<int> userIds, {
    String? photoPath,
  }) async {
    final created = await _client.send(
      td.CreateNewBasicGroupChat(
        userIds: userIds,
        title: title.trim(),
        messageAutoDeleteTime: 0,
      ),
    );
    if (photoPath != null) await setPhoto(created.chatId, photoPath);
    return (
      chatId: created.chatId,
      notAdded: [
        for (final failed in created.failedToAddMembers.failedToAddMembers)
          failed.userId,
      ],
    );
  }

  /// Creates a channel and returns its chat; with a [username] it is
  /// public from the start, with a [photoPath] it has a photo.
  Future<int> createChannel(
    String title, {
    String description = '',
    String username = '',
    String? photoPath,
  }) async {
    final chat = await _client.send(
      td.CreateNewSupergroupChat(
        title: title.trim(),
        isForum: false,
        isChannel: true,
        description: description.trim(),
        messageAutoDeleteTime: 0,
        forImport: false,
      ),
    );
    if (username.trim().isNotEmpty) await setUsername(chat.id, username);
    if (photoPath != null) await setPhoto(chat.id, photoPath);
    return chat.id;
  }

  /// How [chatId] is set up, for its management rows.
  Future<ChatSettings> settings(int chatId) async {
    final chat = await _client.send(td.GetChat(chatId: chatId));
    switch (chat.type) {
      case td.ChatTypeSupergroup(:final supergroupId, :final isChannel):
        _chatOfSupergroup[supergroupId] = chatId;
        final group = await _client.send(
          td.GetSupergroup(supergroupId: supergroupId),
        );
        final full = await _client.send(
          td.GetSupergroupFullInfo(supergroupId: supergroupId),
        );
        final username = group.usernames?.editableUsername ?? '';
        final linked = full.linkedChatId == 0
            ? null
            : await _client
                  .send(td.GetChat(chatId: full.linkedChatId))
                  .then<td.Chat?>((c) => c, onError: (Object _) => null);
        return ChatSettings(
          chatId: chatId,
          isChannel: isChannel,
          isSupergroup: true,
          isForum: group.isForum,
          username: username,
          permissions: chat.permissions,
          slowModeDelay: full.slowModeDelay,
          isAllHistoryAvailable: full.isAllHistoryAvailable,
          canToggleHistory:
              !isChannel &&
              !group.isForum &&
              username.isEmpty &&
              full.linkedChatId == 0,
          joinByRequest: group.joinByRequest,
          linkedChatId: full.linkedChatId,
          linkedChatTitle: linked?.title ?? '',
          bannedCount: full.bannedCount,
          restrictedCount: full.restrictedCount,
          reactions: chat.availableReactions,
          canGetEventLog: true,
        );
      default:
        return ChatSettings(
          chatId: chatId,
          isChannel: false,
          isSupergroup: false,
          isForum: false,
          username: '',
          permissions: chat.permissions,
          slowModeDelay: 0,
          isAllHistoryAvailable: true,
          canToggleHistory: false,
          joinByRequest: false,
          linkedChatId: 0,
          linkedChatTitle: '',
          bannedCount: 0,
          restrictedCount: 0,
          reactions: chat.availableReactions,
          canGetEventLog: false,
        );
    }
  }

  /// Sets what every member of [chatId] may do.
  Future<void> setPermissions(int chatId, td.ChatPermissions permissions) =>
      _client
          .send(td.SetChatPermissions(chatId: chatId, permissions: permissions))
          .then((_) => _notify(chatId));

  /// Sets the seconds between one member's messages; 0 turns slow mode
  /// off. Only the values Telegram takes are kept.
  Future<void> setSlowMode(int chatId, int seconds) => _client
      .send(td.SetChatSlowModeDelay(chatId: chatId, slowModeDelay: seconds))
      .then((_) => _notify(chatId));

  /// The seconds slow mode can be set to, as in the official apps.
  static const slowModeDelays = [0, 10, 30, 60, 300, 900, 3600];

  /// Whether new members of [chatId] see older messages.
  Future<void> setHistoryAvailable(int chatId, {required bool available}) =>
      _supergroupCall(
        chatId,
        (id) => td.ToggleSupergroupIsAllHistoryAvailable(
          supergroupId: id,
          isAllHistoryAvailable: available,
        ),
      );

  /// Turns topics on or off in the group [chatId].
  Future<void> setForum(int chatId, {required bool forum}) => _supergroupCall(
    chatId,
    (id) => td.ToggleSupergroupIsForum(
      supergroupId: id,
      isForum: forum,
      hasForumTabs: false,
    ),
  );

  /// Whether everyone who joins [chatId] by a link waits for approval.
  Future<void> setJoinByRequest(int chatId, {required bool byRequest}) =>
      _supergroupCall(
        chatId,
        (id) => td.ToggleSupergroupJoinByRequest(
          supergroupId: id,
          joinByRequest: byRequest,
          guardBotUserId: 0,
          applyToInviteLinks: false,
        ),
      );

  /// Whether [username] may become the public link of [chatId].
  Future<UsernameCheck> checkUsername(int chatId, String username) async {
    final result = await _client.send(
      td.CheckChatUsername(chatId: chatId, username: username.trim()),
    );
    return switch (result) {
      td.CheckChatUsernameResultOk() => UsernameCheck.ok,
      td.CheckChatUsernameResultUsernameOccupied() => UsernameCheck.occupied,
      td.CheckChatUsernameResultUsernamePurchasable() =>
        UsernameCheck.purchasable,
      td.CheckChatUsernameResultPublicChatsTooMany() => UsernameCheck.tooMany,
      _ => UsernameCheck.invalid,
    };
  }

  /// Makes [chatId] public at t.me/[username], or private with an empty
  /// one.
  Future<void> setUsername(int chatId, String username) => _supergroupCall(
    chatId,
    (id) => td.SetSupergroupUsername(
      supergroupId: id,
      username: username.trim().replaceFirst('@', ''),
    ),
  );

  /// Which reactions members of [chatId] may use.
  Future<void> setReactions(int chatId, td.ChatAvailableReactions reactions) =>
      _client
          .send(
            td.SetChatAvailableReactions(
              chatId: chatId,
              availableReactions: reactions,
            ),
          )
          .then((_) => _notify(chatId));

  /// Links the group [groupId] as the discussion of the channel
  /// [channelId], or unlinks with a null [groupId]. Called from the
  /// group's side, [channelId] is its channel.
  Future<void> setDiscussionGroup(int channelId, int? groupId) => _client
      .send(
        td.SetChatDiscussionGroup(
          chatId: channelId,
          discussionChatId: groupId ?? 0,
        ),
      )
      .then((_) => _notify(channelId));

  /// The user's groups that may become a channel's discussion group.
  Future<List<(int, String)>> suitableDiscussionGroups() async {
    final chats = await _client.send(const td.GetSuitableDiscussionChats());
    final loaded = await Future.wait([
      for (final id in chats.chatIds) _client.send(td.GetChat(chatId: id)),
    ]);
    return [for (final chat in loaded) (chat.id, chat.title)];
  }

  /// Adds [userIds] to the group [chatId]; returns those whose privacy
  /// settings kept them out.
  Future<List<int>> addMembers(int chatId, List<int> userIds) async {
    final failed = await _client.send(
      td.AddChatMembers(chatId: chatId, userIds: userIds),
    );
    _notify(chatId);
    return [for (final f in failed.failedToAddMembers) f.userId];
  }

  /// Gives an administrator of [chatId] a title shown in place of
  /// "admin"; empty for the usual one.
  Future<void> setAdminTitle(int chatId, int userId, String title) => _client
      .send(
        td.SetChatMemberTag(
          chatId: chatId,
          userId: userId,
          tag: String.fromCharCodes(title.trim().runes.take(16)),
        ),
      )
      .then((_) => _notify(chatId));

  /// The users banned from [chatId] and the ones restricted in it, the
  /// banned first. Only a supergroup or channel has any.
  Future<List<RemovedMember>> removedMembers(
    int chatId, {
    String query = '',
  }) async {
    final chat = await _client.send(td.GetChat(chatId: chatId));
    if (chat.type case td.ChatTypeSupergroup(:final supergroupId)) {
      final found = await Future.wait([
        for (final filter in [
          td.SupergroupMembersFilterBanned(query: query),
          td.SupergroupMembersFilterRestricted(query: query),
        ])
          _client.send(
            td.GetSupergroupMembers(
              supergroupId: supergroupId,
              filter: filter,
              offset: 0,
              limit: 200,
            ),
          ),
      ]);
      final members = [...found.first.members, ...found.last.members];
      final people = [
        for (final member in members)
          if (member.memberId is td.MessageSenderUser) member,
      ];
      final users = await Future.wait([
        for (final member in people)
          _client.send(td.GetUser(userId: _userOf(member))),
      ]);
      return [
        for (final (i, member) in people.indexed)
          switch (member.status) {
            td.ChatMemberStatusBanned(:final bannedUntilDate) => RemovedMember(
              userId: users[i].id,
              name: userName(users[i]),
              photo: users[i].profilePhoto?.small,
              isBanned: true,
              until: _date(bannedUntilDate),
            ),
            td.ChatMemberStatusRestricted(
              :final restrictedUntilDate,
              :final permissions,
            ) =>
              RemovedMember(
                userId: users[i].id,
                name: userName(users[i]),
                photo: users[i].profilePhoto?.small,
                isBanned: false,
                permissions: permissions,
                until: _date(restrictedUntilDate),
              ),
            _ => null,
          },
      ].nonNulls.toList();
    }
    return const [];
  }

  /// Lets a banned user join [chatId] again, or lifts a restriction.
  Future<void> unban(int chatId, int userId, {required bool banned}) =>
      _setStatus(
        chatId,
        userId,
        banned
            ? const td.ChatMemberStatusLeft()
            : const td.ChatMemberStatusMember(memberUntilDate: 0),
      );

  /// Who is waiting to join [chatId] by a link that needs approval.
  Future<List<JoinRequest>> joinRequests(int chatId) async {
    final requests = await _client.send(
      td.GetChatJoinRequests(
        chatId: chatId,
        inviteLink: '',
        query: '',
        limit: 100,
      ),
    );
    final users = await Future.wait([
      for (final request in requests.requests)
        _client.send(td.GetUser(userId: request.userId)),
    ]);
    return [
      for (final (i, request) in requests.requests.indexed)
        JoinRequest(
          userId: request.userId,
          name: userName(users[i]),
          photo: users[i].profilePhoto?.small,
          date: _date(request.date) ?? DateTime.now(),
          bio: request.bio,
        ),
    ];
  }

  /// Lets [userId] into [chatId], or turns them down.
  Future<void> processJoinRequest(
    int chatId,
    int userId, {
    required bool approve,
  }) => _client
      .send(
        td.ProcessChatJoinRequest(
          chatId: chatId,
          userId: userId,
          approve: approve,
        ),
      )
      .then((_) => _notify(chatId));

  /// Changes the name, expiry, limit or approval of an additional link.
  Future<td.ChatInviteLink> editLink(
    int chatId,
    td.ChatInviteLink link, {
    required String name,
    DateTime? expiresAt,
    int memberLimit = 0,
    bool joinRequests = false,
  }) async {
    final edited = await _client.send(
      td.EditChatInviteLink(
        chatId: chatId,
        inviteLink: link.inviteLink,
        name: String.fromCharCodes(name.trim().runes.take(32)),
        expirationDate: expiresAt == null
            ? 0
            : expiresAt.millisecondsSinceEpoch ~/ 1000,
        memberLimit: joinRequests ? 0 : memberLimit,
        createsJoinRequest: joinRequests,
      ),
    );
    _notify(chatId);
    return edited;
  }

  /// The recent actions of administrators in [chatId], newest first;
  /// [fromEventId] pages on from an entry's id, [userIds] narrow it to
  /// some administrators.
  Future<List<AdminLogEntry>> recentActions(
    int chatId, {
    int fromEventId = 0,
    List<int> userIds = const [],
    int limit = 50,
  }) async {
    final events = await _client.send(
      td.GetChatEventLog(
        chatId: chatId,
        query: '',
        fromEventId: fromEventId,
        limit: limit,
        userIds: userIds,
      ),
    );
    final names = <int, td.User>{};
    Future<td.User?> user(int id) async {
      if (id == 0) return null;
      return names[id] ??= await _client.send(td.GetUser(userId: id));
    }

    Future<String> senderName(td.MessageSender sender) async =>
        switch (sender) {
          td.MessageSenderUser(:final userId) => userName(
            (await user(userId))!,
          ),
          td.MessageSenderChat(:final chatId) => (await _client.send(
            td.GetChat(chatId: chatId),
          )).title,
        };
    final entries = <AdminLogEntry>[];
    for (final event in events.events) {
      final actor = await user(_senderUser(event.memberId));
      final subjectId = switch (event.action) {
        td.ChatEventMemberPromoted(:final userId) ||
        td.ChatEventMemberInvited(:final userId) ||
        td.ChatEventMemberTagChanged(:final userId) => userId,
        td.ChatEventMemberRestricted(:final memberId) => _senderUser(memberId),
        td.ChatEventMemberJoinedByRequest(:final approverUserId) =>
          approverUserId,
        _ => 0,
      };
      final subject = await user(subjectId);
      entries.add(
        AdminLogEntry(
          id: event.id,
          date: _date(event.date) ?? DateTime.now(),
          actorName: actor != null
              ? userName(actor)
              : await senderName(event.memberId),
          actorPhoto: actor?.profilePhoto?.small,
          action: event.action,
          subjectName: subject == null ? null : userName(subject),
        ),
      );
    }
    return entries;
  }

  /// The administrators of [chatId], to filter recent actions by.
  Future<List<(int, String)>> administrators(int chatId) async {
    final admins = await _client.send(td.GetChatAdministrators(chatId: chatId));
    final users = await Future.wait([
      for (final admin in admins.administrators)
        _client.send(td.GetUser(userId: admin.userId)),
    ]);
    return [for (final user in users) (user.id, userName(user))];
  }

  Future<void> _supergroupCall(
    int chatId,
    td.TdFunction<td.Ok> Function(int supergroupId) request,
  ) async {
    final chat = await _client.send(td.GetChat(chatId: chatId));
    if (chat.type case td.ChatTypeSupergroup(:final supergroupId)) {
      await _client.send(request(supergroupId));
      _notify(chatId);
    } else {
      throw StateError('Not a supergroup');
    }
  }

  Future<void> _setStatus(
    int chatId,
    int userId,
    td.ChatMemberStatus status,
  ) async {
    await _client.send(
      td.SetChatMemberStatus(
        chatId: chatId,
        memberId: td.MessageSenderUser(userId: userId),
        status: status,
      ),
    );
    _notify(chatId);
  }

  Future<int> _me() async =>
      _myId ??= (await _client.send(const td.GetMe())).id;

  Future<List<ManagedMember>> _manage(
    List<td.ChatMember> members,
    ChatRights rights,
    int myId,
  ) async {
    // A channel can be a member of a group too; only users are listed.
    final people = [
      for (final member in members)
        if (member.memberId is td.MessageSenderUser) member,
    ];
    final users = await Future.wait([
      for (final member in people)
        _client.send(td.GetUser(userId: _userOf(member))),
    ]);
    return [
      for (final (i, member) in people.indexed)
        _managed(member, users[i], rights, myId),
    ];
  }

  ManagedMember _managed(
    td.ChatMember member,
    td.User user,
    ChatRights rights,
    int myId,
  ) {
    final status = member.status;
    final self = user.id == myId;
    final owner = status is td.ChatMemberStatusCreator;
    final admin = status is td.ChatMemberStatusAdministrator;
    // An administrator can be edited by the one who appointed them and by
    // the owner; TDLib says which.
    final editableAdmin = admin && status.canBeEdited;
    final plain = !self && !owner && !admin;
    final invitedByMe = member.inviterUserId == myId;
    return ManagedMember(
      userId: user.id,
      name: userName(user),
      status: user.status,
      photo: user.profilePhoto?.small,
      isBot: user.type is td.UserTypeBot,
      isSelf: self,
      role: owner
          ? MemberRole.owner
          : admin
          ? MemberRole.admin
          : MemberRole.member,
      adminRights: admin ? status.rights : null,
      permissions: status is td.ChatMemberStatusRestricted
          ? status.permissions
          : null,
      tag: member.tag,
      canPromote:
          !self &&
          rights.canPromoteMembers &&
          (plain || editableAdmin) &&
          (rights.isSupergroup || rights.isOwner),
      canRestrict: plain && rights.isSupergroup && rights.canRestrictMembers,
      canRemove: rights.isSupergroup
          ? !self &&
                !owner &&
                (!admin || editableAdmin) &&
                rights.canRestrictMembers
          // In a basic group the owner removes anyone, an administrator
          // anyone but administrators, a member whom they invited.
          : rights.isOwner
          ? !self && !owner
          : rights.isAdmin
          ? plain
          : rights.isMember && plain && invitedByMe,
    );
  }

  void _notify(int chatId) {
    _pageContext.remove(chatId);
    if (!_changes.isClosed) _changes.add(chatId);
  }
}

int _userOf(td.ChatMember member) => _senderUser(member.memberId);

int _senderUser(td.MessageSender sender) => switch (sender) {
  td.MessageSenderUser(:final userId) => userId,
  _ => 0,
};

DateTime? _date(int unix) =>
    unix == 0 ? null : DateTime.fromMillisecondsSinceEpoch(unix * 1000);

/// The owner, then the administrators, then everyone else; online first
/// within each.
List<ManagedMember> _ordered(List<ManagedMember> members) {
  int rank(MemberRole role) => switch (role) {
    MemberRole.owner => 0,
    MemberRole.admin => 1,
    MemberRole.member => 2,
  };
  final indexed = members.indexed.toList()
    ..sort((a, b) {
      final byRole = rank(a.$2.role).compareTo(rank(b.$2.role));
      if (byRole != 0) return byRole;
      final byPresence = presenceRank(b.$2.status)
          .compareTo(presenceRank(a.$2.status));
      return byPresence != 0 ? byPresence : a.$1.compareTo(b.$1);
    });
  return [for (final (_, member) in indexed) member];
}
