// A check against the real libmgcalls. Runs only if the path is set:
//   MGCALLS_PATH=/path/to/libmgcalls.dylib dart test test/native_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:mollygram_calls/mollygram_calls.dart';
import 'package:test/test.dart';

void main() {
  final path = Platform.environment['MGCALLS_PATH'];

  test('libmgcalls loads and reports the tgcalls engines tdesktop uses', () {
    final calls = MgCalls.open(path);
    // InstanceImpl, InstanceV2Impl and InstanceV2ReferenceImpl.
    expect(calls.versions, [
      '13.0.0',
      '12.0.0',
      '11.0.0',
      '10.0.0',
      '9.0.0',
      '8.0.0',
      '7.0.0',
      '5.0.0',
      '2.7.7',
    ]);
    expect(calls.maxLayer, 92);
  }, skip: path == null ? 'MGCALLS_PATH is not set' : false);
}
