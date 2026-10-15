import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace_storage.dart';
import 'providers.dart';

/// The accounts folders under the application support folder.
final accountStorageProvider = FutureProvider<AccountStorage>(
  (ref) async => AccountStorage((await getApplicationSupportDirectory()).path),
);

/// Where account keys live: the system keychain.
final accountSecretsProvider = Provider<SecretStore>(
  (ref) => const KeychainSecretStore(),
);

/// The accounts on this computer and which one is open, from the accounts
/// index. Also for the sidebar's account switcher.
final accountsProvider = AsyncNotifierProvider<AccountsNotifier, AccountIndex>(
  AccountsNotifier.new,
);

/// The open account, once the index is read.
final activeAccountProvider = Provider<AccountEntry?>(
  (ref) => ref.watch(accountsProvider).value?.activeAccount,
);

/// The open account's slot once it changed in this run; null before, when
/// the index on disk says which. Kept apart from [accountsProvider] so
/// what is stored per account does not depend on the notifier that saves
/// it on a switch.
final activeSlotProvider = NotifierProvider<ActiveSlot, int?>(ActiveSlot.new);

class ActiveSlot extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int slot) => state = slot;
}

/// Switching, adding and logging out of accounts.
///
/// One account runs at a time: switching closes the open account's TDLib
/// client and starts the chosen one, which takes a moment but keeps one
/// database open and one set of updates to follow.
class AccountsNotifier extends AsyncNotifier<AccountIndex> {
  StreamSubscription<AuthorizationStage>? _stages;

  /// The account that was open before [add], to go back to on cancel.
  int? _beforeAdd;

  @override
  Future<AccountIndex> build() async {
    ref.onDispose(() => unawaited(_stages?.cancel()));
    // Notes who signs in, for the list while another account is open.
    ref.listen(
      telegramSessionProvider,
      (_, next) => _follow(next.value),
      fireImmediately: true,
    );
    final storage = await ref.watch(accountStorageProvider.future);
    return storage.index();
  }

  Future<AccountStorage> get _storage =>
      ref.read(accountStorageProvider.future);

  /// Whether another account can be added.
  bool get canAdd =>
      (state.value?.accounts.length ?? 0) < AccountStorage.maxAccounts;

  /// Whether sign-in is for an added account that can be dropped to go
  /// back to the one open before.
  bool get canCancelAdd => canCancelAddIn(state.value);

  /// [canCancelAdd] for [index], for widgets that watch the index.
  static bool canCancelAddIn(AccountIndex? index) {
    if (index == null || index.activeAccount.isSignedIn) return false;
    return index.accounts.any((a) => a.slot != index.active && a.isSignedIn);
  }

  /// Opens the account in [slot].
  Future<void> switchTo(int slot) async {
    final index = await future;
    if (slot == index.active) return;
    await _closeSession();
    _open(await (await _storage).activate(slot));
    _beforeAdd = null;
    ref.invalidate(telegramSessionProvider);
  }

  /// Adds an account and opens sign-in for it.
  Future<void> add() async {
    final index = await future;
    if (index.accounts.length >= AccountStorage.maxAccounts) return;
    await _closeSession();
    _beforeAdd = index.active;
    _open(await (await _storage).addAccount());
    ref.invalidate(telegramSessionProvider);
  }

  /// Drops the account being added and opens the one before.
  Future<void> cancelAdd() async {
    if (!canCancelAdd) return;
    final index = state.requireValue;
    final back =
        _beforeAdd ??
        index.accounts
            .firstWhere((a) => a.isSignedIn && a.slot != index.active)
            .slot;
    await _closeSession();
    final storage = await _storage;
    await storage.remove(index.active, ref.read(accountSecretsProvider));
    _open(await storage.activate(back));
    _beforeAdd = null;
    ref.invalidate(telegramSessionProvider);
  }

  /// Logs out of the account in [slot] and forgets everything it kept on
  /// this computer: TDLib's data, the message store, the window layout and
  /// the keychain keys. TDLib can only log out of the account it runs, so
  /// another account is opened for it first and comes back after.
  Future<void> logOut(int slot) async {
    final index = await future;
    final entry = index.accounts.where((a) => a.slot == slot).firstOrNull;
    if (entry == null) return;
    final storage = await _storage;
    final secrets = ref.read(accountSecretsProvider);
    if (!entry.isSignedIn && index.active != slot) {
      // Never signed in: nothing to log out of on Telegram's side.
      _open(await storage.remove(slot, secrets));
      return;
    }
    final back = index.active == slot ? null : index.active;
    if (back != null) await switchTo(slot);
    final session = await ref.read(telegramSessionProvider.future);
    await session.authorization.logOut();
    // The closed client still holds the database; it goes before the
    // folder does.
    await session.dispose();
    await ref.read(workspaceSaverProvider).clear();
    var next = await storage.remove(slot, secrets);
    if (back != null && next.accounts.any((a) => a.slot == back)) {
      next = await storage.activate(back);
    }
    _open(next);
    _beforeAdd = null;
    ref.invalidate(telegramSessionProvider);
  }

  /// Takes [index] as the state, and its active slot for what is kept
  /// per account (the window layout).
  void _open(AccountIndex index) {
    state = AsyncData(index);
    ref.read(activeSlotProvider.notifier).set(index.active);
  }

  /// Saves the open account's window layout and closes its session.
  Future<void> _closeSession() async {
    await ref.read(workspaceSaverProvider).flush();
    await ref.read(telegramSessionProvider).value?.dispose();
  }

  void _follow(TelegramSession? session) {
    unawaited(_stages?.cancel());
    _stages = null;
    if (session == null) return;
    void onStage(AuthorizationStage? stage) {
      if (stage?.kind == AuthorizationStageKind.ready) {
        unawaited(_describe(session).catchError((Object _) {}));
      }
    }

    _stages = session.authorization.stages.listen(onStage);
    onStage(session.authorization.currentStage);
  }

  Future<void> _describe(TelegramSession session) async {
    final profile = await session.account.profile();
    final storage = await _storage;
    final index = await future;
    final entry = AccountEntry(
      slot: index.active,
      userId: profile.userId,
      name: profile.name,
      phoneNumber: profile.phoneNumber,
    );
    if (entry == index.activeAccount) return;
    state = AsyncData(await storage.describe(entry));
  }
}

/// How an account is called in lists: its name, else its phone number.
String accountTitle(AccountEntry account, AppLocalizations l10n, int number) {
  if (account.name.isNotEmpty) return account.name;
  if (account.phoneNumber.isNotEmpty) return '+${account.phoneNumber}';
  return l10n.accountNumber(number);
}

/// `app.account.<n>` for each signed-in account, for the palette and for
/// shortcuts the shell may bind to them.
List<PaletteCommand> accountCommands(
  AccountIndex? index,
  AppLocalizations l10n,
  void Function(int slot) switchTo,
) {
  if (index == null || index.accounts.length < 2) return const [];
  return [
    for (final (i, account) in index.accounts.indexed)
      if (account.isSignedIn)
        PaletteCommand(
          id: 'app.account.${i + 1}',
          title: l10n.switchToAccount(accountTitle(account, l10n, i + 1)),
          keywords: [account.phoneNumber],
          run: () => switchTo(account.slot),
        ),
  ];
}

/// The system keychain through flutter_secure_storage.
final class KeychainSecretStore implements SecretStore {
  const KeychainSecretStore([
    this._storage = const FlutterSecureStorage(
      mOptions: MacOsOptions(usesDataProtectionKeychain: false),
    ),
  ]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
