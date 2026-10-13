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
const builtinPluginDirs = ['filters', 'translate'];

const _looks = {
  'filters': (glyph: 'F', color: Color(0xFFFF9F0A)),
  'translate': (glyph: 'A', color: Color(0xFF0A84FF)),
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
