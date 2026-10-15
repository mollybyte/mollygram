import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late ChatFoldersController folders;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    folders = ChatFoldersController(tdlib.createClient());
    await folders.start();
  });

  tearDown(() async {
    await folders.dispose();
    await tdlib.close();
  });

  /// Lets the receive loop deliver what the fake queued.
  Future<void> drain() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  test('follows the folder list and the limits', () async {
    final changes = <void>[];
    folders.changes.listen(changes.add);
    json
      ..pushFolders([(1, 'Work', 'Work'), (2, 'Family', 'Home')], main: 1)
      ..push(_option('chat_folder_count_max', 20))
      ..push(_option('chat_folder_chosen_chat_count_max', 200));
    await folders.folder(1); // Any request lets the updates through.
    await drain();

    expect([for (final f in folders.folders) f.title], ['Work', 'Family']);
    expect(folders.folders.last.iconName, 'Home');
    expect(folders.mainChatListPosition, 1);
    expect(folders.maxFolders, 20);
    expect(folders.maxChosenChats, 200);
    expect(folders.canCreate, isTrue);
    expect(changes, hasLength(3));
  });

  test('says when the folder limit is reached', () async {
    json.pushFolders([for (var i = 1; i <= 10; i++) (i, 'F$i', 'Custom')]);
    await folders.folder(1);
    await drain();
    expect(folders.canCreate, isFalse);
  });

  test('reads a folder into a draft', () async {
    final draft = await folders.folder(1);
    expect(draft.title, 'Work');
    expect(draft.iconName, 'Work');
    expect(draft.includedChatIds, [10, 11]);
    expect(draft.excludedChatIds, [12]);
    expect(draft.includeGroups, isTrue);
    expect(draft.excludeMuted, isTrue);
    expect(draft.includeBots, isFalse);
  });

  test('creates and edits folders', () async {
    const draft = ChatFolderDraft(
      title: '  Team ',
      iconName: 'Work',
      pinnedChatIds: [10],
      includedChatIds: [10, 11],
      includeChannels: true,
    );
    expect(await folders.create(draft), 7);
    final folder = sent('createChatFolder')['folder']! as Map;
    expect(((folder['name']! as Map)['text']! as Map)['text'], 'Team');
    expect((folder['icon']! as Map)['name'], 'Work');
    expect(folder['pinned_chat_ids'], [10]);
    // A pinned chat isn't sent as included too.
    expect(folder['included_chat_ids'], [11]);
    expect(folder['include_channels'], isTrue);

    await folders.edit(7, draft.copyWith(iconName: ''));
    final edit = sent('editChatFolder');
    expect(edit['chat_folder_id'], 7);
    expect((edit['folder']! as Map)['icon'], isNull);
  });

  test('a draft needs a name and some chats to be saved', () {
    expect(const ChatFolderDraft(title: 'A').canSave, isFalse);
    expect(const ChatFolderDraft(includeBots: true).canSave, isFalse);
    expect(
      const ChatFolderDraft(title: 'A', includeBots: true).canSave,
      isTrue,
    );
    expect(
      const ChatFolderDraft(title: 'A', includedChatIds: [1]).canSave,
      isTrue,
    );
    expect(
      const ChatFolderDraft(
        pinnedChatIds: [1],
        includedChatIds: [2, 1],
      ).chosenChatIds,
      [1, 2],
    );
  });

  test('reorders at once and puts the order back on failure', () async {
    json.pushFolders([(1, 'A', 'Custom'), (2, 'B', 'Custom')], main: 1);
    await folders.folder(1);
    await drain();

    await folders.reorder([2, 1]);
    expect([for (final f in folders.folders) f.id], [2, 1]);
    final request = sent('reorderChatFolders');
    expect(request['chat_folder_ids'], [2, 1]);
    expect(request['main_chat_list_position'], 1);
    // TDLib confirms the new order with an update.
    json.pushFolders([(2, 'B', 'Custom'), (1, 'A', 'Custom')], main: 1);
    await folders.folder(1);
    await drain();

    json.failing.add('reorderChatFolders');
    await expectLater(folders.reorder([1, 2]), throwsA(anything));
    expect([for (final f in folders.folders) f.id], [2, 1]);
  });

  test('a failed reorder goes back to the latest reported list', () async {
    json.pushFolders([(1, 'A', 'Custom'), (2, 'B', 'Custom')]);
    await folders.folder(1);
    await drain();

    // TDLib reports a new list while the request is out, then refuses it.
    json
      ..failing.add('reorderChatFolders')
      ..beforeReply['reorderChatFolders'] = () => json.pushFolders([
        (1, 'A', 'Custom'),
        (2, 'B', 'Custom'),
        (3, 'C', 'Custom'),
      ]);
    await expectLater(folders.reorder([2, 1]), throwsA(anything));
    await drain();
    expect([for (final f in folders.folders) f.id], [1, 2, 3]);
  });

  test('deleting a folder before "All chats" moves it up', () async {
    json.pushFolders([(1, 'A', 'Custom'), (2, 'B', 'Custom')], main: 2);
    await folders.folder(1);
    await drain();
    await folders.delete(1);
    expect(folders.mainChatListPosition, 1);
    await folders.delete(2);
    expect(folders.mainChatListPosition, 0);
  });

  test('a draft round-trips everything it does not edit', () {
    const name = td.ChatFolderName(
      text: td.FormattedText(
        text: 'Work 1',
        entities: [
          td.TextEntity(
            offset: 5,
            length: 1,
            type: td.TextEntityTypeCustomEmoji(customEmojiId: 42),
          ),
        ],
      ),
      animateCustomEmoji: true,
    );
    const original = td.ChatFolder(
      name: name,
      icon: td.ChatFolderIcon(name: 'Work'),
      colorId: 3,
      isShareable: true,
      pinnedChatIds: [1, 2],
      includedChatIds: [3],
      excludedChatIds: [4],
      excludeMuted: true,
      excludeRead: false,
      excludeArchived: true,
      includeContacts: false,
      includeNonContacts: true,
      includeBots: false,
      includeGroups: true,
      includeChannels: false,
    );
    final draft = ChatFolderDraft.fromTd(original);
    expect(jsonEncode(draft.toTd().toJson()), jsonEncode(original.toJson()));
    // A name that wasn't touched keeps its custom emoji.
    expect(draft.copyWith(excludeRead: true).toTd().name, same(name));

    final renamed = draft.copyWith(title: 'Job').toTd();
    expect(renamed.name.text.text, 'Job');
    expect(renamed.name.text.entities, isEmpty);
    expect(renamed.colorId, 3);
    expect(renamed.isShareable, isTrue);
    expect(renamed.pinnedChatIds, [1, 2]);
  });

  test('marks secret chats', () async {
    final chats = await folders.describe([30]);
    expect(chats.single.isSecret, isTrue);
    expect(chats.single.kind, FolderChatKind.user);
  });

  test('deletes a folder with the chats to leave', () async {
    json.pushFolders([(1, 'A', 'Custom'), (2, 'B', 'Custom')]);
    await folders.folder(1);
    await drain();

    final leave = await folders.chatsToLeave(1);
    expect([for (final c in leave) c.title], ['Flutter', 'News']);
    expect(
      [for (final c in leave) c.kind],
      [FolderChatKind.group, FolderChatKind.channel],
    );

    await folders.delete(1, leaveChatIds: [20]);
    final request = sent('deleteChatFolder');
    expect(request['chat_folder_id'], 1);
    expect(request['leave_chat_ids'], [20]);
    expect([for (final f in folders.folders) f.id], [2]);
  });

  test('describes chats by kind and leaves out unknown ones', () async {
    json.push(_option('my_id', 5));
    final chats = await folders.describe([10, 11, 20, 21, 99]);
    expect([for (final c in chats) c.id], [10, 11, 20, 21]);
    expect(
      [for (final c in chats) c.kind],
      [
        FolderChatKind.user,
        FolderChatKind.bot,
        FolderChatKind.group,
        FolderChatKind.channel,
      ],
    );
    expect(chats.first.isSelf, isTrue);
  });

  test('offers the main list, or the chats matching a query', () async {
    final all = await folders.candidates();
    expect(sent('getChats')['chat_list'], {'@type': 'chatListMain'});
    expect([for (final c in all) c.id], [10, 11, 20, 21]);

    final found = await folders.candidates(query: ' news ');
    expect(sent('searchChats')['query'], 'news');
    expect([for (final c in found) c.title], ['News']);
  });

  test('lists the recommended folders', () async {
    final recommended = await folders.recommended();
    expect(recommended.single.folder.title, 'Unread');
    expect(recommended.single.folder.excludeRead, isTrue);
    expect(recommended.single.description, 'New messages from all chats');
  });
}

Map<String, Object?> _option(String name, int value) => {
  '@type': 'updateOption',
  'name': name,
  'value': {'@type': 'optionValueInteger', 'value': '$value'},
};

Map<String, Object?> _name(String text) => {
  '@type': 'chatFolderName',
  'text': {'@type': 'formattedText', 'text': text, 'entities': <Object?>[]},
  'animate_custom_emoji': false,
};

Map<String, Object?> _folder(
  String title, {
  List<int> included = const [],
  List<int> excluded = const [],
  bool groups = false,
  bool excludeMuted = false,
  bool excludeRead = false,
  bool contacts = false,
  bool nonContacts = false,
  String? icon,
}) => {
  '@type': 'chatFolder',
  'name': _name(title),
  if (icon != null) 'icon': {'@type': 'chatFolderIcon', 'name': icon},
  'color_id': -1,
  'is_shareable': false,
  'pinned_chat_ids': <int>[],
  'included_chat_ids': included,
  'excluded_chat_ids': excluded,
  'exclude_muted': excludeMuted,
  'exclude_read': excludeRead,
  'exclude_archived': false,
  'include_contacts': contacts,
  'include_non_contacts': nonContacts,
  'include_bots': false,
  'include_groups': groups,
  'include_channels': false,
};

Map<String, Object?> _chat(int id, String title, Map<String, Object?> type) => {
  '@type': 'chat',
  'id': id,
  'type': type,
  'title': title,
  'permissions': {'@type': 'chatPermissions'},
  'notification_settings': {'@type': 'chatNotificationSettings'},
  'available_reactions': {
    '@type': 'chatAvailableReactionsAll',
    'max_reaction_count': 11,
  },
  'video_chat': {'@type': 'videoChat'},
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

  /// Runs before the reply to a request of that type is queued.
  final beforeReply = <String, void Function()>{};
  var _nextClientId = 0;

  final _chats = {
    10: _chat(10, 'Saved', {'@type': 'chatTypePrivate', 'user_id': 5}),
    11: _chat(11, 'Helper bot', {'@type': 'chatTypePrivate', 'user_id': 6}),
    20: _chat(20, 'Flutter', {
      '@type': 'chatTypeSupergroup',
      'supergroup_id': 3,
      'is_channel': false,
    }),
    30: _chat(30, 'Secret', {
      '@type': 'chatTypeSecret',
      'secret_chat_id': 1,
      'user_id': 7,
    }),
    21: _chat(21, 'News', {
      '@type': 'chatTypeSupergroup',
      'supergroup_id': 4,
      'is_channel': true,
    }),
  };

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

  void pushFolders(List<(int, String, String)> folders, {int main = 0}) =>
      push({
        '@type': 'updateChatFolders',
        'chat_folders': [
          for (final (id, title, icon) in folders)
            {
              '@type': 'chatFolderInfo',
              'id': id,
              'name': _name(title),
              'icon': {'@type': 'chatFolderIcon', 'name': icon},
              'color_id': -1,
              'is_shareable': false,
              'has_my_invite_links': false,
            },
        ],
        'main_chat_list_position': main,
        'are_tags_enabled': false,
      });

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
    final type = decoded['@type']! as String;
    if (type != 'close') sent.add(decoded);
    beforeReply.remove(type)?.call();
    final Map<String, Object?> response = failing.contains(type)
        ? {'@type': 'error', 'code': 400, 'message': 'Failed'}
        : switch (type) {
            'getChatFolder' => _folder(
              'Work',
              icon: 'Work',
              included: [10, 11],
              excluded: [12],
              groups: true,
              excludeMuted: true,
            ),
            'createChatFolder' => {
              '@type': 'chatFolderInfo',
              'id': 7,
              'name': _name('Team'),
              'icon': {'@type': 'chatFolderIcon', 'name': 'Work'},
              'color_id': -1,
              'is_shareable': false,
              'has_my_invite_links': false,
            },
            'getChatFolderChatsToLeave' => {
              '@type': 'chats',
              'total_count': 2,
              'chat_ids': [20, 21],
            },
            'getChats' => {
              '@type': 'chats',
              'total_count': 4,
              'chat_ids': [10, 11, 20, 21],
            },
            'searchChats' => {
              '@type': 'chats',
              'total_count': 1,
              'chat_ids': [21],
            },
            'getChat' =>
              _chats[decoded['chat_id']] ??
                  {'@type': 'error', 'code': 400, 'message': 'Chat not found'},
            'getUser' => _user(
              decoded['user_id']! as int,
              bot: decoded['user_id'] == 6,
            ),
            'getRecommendedChatFolders' => {
              '@type': 'recommendedChatFolders',
              'chat_folders': [
                {
                  '@type': 'recommendedChatFolder',
                  'folder': _folder(
                    'Unread',
                    contacts: true,
                    nonContacts: true,
                    excludeRead: true,
                  ),
                  'description': 'New messages from all chats',
                },
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
