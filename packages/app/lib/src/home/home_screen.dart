import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../notifications/notification_service.dart';
import '../notifications/notifications_page.dart';
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

  void _openPlugins() => setState(() => _page = _Page.plugins);

  void _openNotifications() => setState(() => _page = _Page.notifications);

  void _closePage() => setState(() => _page = null);

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
      PaletteCommand(
        id: 'app.notifications',
        title: l10n.notifications,
        keywords: [other.notifications, l10n.settings, other.settings],
        run: _openNotifications,
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
                  child: Sidebar(),
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
    return NotificationsHost(
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
