// Generates lib/src/generated/td_api.dart from schema/td_api.tl.
//
//   dart run tool/generate.dart          from the pinned copy of the schema
//   dart run tool/generate.dart --fetch  first download the schema for the
//                                        commit in tdlib.json
//
// The TDLib version is changed only in tdlib.json, followed by --fetch and a
// commit of the schema together with the generated code.
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
