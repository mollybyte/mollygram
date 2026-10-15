import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/home/workspace_storage.dart';
import 'package:mollygram/src/privacy/privacy_settings.dart';
import 'package:mollygram/src/session/account_overlays.dart';
import 'package:mollygram/src/session/accounts.dart';
import 'package:mollygram/src/session/providers.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram/src/settings/account_page.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AccountStorage storage;
  late _MemorySecrets secrets;
  late List<int> started;

  /// Per slot: the user signed in there (null: signed out) and whether
  /// TDLib refuses to log out.
  late Map<int, ({int? userId, bool failLogOut})> slots;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('accounts');
    storage = AccountStorage(dir.path);
    secrets = _MemorySecrets();
    started = [];
    slots = {};
    await storage.writeIndex(
      AccountIndex(
        active: 0,
        accounts: const [
          AccountEntry(slot: 0, userId: 1, name: 'Anna', phoneNumber: '7999'),
          AccountEntry(slot: 1, userId: 2, name: 'Boris', phoneNumber: '7888'),
        ],
      ),
    );
    for (final slot in [0, 1]) {
      await Directory(storage.slotPath(slot)).create(recursive: true);
      for (final name in AccountStorage.secretNamesFor(slot)) {
        secrets.values[name] = 'key';
      }
    }
  });

  tearDown(() => dir.delete(recursive: true));

  ProviderContainer create() {
    final container = ProviderContainer(
      overrides: [
        privacySettingsStorageProvider.overrideWithValue(
          MemoryPrivacySettingsStorage(),
        ),
        accountStorageProvider.overrideWith((ref) async => storage),
        accountSecretsProvider.overrideWithValue(secrets),
        telegramApiConfigProvider.overrideWithValue(
          const TelegramApiConfig(
            apiId: 12345,
            apiHash: '0123456789abcdef0123456789abcdef',
          ),
        ),
        telegramSessionLauncherProvider.overrideWithValue(
          TelegramSessionLauncher(
            startTdlib: (_) async {
              final slot = (await storage.index()).active;
              final json = _FakeTdJson(
                slots[slot] ?? (userId: null, failLogOut: false),
              );
              return td.Td.custom(json, td.InlineTdEventSource(json));
            },
            loadParameters: (api) async {
              started.add((await storage.index()).active);
              return _parameters(api);
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(telegramSessionProvider, (_, _) {});
    container.listen(accountsProvider, (_, _) {});
    return container;
  }

  Future<AccountIndex> settle(ProviderContainer container) async {
    await container.read(telegramSessionProvider.future);
    return container.read(accountsProvider.future);
  }

  test('switching opens the chosen account with its own layout', () async {
    final container = create();
    await settle(container);
    expect(container.read(activeAccountProvider)?.name, 'Anna');
    await container.read(workspaceStorageProvider).write({'tabs': 'anna'});

    await container.read(accountsProvider.notifier).switchTo(1);
    final index = await settle(container);

    expect(started, [0, 1]);
    expect(index.active, 1);
    expect((await storage.readIndex())!.active, 1);
    expect(container.read(activeAccountProvider)?.name, 'Boris');
    final layout = container.read(workspaceStorageProvider);
    expect(await layout.read(), isNull);
    await layout.write({'tabs': 'boris'});
    String saved(int slot) =>
        File('${storage.slotPath(slot)}${Platform.pathSeparator}workspace.json')
            .readAsStringSync();
    expect(saved(0), contains('anna'));
    expect(saved(1), contains('boris'));
  });

  test('adds up to three accounts; back drops the new one', () async {
    final container = create();
    await settle(container);
    final notifier = container.read(accountsProvider.notifier);

    await notifier.add();
    var index = await settle(container);
    expect(index.active, 2);
    expect(index.accounts, hasLength(3));
    expect(notifier.canAdd, isFalse);
    expect(notifier.backTarget, 0);

    await notifier.back();
    index = await settle(container);
    expect(index.active, 0);
    expect([for (final a in index.accounts) a.slot], [0, 1]);
    // Slot numbers are not reused.
    await notifier.add();
    expect((await settle(container)).active, 3);
    expect(started, [0, 2, 0, 3]);
  });

  test('one change at a time: a second one meanwhile is ignored', () async {
    final container = create();
    await settle(container);
    final notifier = container.read(accountsProvider.notifier);

    await Future.wait([
      notifier.switchTo(1),
      notifier.add(),
      notifier.switchTo(1),
      notifier.logOut(0),
    ]);
    final index = await settle(container);

    expect(started, [0, 1]);
    expect(index.active, 1);
    expect(index.accounts, hasLength(2));
    expect(container.read(accountsActivityProvider), isNull);
  });

  test('a failed log out brings back the open account', () async {
    slots[1] = (userId: null, failLogOut: true);
    final container = create();
    await settle(container);

    await expectLater(
      container.read(accountsProvider.notifier).logOut(1),
      throwsA(isA<td.TdException>()),
    );
    final index = await settle(container);

    expect(started, [0, 1, 0]);
    expect(index.active, 0);
    expect(index.accounts, hasLength(2));
    expect(Directory(storage.slotPath(1)).existsSync(), isTrue);
    expect(secrets.values.keys, containsAll(AccountStorage.secretNamesFor(1)));
  });

  test('an account signed in twice can be dropped for the first', () async {
    slots[2] = (userId: 1, failLogOut: false);
    final container = create();
    await settle(container);
    final notifier = container.read(accountsProvider.notifier);

    await notifier.add();
    await settle(container);
    // The new slot is noted once its profile is read.
    for (var i = 0; i < 50; i++) {
      if (container.read(duplicateAccountProvider) != null) break;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(container.read(duplicateAccountProvider), (added: 2, existing: 0));
    expect((await settle(container)).accounts[2].userId, 1);

    await notifier.resolveDuplicate();
    final index = await settle(container);
    expect(index.active, 0);
    expect([for (final a in index.accounts) a.slot], [0, 1]);
    expect(Directory(storage.slotPath(2)).existsSync(), isFalse);
    expect(container.read(duplicateAccountProvider), isNull);
  });

  test('logging out wipes the account and comes back', () async {
    final container = create();
    await settle(container);

    await container.read(accountsProvider.notifier).logOut(1);
    final index = await settle(container);

    expect(started, [0, 1, 0]);
    expect(index.active, 0);
    expect([for (final a in index.accounts) a.slot], [0]);
    expect(Directory(storage.slotPath(1)).existsSync(), isFalse);
    expect(Directory(storage.slotPath(0)).existsSync(), isTrue);
    expect(secrets.values.keys, AccountStorage.secretNamesFor(0));
  });

  test('logging out of the last account leaves an empty one', () async {
    await storage.writeIndex(
      AccountIndex(
        active: 0,
        accounts: const [AccountEntry(slot: 0, userId: 1)],
        nextSlot: 2,
      ),
    );
    final container = create();
    await settle(container);

    await container.read(accountsProvider.notifier).logOut(0);
    final index = await settle(container);

    expect(index.active, 2);
    expect(index.activeAccount.isSignedIn, isFalse);
    expect(Directory(storage.slotPath(0)).existsSync(), isFalse);
    expect(secrets.values.keys, isNot(contains(AccountStorage.keyNameFor(0))));
  });

  testWidgets('the accounts group lists, switches and logs out', (
    tester,
  ) async {
    final index = (await tester.runAsync(storage.readIndex))!;
    final fake = _FakeAccounts(index);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => fake),
          accountProfileProvider.overrideWith(
            (ref) => Completer<AccountProfile>().future,
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(child: AccountsGroup()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('+7888'), findsOneWidget);
    expect(find.text('Add account'), findsOneWidget);
    expect(find.byKey(const ValueKey('logOut-0')), findsNothing);

    await tester.tap(find.text('Boris'));
    expect(fake.calls, ['switch 1']);

    await tester.tap(find.byKey(const ValueKey('logOut-1')));
    await tester.pumpAndSettle();
    expect(find.text('Log out of Boris?'), findsOneWidget);
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(fake.calls, ['switch 1', 'logOut 1']);

    await tester.tap(find.text('Add account'));
    expect(fake.calls.last, 'add');
  });

  testWidgets('a failed log out shows under the accounts', (tester) async {
    final index = (await tester.runAsync(storage.readIndex))!;
    final fake = _FakeAccounts(index)..failLogOut = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(() => fake),
          accountProfileProvider.overrideWith(
            (ref) => Completer<AccountProfile>().future,
          ),
        ],
        child: MaterialApp(
          theme: buildMgTheme(MgColors.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Material(child: AccountsLayer(child: AccountsGroup())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('logOut-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out').last);
    await tester.pumpAndSettle();
    expect(
      find.text("Couldn't log out. Check the connection and try again."),
      findsOneWidget,
    );

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(AccountsGroup)),
    );
    scope
        .read(accountsActivityProvider.notifier)
        .set(AccountsActivity.loggingOut);
    await tester.pump();
    expect(find.text('Logging out…'), findsOneWidget);
    scope.read(accountsActivityProvider.notifier).set(null);
    await tester.pump();
  });

  test('a command per signed-in account', () async {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final index = (await storage.readIndex())!;
    final switched = <int>[];
    final commands = accountCommands(index, l10n, switched.add);

    // Not the open account; the id is its place in the list.
    expect([for (final c in commands) c.id], ['app.account.2']);
    expect(commands.last.title, 'Switch to Boris');
    commands.last.run();
    expect(switched, [1]);
    expect(
      accountCommands(
        AccountIndex(active: 0, accounts: const [AccountEntry(slot: 0)]),
        l10n,
        switched.add,
      ),
      isEmpty,
    );
  });
}

Future<TdlibParameters> _parameters(TelegramApiConfig api) async =>
    TdlibParameters(
      api: api,
      databaseDirectory: '/tmp/mollygram/database',
      filesDirectory: '/tmp/mollygram/files',
      databaseEncryptionKey: Uint8List.fromList([1, 2, 3]),
      systemLanguageCode: 'en',
      deviceModel: 'Mac',
      applicationVersion: '0.1.0',
    );

/// A TDLib, signed out or signed in as a user, that closes on `close`
/// and on `logOut`.
final class _FakeTdJson implements td.TdJson {
  _FakeTdJson(this.slot);

  final ({int? userId, bool failLogOut}) slot;
  final _queue = Queue<String>();

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
    final type = decoded['@type'];
    final userId = slot.userId;
    final Map<String, Object?> response = switch (type) {
      'getAuthorizationState' when userId != null => {
        '@type': 'authorizationStateReady',
      },
      'getAuthorizationState' => {'@type': 'authorizationStateWaitPhoneNumber'},
      'getMe' when userId != null => {
        '@type': 'user',
        'id': userId,
        'first_name': 'User $userId',
        'phone_number': '7000$userId',
        'status': {'@type': 'userStatusEmpty'},
        'type': {'@type': 'userTypeRegular'},
      },
      'getUserFullInfo' => {
        '@type': 'userFullInfo',
        'gift_settings': {
          '@type': 'giftSettings',
          'accepted_gift_types': {'@type': 'acceptedGiftTypes'},
        },
      },
      'getOption' => {'@type': 'optionValueEmpty'},
      'logOut' when slot.failLogOut => {
        '@type': 'error',
        'code': 500,
        'message': 'NETWORK',
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
    if (type == 'close' || (type == 'logOut' && !slot.failLogOut)) {
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

final class _MemorySecrets implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

final class _FakeAccounts extends AccountsNotifier {
  _FakeAccounts(this._index);

  final AccountIndex _index;
  final calls = <String>[];
  var failLogOut = false;

  @override
  Future<AccountIndex> build() async => _index;

  @override
  Future<void> switchTo(int slot) async => calls.add('switch $slot');

  @override
  Future<void> logOut(int slot) async {
    calls.add('logOut $slot');
    if (failLogOut) throw StateError('offline');
  }

  @override
  Future<void> add() async => calls.add('add');
}
