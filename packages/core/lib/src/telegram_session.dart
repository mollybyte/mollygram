import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'authorization_controller.dart';
import 'authorization_stage.dart';
import 'chat_list_controller.dart';
import 'conversation_controller.dart';
import 'tdlib_initializer.dart';

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
    required this.conversations,
    required this._initializer,
  });

  final td.Td _tdlib;
  final TdlibInitializer _initializer;
  final AuthorizationController authorization;
  final ChatListController chatLists;
  final ConversationController conversations;
  final _errors = StreamController<Object>.broadcast(sync: true);
  StreamSubscription<AuthorizationStage>? _stageSubscription;
  var _disposed = false;

  /// Creates and starts a session around an already-created TDLib instance.
  ///
  /// This entry point keeps library discovery and secure-key retrieval in the
  /// platform layer while making the state transition behavior testable.
  static Future<TelegramSession> attach(
    td.Td tdlib, {
    required TdlibParameters parameters,
  }) async {
    final client = tdlib.createClient();
    final authorization = AuthorizationController(client);
    final conversations = ConversationController(client);
    final session = TelegramSession._(
      tdlib: tdlib,
      authorization: authorization,
      chatLists: ChatListController(client),
      conversations: conversations,
      initializer: TdlibInitializer(client, parameters: parameters),
    );
    session._stageSubscription = authorization.stages.listen(session._onStage);
    await conversations.start();
    await authorization.start();
    return session;
  }

  /// Initialization and synchronization errors suitable for user-facing UI.
  Stream<Object> get errors => _errors.stream;

  void _onStage(AuthorizationStage stage) {
    unawaited(
      _reconcile(stage).onError((Object error, StackTrace stackTrace) {
        _errors.add(error);
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
    await authorization.dispose();
    await _tdlib.close();
    await _errors.close();
  }
}
