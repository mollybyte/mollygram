import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../window_drag_area.dart';

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

/// The plugins settings screen over the whole window. Esc or the back
/// button closes it.
class PluginsPage extends ConsumerWidget {
  const PluginsPage({super.key, required this.onClose});

  final VoidCallback onClose;

  /// Where the back button sits: in the detail pane, past the plugin list
  /// (`_Layout` in mollygram_plugins_ui puts the pane at 276).
  static const _backLeft = 276.0 + 10;

  /// The empty band at the top, over the list's room for the window
  /// buttons and above the plugin details.
  static const _titleBarHeight = 38.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final controller = ref.watch(pluginsControllerProvider).value;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: Focus(
        autofocus: true,
        child: ColoredBox(
          color: c.windowBackground,
          child: controller == null
              ? const SizedBox.expand()
              : Stack(
                  children: [
                    Positioned.fill(
                      child: PluginsScreen(
                        controller: controller,
                        locale: Localizations.localeOf(context).languageCode,
                        brightness: c.brightness,
                      ),
                    ),
                    // The title bar is hidden: this strip drags the window.
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: _titleBarHeight,
                      child: WindowDragArea(),
                    ),
                    Positioned(
                      top: 6,
                      left: _backLeft,
                      child: MgIconButton(
                        icon: MgIcons.back,
                        tooltip: l10n.back,
                        onPressed: onClose,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
