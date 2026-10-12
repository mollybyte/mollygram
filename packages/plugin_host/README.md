# plugin_host

Sandbox for Mollygram JS plugins on quickjs-ng: manifest, permissions, events, declarative UI, memory and time limits, execution in a separate isolate. Specification: [docs/plugins.md](../../docs/plugins.md).

```sh
git submodule update --init
flutter pub get   # from the repository root: the package is part of the pub workspace
cd packages/plugin_host && dart test
```

The native library (quickjs-ng and `src/mg_qjs.c`) is built by a build hook on the first `dart test` or app build; a C compiler is required (Xcode, MSVC, or clang/gcc).

To rebuild the example after editing `example/transcribe/src/index.ts`:

```sh
cd example/transcribe && npx -p typescript@5.9 tsc -p .
```
