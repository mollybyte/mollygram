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
