import 'dart:async';
import 'dart:typed_data';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';
import 'package:test/test.dart';

import 'fake_td_json.dart';

const _closedUpdate = {
  '@type': 'updateAuthorizationState',
  'authorization_state': {'@type': 'authorizationStateClosed'},
};

List<Map<String, Object?>> _handler(int clientId, Map<String, Object?> r) =>
    switch (r['@type']) {
      'getOption' when r['name'] == 'version' => [
        {'@type': 'optionValueString', 'value': '1.8.68'},
      ],
      'getMe' => [
        {'@type': 'error', 'code': 401, 'message': 'Unauthorized'},
      ],
      'testCallString' => [
        {'@type': 'testString', 'value': r['x']},
      ],
      'testCallEmpty' => [
        {'@type': 'ok'},
        asUpdate(_option('x')),
      ],
      'testCallBytes' => [
        {'@type': 'testString', 'value': 'wrong type'},
      ],
      'close' => [
        {'@type': 'ok'},
        asUpdate(_closedUpdate),
      ],
      _ => [
        {'@type': 'error', 'code': 400, 'message': 'Unsupported'},
      ],
    };

Map<String, Object?> _option(String name) => {
  '@type': 'updateOption',
  'name': name,
  'value': {'@type': 'optionValueEmpty'},
};

void main() {
  late FakeTdJson json;
  late Td td;

  setUp(() {
    json = FakeTdJson(
      _handler,
      executeHandler: (r) => {'@type': 'optionValueString', 'value': '1.8.68'},
    );
    td = Td.custom(json, InlineTdEventSource(json));
  });

  tearDown(() => td.close());

  test('ответ сопоставляется с запросом по @extra', () async {
    final client = td.createClient();
    final results = await Future.wait([
      client.send(const TestCallString(x: 'a')),
      client.send(const TestCallString(x: 'b')),
      client.send(const TestCallString(x: 'c')),
    ]);
    expect([for (final r in results) r.value], ['a', 'b', 'c']);
    final extras = {for (final (_, r) in json.sent) r['@extra']};
    expect(extras, hasLength(3));
  });

  test('ошибка TDLib приходит как TdException', () async {
    final client = td.createClient();
    await expectLater(
      client.send(const GetMe()),
      throwsA(
        isA<TdException>()
            .having((e) => e.code, 'code', 401)
            .having((e) => e.message, 'message', 'Unauthorized'),
      ),
    );
  });

  test('ответ неожиданного типа даёт TdDecodeException', () async {
    final client = td.createClient();
    await expectLater(
      client.send(TestCallBytes(x: Uint8List(0))),
      throwsA(isA<TdDecodeException>()),
    );
  });

  test('обновления идут в поток своего клиента', () async {
    final first = td.createClient();
    final second = td.createClient();
    final firstUpdates = <TdObject>[];
    final secondUpdates = <TdObject>[];
    first.updates.listen(firstUpdates.add);
    second.updates.listen(secondUpdates.add);

    await first.send(const TestCallEmpty());
    json.push(second.id, _option('y'));
    await pumpEventQueue();

    expect(firstUpdates.single, isA<UpdateOption>());
    expect((secondUpdates.single as UpdateOption).name, 'y');
  });

  test('битая строка от TDLib не роняет цикл приёма', () async {
    final client = td.createClient();
    final bad = <TdUndecodable>[];
    td.undecodable.listen(bad.add);
    json.pushRaw('{not json');
    json.push(client.id, {'@type': 'updateSomethingFromTheFuture'});
    final result = await client.send(const TestCallString(x: 'ok'));
    expect(result.value, 'ok');
    expect(bad, hasLength(2));
  });

  test(
    'close ждёт authorizationStateClosed и отменяет ожидающие запросы',
    () async {
      final client = td.createClient();
      final states = <TdObject>[];
      client.updates.listen(states.add);
      // На этот запрос фейк ничего не ответит, ответ должен прийти от close.
      final hanging = Completer<void>();
      final silent = FakeTdJson((_, _) => []);
      final silentTd = Td.custom(silent, InlineTdEventSource(silent));
      final silentClient = silentTd.createClient();
      unawaited(
        silentClient
            .send(const GetMe())
            .then<void>((_) {}, onError: (Object e) => hanging.complete()),
      );
      silent.push(silentClient.id, _closedUpdate);
      await hanging.future;
      await silentTd.close();

      await client.close();
      expect(
        (states.last as UpdateAuthorizationState).authorizationState,
        isA<AuthorizationStateClosed>(),
      );
      await expectLater(
        client.send(const GetMe()),
        throwsA(isA<TdClientClosed>()),
      );
    },
  );

  test('execute работает синхронно', () {
    final version = td.execute(const GetOption(name: 'version'));
    expect((version as OptionValueString).value, '1.8.68');
  });
}
