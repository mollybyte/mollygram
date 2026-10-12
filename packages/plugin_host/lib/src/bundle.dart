import 'dart:io';

import 'manifest.dart';

/// Максимальный размер кода плагина. Больше обычно значит, что внутрь
/// затащили что-то лишнее.
const maxSourceBytes = 2 << 20;

/// Плагин на диске: папка с `manifest.yaml` и одним собранным JS-файлом.
final class PluginBundle {
  PluginBundle._(this.directory, this.manifest, this.source);

  final Directory directory;
  final PluginManifest manifest;
  final String source;

  static Future<PluginBundle> load(Directory directory) async {
    final manifestFile = File('${directory.path}/manifest.yaml');
    if (!await manifestFile.exists()) {
      throw ManifestException(['нет manifest.yaml в ${directory.path}']);
    }
    final manifest = PluginManifest.parse(await manifestFile.readAsString());
    final root = await directory.resolveSymbolicLinks();
    final main = File('${directory.path}/${manifest.main}');
    if (!await main.exists()) {
      throw ManifestException(['нет файла ${manifest.main}']);
    }
    // Ссылка наружу из папки плагина считается ошибкой.
    final resolved = await main.resolveSymbolicLinks();
    if (!resolved.startsWith('$root${Platform.pathSeparator}')) {
      throw ManifestException([
        '${manifest.main} указывает за пределы плагина',
      ]);
    }
    if (await main.length() > maxSourceBytes) {
      throw ManifestException(['${manifest.main} больше 2 МБ']);
    }
    return PluginBundle._(directory, manifest, await main.readAsString());
  }
}
