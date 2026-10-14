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

  test('reports a chat TDLib no longer has', () async {
    json.missingChats.add(42);
    expect(await controller.loadChat(42), isFalse);
    expect(json.sent.single, {
      '@type': 'getChat',
      'chat_id': 42,
      '@extra': json.sent.single['@extra'],
    });
  });

  test('keeps loading pages until TDLib reports the end', () async {
    await controller.start();
    expect(controller.hasMore(), isTrue);

    await controller.loadMore();
    expect(controller.hasMore(), isTrue);

    json.endOfList = true;
    await controller.loadMore();
    expect(controller.hasMore(), isFalse);

    // Nothing is requested once the list is exhausted.
    await controller.loadMore();
    expect(json.sent.where((r) => r['@type'] == 'loadChats'), hasLength(3));
  });

  test('shares one request between overlapping loads of a list', () async {
    await controller.start();
    await Future.wait([controller.loadMore(), controller.loadMore()]);

    expect(json.sent.where((r) => r['@type'] == 'loadChats'), hasLength(2));
  });

  test('applies positions sent with a draft change', () async {
    const main = ChatListLocation.main();
    await controller.start();
    controller.store.upsert(
      ChatListEntry(
        id: 5,
        title: 'Draft',
        unreadCount: 0,
        positions: [ChatListPosition(list: main, order: 10, isPinned: false)],
      ),
    );
    json.push({
      '@type': 'updateChatDraftMessage',
      'chat_id': 5,
      'positions': [
        {
          '@type': 'chatPosition',
          'list': {'@type': 'chatListMain'},
          'order': '99',
          'is_pinned': false,
        },
      ],
    });
    await pumpEventQueue();

    expect(controller.store.chat(5)!.positionFor(main)!.order, 99);
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
  var endOfList = false;
  final missingChats = <int>{};
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
    if (decoded['@type'] == 'getChat' &&
        missingChats.contains(decoded['chat_id'])) {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 400,
          'message': 'Chat not found',
          '@client_id': clientId,
          '@extra': decoded['@extra'],
        }),
      );
      return;
    }
    if (endOfList && decoded['@type'] == 'loadChats') {
      _queue.add(
        jsonEncode({
          '@type': 'error',
          'code': 404,
          'message': 'Not Found',
          '@client_id': clientId,
          '@extra': decoded['@extra'],
        }),
      );
      return;
    }
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
