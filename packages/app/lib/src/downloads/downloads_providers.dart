import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../session/providers.dart';

Stream<T> _startWith<T>(T first, Stream<T> rest) async* {
  yield first;
  yield* rest;
}

/// The downloads list, loaded from TDLib the first time it is watched and
/// kept live after.
final downloadsProvider = StreamProvider<List<DownloadEntry>>((ref) {
  final downloads = ref.watch(telegramSessionProvider).requireValue.downloads;
  final controller = StreamController<List<DownloadEntry>>();
  final subscription = downloads.changes.listen(controller.add);
  unawaited(
    downloads
        .load()
        .then((_) => controller.add(downloads.entries))
        .catchError(controller.addError),
  );
  ref.onDispose(() {
    unawaited(subscription.cancel());
    unawaited(controller.close());
  });
  return _startWith(downloads.entries, controller.stream);
});

/// How many downloads are active, paused and finished.
final downloadCountsProvider = StreamProvider<DownloadCounts>((ref) {
  final downloads = ref.watch(telegramSessionProvider).requireValue.downloads;
  return _startWith(downloads.counts, downloads.countChanges);
});

/// Bytes done of bytes to go, over every unfinished download.
final downloadTotalsProvider = StreamProvider<DownloadTotals>((ref) {
  final downloads = ref.watch(telegramSessionProvider).requireValue.downloads;
  return _startWith(downloads.totals, downloads.totalChanges);
});
