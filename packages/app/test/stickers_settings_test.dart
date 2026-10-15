import 'dart:collection';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/settings_window.dart';
import 'package:mollygram/src/settings/stickers/sticker_set_pages.dart';
import 'package:mollygram/src/settings/stickers/stickers_page.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  late _FakeTdJson json;
  late TelegramSession session;
  late ProviderContainer container;

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
  });

  tearDown(() => session.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view
      ..physicalSize = const Size(900, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          telegramSessionProvider.overrideWith((ref) async => session),
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(
            child: SettingsNavigation(
              push: (title, builder) {},
              child: Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return ref.watch(telegramSessionProvider).hasValue
                      ? page
                      : const SizedBox();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Map<String, Object?> sent(String type) =>
      json.sent.lastWhere((r) => r['@type'] == type);

  testWidgets('lists the sets and reorders them by their handles', (
    tester,
  ) async {
    await pump(tester, const StickersPage());
    expect(find.text('Cats'), findsOneWidget);
    expect(find.text('12 stickers'), findsOneWidget);
    expect(find.text('1 sticker'), findsOneWidget);

    final handle = find.byType(ReorderableDragStartListener).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(tester);

    expect(sent('reorderInstalledStickerSets')['sticker_set_ids'], ['2', '1']);
    expect(
      tester.getTopLeft(find.text('Dogs')).dy,
      lessThan(tester.getTopLeft(find.text('Cats')).dy),
    );
  });

  testWidgets('archives a set from its context menu', (tester) async {
    await pump(tester, const StickersPage());
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Cats')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await settle(tester);
    await tester.tap(find.text('Archive'));
    await settle(tester);

    final request = sent('changeStickerSet');
    expect(request['set_id'], '1');
    expect(request['is_archived'], isTrue);
    expect(find.text('Cats'), findsNothing);
  });

  testWidgets('asks before removing a set', (tester) async {
    await pump(tester, const StickersPage());
    Future<void> openRemove() async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Cats')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await settle(tester);
      await tester.tap(find.text('Remove'));
      await settle(tester);
      expect(find.text('Remove this sticker set?'), findsOneWidget);
    }

    await openRemove();
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(json.sent.where((r) => r['@type'] == 'changeStickerSet'), isEmpty);
    expect(find.text('Cats'), findsOneWidget);

    await openRemove();
    await tester.tap(find.text('Remove').last);
    await settle(tester);
    final request = sent('changeStickerSet');
    expect(request['set_id'], '1');
    expect(request['is_installed'], isFalse);
    expect(find.text('Cats'), findsNothing);
  });

  testWidgets('switches change the preferences and TDLib', (tester) async {
    await pump(tester, const StickersPage());
    await tester.tap(find.byKey(const ValueKey('largeEmoji')));
    await tester.tap(find.byKey(const ValueKey('loopStickers')));
    await tester.pump();
    final prefs = container.read(preferencesProvider);
    expect(prefs.largeEmoji, isFalse);
    expect(prefs.loopStickers, isFalse);

    await tester.tap(find.byKey(const ValueKey('animatedEmoji')));
    await settle(tester);
    expect(sent('setOption')['name'], 'disable_animated_emoji');
  });

  testWidgets('adds a set by its link', (tester) async {
    await pump(tester, const StickersPage());
    final field = find.byKey(const ValueKey(('link', StickerSetKind.stickers)));

    await tester.enterText(field, 'https://example.com/x');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('There is no set at this link.'), findsOneWidget);

    await tester.enterText(field, 't.me/addstickers/Birds');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(sent('searchStickerSet')['name'], 'Birds');
    expect(find.text('Birds'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggleSet')));
    await settle(tester);
    final request = sent('changeStickerSet');
    expect(request['set_id'], '3');
    expect(request['is_installed'], isTrue);
  });

  testWidgets('tells a failed lookup from a missing set', (tester) async {
    await pump(tester, const StickersPage());
    final field = find.byKey(const ValueKey(('link', StickerSetKind.stickers)));
    await tester.enterText(field, 't.me/addstickers/Nope/');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(sent('searchStickerSet')['name'], 'Nope');
    expect(find.text('There is no set at this link.'), findsOneWidget);

    await tester.enterText(field, 'Offline');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(
      find.text("Couldn't open the set. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('restores an archived set', (tester) async {
    await pump(
      tester,
      const StickerSetListPage(kind: StickerSetKind.stickers, archived: true),
    );
    expect(find.text('Old'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await settle(tester);
    expect(sent('changeStickerSet')['is_installed'], isTrue);
    expect(find.text('Old'), findsNothing);
  });

  testWidgets('trending emoji sets can be added', (tester) async {
    await pump(
      tester,
      const StickerSetListPage(kind: StickerSetKind.emoji, archived: false),
    );
    expect(find.text('Hearts'), findsOneWidget);
    expect(find.text('40 emoji'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await settle(tester);
    expect(sent('changeStickerSet')['set_id'], '5');
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('pages trending sets and marks them seen', (tester) async {
    json.manyTrending = true;
    await pump(
      tester,
      const StickerSetListPage(kind: StickerSetKind.stickers, archived: false),
    );
    List<Object?> offsets() => [
      for (final r in json.sent)
        if (r['@type'] == 'getTrendingStickerSets') r['offset'],
    ];
    expect(offsets(), [0]);
    expect(
      json.sent.where((r) => r['@type'] == 'viewTrendingStickerSets'),
      isEmpty,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await settle(tester);
    expect(offsets(), [0, 50]);
    expect(find.text('Last', skipOffstage: false), findsOneWidget);
    expect(sent('viewTrendingStickerSets')['sticker_set_ids'], ['100']);
  });

  testWidgets('Add in a trending set\'s sheet updates its row', (tester) async {
    await pump(
      tester,
      const StickerSetListPage(kind: StickerSetKind.emoji, archived: false),
    );
    await tester.tap(find.text('Hearts'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('toggleSet')));
    await settle(tester);
    expect(sent('changeStickerSet')['set_id'], '5');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(find.byKey(const ValueKey('toggleSet')), findsNothing);
    expect(find.text('Remove'), findsOneWidget);
  });

  test('is a section of the settings, found in both languages', () {
    expect(settingsSections, contains(stickersSection));
    final languages = [
      lookupAppLocalizations(const Locale('en')),
      lookupAppLocalizations(const Locale('ru')),
    ];
    expect(
      settingsSectionMatches(stickersSection, 'стикер', languages),
      isTrue,
    );
    expect(
      settingsSectionMatches(stickersSection, 'archived', languages),
      isTrue,
    );
  });
}

Map<String, Object?> _info(
  int id,
  String title, {
  int size = 12,
  bool emoji = false,
  bool archived = false,
}) => {
  '@type': 'stickerSetInfo',
  'id': '$id',
  'title': title,
  'name': title,
  'is_installed': !archived,
  'is_archived': archived,
  'sticker_type': {
    '@type': emoji ? 'stickerTypeCustomEmoji' : 'stickerTypeRegular',
  },
  'size': size,
  'covers': <Object?>[],
};

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];

  /// A full first page of trending stickers, then one more set.
  var manyTrending = false;
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
    final type = decoded['@type']! as String;
    if (type != 'getAuthorizationState') sent.add(decoded);
    final emoji =
        (decoded['sticker_type'] as Map?)?['@type'] == 'stickerTypeCustomEmoji';
    final Map<String, Object?> response = switch (type) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getInstalledStickerSets' => {
        '@type': 'stickerSets',
        'total_count': emoji ? 0 : 2,
        'sets': emoji
            ? <Object?>[]
            : [_info(1, 'Cats'), _info(2, 'Dogs', size: 1)],
      },
      'getArchivedStickerSets' => {
        '@type': 'stickerSets',
        'total_count': 1,
        'sets': [_info(4, 'Old', archived: true)],
      },
      'getTrendingStickerSets' when manyTrending && !emoji => {
        '@type': 'trendingStickerSets',
        'total_count': 51,
        'sets': decoded['offset'] == 0
            ? [
                for (var i = 0; i < 50; i++)
                  {..._info(10 + i, 'Set $i'), 'is_viewed': true},
              ]
            : [_info(100, 'Last')],
        'is_premium': false,
      },
      'getTrendingStickerSets' => {
        '@type': 'trendingStickerSets',
        'total_count': 1,
        'sets': [
          {..._info(5, 'Hearts', emoji: true, size: 40), 'is_installed': false},
        ],
        'is_premium': false,
      },
      'searchStickerSet' when decoded['name'] == 'Birds' => {
        ..._info(3, 'Birds'),
        '@type': 'stickerSet',
        'is_installed': false,
        'stickers': <Object?>[],
        'emojis': <Object?>[],
      },
      'searchStickerSet' when decoded['name'] == 'Hearts' => {
        ..._info(5, 'Hearts', emoji: true, size: 40),
        '@type': 'stickerSet',
        'is_installed': false,
        'stickers': <Object?>[],
        'emojis': <Object?>[],
      },
      'searchStickerSet' when decoded['name'] == 'Offline' => {
        '@type': 'error',
        'code': 500,
        'message': 'Request aborted',
      },
      'searchStickerSet' => {
        '@type': 'error',
        'code': 400,
        'message': 'STICKERSET_INVALID',
      },
      'getOption' => {'@type': 'optionValueEmpty'},
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
