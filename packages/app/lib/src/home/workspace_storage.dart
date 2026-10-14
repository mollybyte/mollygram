import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Where the window layout (tabs, split panes) is kept between launches.
abstract interface class WorkspaceStorage {
  /// The saved layout as decoded JSON, or null when there is none.
  Future<Object?> read();

  Future<void> write(Object? json);

  /// Forgets the layout, for example when the account signs out.
  Future<void> clear();
}

final workspaceStorageProvider = Provider<WorkspaceStorage>(
  (ref) => FileWorkspaceStorage(),
);

/// `workspace.json` next to the TDLib database, which holds one account.
final class FileWorkspaceStorage implements WorkspaceStorage {
  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}workspace.json');
  }

  @override
  Future<Object?> read() async {
    final file = await _file();
    try {
      return jsonDecode(await file.readAsString());
    } on Object {
      // Missing or broken: start with an empty window.
      return null;
    }
  }

  @override
  Future<void> write(Object? json) async {
    final file = await _file();
    // Written next to the file and renamed, so a crash mid-write never
    // leaves half a layout behind.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

/// A [WorkspaceStorage] in memory, for tests.
final class MemoryWorkspaceStorage implements WorkspaceStorage {
  MemoryWorkspaceStorage([this.saved]);

  Object? saved;

  @override
  Future<Object?> read() async => saved;

  @override
  Future<void> write(Object? json) async => saved = json;

  @override
  Future<void> clear() async => saved = null;
}

final workspaceSaverProvider = Provider<WorkspaceSaver>(
  (ref) => WorkspaceSaver(ref.watch(workspaceStorageProvider)),
);

/// Runs [WorkspaceStorage] calls one after another and batches saves.
///
/// Ordering matters: a layout cleared on sign-out must be gone before the
/// next account reads it, and a late clear must not delete the new
/// account's layout. Saves wait [delay] (dragging the split divider changes
/// the layout on every frame); [flush] writes a waiting save right away,
/// for quitting.
final class WorkspaceSaver {
  WorkspaceSaver(
    this._storage, {
    this.delay = const Duration(milliseconds: 500),
  });

  final WorkspaceStorage _storage;
  final Duration delay;

  Future<void> _last = Future.value();
  Timer? _timer;
  Object? _pending;
  var _hasPending = false;

  Future<T> _run<T>(Future<T> Function() operation) {
    final result = _last.then((_) => operation());
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Object?> read() => _run(_storage.read);

  /// Saves [json] after [delay], replacing a save that is still waiting.
  void schedule(Object? json) {
    _pending = json;
    _hasPending = true;
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(flush()));
  }

  /// Writes the waiting save, if any, and completes when every earlier
  /// operation has finished. Never fails: a layout that can't be saved is
  /// not worth an error.
  Future<void> flush() {
    _timer?.cancel();
    if (!_hasPending) return _last;
    final json = _pending;
    _pending = null;
    _hasPending = false;
    return _run(() => _storage.write(json)).catchError((Object _) {});
  }

  /// Drops a waiting save and forgets the stored layout.
  Future<void> clear() {
    _timer?.cancel();
    _pending = null;
    _hasPending = false;
    return _run(_storage.clear).catchError((Object _) {});
  }
}
