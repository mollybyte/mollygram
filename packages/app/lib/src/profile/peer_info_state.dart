import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../home/workspace.dart';
import '../session/providers.dart';

/// What the info panel shows about one chat, kept current. Each time a
/// panel starts watching, the chat is loaded again, so the bio and the
/// member list are fresh.
final peerInfoProvider = StreamProvider.autoDispose.family<PeerInfo?, int>((
  ref,
  chatId,
) {
  final peers = ref.watch(telegramSessionProvider).requireValue.peers;
  final controller = StreamController<PeerInfo?>();
  final subscription = peers.changes.listen((_) {
    if (peers.info(chatId) case final info?) controller.add(info);
  });
  if (peers.info(chatId) case final info?) controller.add(info);
  unawaited(
    peers
        .load(chatId)
        .then<void>(
          (_) {
            if (!controller.isClosed) controller.add(peers.info(chatId));
          },
          onError: (Object error, StackTrace stack) {
            // What was loaded before still beats an error.
            if (!controller.isClosed && peers.info(chatId) == null) {
              controller.addError(error, stack);
            }
          },
        ),
  );
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// The chats whose info panel is open, in whichever pane shows them.
final peerInfoPanelsProvider = NotifierProvider<PeerInfoPanels, Set<int>>(
  PeerInfoPanels.new,
);

class PeerInfoPanels extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void open(int chatId) {
    if (!state.contains(chatId)) state = {...state, chatId};
  }

  void close(int chatId) {
    if (state.contains(chatId)) state = {...state}..remove(chatId);
  }

  void toggle(int chatId) =>
      state.contains(chatId) ? close(chatId) : open(chatId);

  /// Panes showing each chat; a split view can show one chat twice.
  final _hosts = <int, int>{};

  /// A pane started showing [chatId].
  void attach(int chatId) => _hosts[chatId] = (_hosts[chatId] ?? 0) + 1;

  /// A pane stopped showing [chatId]. When no pane shows it any more its
  /// panel closes, so opening the chat later does not bring back a panel
  /// nobody asked for.
  void detach(int chatId) {
    // The whole scope may be gone with the window.
    if (!ref.mounted) return;
    final left = (_hosts[chatId] ?? 1) - 1;
    if (left > 0) {
      _hosts[chatId] = left;
      return;
    }
    _hosts.remove(chatId);
    close(chatId);
  }
}

/// Shows [chatId] (bringing it forward when it is already open) with its
/// info panel open. For the palette, links and anything else that wants
/// to show a profile.
void openPeerInfo(WidgetRef ref, int chatId) {
  ref.read(workspaceControllerProvider).open(chatId);
  ref.read(peerInfoPanelsProvider.notifier).open(chatId);
}

/// Opens or closes the info panel of [chatId]; the chat header calls it.
void togglePeerInfo(WidgetRef ref, int chatId) =>
    ref.read(peerInfoPanelsProvider.notifier).toggle(chatId);
