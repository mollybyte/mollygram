import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:plugin_host/plugin_host.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('built-in plugins load from the app bundle', () async {
    final plugins = await loadBuiltinPlugins();
    expect(plugins.map((p) => p.entry.id), [
      'dev.mollygram.filters',
      'dev.mollygram.codehighlight',
    ]);
    for (final p in plugins) {
      expect(p.entry.builtIn, isTrue);
      expect(p.entry.active, isTrue);
      expect(p.source, contains('mg.on('));
    }
  });

  test('every built-in setting and option has a Russian label', () async {
    for (final p in await loadBuiltinPlugins()) {
      final texts = PluginsStrings.ru.ownPlugin(p.entry.id);
      expect(texts, isNotNull, reason: p.entry.id);
      for (final s in p.entry.manifest.settings) {
        expect(texts!.labels, contains(s.key), reason: s.key);
        if (s.type == SettingType.select) {
          for (final o in s.options) {
            expect(texts.labels, contains('${s.key}.${o.value}'));
          }
        }
      }
    }
  });
}
