import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late PrivacySettingsController privacy;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    privacy = PrivacySettingsController(tdlib.createClient());
    await privacy.start();
  });

  tearDown(() async {
    await privacy.dispose();
    await tdlib.close();
  });

  Future<void> drain() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  List<String> rulesSent() => [
    for (final rule
        in ((sent('setUserPrivacySettingRules')['rules']! as Map)['rules']!
            as List))
      (rule as Map)['@type']! as String,
  ];

  group('choice', () {
    PrivacyChoice read(List<Map<String, Object?>> rules) =>
        PrivacyChoice.fromTd(
          td.UserPrivacySettingRules.fromJson({
            '@type': 'userPrivacySettingRules',
            'rules': rules,
          }),
        );

    test('reads the audience and the exceptions', () {
      final choice = read([
        _users('userPrivacySettingRuleAllowUsers', [5, 6]),
        _chats('userPrivacySettingRuleRestrictChatMembers', [20]),
        {'@type': 'userPrivacySettingRuleAllowContacts'},
        {'@type': 'userPrivacySettingRuleRestrictAll'},
      ]);
      expect(choice.audience, PrivacyAudience.contacts);
      expect(choice.alwaysUsers, [5, 6]);
      expect(choice.neverChats, [20]);
      expect(choice.alwaysCount, 2);
      expect(choice.neverCount, 1);
    });

    test('reads no rules as nobody and allow all as everybody', () {
      expect(read([]).audience, PrivacyAudience.nobody);
      expect(
        read([
          _users('userPrivacySettingRuleRestrictUsers', [7]),
          {'@type': 'userPrivacySettingRuleAllowAll'},
        ]).audience,
        PrivacyAudience.everybody,
      );
    });

    test('writes exceptions before the audience and keeps other rules', () {
      final choice = read([
        {'@type': 'userPrivacySettingRuleAllowPremiumUsers'},
        _users('userPrivacySettingRuleAllowUsers', [5]),
        _users('userPrivacySettingRuleRestrictUsers', [6]),
        {'@type': 'userPrivacySettingRuleAllowContacts'},
      ]);
      expect(
        [for (final r in choice.toTd().rules) r.tdType],
        [
          'userPrivacySettingRuleAllowUsers',
          'userPrivacySettingRuleRestrictUsers',
          'userPrivacySettingRuleAllowPremiumUsers',
          'userPrivacySettingRuleAllowContacts',
          'userPrivacySettingRuleRestrictAll',
        ],
      );

      // Everybody makes "always allow" moot, so it isn't sent.
      final open = choice.copyWith(audience: PrivacyAudience.everybody);
      expect(open.alwaysCount, 0);
      expect(open.neverCount, 1);
      expect(
        [for (final r in open.toTd().rules) r.tdType],
        [
          'userPrivacySettingRuleRestrictUsers',
          'userPrivacySettingRuleAllowPremiumUsers',
          'userPrivacySettingRuleAllowAll',
        ],
      );
      // The lists are kept for when the audience changes back.
      expect(open.alwaysUsers, [5]);
    });

    test('someone moved to one list leaves the other', () {
      final choice = read([
        _users('userPrivacySettingRuleAllowUsers', [5, 6]),
        {'@type': 'userPrivacySettingRuleAllowContacts'},
      ]).copyWith(neverUsers: [6, 7]);
      expect(choice.alwaysUsers, [5]);
      expect(choice.neverUsers, [6, 7]);
    });

    test('finding by phone and invites cannot be closed to everyone', () {
      expect(
        PrivacyRule.invites.audiences,
        isNot(contains(PrivacyAudience.nobody)),
      );
      expect(PrivacyRule.findByPhoneNumber.hasExceptions, isFalse);
      expect(PrivacyRule.lastSeen.audiences, PrivacyAudience.values);
      expect(
        PrivacyRule.of(const td.UserPrivacySettingShowBirthdate()),
        PrivacyRule.birthday,
      );
    });
  });

  test('asks for every setting', () async {
    final all = await privacy.choices();
    expect(all.keys, PrivacyRule.values);
    expect(all[PrivacyRule.lastSeen]!.audience, PrivacyAudience.contacts);
    expect(all[PrivacyRule.phoneNumber]!.audience, PrivacyAudience.nobody);
    expect(
      privacy.cached(PrivacyRule.calls)!.audience,
      PrivacyAudience.everybody,
    );
  });

  test('saves a setting and says so', () async {
    final changed = <PrivacyRule>[];
    privacy.changes.listen(changed.add);
    await privacy.setChoice(
      PrivacyRule.lastSeen,
      const PrivacyChoice(audience: PrivacyAudience.nobody, alwaysUsers: [5]),
    );
    expect(sent('setUserPrivacySettingRules')['setting'], {
      '@type': 'userPrivacySettingShowStatus',
    });
    expect(rulesSent(), [
      'userPrivacySettingRuleAllowUsers',
      'userPrivacySettingRuleRestrictAll',
    ]);
    expect(changed, [PrivacyRule.lastSeen]);
    expect(
      privacy.cached(PrivacyRule.lastSeen)!.audience,
      PrivacyAudience.nobody,
    );
  });

  test('a failed save keeps the setting and rethrows', () async {
    await privacy.choice(PrivacyRule.lastSeen);
    json.failing.add('setUserPrivacySettingRules');
    await expectLater(
      privacy.setChoice(
        PrivacyRule.lastSeen,
        const PrivacyChoice(audience: PrivacyAudience.nobody),
      ),
      throwsA(isA<td.TdException>()),
    );
    expect(
      privacy.cached(PrivacyRule.lastSeen)!.audience,
      PrivacyAudience.contacts,
    );
  });

  test('follows changes made on another device', () async {
    final changed = <PrivacyRule>[];
    privacy.changes.listen(changed.add);
    json.push({
      '@type': 'updateUserPrivacySettingRules',
      'setting': {'@type': 'userPrivacySettingShowBio'},
      'rules': {
        '@type': 'userPrivacySettingRules',
        'rules': [
          {'@type': 'userPrivacySettingRuleRestrictAll'},
        ],
      },
    });
    await privacy.blocked(); // Any request lets the updates through.
    await drain();
    expect(changed, [PrivacyRule.bio]);
    expect(privacy.cached(PrivacyRule.bio)!.audience, PrivacyAudience.nobody);
  });

  test('names people and groups, leaving out unknown ones', () async {
    final peers = await privacy.describe(userIds: [5, 99], chatIds: [20]);
    expect([for (final p in peers) p.name], ['U5', 'Flutter']);
    expect(peers.last.isChat, isTrue);
  });

  test('lists, blocks and unblocks', () async {
    var changes = 0;
    privacy.blockedChanges.listen((_) => changes++);

    final page = await privacy.blocked();
    expect([for (final p in page.peers) p.name], ['U5', 'U6', 'Flutter']);
    expect(page.peers[1].isBot, isTrue);
    expect(page.hasMore, isTrue);
    expect(sent('getBlockedMessageSenders')['limit'], 50);

    await privacy.blocked(offset: 3);
    expect(sent('getBlockedMessageSenders')['offset'], 3);

    await privacy.block(7);
    expect(
      sent('setMessageSenderBlockList'),
      containsPair('block_list', {'@type': 'blockListMain'}),
    );
    await privacy.unblock(page.peers.last);
    final unblock = sent('setMessageSenderBlockList');
    expect(unblock['sender_id'], {'@type': 'messageSenderChat', 'chat_id': 20});
    expect(unblock['block_list'], isNull);
    expect(changes, 2);

    json.push({'@type': 'updateChatBlockList', 'chat_id': 5});
    await privacy.blocked();
    await drain();
    expect(changes, 3);
  });

  test('a failed unblock is not reported as done', () async {
    var changes = 0;
    privacy.blockedChanges.listen((_) => changes++);
    json.failing.add('setMessageSenderBlockList');
    await expectLater(
      privacy.unblock(const PrivacyPeer(id: 5, name: 'U5')),
      throwsA(isA<td.TdException>()),
    );
    expect(changes, 0);
  });
}

Map<String, Object?> _users(String type, List<int> ids) => {
  '@type': type,
  'user_ids': ids,
};

Map<String, Object?> _chats(String type, List<int> ids) => {
  '@type': type,
  'chat_ids': ids,
};

Map<String, Object?> _rules(List<String> types) => {
  '@type': 'userPrivacySettingRules',
  'rules': [
    for (final type in types) {'@type': type},
  ],
};

Map<String, Object?> _user(int id, {bool bot = false}) => {
  '@type': 'user',
  'id': id,
  'first_name': 'U$id',
  'last_name': '',
  'phone_number': '',
  'status': {'@type': 'userStatusEmpty'},
  'type': bot
      ? {'@type': 'userTypeBot', 'inline_query_placeholder': ''}
      : {'@type': 'userTypeRegular'},
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final failing = <String>{};
  var _nextClientId = 0;

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  Map<String, Object?> _rulesOf(Object? setting) =>
      switch ((setting! as Map)['@type']) {
        'userPrivacySettingShowStatus' => _rules([
          'userPrivacySettingRuleAllowContacts',
        ]),
        'userPrivacySettingShowPhoneNumber' => _rules([
          'userPrivacySettingRuleRestrictAll',
        ]),
        _ => _rules(['userPrivacySettingRuleAllowAll']),
      };

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final type = decoded['@type']! as String;
    if (type != 'close') sent.add(decoded);
    final Map<String, Object?> response = failing.contains(type)
        ? {'@type': 'error', 'code': 400, 'message': 'Failed'}
        : switch (type) {
            'getUserPrivacySettingRules' => _rulesOf(decoded['setting']),
            'getUser' => switch (decoded['user_id']) {
              5 || 7 => _user(decoded['user_id']! as int),
              6 => _user(6, bot: true),
              _ => {'@type': 'error', 'code': 404, 'message': 'Not found'},
            },
            'getChat' => {
              '@type': 'chat',
              'id': 20,
              'type': {
                '@type': 'chatTypeSupergroup',
                'supergroup_id': 3,
                'is_channel': false,
              },
              'title': 'Flutter',
              'permissions': {'@type': 'chatPermissions'},
              'notification_settings': {'@type': 'chatNotificationSettings'},
              'available_reactions': {
                '@type': 'chatAvailableReactionsAll',
                'max_reaction_count': 11,
              },
              'video_chat': {'@type': 'videoChat'},
            },
            'getBlockedMessageSenders' => {
              '@type': 'messageSenders',
              'total_count': 5,
              'senders': [
                {'@type': 'messageSenderUser', 'user_id': 5},
                {'@type': 'messageSenderUser', 'user_id': 6},
                {'@type': 'messageSenderChat', 'chat_id': 20},
              ],
            },
            _ => {'@type': 'ok'},
          };
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (type == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': 1,
        }),
      );
    }
  }
}
