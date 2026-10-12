import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late AuthorizationController controller;

  setUp(() {
    json = _FakeTdJson((request) {
      switch (request['@type']) {
        case 'getAuthorizationState':
          return [
            {'@type': 'authorizationStateWaitPhoneNumber'},
          ];
        case 'close':
          return [
            {'@type': 'ok'},
            {
              '@type': 'updateAuthorizationState',
              'authorization_state': {'@type': 'authorizationStateClosed'},
            },
          ];
        default:
          return [
            {'@type': 'ok'},
          ];
      }
    });
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = AuthorizationController(tdlib.createClient());
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  test('publishes the current TDLib authorization stage on start', () async {
    final stages = <AuthorizationStage>[];
    final subscription = controller.stages.listen(stages.add);

    await controller.start();

    expect(stages.single.kind, AuthorizationStageKind.phoneNumber);
    expect(controller.currentStage, stages.single);
    await subscription.cancel();
  });

  test('sends phone, code, password, and QR requests through TDLib', () async {
    await controller.submitPhone('+15550000000');
    await controller.submitCode('12345');
    await controller.submitPassword('correct horse battery staple');
    await controller.requestQrCode();

    expect(
      [for (final request in json.sent) request['@type']],
      [
        'setAuthenticationPhoneNumber',
        'checkAuthenticationCode',
        'checkAuthenticationPassword',
        'requestQrCodeAuthentication',
      ],
    );
    expect(json.sent.first['phone_number'], '+15550000000');
    expect(json.sent.last['other_user_ids'], isEmpty);
  });

  test('maps authorization updates from TDLib', () async {
    final stages = <AuthorizationStage>[];
    final subscription = controller.stages.listen(stages.add);
    await controller.start();

    json.push({
      '@type': 'updateAuthorizationState',
      'authorization_state': {
        '@type': 'authorizationStateWaitOtherDeviceConfirmation',
        'link': 'tg://login?token=updated',
      },
    });
    await pumpEventQueue();

    expect(stages.last.kind, AuthorizationStageKind.qrCode);
    expect(stages.last.qrLink, 'tg://login?token=updated');
    await subscription.cancel();
  });
}

final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this._handler);

  final List<Map<String, Object?>> Function(Map<String, Object?> request)
  _handler;
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
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
    for (final response in _handler(decoded)) {
      _queue.add(
        jsonEncode({
          ...response,
          '@client_id': clientId,
          if (response['@type'] != 'updateAuthorizationState')
            '@extra': decoded['@extra'],
        }),
      );
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
