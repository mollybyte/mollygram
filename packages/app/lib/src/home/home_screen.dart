import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../notifications/notification_service.dart';
import '../privacy/ghost_mode_capsule.dart';
import '../profile/peer_info_host.dart';
import '../session/connection_status_capsule.dart';
import '../settings/settings_window.dart';
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
  static SingleActivator get settingsShortcut =>
      primaryShortcut(LogicalKeyboardKey.comma);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The section the settings opened on; null while they are closed.
  String? _settings;

  void _openSettings([String section = accountSectionId]) =>
      setState(() => _settings = section);

  void _closeSettings() => setState(() => _settings = null);

  List<PaletteCommand> _commands(AppLocalizations l10n) {
    final other = lookupAppLocalizations(
      Locale(l10n.localeName == 'ru' ? 'en' : 'ru'),
    );
    return [
      PaletteCommand(
        id: 'app.settings',
        title: l10n.settings,
        keywords: [other.settings],
        shortcut: HomeScreen.settingsShortcut,
        run: _openSettings,
      ),
      PaletteCommand(
        id: 'app.plugins',
        title: l10n.plugins,
        keywords: [other.plugins, l10n.settings, other.settings],
        run: () => _openSettings('plugins'),
      ),
      PaletteCommand(
        id: 'app.notifications',
        title: l10n.notifications,
        keywords: [other.notifications, l10n.settings, other.settings],
        run: () => _openSettings('notifications'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(workspaceControllerProvider);
    final directory = ref.watch(chatDirectoryProvider);
    final home = CallbackShortcuts(
      bindings: {HomeScreen.settingsShortcut: _openSettings},
      child: GlassScope(
        child: Stack(
          children: [
            const Positioned.fill(child: Wallpaper()),
            Positioned.fill(
              child: WorkspaceShell(
                controller: workspace,
                directory: directory,
                commands: _commands(l10n),
                sidebar: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: Sidebar()),
                      // In the island's title bar, between the window
                      // buttons and the ghost.
                      const Positioned(
                        top: 0,
                        left: 76,
                        right: 48,
                        height: SidebarIsland.titleBarHeight,
                        child: ConnectionStatusCapsule(),
                      ),
                      // At the title bar's right end, clear of the
                      // centered connection status.
                      Positioned(
                        top: 0,
                        right: 12,
                        height: SidebarIsland.titleBarHeight,
                        child: GhostModeCapsule(
                          onTap: () => _openSettings(privacyExtrasSectionId),
                        ),
                      ),
                    ],
                  ),
                ),
                sidebarWidth: SidebarIsland.width + 16,
                paneBuilder: (context, chat, focused) => chat == null
                    ? const _NoChat()
                    : PeerInfoHost(
                        key: ValueKey(chat),
                        chatId: chat,
                        child: ChatView(chatId: chat),
                      ),
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
    final settings = _settings;
    return NotificationsHost(
      child: Stack(
        children: [
          // The chats stay mounted under the settings, so drafts and scroll
          // positions survive opening them.
          Positioned.fill(
            child: ExcludeFocus(
              excluding: settings != null,
              child: TickerMode(enabled: settings == null, child: home),
            ),
          ),
          if (settings != null)
            Positioned.fill(
              child: SettingsWindow(
                initialSection: settings,
                onClose: _closeSettings,
              ),
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
