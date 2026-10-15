import 'dart:collection';
import 'dart:convert';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:test/test.dart';

void main() {
  late _FakeTdJson json;
  late td.Td tdlib;
  late StickerSetsController sets;

  setUp(() async {
    json = _FakeTdJson();
    tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
    sets = StickerSetsController(tdlib.createClient());
    await sets.start();
  });

  tearDown(() async {
    await sets.dispose();
    await tdlib.close();
  });

  Future<void> drain() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  List<int> ids(StickerSetKind kind) => [
    for (final s in sets.installedOf(kind)!) s.id,
  ];

  test('loads installed stickers and emoji apart, once', () async {
    final stickers = await sets.installed(StickerSetKind.stickers);
    expect([for (final s in stickers) s.title], ['Cats', 'Dogs', 'Birds']);
    expect(stickers.first.size, 30);
    final emoji = await sets.installed(StickerSetKind.emoji);
    expect([for (final s in emoji) s.title], ['Hearts']);
    expect(
      (sent('getInstalledStickerSets')['sticker_type']! as Map)['@type'],
      'stickerTypeCustomEmoji',
    );
    await sets.installed(StickerSetKind.stickers);
    expect(
      json.sent.where((r) => r['@type'] == 'getInstalledStickerSets'),
      hasLength(2),
    );
  });

  test('reorders at once and loads the order again on failure', () async {
    await sets.installed(StickerSetKind.stickers);
    final changes = <void>[];
    sets.changes.listen(changes.add);

    await sets.reorder(StickerSetKind.stickers, 2, 0);
    expect(ids(StickerSetKind.stickers), [3, 1, 2]);
    final request = sent('reorderInstalledStickerSets');
    expect(request['sticker_set_ids'], ['3', '1', '2']);
    expect((request['sticker_type']! as Map)['@type'], 'stickerTypeRegular');

    json.failing.add('reorderInstalledStickerSets');
    await expectLater(
      sets.reorder(StickerSetKind.stickers, 0, 2),
      throwsA(anything),
    );
    expect(sets.installedOf(StickerSetKind.stickers), isNull);
    expect(changes, hasLength(3));
    await sets.installed(StickerSetKind.stickers);
    expect(ids(StickerSetKind.stickers), [3, 1, 2]);
  });

  test('a failure does not undo a change that succeeded after it', () async {
    final installed = await sets.installed(StickerSetKind.stickers);
    json.failing.add('reorderInstalledStickerSets');
    final reorder = sets.reorder(StickerSetKind.stickers, 0, 2);
    final archive = sets.archive(installed[1]);
    await expectLater(reorder, throwsA(anything));
    await archive;
    await sets.installed(StickerSetKind.stickers);
    expect(ids(StickerSetKind.stickers), [1, 3]);
  });

  test('a list loaded while an update arrives is not kept', () async {
    json.updateWhileLoading = true;
    final changes = <void>[];
    sets.changes.listen(changes.add);
    await sets.installed(StickerSetKind.stickers);
    expect(sets.installedOf(StickerSetKind.stickers), isNull);
    expect(changes, hasLength(1));
    json.updateWhileLoading = false;
    await sets.installed(StickerSetKind.stickers);
    expect(ids(StickerSetKind.stickers), [1, 2, 3]);
  });

  test('archives and removes at once, reloading on failure', () async {
    final installed = await sets.installed(StickerSetKind.stickers);
    await sets.archive(installed[1]);
    expect(ids(StickerSetKind.stickers), [1, 3]);
    final archive = sent('changeStickerSet');
    expect(archive['set_id'], '2');
    expect(archive['is_installed'], isFalse);
    expect(archive['is_archived'], isTrue);

    json.failing.add('changeStickerSet');
    await expectLater(sets.remove(installed[0]), throwsA(anything));
    expect(sets.installedOf(StickerSetKind.stickers), isNull);
    json.failing.clear();
    await sets.installed(StickerSetKind.stickers);
    expect(ids(StickerSetKind.stickers), [1, 3]);

    await sets.remove(installed[0]);
    expect(ids(StickerSetKind.stickers), [3]);
    expect(sent('changeStickerSet')['is_archived'], isFalse);
  });

  test('installing reloads the list, as does an update', () async {
    await sets.installed(StickerSetKind.stickers);
    await sets.install(9, StickerSetKind.stickers);
    expect(sent('changeStickerSet')['is_installed'], isTrue);
    expect(sets.installedOf(StickerSetKind.stickers), isNull);
    await sets.installed(StickerSetKind.stickers);

    json.push({
      '@type': 'updateInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeRegular'},
      'sticker_set_ids': ['1'],
    });
    await sets.installed(StickerSetKind.emoji); // Lets the update through.
    await drain();
    expect(sets.installedOf(StickerSetKind.stickers), isNull);
    expect(sets.installedOf(StickerSetKind.emoji), isNotNull);
  });

  test('pages archived and trending sets, finds a set by name', () async {
    final archived = await sets.archived(StickerSetKind.emoji, after: 5);
    expect(archived.single.title, 'Old');
    final request = sent('getArchivedStickerSets');
    expect(request['offset_sticker_set_id'], '5');

    final trending = await sets.trending(StickerSetKind.stickers, offset: 50);
    expect(trending.single.title, 'New');
    expect(sent('getTrendingStickerSets')['offset'], 50);

    await sets.viewTrending([4, 5]);
    expect(sent('viewTrendingStickerSets')['sticker_set_ids'], ['4', '5']);

    final set = await sets.byName('CatsPack');
    expect(set.title, 'CatsPack');
  });

  test('animated emoji follow disable_animated_emoji', () async {
    expect(await sets.animatedEmoji(), isTrue);
    json.animatedEmojiOff = true;
    expect(await sets.animatedEmoji(), isFalse);
    await sets.setAnimatedEmoji(true);
    final request = sent('setOption');
    expect(request['name'], 'disable_animated_emoji');
    expect((request['value']! as Map)['value'], isFalse);
  });

  test('reads set names from links', () {
    expect(stickerSetNameOf('https://t.me/addstickers/Cats_1'), 'Cats_1');
    expect(stickerSetNameOf('t.me/addemoji/Hearts'), 'Hearts');
    expect(stickerSetNameOf('tg://addstickers?set=Dogs'), 'Dogs');
    expect(stickerSetNameOf('tg://addemoji?set=Love'), 'Love');
    expect(stickerSetNameOf('  Birds '), 'Birds');
    expect(stickerSetNameOf('https://t.me/addstickers/Cats/'), 'Cats');
    expect(stickerSetNameOf('t.me/addstickers/'), isNull);
    expect(stickerSetNameOf('https://t.me/joinchat/abc'), isNull);
    expect(stickerSetNameOf('https://example.com/addstickers/x'), isNull);
    expect(stickerSetNameOf('two words'), isNull);
  });

  test('moves ids as a list reorders', () {
    expect(movedId([1, 2, 3, 4], 0, 2), [2, 3, 1, 4]);
    expect(movedId([1, 2, 3, 4], 3, 0), [4, 1, 2, 3]);
    expect(movedId([1, 2], 1, 1), [1, 2]);
  });
}

Map<String, Object?> _info(int id, String title, {bool emoji = false}) => {
  '@type': 'stickerSetInfo',
  'id': '$id',
  'title': title,
  'name': title,
  'is_installed': true,
  'sticker_type': {
    '@type': emoji ? 'stickerTypeCustomEmoji' : 'stickerTypeRegular',
  },
  'size': 30,
  'covers': <Object?>[],
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  final failing = <String>{};
  var animatedEmojiOff = false;

  /// Sends an updateInstalledStickerSets ahead of the installed list.
  var updateWhileLoading = false;

  /// The installed stickers, as TDLib keeps them.
  var stickers = [1, 2, 3];
  static const _titles = {1: 'Cats', 2: 'Dogs', 3: 'Birds'};
  var _nextClientId = 0;

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));

  void _apply(String type, Map<String, Object?> r, {required bool emoji}) {
    if (emoji) return;
    switch (type) {
      case 'reorderInstalledStickerSets':
        stickers = [
          for (final id in r['sticker_set_ids']! as List) int.parse('$id'),
        ];
      case 'changeStickerSet':
        final id = int.parse('${r['set_id']}');
        stickers.remove(id);
        if (r['is_installed'] == true) stickers.insert(0, id);
    }
  }

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
    final emoji =
        (decoded['sticker_type'] as Map?)?['@type'] == 'stickerTypeCustomEmoji';
    final Map<String, Object?> response = failing.contains(type)
        ? {'@type': 'error', 'code': 400, 'message': 'Failed'}
        : switch (type) {
            'getInstalledStickerSets' => {
              '@type': 'stickerSets',
              'total_count': emoji ? 1 : 3,
              'sets': emoji
                  ? [_info(7, 'Hearts', emoji: true)]
                  : [
                      for (final id in stickers)
                        _info(id, _titles[id] ?? 'Set'),
                    ],
            },
            'getArchivedStickerSets' => {
              '@type': 'stickerSets',
              'total_count': 1,
              'sets': [_info(4, 'Old', emoji: emoji)],
            },
            'getTrendingStickerSets' => {
              '@type': 'trendingStickerSets',
              'total_count': 1,
              'sets': [_info(5, 'New')],
              'is_premium': false,
            },
            'searchStickerSet' => {
              ..._info(6, decoded['name']! as String),
              '@type': 'stickerSet',
              'stickers': <Object?>[],
              'emojis': <Object?>[],
            },
            'getOption' =>
              animatedEmojiOff
                  ? {'@type': 'optionValueBoolean', 'value': true}
                  : {'@type': 'optionValueEmpty'},
            _ => {'@type': 'ok'},
          };
    if (!failing.contains(type)) _apply(type, decoded, emoji: emoji);
    if (updateWhileLoading && type == 'getInstalledStickerSets') {
      push({
        '@type': 'updateInstalledStickerSets',
        'sticker_type': decoded['sticker_type'],
        'sticker_set_ids': <Object?>[],
      });
    }
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
          '@client_id': clientId,
        }),
      );
    }
  }
}
