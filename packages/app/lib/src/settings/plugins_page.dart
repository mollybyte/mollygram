import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The plugins list: the built-in plugins for now. Installing third-party
/// plugins and running them in the sandbox come with the plugins stage.
final pluginsControllerProvider = FutureProvider<PluginsController>((
  ref,
) async {
  final builtin = await loadBuiltinPlugins();
  final controller = PluginsController([for (final p in builtin) p.entry]);
  ref.onDispose(controller.dispose);
  return controller;
});

/// The plugins page of the settings: the plugin list and the selected
/// plugin, edge to edge in the content pane.
class PluginsPane extends ConsumerWidget {
  const PluginsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final controller = ref.watch(pluginsControllerProvider).value;
    if (controller == null) return ColoredBox(color: c.windowBackground);
    return PluginsScreen(
      controller: controller,
      locale: Localizations.localeOf(context).languageCode,
      brightness: c.brightness,
    );
  }
}
