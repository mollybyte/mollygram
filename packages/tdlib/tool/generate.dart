// Генерирует lib/src/generated/td_api.dart из schema/td_api.tl.
//
//   dart run tool/generate.dart          из закреплённой копии схемы
//   dart run tool/generate.dart --fetch  сначала скачать схему для коммита
//                                        из tdlib.json
//
// Версия TDLib меняется только в tdlib.json, затем --fetch и коммит
// схемы вместе со сгенерированным кодом.
import 'dart:convert';
import 'dart:io';

import 'src/dart_emitter.dart';
import 'src/tl_schema.dart';

Future<void> main(List<String> args) async {
  final root = File.fromUri(Platform.script).parent.parent;
  final pin = jsonDecode(
    File('${root.path}/tdlib.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final version = pin['version']! as String;
  final commit = pin['commit']! as String;
  final schemaFile = File('${root.path}/schema/td_api.tl');

  if (args.contains('--fetch')) {
    final url = Uri.parse(
      'https://raw.githubusercontent.com/tdlib/td/$commit/td/generate/scheme/td_api.tl',
    );
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != 200) {
        stderr.writeln('GET $url: ${response.statusCode}');
        exit(1);
      }
      await response.pipe(schemaFile.openWrite());
    } finally {
      client.close();
    }
    stdout.writeln('Fetched td_api.tl for $commit');
  }

  final schema = parseTlSchema(schemaFile.readAsStringSync());
  final out = File('${root.path}/lib/src/generated/td_api.dart');
  out.writeAsStringSync(emitLibrary(schema, version: version, commit: commit));
  final format = await Process.run(Platform.resolvedExecutable, [
    'format',
    out.path,
  ]);
  if (format.exitCode != 0) {
    stderr.write(format.stderr);
    exit(format.exitCode);
  }
  stdout.writeln(
    'Generated ${schema.abstractClasses.length} classes, '
    '${schema.objects.length} objects, ${schema.functions.length} functions',
  );
}
