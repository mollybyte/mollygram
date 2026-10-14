import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatListController controller;

  setUp(() {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    controller = ChatListController(tdlib.createClient());
  });

  tearDown(() async {
    await controller.dispose();
    await tdlib.close();
  });

  test('loads the main list through TDLib updates', () async {
    await controller.start();

    expect(json.sent.single['@type'], 'loadChats');
    expect(json.sent.single['limit'], 100);
    expect(json.sent.single, isNot(contains('chat_list')));
  });

  test('projects server folders in their declared order', () async {
    final changes = <void>[];
    final subscription = controller.changes.listen(changes.add);
    await controller.start();

    json.push({
      '@type': 'updateChatFolders',
      'chat_folders': [
        _folder(id: 7, name: 'Work', icon: 'Work'),
        _folder(id: 4, name: 'Family', icon: 'Favorite'),
      ],
      'main_chat_list_position': 0,
      'are_tags_enabled': false,
    });
    await pumpEventQueue();

    expect(controller.store.folders.map((folder) => folder.title), [
      'Work',
      'Family',
    ]);
    expect(changes, isNotEmpty);
    await subscription.cancel();
  });
}

Map<String, Object?> _folder({
  required int id,
  required String name,
  required String icon,
}) => {
  '@type': 'chatFolderInfo',
  'id': id,
  'name': {
    '@type': 'chatFolderName',
    'text': {'@type': 'formattedText', 'text': name, 'entities': <Object?>[]},
    'animate_custom_emoji': false,
  },
  'icon': {'@type': 'chatFolderIcon', 'name': icon},
  'color_id': -1,
  'is_shareable': false,
  'has_my_invite_links': false,
};

final class _FakeTdJson implements td.TdJson {
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
    _queue.add(
      jsonEncode({
        '@type': 'ok',
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
