import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';

typedef FakeHandler = List<Map<String, Object?>> Function(
  int clientId,
  Map<String, Object?> request,
);

/// An in-memory [TdJson] that answers each `send` with whatever [handler]
/// returns, with `@client_id` and `@extra` filled in.
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

  /// Queues an object without `@extra`, as an update.
  void push(int clientId, Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': clientId}));

  /// Queues an arbitrary string.
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

/// Marks a response as having no `@extra`, i.e. an update sent in reply to a
/// request.
Map<String, Object?> asUpdate(Map<String, Object?> json) => {
  ...json,
  '@extra': false,
};
