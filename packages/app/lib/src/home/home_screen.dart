import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/connection_status_capsule.dart';
import '../settings/plugins_page.dart';
import '../window_drag_area.dart';
import 'chat_view.dart';
import 'sidebar.dart';
import 'workspace.dart';

/// The signed-in window: wallpaper, the floating sidebar and the workspace
/// (tabs, one or two chat panes, the ⌘K palette). [GlassScope] gives all
/// glass panels one shared backdrop read.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  /// ⌘, (Ctrl+, off macOS), the usual settings shortcut.
  static SingleActivator get pluginsShortcut =>
      primaryShortcut(LogicalKeyboardKey.comma);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _pluginsOpen = false;

  void _openPlugins() => setState(() => _pluginsOpen = true);

  void _closePlugins() => setState(() => _pluginsOpen = false);

  List<PaletteCommand> _commands(AppLocalizations l10n) {
    final other = lookupAppLocalizations(
      Locale(l10n.localeName == 'ru' ? 'en' : 'ru'),
    );
    return [
      PaletteCommand(
        id: 'app.plugins',
        title: l10n.plugins,
        keywords: [other.plugins, l10n.settings, other.settings],
        shortcut: HomeScreen.pluginsShortcut,
        run: _openPlugins,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(workspaceControllerProvider);
    final directory = ref.watch(chatDirectoryProvider);
    final home = CallbackShortcuts(
      bindings: {HomeScreen.pluginsShortcut: _openPlugins},
      child: GlassScope(
        child: Stack(
          children: [
            const Positioned.fill(child: Wallpaper()),
            Positioned.fill(
              child: WorkspaceShell(
                controller: workspace,
                directory: directory,
                commands: _commands(l10n),
                sidebar: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      Positioned.fill(child: Sidebar()),
                      // In the island's title bar, right of the window
                      // buttons.
                      Positioned(
                        top: 0,
                        left: 76,
                        right: 8,
                        height: SidebarIsland.titleBarHeight,
                        child: ConnectionStatusCapsule(),
                      ),
                    ],
                  ),
                ),
                sidebarWidth: SidebarIsland.width + 16,
                paneBuilder: (context, chat, focused) => chat == null
                    ? const _NoChat()
                    : ChatView(key: ValueKey(chat), chatId: chat),
                // Jumping to the message itself comes with the chat view's
                // history navigation; for now the chat opens.
                onOpenMessage: (message, target) =>
                    workspace.open(message.chatId, target: target),
              ),
            ),
          ],
        ),
      ),
    );
    return Stack(
      children: [
        // The chats stay mounted under the plugins screen, so drafts and
        // scroll positions survive opening it.
        Positioned.fill(
          child: ExcludeFocus(
            excluding: _pluginsOpen,
            child: TickerMode(enabled: !_pluginsOpen, child: home),
          ),
        ),
        if (_pluginsOpen)
          Positioned.fill(child: PluginsPage(onClose: _closePlugins)),
      ],
    );
  }
}

class _NoChat extends StatelessWidget {
  const _NoChat();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 52,
        child: WindowDragArea(),
      ),
      Center(child: DatePill(AppLocalizations.of(context).selectChat)),
    ],
  );
}
