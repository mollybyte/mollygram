import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/home/workspace_storage.dart';

void main() {
  test('a read waits for a clear that is still running', () async {
    final storage = _SlowStorage(saved: {'old': true});
    final saver = WorkspaceSaver(storage);

    final cleared = saver.clear();
    final read = saver.read();
    storage.release();
    await cleared;

    expect(await read, isNull);
    expect(storage.calls, ['clear', 'read']);
  });

  test('flush writes the waiting save at once', () async {
    final storage = MemoryWorkspaceStorage();
    final saver = WorkspaceSaver(storage, delay: const Duration(hours: 1))
      ..schedule({'a': 1})
      ..schedule({'a': 2});

    await saver.flush();
    expect(storage.saved, {'a': 2});
  });

  test('clear drops a waiting save', () async {
    final storage = MemoryWorkspaceStorage({'a': 1});
    final saver = WorkspaceSaver(storage, delay: const Duration(hours: 1))
      ..schedule({'a': 2});

    await saver.clear();
    await saver.flush();
    expect(storage.saved, isNull);
  });

  test('a failing write does not surface', () async {
    final saver = WorkspaceSaver(_FailingStorage())..schedule({'a': 1});
    await saver.flush();
  });
}

/// Holds its first operation until [release].
final class _SlowStorage implements WorkspaceStorage {
  _SlowStorage({this.saved});

  Object? saved;
  final calls = <String>[];
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<Object?> read() async {
    calls.add('read');
    return saved;
  }

  @override
  Future<void> write(Object? json) async {
    calls.add('write');
    saved = json;
  }

  @override
  Future<void> clear() async {
    calls.add('clear');
    await _gate.future;
    saved = null;
  }
}

final class _FailingStorage implements WorkspaceStorage {
  @override
  Future<Object?> read() async => null;

  @override
  Future<void> write(Object? json) async => throw StateError('disk full');

  @override
  Future<void> clear() async {}
}
