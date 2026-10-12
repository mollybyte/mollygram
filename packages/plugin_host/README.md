# plugin_host

Песочница для JS-плагинов Mollygram на quickjs-ng: манифест, права, события, декларативный UI, лимиты памяти и времени, запуск в отдельном изоляте. Спецификация: [docs/plugins.md](../../docs/plugins.md).

```sh
git submodule update --init
flutter pub get   # из корня репозитория: пакет входит в pub workspace
cd packages/plugin_host && dart test
```

Нативная библиотека (quickjs-ng и `src/mg_qjs.c`) собирается build hook'ом при первом `dart test` или сборке приложения; нужен C-компилятор (Xcode, MSVC или clang/gcc).

Пересобрать пример после правки `example/transcribe/src/index.ts`:

```sh
cd example/transcribe && npx -p typescript@5.9 tsc -p .
```
