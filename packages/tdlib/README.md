# mollygram_tdlib

Тонкая привязка к TDLib через JSON-интерфейс `td_json`.

- `TdJsonFfi` вызывает четыре функции C API через `dart:ffi`.
- `td_receive` крутится в фоновом изоляте, там же разбираются JSON и объекты td_api, в UI-изолят приходят готовые пачки событий.
- `Td` держит одну библиотеку и любое число клиентов (по одному на аккаунт), `TdClient.send` сопоставляет ответы с запросами по `@extra`.
- Типы td_api (sealed-классы, `fromJson`/`toJson`) генерируются из `schema/td_api.tl`.

```dart
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

final tdlib = await td.Td.start(libraryPath: 'libtdjson.dylib');
final client = tdlib.createClient();
client.updates.listen(print);
final state = await client.send(const td.GetAuthorizationState());
```

## Версия TDLib

Версия и коммит закреплены в [`tdlib.json`](tdlib.json). `Td.start` сверяет версию загруженной библиотеки со схемой и бросает `TdVersionMismatch`, если они разные.

Чтобы обновить TDLib:

1. Поменять `version` и `commit` в `tdlib.json`.
2. `dart run tool/generate.dart --fetch` скачает схему этого коммита и перегенерирует `lib/src/generated/td_api.dart`.
3. Закоммитить всё вместе. Workflow [`tdlib.yml`](../../.github/workflows/tdlib.yml) соберёт новую `libtdjson.dylib`.

CI проверяет, что сгенерированный код совпадает со схемой.

## Тесты

`dart test` гоняет всё на подменённом `TdJson`. Проверка на настоящей библиотеке:

```sh
TDJSON_PATH=/path/to/libtdjson.dylib dart test test/native_test.dart
```
