// Проверка на настоящей libtdjson. Запускается, только если задан путь:
//   TDJSON_PATH=/path/to/libtdjson.dylib dart test test/native_test.dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:mollygram_tdlib/mollygram_tdlib.dart';
import 'package:test/test.dart';

void main() {
  final path = Platform.environment['TDJSON_PATH'];

  test(
    'libtdjson совпадает со схемой и отвечает клиенту',
    () async {
      final td = await Td.start(libraryPath: path);
      td.execute(const SetLogVerbosityLevel(newVerbosityLevel: 1));
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
      // Стартовые updateOption и прочие обновления разбираются без потерь.
      expect(updates, isNotEmpty);
      expect(undecodable, isEmpty);
      expect(
        (updates.last as UpdateAuthorizationState).authorizationState,
        isA<AuthorizationStateClosed>(),
      );
    },
    skip: path == null ? 'TDJSON_PATH не задан' : false,
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
