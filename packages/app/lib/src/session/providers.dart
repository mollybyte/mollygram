import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' show TdClientClosed;

import '../home/workspace_storage.dart';
import '../privacy/message_store.dart';
import '../privacy/privacy_settings.dart';
import '../settings/preferences.dart';
import 'sign_in_actions.dart';
import 'telegram_session_launcher.dart';

/// The api_id and api_hash compiled into this build.
final telegramApiConfigProvider = Provider<TelegramApiConfig>(
  (ref) => TelegramApiConfig.fromEnvironment,
);

final telegramSessionLauncherProvider = Provider<TelegramSessionLauncher>(
  (ref) => TelegramSessionLauncher(),
);

/// Thrown when the build has no Telegram API keys.
final class MissingApiKeys implements Exception {
  const MissingApiKeys();
}

/// The running TDLib session. It is created once and closed with the app.
final telegramSessionProvider = FutureProvider<TelegramSession>((ref) async {
  final config = ref.watch(telegramApiConfigProvider);
  if (!config.isConfigured) throw const MissingApiKeys();
  final launcher = ref.watch(telegramSessionLauncherProvider);
  // The saved privacy extras apply from the first request on.
  await ref.read(privacySettingsProvider.notifier).loaded;
  TelegramSession session;
  for (var attempt = 1; ; attempt++) {
    try {
      session = await launcher.start(
        config,
        privacy: ref.read(privacySettingsProvider),
        openStore: ref.read(messageStoreOpenerProvider),
      );
      break;
    } on SessionClosedElsewhere {
      // Closed as it started; the next client starts signed out.
      if (attempt == 3) rethrow;
      await _forgetAccount(ref);
    }
  }
  // Replaced while starting (another account was opened): nothing else
  // will close this client, and it holds the account's database lock.
  if (!ref.mounted) {
    await session.dispose();
    throw StateError('The session was replaced while it started');
  }
  // A switch flipped while the session was starting.
  session.privacySettings = ref.read(privacySettingsProvider);
  // The Data and storage switches reach the files as they change.
  session.files.autoDownloadKinds = ref.read(autoDownloadKindsProvider);
  ref.listen(
    autoDownloadKindsProvider,
    (_, kinds) => session.files.autoDownloadKinds = kinds,
  );
  // Online while the window is active, as the official client is.
  final privacy = session.privacy;
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) =>
        privacy.foreground = state == AppLifecycleState.resumed,
  );
  final state = WidgetsBinding.instance.lifecycleState;
  privacy.foreground = state == null || state == AppLifecycleState.resumed;
  var disposed = false;
  ref.onDispose(() {
    disposed = true;
    lifecycle.dispose();
    unawaited(session.dispose());
  });
  // Terminated from another device: TDLib has logged out and closed the
  // client, so a new session starts and the app lands on sign-in.
  unawaited(
    session.closedElsewhere.then((_) async {
      await session.dispose();
      if (disposed) return;
      await _forgetAccount(ref);
      if (!disposed) ref.invalidateSelf();
    }),
  );
  return session;
});

/// Forgets what belonged to an account that was signed out elsewhere: the
/// saved window layout and the selected folder. The sign-in screen never
/// sees the old session reach the phone number step, which is where a
/// sign-out normally clears them.
Future<void> _forgetAccount(Ref ref) async {
  await ref.read(workspaceSaverProvider).clear();
  ref.invalidate(selectedChatListProvider);
}

/// TDLib's current sign-in step.
final authorizationStageProvider = StreamProvider<AuthorizationStage>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  return _startWith(
    session.authorization.currentStage,
    session.authorization.stages,
  );
});

/// How the connection to Telegram is doing, for the status in the window.
final connectionStatusProvider = StreamProvider<ConnectionStatus>((ref) {
  final connection = ref.watch(telegramSessionProvider).requireValue.connection;
  return _startWith(connection.current, connection.changes);
});

/// Sends what the user typed on the sign-in screen to TDLib.
final signInActionsProvider = Provider<SignInActions>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  return SessionSignInActions(
    session.authorization,
    restart: () async {
      // The old client has to be closed before a new one opens the same
      // database, or TDLib can't lock it.
      await session.dispose();
      ref.invalidate(telegramSessionProvider);
    },
  );
});

/// Whether the sign-in screen opens on the phone number form rather than
/// the QR code. It outlives the session, which is restarted to leave the
/// QR step (see [SignInActions.leaveQrCode]).
final preferPhoneSignInProvider = NotifierProvider<PreferPhoneSignIn, bool>(
  PreferPhoneSignIn.new,
);

class PreferPhoneSignIn extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

/// Chat folders in the server-defined order.
final chatFoldersProvider = StreamProvider<List<ChatFolder>>((ref) {
  final chatLists = ref.watch(telegramSessionProvider).requireValue.chatLists;
  return _startWith(
    chatLists.store.folders,
    chatLists.changes.map((_) => chatLists.store.folders),
  );
});

/// The folder shown in the sidebar.
final selectedChatListProvider =
    NotifierProvider<SelectedChatList, ChatListLocation>(SelectedChatList.new);

class SelectedChatList extends Notifier<ChatListLocation> {
  @override
  ChatListLocation build() => const ChatListLocation.main();

  void select(ChatListLocation list) => state = list;
}

/// Chats of one list, sorted the way TDLib orders them.
final chatListProvider =
    StreamProvider.family<List<ChatListEntry>, ChatListLocation>((ref, list) {
      final chatLists = ref
          .watch(telegramSessionProvider)
          .requireValue
          .chatLists;
      if (!list.isMain) unawaited(_ignoreClosed(chatLists.loadMore(list)));
      // Every update of any chat fires `changes`; a list that holds the very
      // same rows is not sent on, so the sidebar does not rebuild for it.
      return _startWith(
        chatLists.store.chatsFor(list),
        _batched(
          chatLists.changes,
          _burst,
        ).map((_) => chatLists.store.chatsFor(list)),
      ).distinct(_sameRows);
    });

/// Sending a message makes TDLib send several updates one after another:
/// the draft clears, the message appears, the chat moves up, its last message
/// settles. Shown one by one they flash the row through states that are
/// gone a moment later, so the sidebar waits this long to take them
/// together.
const _burst = Duration(milliseconds: 32);

/// Passes the events of [source] on at most once per [window]: the first
/// event opens a window and one event leaves when it ends, for all that
/// arrived in it.
Stream<void> _batched(Stream<void> source, Duration window) {
  late final StreamController<void> controller;
  StreamSubscription<void>? subscription;
  Timer? timer;
  controller = StreamController<void>(
    onListen: () {
      subscription = source.listen(
        (_) => timer ??= Timer(window, () {
          timer = null;
          if (!controller.isClosed) controller.add(null);
        }),
        onError: controller.addError,
        onDone: () {
          timer?.cancel();
          unawaited(controller.close());
        },
      );
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
      return subscription?.cancel();
    },
  );
  return controller.stream;
}

/// Whether two lists hold the same entries, by identity: the store replaces
/// an entry when it changes.
bool _sameRows(List<ChatListEntry> a, List<ChatListEntry> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i])) return false;
  }
  return true;
}

/// One chat's sidebar entry, kept current, for the chat header.
final chatEntryProvider = StreamProvider.family<ChatListEntry?, int>((
  ref,
  chatId,
) {
  final chatLists = ref.watch(telegramSessionProvider).requireValue.chatLists;
  return _startWith(
    chatLists.store.chat(chatId),
    chatLists.changes.map((_) => chatLists.store.chat(chatId)),
  ).distinct();
});

/// Text messages of one chat, newest first.
final conversationProvider =
    StreamProvider.family<List<ConversationMessage>, int>((ref, chatId) {
      final conversations = ref
          .watch(telegramSessionProvider)
          .requireValue
          .conversations;
      unawaited(_ignoreClosed(conversations.loadHistory(chatId)));
      return _startWith(
        conversations.store.messagesFor(chatId),
        conversations.changes.map(
          (_) => conversations.store.messagesFor(chatId),
        ),
      );
    });

/// Lets a background request fail quietly when the session closes under it
/// (sign-in restarts it, the app closes it).
Future<void> _ignoreClosed(Future<void> request) =>
    request.catchError((Object _) {}, test: (error) => error is TdClientClosed);

/// Emits [first] (when not null), then everything from [rest].
///
/// The subscription to [rest] is made before [first] is delivered, so an
/// update that arrives in between is not lost.
Stream<T> _startWith<T>(T? first, Stream<T> rest) {
  late final StreamController<T> controller;
  StreamSubscription<T>? subscription;
  controller = StreamController<T>(
    onListen: () {
      subscription = rest.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      if (first != null) controller.add(first);
    },
    onCancel: () => subscription?.cancel(),
  );
  return controller.stream;
}
