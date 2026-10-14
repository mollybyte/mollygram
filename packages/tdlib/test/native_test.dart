// A check against the real libtdjson. Runs only if the path is set:
//   TDJSON_PATH=/path/to/libtdjson.dylib dart test test/native_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';
import 'package:test/test.dart';

void main() {
  final path = Platform.environment['TDJSON_PATH'];

  test(
    'libtdjson matches the schema and responds to a client',
    () async {
      final td = await Td.start(libraryPath: path);
      expect(
        td.execute(const GetLogVerbosityLevel()).verbosityLevel,
        Td.defaultLogVerbosity,
      );
      final version = td.execute(const GetOption(name: 'version'));
      expect((version as OptionValueString).value, tdlibVersion);

      final undecodable = <TdUndecodable>[];
      td.undecodable.listen(undecodable.add);
      final client = td.createClient();
      final updates = <TdObject>[];
      client.updates.listen(updates.add);
      final state = await client.send(const GetAuthorizationState());
      expect(state, isA<AuthorizationStateWaitTdlibParameters>());

      await td.close();
      // Startup updateOption and other updates decode without loss.
      expect(updates, isNotEmpty);
      expect(undecodable, isEmpty);
      expect(
        (updates.last as UpdateAuthorizationState).authorizationState,
        isA<AuthorizationStateClosed>(),
      );
    },
    skip: path == null ? 'TDJSON_PATH is not set' : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
