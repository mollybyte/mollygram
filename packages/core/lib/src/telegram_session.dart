import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'account_settings.dart';
import 'authorization_controller.dart';
import 'authorization_stage.dart';
import 'chat_folders.dart';
import 'chat_list_controller.dart';
import 'chat_management.dart';
import 'chat_search.dart';
import 'chat_search_controller.dart';
import 'connection_status.dart';
import 'contacts_controller.dart';
import 'conversation_controller.dart';
import 'file_controller.dart';
import 'link_resolver.dart';
import 'mention_search.dart';
import 'notification_controller.dart';
import 'peer_info.dart';
import 'privacy_guard.dart';
import 'proxy_controller.dart';
import 'sticker_library.dart';
import 'storage_usage.dart';
import 'store/message_capture.dart';
import 'tdlib_initializer.dart';

/// Thrown by [TelegramSession.attach] when TDLib closes the client while
/// the session starts, without the app asking. Like
/// [TelegramSession.closedElsewhere], it means: start a new session.
final class SessionClosedElsewhere implements Exception {
  const SessionClosedElsewhere();

  @override
  String toString() => 'SessionClosedElsewhere';
}

/// Owns one TDLib instance and coordinates its initial authorization flow.
///
/// A session has a single account client. It sends parameters only when TDLib
/// asks for them, then starts chat-list synchronization after authorization is
/// ready. The UI can use [authorization] and [chatLists] independently.
final class TelegramSession {
  TelegramSession._({
    required this._tdlib,
    required this.authorization,
    required this.chatLists,
    required this.folders,
    required this.conversations,
    required this.search,
    required this.chatSearch,
    required this.files,
    required this.notifications,
    required this.stickers,
    required this.peers,
    required this.account,
    required this.mentions,
    required this.storage,
    required this.connection,
    required this.privacy,
    required this.capture,
    required this.contacts,
    required this.management,
    required this.links,
    required this.proxies,
    required this._initializer,
  });

  final td.Td _tdlib;
  final TdlibInitializer _initializer;
  final AuthorizationController authorization;
  final ChatListController chatLists;

  /// The chat folders and their editing.
  final ChatFoldersController folders;
  final ConversationController conversations;
  final ChatSearch search;

  /// Search inside one chat and its shared media.
  final ChatSearchController chatSearch;
  final FileController files;
  final NotificationController notifications;
  final StickerLibrary stickers;
  final PeerInfoController peers;
  final AccountSettings account;
  final StorageManager storage;

  /// Group members for @mentions in the composer.
  final MentionSearch mentions;

  /// The connection state, for the "Connecting…" status in the window.
  final ConnectionMonitor connection;

  /// Ghost mode and the other privacy extras: the one filter on what
  /// this session sends to TDLib.
  final PrivacyGuard privacy;

  /// Keeps deleted messages and edit history while their switches are on.
  final MessageCapture capture;

  /// Applies the privacy extras to the guard and the capture.
  set privacySettings(PrivacySettings settings) {
    privacy.settings = settings;
    capture
      ..keepDeleted = settings.keepDeletedMessages
      ..keepEdits = settings.keepEditHistory;
  }

  /// Contacts and the users TDLib has sent.
  final ContactsController contacts;

  /// Group and channel administration.
  final ChatManagement management;
  final LinkResolver links;

  /// The proxies TDLib can connect through.
  final ProxyController proxies;
  final _errors = StreamController<Object>.broadcast(sync: true);
  final _closedElsewhere = Completer<void>();
  StreamSubscription<AuthorizationStage>? _stageSubscription;
  Future<void>? _firstReconcile;
  var _disposed = false;

  /// Creates and starts a session around an already-created TDLib instance.
  ///
  /// This entry point keeps library discovery and secure-key retrieval in the
  /// platform layer while making the state transition behavior testable.
  static Future<TelegramSession> attach(
    td.Td tdlib, {
    required TdlibParameters parameters,
    PrivacySettings privacy = const PrivacySettings(),
    MessageStoreOpener? openStore,
  }) async {
    final client = tdlib.createClient();
    // First, so that nothing reaches TDLib before the filter is in place.
    final guard = PrivacyGuard(client, settings: privacy);
    // Next, so that it sees every message the app loads.
    final capture = MessageCapture(
      client,
      openStore: openStore,
      keepDeleted: privacy.keepDeletedMessages,
      keepEdits: privacy.keepEditHistory,
    );
    final authorization = AuthorizationController(client);
    final conversations = ConversationController(client);
    final files = FileController(client);
    final mentions = MentionSearch(client);
    final peers = PeerInfoController(client);
    final connection = ConnectionMonitor(client);
    final notifications = NotificationController(
      client,
      deliberately: guard.deliberately,
    );
    final contacts = ContactsController(client);
    final management = ChatManagement(client);
    final folders = ChatFoldersController(client);
    final session = TelegramSession._(
      tdlib: tdlib,
      authorization: authorization,
      chatLists: ChatListController(client),
      folders: folders,
      conversations: conversations,
      search: ChatSearch(client),
      chatSearch: ChatSearchController(client),
      files: files,
      notifications: notifications,
      stickers: StickerLibrary(client),
      peers: peers,
      account: AccountSettings(client),
      mentions: mentions,
      storage: StorageManager(client),
      connection: connection,
      privacy: guard,
      capture: capture,
      contacts: contacts,
      management: management,
      links: LinkResolver(client),
      proxies: ProxyController(client),
      initializer: TdlibInitializer(client, parameters: parameters),
    );
    session._stageSubscription = authorization.stages.listen(session._onStage);
    unawaited(
      authorization.closed.then((_) {
        if (session._disposed || authorization.logOutRequested) return;
        session._closedElsewhere.complete();
      }),
    );
    try {
      await conversations.start();
      await files.start();
      await mentions.start();
      await peers.start();
      await connection.start();
      await contacts.start();
      await management.start();
      await notifications.start();
      await folders.start();
      await authorization.start();
      // Sending the parameters is part of starting: a wrong database key or
      // bad credentials must fail the session, not leave the UI waiting.
      if (authorization.currentStage?.kind ==
          AuthorizationStageKind.tdlibParameters) {
        await session._firstReconcile;
      }
    } catch (error) {
      // TDLib closed the client while the session was starting, such as
      // when the session was terminated elsewhere just before launch.
      final closed =
          !authorization.logOutRequested &&
          (error is td.TdClientClosed || session._closedElsewhere.isCompleted);
      await session.dispose();
      if (closed) throw const SessionClosedElsewhere();
      rethrow;
    }
    return session;
  }

  /// Completes when TDLib closes the client without this app asking, such
  /// as when the session is terminated from another device: TDLib logs
  /// out, deletes the local data and closes. The client can't be used
  /// again; the app disposes the session and starts a new one, which
  /// begins at sign-in.
  Future<void> get closedElsewhere => _closedElsewhere.future;

  /// Initialization and synchronization errors suitable for user-facing UI.
  Stream<Object> get errors => _errors.stream;

  void _onStage(AuthorizationStage stage) {
    final reconcile = _reconcile(stage);
    _firstReconcile ??= reconcile;
    unawaited(
      reconcile.onError((Object error, StackTrace stackTrace) {
        if (!_errors.isClosed) _errors.add(error);
      }),
    );
  }

  Future<void> _reconcile(AuthorizationStage stage) async {
    if (_disposed) return;
    switch (stage.kind) {
      case AuthorizationStageKind.tdlibParameters:
        await _initializer.initialize();
      case AuthorizationStageKind.ready:
        await chatLists.start();
      case AuthorizationStageKind.phoneNumber:
      case AuthorizationStageKind.qrCode:
      case AuthorizationStageKind.code:
      case AuthorizationStageKind.password:
      case AuthorizationStageKind.closing:
      case AuthorizationStageKind.unavailable:
        break;
    }
  }

  /// Closes the client and receive loop owned by this session.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stageSubscription?.cancel();
    await chatLists.dispose();
    await conversations.dispose();
    await files.dispose();
    await mentions.dispose();
    await peers.dispose();
    await connection.dispose();
    await contacts.dispose();
    await management.dispose();
    await notifications.dispose();
    await folders.dispose();
    await authorization.dispose();
    await _tdlib.close();
    // After close: requests sent while the client closes stay filtered.
    await privacy.dispose();
    await capture.dispose();
    await _errors.close();
  }
}
