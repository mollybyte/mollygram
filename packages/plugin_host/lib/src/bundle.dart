import 'dart:io';

import 'manifest.dart';

/// The maximum size of a plugin's code. Anything larger usually means
/// something unnecessary got bundled in.
const maxSourceBytes = 2 << 20;

/// A plugin on disk: a folder with `manifest.yaml` and one bundled JS file.
final class PluginBundle {
  PluginBundle._(
    this.directory,
    this.manifestSource,
    this.manifest,
    this.source,
  );

  final Directory directory;

  /// `manifest.yaml` as written, the same text [manifest] was parsed from.
  final String manifestSource;
  final PluginManifest manifest;
  final String source;

  static Future<PluginBundle> load(Directory directory) async {
    final manifestFile = File('${directory.path}/manifest.yaml');
    if (!await manifestFile.exists()) {
      throw ManifestException(['no manifest.yaml in ${directory.path}']);
    }
    final root = await directory.resolveSymbolicLinks();
    // A linked manifest must stay inside the plugin folder too.
    if (!_inside(await manifestFile.resolveSymbolicLinks(), root)) {
      throw ManifestException(['manifest.yaml points outside the plugin']);
    }
    final manifestSource = await manifestFile.readAsString();
    final manifest = PluginManifest.parse(manifestSource);
    final main = File('${directory.path}/${manifest.main}');
    if (!await main.exists()) {
      throw ManifestException(['file ${manifest.main} not found']);
    }
    // A link pointing outside the plugin folder is an error.
    final resolved = await main.resolveSymbolicLinks();
    if (!_inside(resolved, root)) {
      throw ManifestException(['${manifest.main} points outside the plugin']);
    }
    if (await main.length() > maxSourceBytes) {
      throw ManifestException(['${manifest.main} is larger than 2 MB']);
    }
    return PluginBundle._(
      directory,
      manifestSource,
      manifest,
      await main.readAsString(),
    );
  }

  static bool _inside(String path, String root) =>
      path.startsWith('$root${Platform.pathSeparator}');
}
