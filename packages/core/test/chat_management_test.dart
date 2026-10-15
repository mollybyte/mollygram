import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatManagement management;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    management = ChatManagement(tdlib.createClient());
    await management.start();
  });

  tearDown(() async {
    await management.dispose();
    await tdlib.close();
  });

  group('rights', () {
    test('an owner may do everything', () async {
      json.answer = (r) => switch (r['@type']) {
        'getChat' => _chat(1, _superType(5), canDelete: true),
        'getSupergroup' => _supergroup(5, _creator),
        _ => null,
      };
      final rights = await management.rights(1);
      expect(rights.isOwner, isTrue);
      expect(rights.isSupergroup, isTrue);
      expect(rights.canManageLinks, isTrue);
      expect(rights.canDeleteChat, isTrue);
    });

    test('an administrator has the rights given', () async {
      json.answer = (r) => switch (r['@type']) {
        'getChat' => _chat(1, _superType(5)),
        'getSupergroup' => _supergroup(5, _admin(changeInfo: true)),
        _ => null,
      };
      final rights = await management.rights(1);
      expect(rights.isAdmin, isTrue);
      expect(rights.canChangeInfo, isTrue);
      expect(rights.canPromoteMembers, isFalse);
      expect(rights.canManageLinks, isFalse);
    });

    test('a member of a basic group has what everyone may', () async {
      json.answer = (r) => switch (r['@type']) {
        'getChat' => _chat(
          1,
          {'@type': 'chatTypeBasicGroup', 'basic_group_id': 3},
          permissions: {'@type': 'chatPermissions', 'can_change_info': true},
        ),
        'getBasicGroup' => _basicGroup(3, _member),
        _ => null,
      };
      final rights = await management.rights(1);
      expect(rights.isAdmin || rights.isOwner, isFalse);
      expect(rights.canChangeInfo, isTrue);
      expect(rights.canInviteUsers, isFalse);
    });

    test('a private chat has none', () async {
      json.answer = (r) => r['@type'] == 'getChat'
          ? _chat(1, {'@type': 'chatTypePrivate', 'user_id': 2})
          : null;
      expect((await management.rights(1)).isMember, isFalse);
    });
  });

  group('members', () {
    void supergroup({String status = 'creator'}) {
      json.answer = (r) => switch (r['@type']) {
        'getMe' => _user(1, 'Me'),
        'getChat' => _chat(10, _superType(5)),
        'getSupergroup' => _supergroup(
          5,
          status == 'creator' ? _creator : _admin(changeInfo: true),
        ),
        'getSupergroupMembers' => switch ((r['filter']! as Map)['@type']) {
          'supergroupMembersFilterAdministrators' => _members(2, [
            _chatMember(1, _creator),
            _chatMember(4, _admin(canBeEdited: true)),
          ]),
          'supergroupMembersFilterRecent' => _members(120, [
            for (final id in [4, 6, 7]) _chatMember(id, _member),
          ]),
          _ => _members(1, [_chatMember(7, _member)]),
        },
        'getUser' => _user(
          r['user_id']! as int,
          'User ${r['user_id']}',
          online: r['user_id'] == 7,
        ),
        _ => null,
      };
    }

    test('come admins first, then online, without repeats', () async {
      supergroup();
      final page = await management.members(10, limit: 3);
      expect([for (final m in page.members) m.userId], [1, 4, 7, 6]);
      expect(page.members.first.role, MemberRole.owner);
      expect(page.members.first.isSelf, isTrue);
      expect(page.hasMore, isTrue);
      expect(page.nextOffset, 3);
    });

    test('say what the user may do to each', () async {
      supergroup();
      final page = await management.members(10, limit: 3);
      final byId = {for (final m in page.members) m.userId: m};
      // Yourself and the owner: nothing.
      expect(byId[1]!.canPromote || byId[1]!.canRemove, isFalse);
      // An administrator you appointed: edit and remove, not restrict.
      expect(byId[4]!.canPromote, isTrue);
      expect(byId[4]!.canRemove, isTrue);
      expect(byId[4]!.canRestrict, isFalse);
      expect(byId[4]!.adminRights, isNotNull);
      // A member: everything.
      expect(byId[6]!.canPromote && byId[6]!.canRestrict, isTrue);
    });

    test('an administrator without rights may do nothing', () async {
      supergroup(status: 'admin');
      final page = await management.members(10, limit: 3);
      expect(
        page.members.any((m) => m.canPromote || m.canRemove || m.canRestrict),
        isFalse,
      );
    });

    test('search pages without the administrators', () async {
      supergroup();
      final page = await management.members(10, query: ' us ');
      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'getSupergroupMembers',
      );
      expect(request['filter'], {
        '@type': 'supergroupMembersFilterSearch',
        'query': 'us',
      });
      expect([for (final m in page.members) m.userId], [7]);
      expect(page.hasMore, isFalse);
    });

    test('of a basic group come whole and filter by name', () async {
      json.answer = (r) => switch (r['@type']) {
        'getMe' => _user(1, 'Me'),
        'getChat' => _chat(10, {
          '@type': 'chatTypeBasicGroup',
          'basic_group_id': 3,
        }),
        'getBasicGroup' => _basicGroup(3, _creator),
        'getBasicGroupFullInfo' => {
          '@type': 'basicGroupFullInfo',
          'members': [
            _chatMember(1, _creator),
            _chatMember(2, _member),
            _chatMember(3, _member),
          ],
          'bot_commands': <Object?>[],
        },
        'getUser' => _user(
          r['user_id']! as int,
          ['', 'Me', 'Vera', 'Boris'][r['user_id']! as int],
        ),
        _ => null,
      };
      final all = await management.members(10);
      expect(all.members, hasLength(3));
      // The owner of a basic group may remove and promote.
      expect(all.members.last.canRemove && all.members.last.canPromote, isTrue);
      expect(all.members.last.canRestrict, isFalse);
      final found = await management.members(10, query: 'ver');
      expect([for (final m in found.members) m.name], ['Vera']);
    });
  });

  group('actions', () {
    test('promote, demote, restrict and remove send the status', () async {
      final changed = <int>[];
      final sub = management.changes.listen(changed.add);
      const rights = td.ChatAdministratorRights(
        canManageChat: true,
        canChangeInfo: true,
        canPostMessages: false,
        canEditMessages: false,
        canDeleteMessages: true,
        canInviteUsers: true,
        canRestrictMembers: false,
        canPinMessages: true,
        canManageTopics: false,
        canPromoteMembers: false,
        canManageVideoChats: false,
        canPostStories: false,
        canEditStories: false,
        canDeleteStories: false,
        canManageDirectMessages: false,
        canManageTags: false,
        canSendWelcomeMessages: false,
        isAnonymous: false,
      );
      await management.promote(10, 4, rights);
      await management.demote(10, 4);
      await management.restrict(10, 6, _readOnly);
      await management.remove(10, 7);

      final statuses = [
        for (final r in json.sent)
          if (r['@type'] == 'setChatMemberStatus')
            (r['status']! as Map)['@type'],
      ];
      expect(statuses, [
        'chatMemberStatusAdministrator',
        'chatMemberStatusMember',
        'chatMemberStatusRestricted',
      ]);
      final ban = json.sent.lastWhere((r) => r['@type'] == 'banChatMember');
      expect(ban['member_id'], {'@type': 'messageSenderUser', 'user_id': 7});
      expect(changed, [10, 10, 10, 10]);
      await sub.cancel();
    });

    test('edit the title, description and photo', () async {
      await management.setTitle(10, '  Team ');
      await management.setDescription(10, 'About ');
      await management.setPhoto(10, '/tmp/a.jpg');
      await management.setPhoto(10, null);
      expect(
        json.sent.firstWhere((r) => r['@type'] == 'setChatTitle')['title'],
        'Team',
      );
      expect(
        json.sent.firstWhere(
          (r) => r['@type'] == 'setChatDescription',
        )['description'],
        'About',
      );
      final photos = [
        for (final r in json.sent)
          if (r['@type'] == 'setChatPhoto') r['photo'],
      ];
      expect((photos.first! as Map)['@type'], 'inputChatPhotoStatic');
      expect(photos.last, isNull);
    });

    test('follow member updates from elsewhere', () async {
      final changed = <int>[];
      final sub = management.changes.listen(changed.add);
      json.push({
        '@type': 'updateChatMember',
        'chat_id': 12,
        'old_chat_member': _chatMember(2, _member),
        'new_chat_member': _chatMember(2, _admin()),
      });
      // The fake hands out updates while TDLib is being asked something.
      await management.setTitle(12, 'Team');
      await pumpEventQueue();
      expect(changed, [12]);
      await sub.cancel();
    });
  });

  group('invite links', () {
    test('list the primary first', () async {
      json.answer = (r) => switch (r['@type']) {
        'getMe' => _user(1, 'Me'),
        'getChatInviteLinks' => {
          '@type': 'chatInviteLinks',
          'total_count': 2,
          'invite_links': [_link('b'), _link('a', primary: true)],
        },
        _ => null,
      };
      final links = await management.inviteLinks(10);
      expect(
        [for (final l in links) l.inviteLink],
        ['https://t.me/+a', 'https://t.me/+b'],
      );
      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'getChatInviteLinks',
      );
      expect(request['creator_user_id'], 1);
      expect(request['is_revoked'], isFalse);
    });

    test('create one that asks to join without a limit', () async {
      json.answer = (r) =>
          r['@type'] == 'createChatInviteLink' ? _link('c') : null;
      await management.createLink(
        10,
        name: ' Friends ',
        expiresAt: DateTime.fromMillisecondsSinceEpoch(5000 * 1000),
        memberLimit: 20,
        joinRequests: true,
      );
      final request = json.sent.lastWhere(
        (r) => r['@type'] == 'createChatInviteLink',
      );
      expect(request['name'], 'Friends');
      expect(request['expiration_date'], 5000);
      expect(request['member_limit'], 0);
      expect(request['creates_join_request'], isTrue);
    });

    test('revoking the primary link replaces it', () async {
      json.answer = (r) => switch (r['@type']) {
        'replacePrimaryChatInviteLink' => _link('n', primary: true),
        'revokeChatInviteLink' => {
          '@type': 'chatInviteLinks',
          'total_count': 0,
          'invite_links': <Object?>[],
        },
        _ => null,
      };
      final primary = td.ChatInviteLink.fromJson(_link('a', primary: true));
      final other = td.ChatInviteLink.fromJson(_link('b'));
      await management.revokeLink(10, primary);
      await management.revokeLink(10, other);
      final types = [for (final r in json.sent) r['@type']];
      expect(types, contains('replacePrimaryChatInviteLink'));
      final revoke = json.sent.lastWhere(
        (r) => r['@type'] == 'revokeChatInviteLink',
      );
      expect(revoke['invite_link'], 'https://t.me/+b');
    });
  });

  group('create', () {
    test('a group with members and a channel', () async {
      json.answer = (r) => switch (r['@type']) {
        'createNewBasicGroupChat' => {
          '@type': 'createdBasicGroupChat',
          'chat_id': 30,
          'failed_to_add_members': {
            '@type': 'failedToAddMembers',
            'failed_to_add_members': <Object?>[],
          },
        },
        'createNewSupergroupChat' => _chat(31, _superType(9, channel: true)),
        _ => null,
      };
      expect(await management.createGroup(' Trip ', [2, 3]), 30);
      expect(await management.createChannel('News', description: 'D'), 31);
      final group = json.sent.firstWhere(
        (r) => r['@type'] == 'createNewBasicGroupChat',
      );
      expect(group['user_ids'], [2, 3]);
      expect(group['title'], 'Trip');
      final channel = json.sent.firstWhere(
        (r) => r['@type'] == 'createNewSupergroupChat',
      );
      expect(channel['is_channel'], isTrue);
      expect(channel['description'], 'D');
    });

    test('leave and delete', () async {
      await management.leave(10);
      await management.deleteChat(11);
      expect([
        for (final r in json.sent) r['@type'],
      ], containsAll(['leaveChat', 'deleteChat']));
    });
  });
}

const _creator = {
  '@type': 'chatMemberStatusCreator',
  'is_anonymous': false,
  'is_member': true,
};

const _member = {'@type': 'chatMemberStatusMember', 'member_until_date': 0};

Map<String, Object?> _admin({
  bool canBeEdited = false,
  bool changeInfo = false,
}) => {
  '@type': 'chatMemberStatusAdministrator',
  'can_be_edited': canBeEdited,
  'rights': {'@type': 'chatAdministratorRights', 'can_change_info': changeInfo},
};

const _readOnly = td.ChatPermissions(
  canSendBasicMessages: false,
  canSendAudios: false,
  canSendDocuments: false,
  canSendPhotos: false,
  canSendVideos: false,
  canSendVideoNotes: false,
  canSendVoiceNotes: false,
  canSendPolls: false,
  canSendOtherMessages: false,
  canAddLinkPreviews: false,
  canReactToMessages: false,
  canEditTag: false,
  canChangeInfo: false,
  canInviteUsers: false,
  canPinMessages: false,
  canCreateTopics: false,
);

Map<String, Object?> _superType(int id, {bool channel = false}) => {
  '@type': 'chatTypeSupergroup',
  'supergroup_id': id,
  'is_channel': channel,
};

Map<String, Object?> _chat(
  int id,
  Map<String, Object?> type, {
  bool canDelete = false,
  Map<String, Object?> permissions = const {'@type': 'chatPermissions'},
}) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': 'Chat',
  'permissions': permissions,
  'can_be_deleted_for_all_users': canDelete,
  'positions': <Object?>[],
  'chat_lists': <Object?>[],
  'notification_settings': {'@type': 'chatNotificationSettings'},
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
};

Map<String, Object?> _supergroup(int id, Map<String, Object?> status) => {
  '@type': 'supergroup',
  'id': id,
  'status': status,
};

Map<String, Object?> _basicGroup(int id, Map<String, Object?> status) => {
  '@type': 'basicGroup',
  'id': id,
  'status': status,
};

Map<String, Object?> _user(int id, String name, {bool online = false}) => {
  '@type': 'user',
  'id': id,
  'first_name': name,
  'last_name': '',
  'phone_number': '',
  'status': online
      ? {'@type': 'userStatusOnline', 'expires': 99}
      : {'@type': 'userStatusRecently', 'by_my_privacy_settings': false},
  'type': {'@type': 'userTypeRegular'},
};

Map<String, Object?> _chatMember(int userId, Map<String, Object?> status) => {
  '@type': 'chatMember',
  'member_id': {'@type': 'messageSenderUser', 'user_id': userId},
  'inviter_user_id': 1,
  'status': status,
};

Map<String, Object?> _members(int total, List<Map<String, Object?>> list) => {
  '@type': 'chatMembers',
  'total_count': total,
  'members': list,
};

Map<String, Object?> _link(String code, {bool primary = false}) => {
  '@type': 'chatInviteLink',
  'invite_link': 'https://t.me/+$code',
  'name': '',
  'creator_user_id': 1,
  'is_primary': primary,
};

/// Answers each request with what [answer] gives for it, `ok` otherwise.
final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  Map<String, Object?>? Function(Map<String, Object?> request) answer = (_) =>
      null;
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    sent.add(decoded);
    final type = decoded['@type']! as String;
    _queue.add(
      jsonEncode({
        ...answer(decoded) ?? {'@type': 'ok'},
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (type == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
