import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Download priorities, 1 to 32: what the user is looking at goes first.
abstract final class DownloadPriority {
  /// Thumbnails and stickers: small, and many at once.
  static const int preview = 8;

  /// Photos, GIFs and video messages in the visible part of the chat.
  static const int media = 16;

  /// Something the user opened or asked for.
  static const int requested = 32;
}

/// Keeps the newest state of every file TDLib told us about, and starts
/// and cancels downloads.
///
/// A file arrives inside the message that has it and then changes through
/// `updateFile` as it downloads, so a widget asks [latest] for the current
/// state and listens to [changesOf].
final class FileController {
  FileController(this._client);

  final td.TdClient _client;
  final _files = <int, td.File>{};
  final _changes = StreamController<td.File>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;

  Future<void> start() async {
    _subscription ??= _client.updates.listen((update) {
      if (update is td.UpdateFile) _put(update.file);
    });
  }

  /// The newest known state of [file].
  td.File latest(td.File file) => _files[file.id] ?? file;

  /// Each new state of the file [fileId].
  Stream<td.File> changesOf(int fileId) =>
      _changes.stream.where((file) => file.id == fileId);

  /// Starts downloading [fileId] in the background. Progress arrives
  /// through [changesOf]; the returned file is the state right after the
  /// request.
  Future<td.File> download(
    int fileId, {
    int priority = DownloadPriority.media,
  }) async {
    final file = await _client.send(
      td.DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: 0,
        limit: 0,
        synchronous: false,
      ),
    );
    _put(file);
    return file;
  }

  /// Downloads [fileId] and completes with the finished file, or throws a
  /// [td.TdException] when TDLib can't download it.
  Future<td.File> downloadNow(
    int fileId, {
    int priority = DownloadPriority.requested,
  }) async {
    final file = await _client.send(
      td.DownloadFile(
        fileId: fileId,
        priority: priority,
        offset: 0,
        limit: 0,
        synchronous: true,
      ),
    );
    _put(file);
    return file;
  }

  /// Stops a download that is in progress.
  Future<void> cancel(int fileId) async {
    await _client.send(
      td.CancelDownloadFile(fileId: fileId, onlyIfPending: false),
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  void _put(td.File file) {
    _files[file.id] = file;
    if (!_changes.isClosed) _changes.add(file);
  }
}

/// The local path of [file] once it is fully downloaded, otherwise null.
String? downloadedPath(td.File file) =>
    file.local.isDownloadingCompleted && file.local.path.isNotEmpty
    ? file.local.path
    : null;
