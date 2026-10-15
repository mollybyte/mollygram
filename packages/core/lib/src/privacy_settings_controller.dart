import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A privacy setting of the account, as the Privacy and security page
/// lists them.
enum PrivacyRule {
  phoneNumber,

  /// Who can find the user by phone number; asked only while
  /// [phoneNumber] isn't shown to everybody.
  findByPhoneNumber,
  lastSeen,
  profilePhoto,
  forwards,
  calls,
  voiceMessages,
  invites,
  bio,
  birthday;

  td.UserPrivacySetting get setting => switch (this) {
    phoneNumber => const td.UserPrivacySettingShowPhoneNumber(),
    findByPhoneNumber => const td.UserPrivacySettingAllowFindingByPhoneNumber(),
    lastSeen => const td.UserPrivacySettingShowStatus(),
    profilePhoto => const td.UserPrivacySettingShowProfilePhoto(),
    forwards => const td.UserPrivacySettingShowLinkInForwardedMessages(),
    calls => const td.UserPrivacySettingAllowCalls(),
    voiceMessages =>
      const td.UserPrivacySettingAllowPrivateVoiceAndVideoNoteMessages(),
    invites => const td.UserPrivacySettingAllowChatInvites(),
    bio => const td.UserPrivacySettingShowBio(),
    birthday => const td.UserPrivacySettingShowBirthdate(),
  };

  /// The audiences Telegram takes for this setting: finding by phone
  /// number and group invites can't be closed to everyone.
  List<PrivacyAudience> get audiences => switch (this) {
    findByPhoneNumber ||
    invites => const [PrivacyAudience.everybody, PrivacyAudience.contacts],
    _ => PrivacyAudience.values,
  };

  /// Whether the setting takes "Always allow" and "Never allow" lists.
  bool get hasExceptions => this != findByPhoneNumber;

  static PrivacyRule? of(td.UserPrivacySetting setting) {
    for (final rule in values) {
      if (rule.setting.tdType == setting.tdType) return rule;
    }
    return null;
  }
}

/// Who a privacy setting is open to before its exceptions.
enum PrivacyAudience { everybody, contacts, nobody }

/// A privacy setting as the user picks it: an audience and the people
/// and groups always or never allowed. Rules the app doesn't show, such
/// as Premium users or bots, are kept as they are.
final class PrivacyChoice {
  const PrivacyChoice({
    required this.audience,
    this.alwaysUsers = const [],
    this.neverUsers = const [],
    this.alwaysChats = const [],
    this.neverChats = const [],
    this.kept = const [],
  });

  /// Reads TDLib's rules: the first of "allow all", "allow contacts" is
  /// the audience, nobody when neither is there.
  factory PrivacyChoice.fromTd(td.UserPrivacySettingRules rules) {
    var audience = PrivacyAudience.nobody;
    final alwaysUsers = <int>[];
    final neverUsers = <int>[];
    final alwaysChats = <int>[];
    final neverChats = <int>[];
    final kept = <td.UserPrivacySettingRule>[];
    for (final rule in rules.rules) {
      switch (rule) {
        case td.UserPrivacySettingRuleAllowAll():
          if (audience == PrivacyAudience.nobody) {
            audience = PrivacyAudience.everybody;
          }
        case td.UserPrivacySettingRuleAllowContacts():
          if (audience == PrivacyAudience.nobody) {
            audience = PrivacyAudience.contacts;
          }
        case td.UserPrivacySettingRuleRestrictAll():
          break;
        case td.UserPrivacySettingRuleAllowUsers(:final userIds):
          alwaysUsers.addAll(userIds);
        case td.UserPrivacySettingRuleRestrictUsers(:final userIds):
          neverUsers.addAll(userIds);
        case td.UserPrivacySettingRuleAllowChatMembers(:final chatIds):
          alwaysChats.addAll(chatIds);
        case td.UserPrivacySettingRuleRestrictChatMembers(:final chatIds):
          neverChats.addAll(chatIds);
        default:
          kept.add(rule);
      }
    }
    return PrivacyChoice(
      audience: audience,
      alwaysUsers: List.unmodifiable(alwaysUsers),
      neverUsers: List.unmodifiable(neverUsers),
      alwaysChats: List.unmodifiable(alwaysChats),
      neverChats: List.unmodifiable(neverChats),
      kept: List.unmodifiable(kept),
    );
  }

  final PrivacyAudience audience;
  final List<int> alwaysUsers;
  final List<int> neverUsers;

  /// Groups whose members are always or never allowed.
  final List<int> alwaysChats;
  final List<int> neverChats;

  /// Rules this choice doesn't edit, sent back unchanged.
  final List<td.UserPrivacySettingRule> kept;

  /// "Always allow" means nothing when everybody is allowed, and "never
  /// allow" nothing when nobody is.
  bool get showsAlways => audience != PrivacyAudience.everybody;
  bool get showsNever => audience != PrivacyAudience.nobody;

  /// How many people and groups are always allowed, as shown.
  int get alwaysCount =>
      showsAlways ? alwaysUsers.length + alwaysChats.length : 0;
  int get neverCount => showsNever ? neverUsers.length + neverChats.length : 0;

  /// TDLib's rules, checked in order: the exceptions, the kept rules,
  /// then the audience. Exceptions the audience makes moot are dropped.
  td.UserPrivacySettingRules toTd() => td.UserPrivacySettingRules(
    rules: [
      // People named one by one come before groups, so someone in
      // "never allow" stays out even when a group they're in is allowed.
      if (showsAlways && alwaysUsers.isNotEmpty)
        td.UserPrivacySettingRuleAllowUsers(userIds: alwaysUsers),
      if (showsNever && neverUsers.isNotEmpty)
        td.UserPrivacySettingRuleRestrictUsers(userIds: neverUsers),
      if (showsAlways && alwaysChats.isNotEmpty)
        td.UserPrivacySettingRuleAllowChatMembers(chatIds: alwaysChats),
      if (showsNever && neverChats.isNotEmpty)
        td.UserPrivacySettingRuleRestrictChatMembers(chatIds: neverChats),
      ...kept,
      ...switch (audience) {
        PrivacyAudience.everybody => const [
          td.UserPrivacySettingRuleAllowAll(),
        ],
        PrivacyAudience.contacts => const [
          td.UserPrivacySettingRuleAllowContacts(),
          td.UserPrivacySettingRuleRestrictAll(),
        ],
        PrivacyAudience.nobody => const [
          td.UserPrivacySettingRuleRestrictAll(),
        ],
      },
    ],
  );

  /// A copy with [audience]; someone in both lists ends up only in the
  /// one changed last.
  PrivacyChoice copyWith({
    PrivacyAudience? audience,
    List<int>? alwaysUsers,
    List<int>? neverUsers,
    List<int>? alwaysChats,
    List<int>? neverChats,
  }) {
    var always = alwaysUsers ?? this.alwaysUsers;
    var never = neverUsers ?? this.neverUsers;
    if (alwaysUsers != null) {
      never = [...never.where((id) => !alwaysUsers.contains(id))];
    } else if (neverUsers != null) {
      always = [...always.where((id) => !neverUsers.contains(id))];
    }
    var alwaysGroups = alwaysChats ?? this.alwaysChats;
    var neverGroups = neverChats ?? this.neverChats;
    if (alwaysChats != null) {
      neverGroups = [...neverGroups.where((id) => !alwaysChats.contains(id))];
    } else if (neverChats != null) {
      alwaysGroups = [...alwaysGroups.where((id) => !neverChats.contains(id))];
    }
    return PrivacyChoice(
      audience: audience ?? this.audience,
      alwaysUsers: List.unmodifiable(always),
      neverUsers: List.unmodifiable(never),
      alwaysChats: List.unmodifiable(alwaysGroups),
      neverChats: List.unmodifiable(neverGroups),
      kept: kept,
    );
  }
}

/// A person or a group as a privacy list shows it.
final class PrivacyPeer {
  const PrivacyPeer({
    required this.id,
    required this.name,
    this.isChat = false,
    this.isBot = false,
    this.photo,
  });

  /// A user id, or a chat id when [isChat].
  final int id;
  final bool isChat;
  final bool isBot;
  final String name;
  final td.File? photo;
}

/// One page of the blocked list.
final class BlockedPage {
  const BlockedPage({
    required this.peers,
    required this.totalCount,
    required this.nextOffset,
  });

  /// The senders of the page that TDLib could name; one it couldn't is
  /// left out but still counts toward [nextOffset].
  final List<PrivacyPeer> peers;
  final int totalCount;

  /// Where the next page starts: the offset asked for plus every sender
  /// TDLib returned.
  final int nextOffset;

  bool get hasMore => nextOffset < totalCount;
}

/// The account's privacy settings and blocked list, after TelegramSwift's
/// PrivacyAndSecurityViewController.
final class PrivacySettingsController {
  PrivacySettingsController(this._client);

  final td.TdClient _client;
  final _changes = StreamController<PrivacyRule>.broadcast(sync: true);
  final _blockedChanges = StreamController<void>.broadcast(sync: true);
  final _choices = <PrivacyRule, PrivacyChoice>{};
  StreamSubscription<td.TdObject>? _subscription;

  /// How many blocked senders a page asks for; TDLib's most is 100.
  static const pageSize = 50;
  static const maxPageSize = 100;

  /// Fires with a setting that changed, here or on another device.
  Stream<PrivacyRule> get changes => _changes.stream;

  /// Fires when someone is blocked or unblocked.
  Stream<void> get blockedChanges => _blockedChanges.stream;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateUserPrivacySettingRules(:final setting, :final rules):
        final rule = PrivacyRule.of(setting);
        if (rule == null) return;
        _choices[rule] = PrivacyChoice.fromTd(rules);
        if (!_changes.isClosed) _changes.add(rule);
      case td.UpdateChatBlockList(blockList: null || td.BlockListMain()):
        if (!_blockedChanges.isClosed) _blockedChanges.add(null);
      default:
        return;
    }
  }

  /// The setting as TDLib last told it, or null before it is asked.
  PrivacyChoice? cached(PrivacyRule rule) => _choices[rule];

  Future<PrivacyChoice> choice(PrivacyRule rule) async {
    final rules = await _client.send(
      td.GetUserPrivacySettingRules(setting: rule.setting),
    );
    return _choices[rule] = PrivacyChoice.fromTd(rules);
  }

  /// Every setting the page lists, asked for at once. A setting that
  /// fails to load is left out, so the others still show; only when all
  /// fail is the error thrown.
  Future<Map<PrivacyRule, PrivacyChoice>> choices() async {
    Object? error;
    final all = await Future.wait([
      for (final rule in PrivacyRule.values)
        choice(rule).then<PrivacyChoice?>(
          (value) => value,
          onError: (Object e) {
            error = e;
            return null;
          },
        ),
    ]);
    final loaded = {
      for (var i = 0; i < all.length; i++) PrivacyRule.values[i]: ?all[i],
    };
    if (loaded.isEmpty && error != null) throw error!;
    return loaded;
  }

  /// Saves [choice]; on failure the setting stays as it was and the
  /// error is rethrown.
  Future<void> setChoice(PrivacyRule rule, PrivacyChoice choice) async {
    await _client.send(
      td.SetUserPrivacySettingRules(
        setting: rule.setting,
        rules: choice.toTd(),
      ),
    );
    _choices[rule] = choice;
    if (!_changes.isClosed) _changes.add(rule);
  }

  /// Names and photos of [userIds] and [chatIds]; ones TDLib doesn't
  /// know are left out.
  Future<List<PrivacyPeer>> describe({
    Iterable<int> userIds = const [],
    Iterable<int> chatIds = const [],
  }) async {
    final peers = await Future.wait([
      for (final id in userIds) _user(id),
      for (final id in chatIds) _chat(id),
    ]);
    return [...peers.nonNulls];
  }

  Future<PrivacyPeer?> _user(int id) async {
    try {
      final user = await _client.send(td.GetUser(userId: id));
      return PrivacyPeer(
        id: id,
        name: [
          user.firstName,
          user.lastName,
        ].where((s) => s.isNotEmpty).join(' '),
        isBot: user.type is td.UserTypeBot,
        photo: user.profilePhoto?.small,
      );
    } on td.TdException {
      return null;
    }
  }

  Future<PrivacyPeer?> _chat(int id) async {
    try {
      final chat = await _client.send(td.GetChat(chatId: id));
      return PrivacyPeer(
        id: id,
        name: chat.title,
        isChat: true,
        photo: chat.photo?.small,
      );
    } on td.TdException {
      return null;
    }
  }

  /// A page of the people and chats the user blocked, newest first;
  /// [limit] 1 is enough to learn how many there are.
  Future<BlockedPage> blocked({int offset = 0, int limit = pageSize}) async {
    final found = await _client.send(
      td.GetBlockedMessageSenders(
        blockList: const td.BlockListMain(),
        offset: offset,
        limit: limit,
      ),
    );
    final peers = await Future.wait<PrivacyPeer?>([
      for (final sender in found.senders)
        switch (sender) {
          td.MessageSenderUser(:final userId) => _user(userId),
          td.MessageSenderChat(:final chatId) => _chat(chatId),
        },
    ]);
    return BlockedPage(
      peers: [...peers.nonNulls],
      totalCount: found.totalCount,
      nextOffset: offset + found.senders.length,
    );
  }

  Future<void> block(int userId) => _setBlocked(
    td.MessageSenderUser(userId: userId),
    const td.BlockListMain(),
  );

  Future<void> unblock(PrivacyPeer peer) => _setBlocked(
    peer.isChat
        ? td.MessageSenderChat(chatId: peer.id)
        : td.MessageSenderUser(userId: peer.id),
    null,
  );

  Future<void> _setBlocked(td.MessageSender sender, td.BlockList? list) async {
    await _client.send(
      td.SetMessageSenderBlockList(senderId: sender, blockList: list),
    );
    if (!_blockedChanges.isClosed) _blockedChanges.add(null);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
    await _blockedChanges.close();
  }
}
