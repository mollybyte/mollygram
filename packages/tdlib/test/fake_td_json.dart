import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';

typedef FakeHandler = List<Map<String, Object?>> Function(
  int clientId,
  Map<String, Object?> request,
);

/// [TdJson] в памяти: на каждый `send` отвечает тем, что вернёт [handler],
/// с подставленными `@client_id` и `@extra`.
final class FakeTdJson implements TdJson {
  FakeTdJson(this.handler, {this.executeHandler});

  final FakeHandler handler;
  final Map<String, Object?> Function(Map<String, Object?> request)?
  executeHandler;
  final _queue = Queue<String>();
  final sent = <(int, Map<String, Object?>)>[];
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  void send(int clientId, String request) {
    final json = jsonDecode(request) as Map<String, Object?>;
    sent.add((clientId, json));
    final extra = json['@extra'];
    for (final response in handler(clientId, json)) {
      _queue.add(
        jsonEncode(
          {
            ...response,
            '@client_id': clientId,
            if (extra != null && response['@extra'] != false) '@extra': extra,
          }..removeWhere((k, v) => k == '@extra' && v == false),
        ),
      );
    }
  }

  /// Положить в очередь объект без `@extra`, как обновление.
  void push(int clientId, Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': clientId}));

  /// Положить в очередь произвольную строку.
  void pushRaw(String raw) => _queue.add(raw);

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  String? execute(String request) {
    final handler = executeHandler;
    if (handler == null) return null;
    return jsonEncode(handler(jsonDecode(request) as Map<String, Object?>));
  }
}

/// Ответ без `@extra`, то есть обновление, отправленное в ответ на запрос.
Map<String, Object?> asUpdate(Map<String, Object?> json) => {
  ...json,
  '@extra': false,
};
