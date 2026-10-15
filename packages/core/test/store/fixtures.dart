import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

Map<String, Object?> textContent(String text) => {
  '@type': 'messageText',
  'text': {'@type': 'formattedText', 'text': text, 'entities': <Object?>[]},
};

Map<String, Object?> messageJson(
  int chatId,
  int id,
  String text, {
  int sender = 42,
  int date = 1700000000,
  int editDate = 0,
  bool selfDestruct = false,
}) => {
  '@type': 'message',
  'id': id,
  'chat_id': chatId,
  'sender_id': {'@type': 'messageSenderUser', 'user_id': sender},
  'date': date,
  'edit_date': editDate,
  'content': textContent(text),
  if (selfDestruct)
    'self_destruct_type': {
      '@type': 'messageSelfDestructTypeTimer',
      'self_destruct_time': 10,
    },
};

td.Message message(int chatId, int id, String text, {int sender = 42}) =>
    td.Message.fromJson(messageJson(chatId, id, text, sender: sender));

String textOf(td.MessageContent content) =>
    (content as td.MessageText).text.text;

/// A TDLib that answers requests from [answers] by type (`ok` otherwise)
/// and delivers what [push] queues.
final class FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final answers = <String, Map<String, Object?>>{};

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
    final type = decoded['@type']! as String;
    if (type != 'close') sent.add(decoded);
    _queue.add(
      jsonEncode({
        ...answers[type] ?? {'@type': 'ok'},
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
