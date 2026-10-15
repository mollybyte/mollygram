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
    List<int> userIds,
  ) async {
    final created = await _client.send(
      td.CreateNewBasicGroupChat(
        userIds: userIds,
        title: title.trim(),
        messageAutoDeleteTime: 0,
      ),
    );
    return (
      chatId: created.chatId,
      notAdded: [
        for (final failed in created.failedToAddMembers.failedToAddMembers)
          failed.userId,
      ],
    );
  }

  /// Creates a channel and returns its chat.
  Future<int> createChannel(String title, {String description = ''}) async {
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
    return chat.id;
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

int _userOf(td.ChatMember member) => switch (member.memberId) {
  td.MessageSenderUser(:final userId) => userId,
  _ => 0,
};

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
