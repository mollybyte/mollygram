import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../commands/command_registry.dart';
import '../contacts/people_sheet.dart';
import '../downloads/downloads_sheet.dart';
import '../links/link_host.dart';
import '../links/link_router.dart' show workspaceShellKey;
import '../notifications/notification_service.dart';
import '../plugins/plugin_commands.dart';
import '../profile/new_chat_sheet.dart';
import '../profile/peer_info_host.dart';
import '../secret/secret_chat.dart';
import '../session/accounts.dart';
import '../session/connection_status_capsule.dart';
import '../session/providers.dart';
import '../settings/appearance.dart';
import '../settings/settings_window.dart';
import '../shared_media/message_jump.dart';
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

  List<PaletteCommand> _secretCommands() =>
      secretChatCommands(context, ref, _l10n);

  @override
  void initState() {
    super.initState();
    _registry
      ..register('app', _commands)
      ..register('accounts', _accountCommands)
      ..register('secret', _secretCommands)
      ..register('shell', _shellCommands)
      ..registerShortcuts('shell', _shellShortcuts)
      ..addListener(_keysChanged);
  }

  /// The user changed a key: the bindings are built again.
  void _keysChanged() => setState(() {});

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
      ..removeListener(_keysChanged)
      ..unregister('app', _commands)
      ..unregister('accounts', _accountCommands)
      ..unregister('secret', _secretCommands)
      ..unregister('shell', _shellCommands)
      ..unregisterShortcuts('shell', _shellShortcuts);
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
        id: 'app.downloads',
        title: l10n.downloads,
        keywords: [other.downloads],
        shortcut: downloadsShortcut,
        run: () => unawaited(showDownloadsSheet(context)),
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

  List<ShortcutAction> _shellShortcuts() => shellShortcutActions(_shellStrings);

  List<PaletteCommand> _shellCommands() =>
      shellCommands(ref.read(workspaceControllerProvider), _shellStrings);

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(workspaceControllerProvider);
    final directory = ref.watch(chatDirectoryProvider);
    ref.watch(pluginCommandsProvider);
    final keys = _registry.effectiveKeys();
    final home = CallbackShortcuts(
      // The shell binds its own shortcuts.
      bindings: {
        ..._registry.shortcutsOf('app'),
        ..._registry.shortcutsOf('plugins'),
      },
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
                chatAvatar: (chat, size) => PeerAvatar.chat(
                  name: chat.title,
                  size: size,
                  photo: ref
                      .read(telegramSessionProvider)
                      .requireValue
                      .chatLists
                      .store
                      .chat(chat.id)
                      ?.photo,
                ),
                shortcuts: (id) => keys[id]?.activator,
                sidebar: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Sidebar(
                          onSettings: _openSettings,
                          onPrivacy: () =>
                              _openSettings(privacyExtrasSectionId),
                          onNewMessage: _newMessage,
                        ),
                      ),
                      // Over the search field in the list column's title
                      // bar while the app is not connected; it takes no
                      // clicks.
                      const Positioned(
                        top: 0,
                        left: FolderRail.width + 12,
                        right: 84,
                        height: SidebarIsland.titleBarHeight,
                        child: ConnectionStatusCapsule(),
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
                // The chat's view scrolls to the message once it is open.
                onOpenMessage: (message, target) {
                  ref
                      .read(messageJumpProvider.notifier)
                      .request(message.chatId, message.messageId);
                  workspace.open(message.chatId, target: target);
                },
              ),
            ),
          ],
        ),
      ),
    );
    final settings = _settings;
    return SecretScreenProtection(
      child: LinkHost(
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
