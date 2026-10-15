import 'package:flutter/services.dart';
import 'package:plugin_host/plugin_host.dart';

import 'controller.dart';

/// A plugin that ships with the app, loaded from plugin_host's assets.
final class BuiltinPlugin {
  const BuiltinPlugin(this.entry, this.source);

  final PluginEntry entry;

  /// The bundled JS to start in a `PluginWorker`.
  final String source;
}

/// Our own plugins: shown first, can be turned off but not uninstalled.
///
/// Translation is not among them: it is part of the chat itself, a bar
/// under the header that translates the whole conversation in place.
const builtinPluginDirs = ['filters', 'code_highlight'];

const _looks = {
  'filters': (glyph: 'F', color: Color(0xFFFF9F0A)),
  'code_highlight': (glyph: '{', color: Color(0xFF30A46C)),
};

Future<List<BuiltinPlugin>> loadBuiltinPlugins([AssetBundle? bundle]) async {
  final assets = bundle ?? rootBundle;
  return [
    for (final dir in builtinPluginDirs)
      await _load(assets, 'packages/plugin_host/builtin/$dir', dir),
  ];
}

Future<BuiltinPlugin> _load(AssetBundle assets, String path, String dir) async {
  final manifestSource = await assets.loadString('$path/manifest.yaml');
  final manifest = PluginManifest.parse(manifestSource);
  final source = await assets.loadString('$path/${manifest.main}');
  final look = _looks[dir];
  return BuiltinPlugin(
    PluginEntry(
      manifest: manifest,
      manifestSource: manifestSource.trim(),
      builtIn: true,
      installed: true,
      glyph: look?.glyph,
      color: look?.color,
    ),
    source,
  );
}
