import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late LinkResolver links;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    links = LinkResolver(tdlib.createClient());
  });

  tearDown(() => tdlib.close());

  List<Object?> sentTypes() => [for (final r in json.sent) r['@type']];

  test('offers the proxy of a proxy link', () async {
    json.linkType = {
      '@type': 'internalLinkTypeProxy',
      'proxy': {
        '@type': 'proxy',
        'server': 'mt.example',
        'port': 443,
        'type': {'@type': 'proxyTypeMtproto', 'secret': 'ee00'},
      },
    };
    final target = await links.resolve(
      'tg://proxy?server=mt.example&port=443&secret=ee00',
    );
    expect(
      (target! as ProxyLinkTarget).proxy,
      const ProxySettings(
        server: 'mt.example',
        port: 443,
        kind: ProxyKind.mtproto,
        secret: 'ee00',
      ),
    );
  });

  test('a proxy link without a proxy is not supported', () async {
    json.linkType = {'@type': 'internalLinkTypeProxy'};
    final target = await links.resolve('tg://proxy?server=x');
    expect(target, isA<UnsupportedLinkTarget>());
    expect((target! as UnsupportedLinkTarget).webFallback, isNull);
  });

  test('opens other sites in the browser without asking TDLib', () async {
    final target = await links.resolve('example.com/page');
    expect(target, isA<ExternalLinkTarget>());
    expect(
      (target! as ExternalLinkTarget).uri.toString(),
      'https://example.com/page',
    );
    expect(json.sent, isEmpty);
  });

  test('ignores text that is not a link and unsafe schemes', () async {
    expect(await links.resolve('two words'), isNull);
    expect(await links.resolve('file:///etc/passwd'), isNull);
    expect(json.sent, isEmpty);
  });

  test('opens a chat the user is in by its username', () async {
    json.linkType = {
      '@type': 'internalLinkTypePublicChat',
      'chat_username': 'friends',
    };
    json.chat = _chat(7, 'Friends', supergroup: 70);
    json.memberStatus = 'chatMemberStatusMember';
    final target = await links.resolve('@friends');
    expect((target! as ChatLinkTarget).chatId, 7);
    expect(json.sent.first['link'], 'https://t.me/friends');
    expect(sentTypes(), [
      'getInternalLinkType',
      'searchPublicChat',
      'getSupergroup',
    ]);
  });

  test('previews a public channel the user is not in', () async {
    json.linkType = {
      '@type': 'internalLinkTypePublicChat',
      'chat_username': 'news',
    };
    json.chat = _chat(8, 'News', supergroup: 80, channel: true);
    final target = await links.resolve('https://t.me/news');
    final preview = (target! as JoinLinkTarget).preview;
    expect(preview.chatId, 8);
    expect(preview.title, 'News');
    expect(preview.isChannel, isTrue);
    expect(preview.username, 'news');
    expect(preview.memberCount, 1200);
    expect(preview.description, 'Daily news');
    expect(preview.inviteLink, isNull);
    expect(preview.canPreview, isTrue);
  });

  test(
    'previews a group the user is restricted in but not a member of',
    () async {
      json.linkType = {
        '@type': 'internalLinkTypePublicChat',
        'chat_username': 'talk',
      };
      json.chat = _chat(9, 'Talk', supergroup: 90);
      json.memberStatusJson = {
        '@type': 'chatMemberStatusRestricted',
        'is_member': false,
        'permissions': {'@type': 'chatPermissions'},
      };
      expect(await links.resolve('t.me/talk'), isA<JoinLinkTarget>());
      json.memberStatusJson = {
        '@type': 'chatMemberStatusRestricted',
        'is_member': true,
        'permissions': {'@type': 'chatPermissions'},
      };
      expect(
        (await links.resolve('t.me/talk'))! as ChatLinkTarget,
        isA<ChatLinkTarget>(),
      );
    },
  );

  test('refuses a chat the user was banned from', () async {
    json.linkType = {
      '@type': 'internalLinkTypePublicChat',
      'chat_username': 'club',
    };
    json.chat = _chat(9, 'Club', supergroup: 90);
    json.memberStatus = 'chatMemberStatusBanned';
    expect(await links.resolve('t.me/club'), isA<ForbiddenLinkTarget>());
  });

  test('opens a private chat by username', () async {
    json.linkType = {
      '@type': 'internalLinkTypePublicChat',
      'chat_username': 'anna',
    };
    json.chat = _chat(3, 'Anna');
    final target = await links.resolve('tg://resolve?domain=anna');
    expect((target! as ChatLinkTarget).chatId, 3);
    expect(sentTypes(), ['getInternalLinkType', 'searchPublicChat']);
  });

  test('reports an unknown username', () async {
    json.linkType = {
      '@type': 'internalLinkTypePublicChat',
      'chat_username': 'nobody',
    };
    json.chat = null;
    expect(await links.resolve('t.me/nobody'), isA<MissingLinkTarget>());
  });

  test('asks before joining through an invite link', () async {
    json.linkType = {
      '@type': 'internalLinkTypeChatInvite',
      'invite_link': 'https://t.me/+abc',
    };
    final target = await links.resolve('https://t.me/+abc');
    final preview = (target! as JoinLinkTarget).preview;
    expect(preview.inviteLink, 'https://t.me/+abc');
    expect(preview.title, 'Book club');
    expect(preview.memberCount, 12);
    expect(preview.isChannel, isFalse);
    expect(preview.createsJoinRequest, isTrue);
    expect(preview.canPreview, isFalse);
  });

  test('opens the chat of an invite link the user already used', () async {
    json.linkType = {
      '@type': 'internalLinkTypeChatInvite',
      'invite_link': 'https://t.me/+abc',
    };
    json.inviteChatId = 9;
    json.chat = _chat(9, 'Book club', inList: true);
    final target = await links.resolve('tg://join?invite=abc');
    expect((target! as ChatLinkTarget).chatId, 9);
  });

  test('reports an expired invite link', () async {
    json.linkType = {
      '@type': 'internalLinkTypeChatInvite',
      'invite_link': 'https://t.me/+old',
    };
    json.inviteExpired = true;
    expect(await links.resolve('https://t.me/+old'), isA<MissingLinkTarget>());
  });

  test('opens the chat of a message link', () async {
    json.linkType = {
      '@type': 'internalLinkTypeMessage',
      'url': 'https://t.me/c/123/45',
    };
    json.messageChatId = 5;
    final target = await links.resolve('https://t.me/c/123/45');
    expect((target! as ChatLinkTarget).chatId, 5);
    expect(json.sent.last['url'], 'https://t.me/c/123/45');
  });

  test('reports a message link to a chat out of reach', () async {
    json.linkType = {
      '@type': 'internalLinkTypeMessage',
      'url': 'https://t.me/c/1/2',
    };
    json.messageChatId = 0;
    expect(await links.resolve('t.me/c/1/2'), isA<MissingLinkTarget>());
  });

  test('maps settings links to the settings command', () async {
    json.linkType = {'@type': 'internalLinkTypeSettings'};
    final target = await links.resolve('tg://settings');
    expect((target! as CommandLinkTarget).commandId, 'app.settings');
  });

  test('sends unsupported web links to the browser', () async {
    json.linkType = {
      '@type': 'internalLinkTypeStickerSet',
      'sticker_set_name': 'cats',
    };
    final web = await links.resolve('https://t.me/addstickers/cats');
    expect(
      (web! as UnsupportedLinkTarget).webFallback.toString(),
      'https://t.me/addstickers/cats',
    );
    final tg = await links.resolve('tg://addstickers?set=cats');
    expect((tg! as UnsupportedLinkTarget).webFallback, isNull);
  });

  test('opens t.me pages TDLib does not know on the site', () async {
    json.linkType = null;
    final target = await links.resolve('https://t.me/');
    expect(target, isA<ExternalLinkTarget>());
    final tg = await links.resolve('tg://whatever');
    expect(tg, isA<UnsupportedLinkTarget>());
  });

  group('join', () {
    const invite = ChatJoinPreview(
      title: 'Book club',
      isChannel: false,
      inviteLink: 'https://t.me/+abc',
    );
    const public = ChatJoinPreview(title: 'News', isChannel: true, chatId: 8);

    test('joins through the invite link', () async {
      json.joinResult = {'@type': 'chatJoinResultSuccess', 'chat_id': 9};
      final result = await links.join(invite);
      expect((result as ChatJoined).chatId, 9);
      expect(json.sent.single['@type'], 'joinChatByInviteLink');
      expect(json.sent.single['invite_link'], 'https://t.me/+abc');
    });

    test('joins a public chat by id', () async {
      json.joinResult = {'@type': 'chatJoinResultSuccess', 'chat_id': 0};
      final result = await links.join(public);
      expect((result as ChatJoined).chatId, 8);
      expect(json.sent.single['@type'], 'joinChat');
      expect(json.sent.single['chat_id'], 8);
    });

    test('reports a sent request and failures', () async {
      json.joinResult = {'@type': 'chatJoinResultRequestSent'};
      expect(await links.join(invite), isA<JoinRequestSent>());
      json.joinResult = null;
      expect(await links.join(invite), isA<JoinFailed>());
    });
  });
}

Map<String, Object?> _chat(
  int id,
  String title, {
  int? supergroup,
  bool channel = false,
  bool inList = false,
}) => {
  '@type': 'chat',
  'id': id,
  'title': title,
  'type': supergroup == null
      ? {'@type': 'chatTypePrivate', 'user_id': id}
      : {
          '@type': 'chatTypeSupergroup',
          'supergroup_id': supergroup,
          'is_channel': channel,
        },
  'positions': [
    if (inList)
      {
        '@type': 'chatPosition',
        'list': {'@type': 'chatListMain'},
        'order': '1',
        'is_pinned': false,
      },
  ],
  'permissions': {'@type': 'chatPermissions'},
  'notification_settings': {'@type': 'chatNotificationSettings'},
  'available_reactions': {'@type': 'chatAvailableReactionsAll'},
  'video_chat': {'@type': 'videoChat'},
};

const _error = {'@type': 'error', 'code': 400, 'message': 'Bad request'};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  Map<String, Object?>? linkType;
  Map<String, Object?>? chat;
  String memberStatus = 'chatMemberStatusLeft';
  Map<String, Object?>? memberStatusJson;
  int inviteChatId = 0;
  bool inviteExpired = false;
  int messageChatId = 0;
  Map<String, Object?>? joinResult;
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
    if (decoded['@type'] != 'close') sent.add(decoded);
    final response = switch (decoded['@type']) {
      'getInternalLinkType' => linkType ?? _error,
      'searchPublicChat' || 'getChat' => chat ?? _error,
      'getSupergroup' => {
        '@type': 'supergroup',
        'id': 1,
        'status': memberStatusJson ?? {'@type': memberStatus},
        'member_count': 1200,
      },
      'getSupergroupFullInfo' => {
        '@type': 'supergroupFullInfo',
        'description': 'Daily news',
      },
      'checkChatInviteLink' when inviteExpired => _error,
      'checkChatInviteLink' => {
        '@type': 'chatInviteLinkInfo',
        'chat_id': inviteChatId,
        'type': {'@type': 'inviteLinkChatTypeSupergroup'},
        'title': 'Book club',
        'member_count': 12,
        'creates_join_request': true,
      },
      'getMessageLinkInfo' => {
        '@type': 'messageLinkInfo',
        'chat_id': messageChatId,
      },
      'joinChat' || 'joinChatByInviteLink' => joinResult ?? _error,
      _ => {'@type': 'ok'},
    };
    _queue.add(
      jsonEncode({
        ...response,
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
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
