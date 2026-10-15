import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'file_controller.dart';

/// One file in the downloads list: what TDLib remembers about it and the
/// newest state of the file itself.
final class DownloadEntry {
  const DownloadEntry({
    required this.file,
    required this.message,
    required this.addDate,
    required this.completeDate,
    required this.isPaused,
  });

  final td.File file;

  /// The message the file came with, for its name and its chat.
  final td.Message message;

  /// When it was added, in seconds since the epoch.
  final int addDate;

  /// When it finished, in seconds since the epoch; 0 while it hasn't.
  final int completeDate;
  final bool isPaused;

  int get fileId => file.id;
  int get chatId => message.chatId;
  int get messageId => message.id;

  bool get isCompleted =>
      completeDate != 0 || file.local.isDownloadingCompleted;

  /// Downloading right now: neither finished nor paused.
  bool get isActive => !isCompleted && !isPaused;

  /// The size, or what TDLib expects it to be.
  int get expectedSize => file.size != 0 ? file.size : file.expectedSize;

  int get downloadedSize =>
      isCompleted ? expectedSize : file.local.downloadedSize;

  /// 0 to 1; 0 while the size is unknown.
  double get progress {
    final total = expectedSize;
    if (total <= 0) return isCompleted ? 1 : 0;
    return (downloadedSize / total).clamp(0, 1);
  }

  DownloadEntry copyWith({
    td.File? file,
    td.Message? message,
    int? addDate,
    int? completeDate,
    bool? isPaused,
  }) => DownloadEntry(
    file: file ?? this.file,
    message: message ?? this.message,
    addDate: addDate ?? this.addDate,
    completeDate: completeDate ?? this.completeDate,
    isPaused: isPaused ?? this.isPaused,
  );
}

/// How many downloads are in each state.
final class DownloadCounts {
  const DownloadCounts({this.active = 0, this.paused = 0, this.completed = 0});

  final int active;
  final int paused;
  final int completed;

  int get total => active + paused + completed;
  bool get isEmpty => total == 0;

  static DownloadCounts of(td.DownloadedFileCounts counts) => DownloadCounts(
    active: counts.activeCount,
    paused: counts.pausedCount,
    completed: counts.completedCount,
  );

  @override
  bool operator ==(Object other) =>
      other is DownloadCounts &&
      other.active == active &&
      other.paused == paused &&
      other.completed == completed;

  @override
  int get hashCode => Object.hash(active, paused, completed);
}

/// Bytes of the downloads that are not finished yet, from
/// `updateFileDownloads`.
final class DownloadTotals {
  const DownloadTotals({
    this.totalSize = 0,
    this.totalCount = 0,
    this.downloadedSize = 0,
  });

  final int totalSize;
  final int totalCount;
  final int downloadedSize;

  double get progress =>
      totalSize <= 0 ? 0 : (downloadedSize / totalSize).clamp(0, 1);

  @override
  bool operator ==(Object other) =>
      other is DownloadTotals &&
      other.totalSize == totalSize &&
      other.totalCount == totalCount &&
      other.downloadedSize == downloadedSize;

  @override
  int get hashCode => Object.hash(totalSize, totalCount, downloadedSize);
}

/// The downloads list as TDLib keeps it (`addFileToDownloads` and the
/// `updateFileDownload*` updates): what the user asked to download, active
/// first, with pausing, resuming, removing and clearing.
///
/// A file downloaded on its own (a visible photo) is not in the list; only
/// one the user asked for is, as in Telegram for macOS.
final class DownloadsController {
  DownloadsController(this._client, this._files);

  final td.TdClient _client;
  final FileController _files;

  /// Newest state by file id. Order comes from [entries].
  final _entries = <int, DownloadEntry>{};
  final _changes = StreamController<List<DownloadEntry>>.broadcast(sync: true);
  final _countChanges = StreamController<DownloadCounts>.broadcast(sync: true);
  final _totalChanges = StreamController<DownloadTotals>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  StreamSubscription<td.File>? _fileSubscription;
  Future<void>? _loading;
  var _loaded = false;
  var _counts = const DownloadCounts();
  var _totals = const DownloadTotals();

  /// Every entry, active first, then paused, then finished, newest first
  /// within each group.
  List<DownloadEntry> get entries {
    final list = _entries.values.toList();
    int rank(DownloadEntry e) => e.isActive ? 0 : (e.isPaused ? 1 : 2);
    list.sort((a, b) {
      final byState = rank(a).compareTo(rank(b));
      if (byState != 0) return byState;
      return b.addDate.compareTo(a.addDate);
    });
    return list;
  }

  /// Each new list, after any change to any entry.
  Stream<List<DownloadEntry>> get changes => _changes.stream;

  DownloadCounts get counts => _counts;
  Stream<DownloadCounts> get countChanges => _countChanges.stream;

  DownloadTotals get totals => _totals;
  Stream<DownloadTotals> get totalChanges => _totalChanges.stream;

  /// Whether [load] has run once; the counts arrive with the first update
  /// even before.
  bool get isLoaded => _loaded;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
    _fileSubscription ??= _files.changes.listen(_onFile);
  }

  /// Reads the list from TDLib, once; further calls wait for the same read.
  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    var offset = '';
    DownloadCounts? counts;
    do {
      final found = await _client.send(
        td.SearchFileDownloads(
          query: '',
          onlyActive: false,
          onlyCompleted: false,
          offset: offset,
          limit: 100,
        ),
      );
      counts = DownloadCounts.of(found.totalCounts);
      for (final item in found.files) {
        _entries[item.fileId] = _entryOf(item);
      }
      offset = found.nextOffset;
    } while (offset.isNotEmpty);
    _loaded = true;
    _setCounts(counts);
    _emit();
  }

  /// Adds [fileId] from the message to the list and starts downloading it
  /// at [priority]. A file already in the list is resumed.
  Future<td.File> add(
    int fileId, {
    required int chatId,
    required int messageId,
    int priority = DownloadPriority.requested,
  }) async {
    final file = await _client.send(
      td.AddFileToDownloads(
        fileId: fileId,
        chatId: chatId,
        messageId: messageId,
        priority: priority,
      ),
    );
    _files.put(file);
    return file;
  }

  Future<void> pause(int fileId) => _setPaused(fileId, true);

  Future<void> resume(int fileId) => _setPaused(fileId, false);

  Future<void> _setPaused(int fileId, bool paused) async {
    await _client.send(
      td.ToggleDownloadIsPaused(fileId: fileId, isPaused: paused),
    );
  }

  Future<void> pauseAll() => _setAllPaused(true);

  Future<void> resumeAll() => _setAllPaused(false);

  Future<void> _setAllPaused(bool paused) async {
    await _client.send(td.ToggleAllDownloadsArePaused(arePaused: paused));
  }

  /// Takes [fileId] off the list. The file stays in the cache unless
  /// [deleteFromCache]; an unfinished download is cancelled either way.
  Future<void> remove(int fileId, {bool deleteFromCache = false}) async {
    await _client.send(
      td.RemoveFileFromDownloads(
        fileId: fileId,
        deleteFromCache: deleteFromCache,
      ),
    );
    // TDLib confirms with updateFileRemovedFromDownloads; dropped here too,
    // so the list reacts at once.
    if (_entries.remove(fileId) != null) _emit();
  }

  /// Clears the finished downloads, or every download when [onlyCompleted]
  /// is false (unfinished ones are cancelled).
  Future<void> clear({bool onlyCompleted = true}) async {
    await _client.send(
      td.RemoveAllFilesFromDownloads(
        onlyActive: false,
        onlyCompleted: onlyCompleted,
        deleteFromCache: false,
      ),
    );
    _entries.removeWhere((_, e) => !onlyCompleted || e.isCompleted);
    _emit();
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _fileSubscription?.cancel();
    await _changes.close();
    await _countChanges.close();
    await _totalChanges.close();
  }

  DownloadEntry _entryOf(td.FileDownload item) {
    final known = _entries[item.fileId];
    final file = known?.file ?? _files.latestById(item.fileId);
    return DownloadEntry(
      file: file ?? _fileOfMessage(item.message, item.fileId) ?? _stub(item),
      message: item.message,
      addDate: item.addDate,
      completeDate: item.completeDate,
      isPaused: item.isPaused,
    );
  }

  /// A file whose state has not reached us yet: only its id is known.
  static td.File _stub(td.FileDownload item) => td.File(
    id: item.fileId,
    size: 0,
    expectedSize: 0,
    local: const td.LocalFile(
      path: '',
      canBeDownloaded: true,
      canBeDeleted: false,
      isDownloadingActive: false,
      isDownloadingCompleted: false,
      downloadOffset: 0,
      downloadedPrefixSize: 0,
      downloadedSize: 0,
    ),
    remote: const td.RemoteFile(
      id: '',
      uniqueId: '',
      isUploadingActive: false,
      isUploadingCompleted: true,
      uploadedSize: 0,
    ),
  );

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateFileAddedToDownloads(:final fileDownload, :final counts):
        _entries[fileDownload.fileId] = _entryOf(fileDownload);
        _setCounts(DownloadCounts.of(counts));
        _emit();
      case td.UpdateFileDownload(
        :final fileId,
        :final completeDate,
        :final isPaused,
        :final counts,
      ):
        final entry = _entries[fileId];
        if (entry != null) {
          _entries[fileId] = entry.copyWith(
            completeDate: completeDate,
            isPaused: isPaused,
          );
        }
        _setCounts(DownloadCounts.of(counts));
        _emit();
      case td.UpdateFileRemovedFromDownloads(:final fileId, :final counts):
        _entries.remove(fileId);
        _setCounts(DownloadCounts.of(counts));
        _emit();
      case td.UpdateFileDownloads(
        :final totalSize,
        :final totalCount,
        :final downloadedSize,
      ):
        _totals = DownloadTotals(
          totalSize: totalSize,
          totalCount: totalCount,
          downloadedSize: downloadedSize,
        );
        if (!_totalChanges.isClosed) _totalChanges.add(_totals);
      default:
    }
  }

  void _onFile(td.File file) {
    final entry = _entries[file.id];
    if (entry == null) return;
    _entries[file.id] = entry.copyWith(file: file);
    _emit();
  }

  void _setCounts(DownloadCounts counts) {
    if (counts == _counts) return;
    _counts = counts;
    if (!_countChanges.isClosed) _countChanges.add(counts);
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(entries);
  }
}

/// The file of [message] with [fileId], when its content carries one.
td.File? _fileOfMessage(td.Message message, int fileId) {
  final candidates = switch (message.content) {
    td.MessageDocument(:final document) => [document.document],
    td.MessagePhoto(:final photo) => [for (final s in photo.sizes) s.photo],
    td.MessageVideo(:final video) => [video.video],
    td.MessageAnimation(:final animation) => [animation.animation],
    td.MessageAudio(:final audio) => [audio.audio],
    td.MessageVoiceNote(:final voiceNote) => [voiceNote.voice],
    td.MessageVideoNote(:final videoNote) => [videoNote.video],
    td.MessageSticker(:final sticker) => [sticker.sticker],
    _ => const <td.File>[],
  };
  for (final file in candidates) {
    if (file.id == fileId) return file;
  }
  return null;
}
