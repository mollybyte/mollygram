import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../commands/command_registry.dart';
import '../links/link_host.dart';
import '../notifications/notification_service.dart';
import '../notifications/notifications_page.dart';
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

/// A settings screen shown over the chats.
enum _Page { plugins, notifications }

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _Page? _page;
  late final CommandRegistry _registry = ref.read(commandRegistryProvider);
  late AppLocalizations _l10n;
  late ShellStrings _shellStrings;

  void _openPlugins() => setState(() => _page = _Page.plugins);

  void _openNotifications() => setState(() => _page = _Page.notifications);

  void _closePage() => setState(() => _page = null);

  @override
  void initState() {
    super.initState();
    _registry
      ..register('app', _commands)
      ..register('shell', _shellCommands);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    _shellStrings = ShellStrings.forLocale(
      Localizations.maybeLocaleOf(context),
    );
  }

  @override
  void dispose() {
    _registry
      ..unregister('app', _commands)
      ..unregister('shell', _shellCommands);
    super.dispose();
  }

  List<PaletteCommand> _commands() {
    final l10n = _l10n;
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
      PaletteCommand(
        id: 'app.notifications',
        title: l10n.notifications,
        keywords: [other.notifications, l10n.settings, other.settings],
        run: _openNotifications,
      ),
    ];
  }

  List<PaletteCommand> _shellCommands() =>
      shellCommands(ref.read(workspaceControllerProvider), _shellStrings);

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final directory = ref.watch(chatDirectoryProvider);
    final home = CallbackShortcuts(
      // The shell binds its own shortcuts.
      bindings: _registry.shortcutsOf('app'),
      child: GlassScope(
        child: Stack(
          children: [
            const Positioned.fill(child: Wallpaper()),
            Positioned.fill(
              child: WorkspaceShell(
                controller: workspace,
                directory: directory,
                commandSource: () => _registry.commands,
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
    final covered = _page != null;
    return LinkHost(
      child: NotificationsHost(
        child: Stack(
          children: [
            // The chats stay mounted under a settings screen, so drafts and
            // scroll positions survive opening it.
            Positioned.fill(
              child: ExcludeFocus(
                excluding: covered,
                child: TickerMode(enabled: !covered, child: home),
              ),
            ),
            if (_page case final page?)
              Positioned.fill(
                child: switch (page) {
                  _Page.plugins => PluginsPage(onClose: _closePage),
                  _Page.notifications => NotificationsPage(onClose: _closePage),
                },
              ),
          ],
        ),
      ),
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
