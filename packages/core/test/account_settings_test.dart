import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late td.Td tdlib;
  tearDown(() => tdlib.close());

  (AccountSettings, _FakeTdJson) account(
    Map<String, Map<String, Object?>> responses,
  ) {
    final json = _FakeTdJson(responses);
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    return (AccountSettings(tdlib.createClient()), json);
  }

  Map<String, Object?> session(
    int id, {
    bool current = false,
    int lastActive = 0,
  }) => {
    '@type': 'session',
    'id': '$id',
    'is_current': current,
    'device_type': {'@type': 'sessionDeviceTypeMac'},
    'application_name': 'Telegram macOS',
    'application_version': ' 11.2 ',
    'device_model': 'MacBook Pro',
    'platform': 'macOS',
    'system_version': '15.1',
    'last_active_date': lastActive,
    'location': 'Berlin, Germany',
  };

  test('reads the profile with the bio from the full info', () async {
    final (settings, client) = account({
      'getMe': {
        '@type': 'user',
        'id': 42,
        'first_name': 'Anna',
        'last_name': 'Petrova',
        'usernames': {
          '@type': 'usernames',
          'active_usernames': ['anna'],
          'editable_username': 'anna',
        },
        'phone_number': '79991234567',
        'status': {'@type': 'userStatusEmpty'},
        'type': {'@type': 'userTypeRegular'},
        'is_premium': true,
      },
      'getOption': {'@type': 'optionValueEmpty'},
      'getUserFullInfo': {
        '@type': 'userFullInfo',
        'bio': {'@type': 'formattedText', 'text': 'Hi', 'entities': <Object>[]},
        'gift_settings': {
          '@type': 'giftSettings',
          'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
        },
      },
    });
    final profile = await settings.profile();

    expect(profile.name, 'Anna Petrova');
    expect(profile.username, 'anna');
    expect(profile.phoneNumber, '79991234567');
    expect(profile.bio, 'Hi');
    expect(profile.bioLimit, 140);
    expect(profile.photo, isNull);
    expect(
      client.sent,
      contains(equals({'@type': 'getUserFullInfo', 'user_id': 42})),
    );
  });

  test('keeps the TDLib session order with this session on top', () async {
    final (settings, _) = account({
      'getActiveSessions': {
        '@type': 'sessions',
        'sessions': [
          session(1, lastActive: 100),
          session(2, lastActive: 300),
          session(3, current: true, lastActive: 50),
        ],
        'inactive_session_ttl_days': 180,
      },
    });
    final sessions = await settings.activeSessions();

    expect([for (final s in sessions) s.id], [3, 1, 2]);
    expect(sessions.first.isCurrent, isTrue);
    expect(sessions.first.application, 'Telegram macOS 11.2');
    expect(sessions.first.device, 'MacBook Pro, macOS 15.1');
  });

  test('takes the bio limit from the option when TDLib has it', () async {
    Map<String, Map<String, Object?>> responses(Map<String, Object?> option) =>
        {
          'getMe': {
            '@type': 'user',
            'id': 42,
            'status': {'@type': 'userStatusEmpty'},
            'type': {'@type': 'userTypeRegular'},
          },
          'getUserFullInfo': {
            '@type': 'userFullInfo',
            'gift_settings': {
              '@type': 'giftSettings',
              'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
            },
          },
          'getOption': option,
        };
    final (withOption, _) = account(
      responses({'@type': 'optionValueInteger', 'value': '120'}),
    );
    expect((await withOption.profile()).bioLimit, 120);
    await tdlib.close();

    final (without, _) = account(
      responses({'@type': 'error', 'code': 400, 'message': 'Option not found'}),
    );
    expect((await without.profile()).bioLimit, 70);
  });

  test('reads the connected business bot, or none', () async {
    final (settings, client) = account({
      'getBusinessConnectedBot': {
        '@type': 'businessConnectedBotInfo',
        'bot': {
          '@type': 'businessConnectedBot',
          'bot_user_id': 7,
          'recipients': {'@type': 'businessRecipients'},
          'rights': {'@type': 'businessBotRights'},
        },
      },
      'getUser': {
        '@type': 'user',
        'id': 7,
        'first_name': 'Shop bot',
        'usernames': {
          '@type': 'usernames',
          'active_usernames': ['shopbot'],
        },
        'status': {'@type': 'userStatusEmpty'},
        'type': {'@type': 'userTypeBot'},
      },
      'deleteBusinessConnectedBot': {'@type': 'ok'},
    });
    final bot = await settings.connectedBot();
    expect(bot?.name, 'Shop bot');
    expect(bot?.username, 'shopbot');
    await settings.disconnectBot(7);
    expect(client.sent.last, {
      '@type': 'deleteBusinessConnectedBot',
      'bot_user_id': 7,
    });
    await tdlib.close();

    final (none, _) = account({
      'getBusinessConnectedBot': {
        '@type': 'error',
        'code': 404,
        'message': 'Not Found',
      },
    });
    expect(await none.connectedBot(), isNull);
    await tdlib.close();

    final (failing, _) = account({
      'getBusinessConnectedBot': {
        '@type': 'error',
        'code': 500,
        'message': 'Internal',
      },
    });
    await expectLater(failing.connectedBot(), throwsA(isA<td.TdException>()));
  });

  test('terminates one session or all the others', () async {
    final (settings, client) = account({
      'terminateSession': {'@type': 'ok'},
      'terminateAllOtherSessions': {'@type': 'ok'},
    });
    await settings.terminateSession(7);
    await settings.terminateOtherSessions();

    expect(client.sent, [
      {'@type': 'terminateSession', 'session_id': '7'},
      {'@type': 'terminateAllOtherSessions'},
    ]);
  });

  test('trims the name and bio it sends', () async {
    final (settings, client) = account({
      'setName': {'@type': 'ok'},
      'setBio': {'@type': 'ok'},
    });
    await settings.setName(' Anna ', '');
    await settings.setBio(' Hello\n');

    expect(client.sent, [
      {'@type': 'setName', 'first_name': 'Anna', 'last_name': ''},
      {'@type': 'setBio', 'bio': 'Hello'},
    ]);
  });

  test('maps the username check to an availability', () async {
    final (settings, client) = account({
      'checkChatUsername': {'@type': 'checkChatUsernameResultUsernameOccupied'},
    });
    expect(
      await settings.checkUsername(42, 'anna'),
      UsernameAvailability.occupied,
    );
    expect(client.sent.single, {
      '@type': 'checkChatUsername',
      'chat_id': 42,
      'username': 'anna',
    });
  });

  test('finds what is wrong with a username before asking Telegram', () {
    expect(usernameIssue(''), isNull);
    expect(usernameIssue('anna_p'), isNull);
    expect(usernameIssue('anna'), UsernameIssue.tooShort);
    expect(usernameIssue('a' * 33), UsernameIssue.tooLong);
    expect(usernameIssue('anna-p'), UsernameIssue.invalidCharacter);
    expect(usernameIssue('анна_п'), UsernameIssue.invalidCharacter);
    expect(usernameIssue('1anna'), UsernameIssue.startsWithLetter);
    expect(usernameIssue('_anna'), UsernameIssue.startsWithLetter);
    expect(usernameIssue('anna_'), UsernameIssue.endsWithUnderscore);
  });
}

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this.responses);

  final Map<String, Map<String, Object?>> responses;
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  @override
  int createClientId() => 1;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    final extra = decoded.remove('@extra');
    if (responses.containsKey(decoded['@type'])) sent.add(decoded);
    _queue.add(
      jsonEncode({
        ...responses[decoded['@type']] ?? {'@type': 'ok'},
        '@client_id': clientId,
        '@extra': extra,
      }),
    );
    if (decoded['@type'] == 'close') {
      _queue.add(
        jsonEncode({
          '@type': 'updateAuthorizationState',
          'authorization_state': {'@type': 'authorizationStateClosed'},
          '@client_id': clientId,
        }),
      );
    }
  }
}
