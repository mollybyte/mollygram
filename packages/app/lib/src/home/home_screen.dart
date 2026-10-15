import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../commands/command_registry.dart';
import '../contacts/people_sheet.dart';
import '../links/link_host.dart';
import '../links/link_router.dart' show workspaceShellKey;
import '../notifications/notification_service.dart';
import '../plugins/plugin_commands.dart';
import '../privacy/ghost_mode_capsule.dart';
import '../profile/new_chat_sheet.dart';
import '../profile/peer_info_host.dart';
import '../session/accounts.dart';
import '../session/connection_status_capsule.dart';
import '../settings/appearance.dart';
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

  /// ⌘N (Ctrl+N off macOS): write to someone.
  static SingleActivator get newMessageShortcut =>
      primaryShortcut(LogicalKeyboardKey.keyN);

  /// ⌘, (Ctrl+, off macOS), the usual settings shortcut.
  static SingleActivator get settingsShortcut =>
      primaryShortcut(LogicalKeyboardKey.comma);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The section the settings opened on; null while they are closed.
  String? _settings;
  late final CommandRegistry _registry = ref.read(commandRegistryProvider);
  late AppLocalizations _l10n;
  late ShellStrings _shellStrings;

  void _openSettings([String section = accountSectionId]) =>
      setState(() => _settings = section);

  void _closeSettings() => setState(() => _settings = null);

  void _newMessage() => unawaited(showPeopleSheet(context));

  @override
  void initState() {
    super.initState();
    _registry
      ..register('app', _commands)
      ..register('accounts', _accountCommands)
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
      ..unregister('accounts', _accountCommands)
      ..unregister('shell', _shellCommands);
    super.dispose();
  }

  List<PaletteCommand> _accountCommands() => accountCommands(
    ref.read(accountsProvider).value,
    _l10n,
    (slot) => unawaited(ref.read(accountsProvider.notifier).switchTo(slot)),
  );

  List<PaletteCommand> _commands() {
    final l10n = _l10n;
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
        id: 'app.newMessage',
        title: l10n.newMessage,
        keywords: [other.newMessage],
        shortcut: HomeScreen.newMessageShortcut,
        run: _newMessage,
      ),
      ...newChatCommands(() => context, l10n, other),
      PaletteCommand(
        id: 'app.contacts',
        title: l10n.contacts,
        keywords: [other.contacts],
        run: () =>
            unawaited(showPeopleSheet(context, mode: PeopleSheetMode.contacts)),
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

  List<PaletteCommand> _shellCommands() =>
      shellCommands(ref.read(workspaceControllerProvider), _shellStrings);

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final directory = ref.watch(chatDirectoryProvider);
    ref.watch(pluginCommandsProvider);
    final home = CallbackShortcuts(
      // The shell binds its own shortcuts.
      bindings: _registry.shortcutsOf('app'),
      child: GlassScope(
        child: Stack(
          children: [
            const Positioned.fill(child: ChatBackground()),
            Positioned.fill(
              child: WorkspaceShell(
                key: workspaceShellKey,
                controller: workspace,
                directory: directory,
                commandSource: () => _registry.commands,
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
    return LinkHost(
      contentLeft: SidebarIsland.width + 16,
      covered: settings != null,
      child: NotificationsHost(
        child: Stack(
          children: [
            // The chats stay mounted under the settings, so drafts and
            // scroll positions survive opening them.
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
