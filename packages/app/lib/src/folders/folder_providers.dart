import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../session/providers.dart';

/// The account's chat folders in their order, kept up to date.
final folderSummariesProvider = StreamProvider<List<ChatFolderSummary>>((ref) {
  final folders = ref.watch(telegramSessionProvider).requireValue.folders;
  final controller = StreamController<List<ChatFolderSummary>>();
  controller.add(folders.folders);
  final subscription = folders.changes.listen(
    (_) => controller.add(folders.folders),
  );
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});

/// The folders Telegram suggests that the account doesn't have yet.
final recommendedFoldersProvider =
    FutureProvider.autoDispose<List<RecommendedChatFolder>>((ref) {
      final folders = ref.watch(telegramSessionProvider).requireValue.folders;
      // A suggestion taken becomes a folder: the list is asked for again.
      final subscription = folders.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(() => unawaited(subscription.cancel()));
      return folders.recommended();
    });
