import 'dart:io';

import 'manifest.dart';

/// The maximum size of a plugin's code. Anything larger usually means
/// something unnecessary got bundled in.
const maxSourceBytes = 2 << 20;

/// A plugin on disk: a folder with `manifest.yaml` and one bundled JS file.
final class PluginBundle {
  PluginBundle._(this.directory, this.manifest, this.source);

  final Directory directory;
  final PluginManifest manifest;
  final String source;

  static Future<PluginBundle> load(Directory directory) async {
    final manifestFile = File('${directory.path}/manifest.yaml');
    if (!await manifestFile.exists()) {
      throw ManifestException(['no manifest.yaml in ${directory.path}']);
    }
    final manifest = PluginManifest.parse(await manifestFile.readAsString());
    final root = await directory.resolveSymbolicLinks();
    final main = File('${directory.path}/${manifest.main}');
    if (!await main.exists()) {
      throw ManifestException(['file ${manifest.main} not found']);
    }
    // A link pointing outside the plugin folder is an error.
    final resolved = await main.resolveSymbolicLinks();
    if (!resolved.startsWith('$root${Platform.pathSeparator}')) {
      throw ManifestException(['${manifest.main} points outside the plugin']);
    }
    if (await main.length() > maxSourceBytes) {
      throw ManifestException(['${manifest.main} is larger than 2 MB']);
    }
    return PluginBundle._(directory, manifest, await main.readAsString());
  }
}
