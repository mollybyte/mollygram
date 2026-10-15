import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/folders/folder_editor.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/folders_page.dart';
import 'package:mollygram/src/settings/settings_window.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  late _FakeTdJson json;
  late TelegramSession session;

  setUp(() async {
    json = _FakeTdJson();
    session = await TelegramSession.attach(
      td.Td.custom(json, td.InlineTdEventSource(json)),
      parameters: TdlibParameters(
        api: const TelegramApiConfig(
          apiId: 12345,
          apiHash: '0123456789abcdef0123456789abcdef',
        ),
        databaseDirectory: '/tmp/mollygram/database',
        filesDirectory: '/tmp/mollygram/files',
        databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
        systemLanguageCode: 'en',
        deviceModel: 'Mac',
        applicationVersion: '0.1.0',
      ),
    );
    json.push({
      '@type': 'updateOption',
      'name': 'my_id',
      'value': {'@type': 'optionValueInteger', 'value': '5'},
    });
  });

  tearDown(() => session.dispose());

  /// Lets TDLib answer and the answers show. Spinners never settle, so
  /// frames are pumped by time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(_tick));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view
      ..physicalSize = const Size(900, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: _WhenSignedIn(child: child)),
        ),
      ),
    );
    await settle(tester);
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  Map<String, Object?> folderOf(String type) =>
      sent(type)['folder']! as Map<String, Object?>;

  group('folders page', () {
    testWidgets('lists the folders and adds a recommended one', (tester) async {
      json.pushFolders([(1, 'Work', 'Work'), (2, 'Family', 'Home')]);
      await pump(tester, const FoldersPage());

      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Create folder'), findsOneWidget);
      expect(find.text('Recommended folders'), findsOneWidget);
      expect(find.text('New messages from all chats'), findsOneWidget);

      await tester.tap(find.text('Add'));
      await settle(tester);
      expect(
        ((folderOf('createChatFolder')['name']! as Map)['text']!
            as Map)['text'],
        'Unread',
      );
      expect(find.text('New messages from all chats'), findsNothing);
    });

    testWidgets('stops at the folder limit', (tester) async {
      json.pushFolders([for (var i = 1; i <= 10; i++) (i, 'F$i', 'Custom')]);
      await pump(tester, const FoldersPage());

      expect(find.text('You can have up to 10 folders.'), findsOneWidget);
      expect(find.text('Recommended folders'), findsNothing);
      await tester.tap(find.text('Create folder'));
      await settle(tester);
      expect(find.byType(FolderEditor), findsNothing);
    });

    testWidgets('reorders folders by their handles', (tester) async {
      json.pushFolders([(1, 'Work', 'Work'), (2, 'Family', 'Home')]);
      await pump(tester, const FoldersPage());

      final handle = find.byType(ReorderableDragStartListener).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await settle(tester);

      expect(sent('reorderChatFolders')['chat_folder_ids'], [2, 1]);
      expect(
        tester.getTopLeft(find.text('Family')).dy,
        lessThan(tester.getTopLeft(find.text('Work')).dy),
      );
    });

    testWidgets('opens the editor of a folder', (tester) async {
      json.pushFolders([(1, 'Work', 'Work')]);
      await pump(tester, const FoldersPage());
      await tester.tap(find.text('Work'));
      await settle(tester);
      expect(find.text('Edit folder'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
    });

    test('is a section of the settings, found in both languages', () {
      expect(settingsSections, contains(foldersSection));
      final languages = [
        lookupAppLocalizations(const Locale('en')),
        lookupAppLocalizations(const Locale('ru')),
      ];
      expect(settingsSectionMatches(foldersSection, 'папк', languages), isTrue);
      expect(
        settingsSectionMatches(foldersSection, 'recommended', languages),
        isTrue,
      );
    });
  });

  group('editor', () {
    testWidgets('creates a folder from chat types and chats', (tester) async {
      await pump(tester, const FolderEditor());
      expect(find.text('New folder'), findsOneWidget);

      // Without a name and chats there is nothing to save.
      await tester.tap(find.text('Create folder'));
      await settle(tester);
      expect(json.types, isNot(contains('createChatFolder')));

      await tester.enterText(find.byType(TextField), 'Team chats here');
      await tester.pump();
      // The name stops at TDLib's 12 characters.
      expect(find.text('Team chats h'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Team');

      await tester.tap(find.text('Add chats'));
      await settle(tester);
      expect(find.text('Chat types'), findsOneWidget);
      expect(find.text('0 of 100'), findsOneWidget);
      await tester.tap(find.text('Groups'));
      await tester.tap(find.text('News'));
      await tester.pump();
      expect(find.text('1 of 100'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);

      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);

      await tester.tap(find.byTooltip('Folder icon'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('Work')));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Create folder'));
      await settle(tester);
      final folder = folderOf('createChatFolder');
      expect(((folder['name']! as Map)['text']! as Map)['text'], 'Team');
      expect(folder['include_groups'], isTrue);
      expect(folder['included_chat_ids'], [21]);
      expect((folder['icon']! as Map)['name'], 'Work');
    });

    testWidgets('searches the picker', (tester) async {
      await pump(tester, const FolderEditor());
      await tester.tap(find.text('Exclude chats'));
      await settle(tester);
      expect(find.text('Muted'), findsOneWidget);
      expect(find.text('Contacts'), findsNothing);

      await tester.enterText(find.byType(TextField).last, 'news');
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);
      expect(sent('searchChats')['query'], 'news');
      expect(find.text('Muted'), findsNothing);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);
    });

    testWidgets('edits a folder and removes a chat', (tester) async {
      await pump(tester, const FolderEditor(id: 1));
      expect(find.text('Edit folder'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);
      expect(find.text('Saved Messages'), findsOneWidget);
      expect(find.text('Muted'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove').at(1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      await settle(tester);

      final edit = sent('editChatFolder');
      expect(edit['chat_folder_id'], 1);
      final folder = edit['folder']! as Map;
      expect(folder['pinned_chat_ids'], [10]);
      expect(folder['included_chat_ids'], isEmpty);
      expect(folder['exclude_muted'], isTrue);
    });

    testWidgets('deletes a folder, leaving the chats ticked', (tester) async {
      await pump(tester, const FolderEditor(id: 1));
      await tester.tap(find.text('Delete folder'));
      await settle(tester);

      expect(find.text('Delete “Work”?'), findsOneWidget);
      expect(find.text('News'), findsOneWidget);
      // Untick Flutter, keep News.
      await tester.tap(find.text('Flutter').last);
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await settle(tester);

      final request = sent('deleteChatFolder');
      expect(request['chat_folder_id'], 1);
      expect(request['leave_chat_ids'], [21]);
    });

    testWidgets('keeps the editor open when saving fails', (tester) async {
      json.failing.add('editChatFolder');
      await pump(tester, const FolderEditor(id: 1));
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text("Couldn't save the change."), findsOneWidget);
    });
  });

  group('limits', () {
    void limit(int max) => json.push({
      '@type': 'updateOption',
      'name': 'chat_folder_chosen_chat_count_max',
      'value': {'@type': 'optionValueInteger', 'value': '$max'},
    });

    testWidgets('the picker stops at the limit, secret chats aside', (
      tester,
    ) async {
      limit(1);
      await pump(tester, const FolderEditor());
      await tester.tap(find.text('Add chats'));
      await settle(tester);
      expect(find.text('0 of 1'), findsOneWidget);

      await tester.tap(find.text('News'));
      await tester.pump();
      await tester.tap(find.text('Flutter'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.text('A folder can have up to 1 chats.'), findsOneWidget);

      await tester.ensureVisible(find.text('Secret'));
      await tester.pump();
      await tester.tap(find.text('Secret'));
      await tester.pump();
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('News'), findsOneWidget);
      expect(find.text('Secret'), findsOneWidget);
      expect(find.text('Flutter'), findsNothing);
    });

    testWidgets('Done waits while a folder is over the limit', (tester) async {
      limit(1);
      await pump(tester, const FolderEditor(id: 1));
      await tester.tap(find.text('Add chats'));
      await settle(tester);
      expect(find.text('2 of 1'), findsOneWidget);
      expect(find.text('A folder can have up to 1 chats.'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Chat types'), findsOneWidget);

      // Unticking one brings it back within the limit.
      await tester.tap(find.text('Flutter').last);
      await tester.pump();
      await tester.tap(find.text('Done'));
      await settle(tester);
      expect(find.text('Chat types'), findsNothing);
    });

    testWidgets('the exclude picker has a limit too', (tester) async {
      limit(5);
      await pump(tester, const FolderEditor());
      await tester.tap(find.text('Exclude chats'));
      await settle(tester);
      expect(find.text('0 of 5'), findsOneWidget);
    });
  });

  testWidgets('a shared folder offers no chat types or exclusions', (
    tester,
  ) async {
    json.shareable = true;
    await pump(tester, const FolderEditor(id: 1));
    expect(find.text('Excluded chats'), findsNothing);
    expect(find.text('Muted'), findsNothing);
    await tester.tap(find.text('Add chats'));
    await settle(tester);
    expect(find.text('Chat types'), findsNothing);
    expect(find.text('News'), findsOneWidget);
  });

  testWidgets('names chats TDLib no longer knows', (tester) async {
    json.extraIncluded = [99];
    await pump(tester, const FolderEditor(id: 1));
    expect(find.text('Deleted chat'), findsOneWidget);
  });

  testWidgets('stays open while saving, to show a failure', (tester) async {
    json
      ..failing.add('editChatFolder')
      ..held.add('editChatFolder');
    await pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: GestureDetector(
            onTap: () => showFolderEditor(context, id: 1),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.tap(find.text('Save'));
    await settle(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.tap(find.text('Cancel'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('Edit folder'), findsOneWidget);

    json.release('editChatFolder');
    await settle(tester);
    expect(find.text("Couldn't save the change."), findsOneWidget);
  });

  testWidgets('the sheet opens and closes on Escape', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: GestureDetector(
            onTap: () => showFolderEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('New folder'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.text('New folder'), findsNothing);
  });
}

const _tick = Duration(milliseconds: 20);

class _WhenSignedIn extends ConsumerWidget {
  const _WhenSignedIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(telegramSessionProvider).hasValue ? child : const SizedBox();
}

Map<String, Object?> _name(String text) => {
  '@type': 'chatFolderName',
  'text': {'@type': 'formattedText', 'text': text, 'entities': <Object?>[]},
  'animate_custom_emoji': false,
};

Map<String, Object?> _folder(
  String title, {
  List<int> included = const [],
  List<int> pinned = const [],
  bool contacts = false,
  bool nonContacts = false,
  bool excludeMuted = false,
  bool excludeRead = false,
  String? icon,
  bool shareable = false,
}) => {
  '@type': 'chatFolder',
  'name': _name(title),
  if (icon != null) 'icon': {'@type': 'chatFolderIcon', 'name': icon},
  'color_id': -1,
  'is_shareable': shareable,
  'pinned_chat_ids': pinned,
  'included_chat_ids': included,
  'excluded_chat_ids': <int>[],
  'exclude_muted': excludeMuted,
  'exclude_read': excludeRead,
  'exclude_archived': false,
  'include_contacts': contacts,
  'include_non_contacts': nonContacts,
  'include_bots': false,
  'include_groups': false,
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

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final failing = <String>{};

  /// Whether folder 1 is shared by an invite link.
  var shareable = false;

  /// More chats folder 1 takes in, after Flutter.
  var extraIncluded = <int>[];

  /// Replies to these requests wait for [release].
  final held = <String>{};
  final _waiting = <String, List<String>>{};

  void release(String type) => _queue.addAll(_waiting.remove(type) ?? []);
  var _nextClientId = 0;

  Iterable<Object?> get types => sent.map((r) => r['@type']);

  final _chats = {
    10: _chat(10, 'Me', {'@type': 'chatTypePrivate', 'user_id': 5}),
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

  void pushFolders(List<(int, String, String)> folders) => push({
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
    'main_chat_list_position': 0,
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
    if (type != 'getAuthorizationState' && type != 'loadChats') {
      sent.add(decoded);
    }
    final Map<String, Object?> response = failing.contains(type)
        ? {'@type': 'error', 'code': 400, 'message': 'Failed'}
        : switch (type) {
            'getAuthorizationState' => {'@type': 'authorizationStateReady'},
            'getChatFolder' => _folder(
              'Work',
              icon: 'Work',
              pinned: [10],
              included: [20, ...extraIncluded],
              excludeMuted: true,
              shareable: shareable,
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
              'chat_ids': [10, 20, 21, 30],
            },
            'searchChats' => {
              '@type': 'chats',
              'total_count': 1,
              'chat_ids': [21],
            },
            'getChat' =>
              _chats[decoded['chat_id']] ??
                  {'@type': 'error', 'code': 400, 'message': 'Not found'},
            'getUser' => {
              '@type': 'user',
              'id': decoded['user_id'],
              'first_name': 'Me',
              'last_name': '',
              'phone_number': '',
              'status': {'@type': 'userStatusEmpty'},
              'type': {'@type': 'userTypeRegular'},
            },
            'getRecommendedChatFolders' => {
              '@type': 'recommendedChatFolders',
              'chat_folders': [
                // TDLib stops suggesting a folder once there is one like it.
                if (!types.contains('createChatFolder'))
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
    final reply = jsonEncode({
      ...response,
      '@client_id': clientId,
      '@extra': decoded['@extra'],
    });
    if (held.contains(type)) {
      (_waiting[type] ??= []).add(reply);
    } else {
      _queue.add(reply);
    }
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
