import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

/// Builds quickjs-ng together with our src/mg_qjs.c wrapper into a single
/// dynamic library. The package has no other native dependencies.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final os = input.config.code.targetOS;
    const qjs = 'third_party/quickjs-ng';
    final builder = CBuilder.library(
      name: 'mg_qjs',
      assetName: 'src/native/bindings.dart',
      sources: [
        'src/mg_qjs.c',
        '$qjs/dtoa.c',
        '$qjs/libregexp.c',
        '$qjs/libunicode.c',
        '$qjs/quickjs.c',
      ],
      includes: [qjs],
      defines: {
        if (os == OS.windows) ...{
          'WIN32_LEAN_AND_MEAN': null,
          '_CRT_SECURE_NO_WARNINGS': null,
          '_WIN32_WINNT': '0x0601',
        } else
          '_GNU_SOURCE': null,
      },
      // Same flags as quickjs-ng's CMakeLists.txt: the engine relies on
      // unsigned char and on C11 atomics in MSVC.
      flags: os == OS.windows
          ? ['/experimental:c11atomics', '/J', '/wd4996']
          : ['-funsigned-char'],
      libraries: [if (os == OS.linux || os == OS.android) 'm'],
      std: os == OS.windows ? 'c11' : 'gnu11',
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.WARNING
        ..onRecord.listen((r) => print(r.message)),
    );
  });
}
