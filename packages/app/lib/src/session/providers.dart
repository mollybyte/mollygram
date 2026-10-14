import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

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
  final session = await ref
      .watch(telegramSessionLauncherProvider)
      .start(config);
  ref.onDispose(() => unawaited(session.dispose()));
  return session;
});

/// TDLib's current sign-in step.
final authorizationStageProvider = StreamProvider<AuthorizationStage>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  return _startWith(
    session.authorization.currentStage,
    session.authorization.stages,
  );
});

/// Sends what the user typed on the sign-in screen to TDLib.
final signInActionsProvider = Provider<SignInActions>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  return SessionSignInActions(session.authorization);
});

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
      if (!list.isMain) unawaited(chatLists.loadMore(list));
      return _startWith(
        chatLists.store.chatsFor(list),
        chatLists.changes.map((_) => chatLists.store.chatsFor(list)),
      );
    });

/// The chat open in the main pane.
final selectedChatProvider = NotifierProvider<SelectedChat, int?>(
  SelectedChat.new,
);

class SelectedChat extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int chatId) => state = chatId;
}

/// Text messages of one chat, newest first.
final conversationProvider =
    StreamProvider.family<List<ConversationMessage>, int>((ref, chatId) {
      final conversations = ref
          .watch(telegramSessionProvider)
          .requireValue
          .conversations;
      unawaited(conversations.loadHistory(chatId));
      return _startWith(
        conversations.store.messagesFor(chatId),
        conversations.changes.map(
          (_) => conversations.store.messagesFor(chatId),
        ),
      );
    });

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
