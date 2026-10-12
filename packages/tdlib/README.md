# mollygram_tdlib

A thin binding to TDLib through the `td_json` JSON interface.

- `TdJsonFfi` calls the four C API functions via `dart:ffi`.
- `td_receive` runs in a background isolate, which also parses JSON into td_api objects; the UI isolate receives ready-made batches of events.
- `Td` holds one library instance and any number of clients (one per account); `TdClient.send` matches responses to requests by `@extra`.
- td_api types (sealed classes, `fromJson`/`toJson`) are generated from `schema/td_api.tl`.

```dart
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

final tdlib = await td.Td.start(libraryPath: 'libtdjson.dylib');
final client = tdlib.createClient();
client.updates.listen(print);
final state = await client.send(const td.GetAuthorizationState());
```

## TDLib version

The version and commit are pinned in [`tdlib.json`](tdlib.json). `Td.start` checks the loaded library's version against the schema and throws `TdVersionMismatch` if they differ.

To update TDLib:

1. Change `version` and `commit` in `tdlib.json`.
2. Run `dart run tool/generate.dart --fetch` to download the schema for that commit and regenerate `lib/src/generated/td_api.dart`.
3. Commit everything together. The [`tdlib.yml`](../../.github/workflows/tdlib.yml) workflow builds the new `libtdjson.dylib`.

CI checks that the generated code matches the schema.

## Tests

`dart test` runs everything against a fake `TdJson`. To test against the real library:

```sh
TDJSON_PATH=/path/to/libtdjson.dylib dart test test/native_test.dart
```
