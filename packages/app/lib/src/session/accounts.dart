import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace_storage.dart';
import '../profile/peer_info_state.dart';
import '../shared_media/message_jump.dart';
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

/// What the accounts are busy with, for the UI to wait: rows are disabled
/// while anything runs, and logging out covers the window.
enum AccountsActivity { switching, loggingOut }

final accountsActivityProvider =
    NotifierProvider<AccountsActivityNotifier, AccountsActivity?>(
      AccountsActivityNotifier.new,
    );

class AccountsActivityNotifier extends Notifier<AccountsActivity?> {
  @override
  AccountsActivity? build() => null;

  void set(AccountsActivity? activity) => state = activity;
}

/// An account signed in to a second slot: [added] is the new slot,
/// [existing] the one that already had it.
typedef DuplicateAccount = ({int added, int existing});

final duplicateAccountProvider =
    NotifierProvider<DuplicateAccountNotifier, DuplicateAccount?>(
      DuplicateAccountNotifier.new,
    );

class DuplicateAccountNotifier extends Notifier<DuplicateAccount?> {
  @override
  DuplicateAccount? build() => null;

  void set(DuplicateAccount? duplicate) => state = duplicate;
}

/// Switching, adding and logging out of accounts.
///
/// One account runs at a time: switching closes the open account's TDLib
/// client and starts the chosen one, which takes a moment but keeps one
/// database open and one set of updates to follow. The other accounts get
/// no updates or notifications until opened.
///
/// One change runs at a time, until the next account's session has
/// started; asking for another meanwhile (a double click, the palette) is
/// ignored.
class AccountsNotifier extends AsyncNotifier<AccountIndex> {
  StreamSubscription<AuthorizationStage>? _stages;

  /// The account that was open before [add], to go back to.
  int? _beforeAdd;
  Future<void>? _running;

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
    final index = await storage.index();
    if (!index.legacy) {
      // What a removal interrupted by a crash left behind.
      await storage
          .cleanUp(ref.read(accountSecretsProvider))
          .catchError((Object _) {});
    }
    return index;
  }

  Future<AccountStorage> get _storage =>
      ref.read(accountStorageProvider.future);

  SecretStore get _secrets => ref.read(accountSecretsProvider);

  /// Whether a switch, an add or a log out is running.
  bool get isBusy => _running != null;

  /// Whether another account can be added.
  bool get canAdd => canAddIn(state.value);

  static bool canAddIn(AccountIndex? index) =>
      index != null &&
      !index.legacy &&
      index.accounts.length < AccountStorage.maxAccounts;

  /// The account [back] goes to from sign-in or a failed start: the one
  /// open before an add, else the first other signed-in one.
  int? get backTarget => backTargetIn(state.value, _beforeAdd);

  static int? backTargetIn(AccountIndex? index, [int? preferred]) {
    if (index == null || index.legacy) return null;
    final others = [
      for (final a in index.accounts)
        if (a.slot != index.active && a.isSignedIn) a.slot,
    ];
    if (others.contains(preferred)) return preferred;
    return others.firstOrNull;
  }

  Future<void> _exclusive(
    AccountsActivity activity,
    Future<void> Function() action,
  ) async {
    if (_running != null) return;
    final busy = ref.read(accountsActivityProvider.notifier)..set(activity);
    final run = action();
    _running = run;
    try {
      await run;
    } finally {
      _running = null;
      busy.set(null);
    }
  }

  /// Opens the account in [slot].
  Future<void> switchTo(int slot) =>
      _exclusive(AccountsActivity.switching, () => _switchTo(slot));

  Future<void> _switchTo(int slot) async {
    final index = await future;
    if (slot == index.active || !index.accounts.any((a) => a.slot == slot)) {
      return;
    }
    _beforeAdd = null;
    await _reopen(() async => (await _storage).activate(slot));
  }

  /// Adds an account and opens sign-in for it.
  Future<void> add() => _exclusive(AccountsActivity.switching, () async {
    final index = await future;
    if (!canAddIn(index)) return;
    _beforeAdd = index.active;
    await _reopen(() async => (await _storage).addAccount());
  });

  /// Leaves sign-in, or a session that failed to start, for [backTarget].
  /// An added account that never signed in is dropped.
  Future<void> back() => _exclusive(AccountsActivity.switching, () async {
    final index = await future;
    final target = backTargetIn(index, _beforeAdd);
    if (target == null) return;
    final drop = !index.activeAccount.maybeSignedIn;
    _beforeAdd = null;
    await _reopen(() async {
      final storage = await _storage;
      if (drop) await storage.remove(index.active, _secrets);
      return storage.activate(target);
    });
  });

  /// Logs out of the account in [slot] and forgets everything it kept on
  /// this computer: TDLib's data, the message store, the window layout and
  /// the keychain keys. TDLib can only log out of the account it runs, so
  /// the account is opened for it first, and the one that was open comes
  /// back after, also when logging out fails.
  Future<void> logOut(int slot) =>
      _exclusive(AccountsActivity.loggingOut, () => _logOut(slot));

  Future<void> _logOut(int slot) async {
    final index = await future;
    final entry = index.accounts.where((a) => a.slot == slot).firstOrNull;
    if (entry == null) return;
    final storage = await _storage;
    if (!entry.maybeSignedIn && index.active != slot) {
      // Never signed in: nothing to log out of on Telegram's side.
      _open(await storage.remove(slot, _secrets));
      return;
    }
    final back = index.active == slot ? null : index.active;
    if (back != null) await _switchTo(slot);
    final TelegramSession session;
    try {
      session = await ref.read(telegramSessionProvider.future);
      await session.authorization.logOut();
    } catch (_) {
      if (back != null) await _switchTo(back);
      rethrow;
    }
    // The closed client still holds the database; it goes before the
    // folder does.
    await session.dispose();
    await ref.read(workspaceSaverProvider).clear();
    try {
      if (index.legacy) return;
      var next = await storage.remove(slot, _secrets);
      if (back != null && next.accounts.any((a) => a.slot == back)) {
        next = await storage.activate(back);
      }
      _open(next);
    } catch (_) {
      _open(await storage.index());
      rethrow;
    } finally {
      _beforeAdd = null;
      _restart();
      await _started();
    }
  }

  /// Logs out of the added copy of an account that was already here and
  /// opens the existing one.
  Future<void> resolveDuplicate() =>
      _exclusive(AccountsActivity.loggingOut, () async {
        final duplicate = ref.read(duplicateAccountProvider);
        if (duplicate == null) return;
        ref.read(duplicateAccountProvider.notifier).set(null);
        await _logOut(duplicate.added);
        await _switchTo(duplicate.existing);
      });

  /// Closes the open session, applies [change] to the index and starts
  /// the session of the slot it makes active. When [change] fails, the
  /// open account starts again.
  Future<void> _reopen(Future<AccountIndex> Function() change) async {
    await _closeSession();
    try {
      _open(await change());
    } finally {
      _restart();
      await _started();
    }
  }

  /// Takes [index] as the state, and its active slot for what is kept
  /// per account (the window layout).
  void _open(AccountIndex index) {
    state = AsyncData(index);
    ref.read(activeSlotProvider.notifier).set(index.active);
  }

  /// Starts the active account's session, without the open account's
  /// folder, info panels or message jumps.
  void _restart() {
    ref
      ..invalidate(selectedChatListProvider)
      ..invalidate(peerInfoPanelsProvider)
      ..invalidate(messageJumpProvider)
      ..invalidate(telegramSessionProvider);
  }

  /// Waits for the session to start, or to fail to.
  Future<void> _started() async {
    try {
      await ref.read(telegramSessionProvider.future);
    } on Object {
      // Shown by the app; the accounts are free again either way.
    }
  }

  /// Saves the open account's window layout and closes its session, once
  /// it has started.
  Future<void> _closeSession() async {
    await ref.read(workspaceSaverProvider).flush();
    TelegramSession? session;
    try {
      session = await ref.read(telegramSessionProvider.future);
    } on Object {
      session = null;
    }
    await session?.dispose();
  }

  void _follow(TelegramSession? session) {
    unawaited(_stages?.cancel());
    _stages = null;
    if (session == null) return;
    // The slot this session belongs to, before anything can switch.
    final slot = switch (state.value) {
      final index? => Future.value(index.active),
      null => _storage.then((s) => s.index()).then((i) => i.active),
    };
    void onStage(AuthorizationStage? stage) {
      if (stage?.kind == AuthorizationStageKind.ready) {
        unawaited(
          slot.then((s) => _describe(session, s)).catchError((Object _) {}),
        );
      }
    }

    _stages = session.authorization.stages.listen(onStage);
    onStage(session.authorization.currentStage);
  }

  Future<void> _describe(TelegramSession session, int slot) async {
    final profile = await session.account.profile();
    final storage = await _storage;
    final index = await future;
    final known = index.accounts.where((a) => a.slot == slot).firstOrNull;
    if (known == null || index.legacy) return;
    final entry = AccountEntry(
      slot: slot,
      userId: profile.userId,
      name: profile.name,
      phoneNumber: profile.phoneNumber,
    );
    if (entry != known) state = AsyncData(await storage.describe(entry));
    final existing = index.accounts
        .where((a) => a.slot != slot && a.userId == profile.userId)
        .firstOrNull;
    if (existing != null) {
      ref.read(duplicateAccountProvider.notifier).set((
        added: slot,
        existing: existing.slot,
      ));
    }
  }
}

/// How an account is called in lists: its name, else its phone number.
String accountTitle(AccountEntry account, AppLocalizations l10n, int number) {
  if (account.name.isNotEmpty) return account.name;
  if (account.phoneNumber.isNotEmpty) return '+${account.phoneNumber}';
  return l10n.accountNumber(number);
}

/// `app.account.<n>` for each signed-in account but the open one, for the
/// palette and for shortcuts the shell may bind to them (⌘1..⌘3): `n` is
/// the account's place in the list, which only changes when an account
/// before it is removed.
List<PaletteCommand> accountCommands(
  AccountIndex? index,
  AppLocalizations l10n,
  void Function(int slot) switchTo,
) {
  if (index == null || index.accounts.length < 2) return const [];
  return [
    for (final (i, account) in index.accounts.indexed)
      if (account.isSignedIn && account.slot != index.active)
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
