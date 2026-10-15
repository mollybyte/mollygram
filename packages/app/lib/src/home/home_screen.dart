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
import '../settings/preferences.dart';
import '../settings/settings_window.dart';
import '../shared_media/message_jump.dart';
import '../window_drag_area.dart';
import 'chat_view.dart';
import 'sidebar.dart';
import 'workspace.dart';

/// The signed-in window: the tinted frame with the sidebar lying on it and
/// the workspace (tabs, one or two chat panes, each on its own [ChatCard],
/// the ⌘K palette). [GlassScope] gives all glass panels one shared
/// backdrop read.
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

  /// The sidebar's width while its edge is dragged; saved when let go.
  double? _dragWidth;

  void _resize(double dx) {
    final width =
        (_dragWidth ?? ref.read(preferencesProvider).sidebarWidth) + dx;
    setState(
      () => _dragWidth = width.clamp(
        Preferences.minSidebarWidth,
        Preferences.maxSidebarWidth,
      ),
    );
  }

  void _endResize() {
    final width = _dragWidth;
    if (width == null) return;
    ref
        .read(preferencesProvider.notifier)
        .update((p) => p.copyWith(sidebarWidth: width));
    setState(() => _dragWidth = null);
  }

  void _resetWidth() => ref
      .read(preferencesProvider.notifier)
      .update((p) => p.copyWith(sidebarWidth: Preferences.defaultSidebarWidth));

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
    final double sidebarWidth =
        _dragWidth ??
        ref.watch(preferencesProvider.select((p) => p.sidebarWidth));
    final home = CallbackShortcuts(
      // The shell binds its own shortcuts.
      bindings: {
        ..._registry.shortcutsOf('app'),
        ..._registry.shortcutsOf('plugins'),
      },
      child: GlassScope(
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: MgColors.of(context).frame),
            ),
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
                sidebar: Stack(
                  children: [
                    Positioned.fill(
                      child: Sidebar(
                        onSettings: _openSettings,
                        onPrivacy: () => _openSettings(privacyExtrasSectionId),
                        onNewMessage: _newMessage,
                      ),
                    ),
                    // Over the title bar row, between the window buttons and
                    // the actions, while the app is not connected; it takes
                    // no clicks.
                    const Positioned(
                      top: SidebarIsland.topInset,
                      left: 76,
                      right: 112,
                      height: SidebarIsland.titleBarHeight,
                      child: ConnectionStatusCapsule(),
                    ),
                  ],
                ),
                sidebarWidth: sidebarWidth,
                paneBuilder: (context, chat, focused) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    SidebarIsland.topInset,
                    SidebarIsland.topInset,
                    SidebarIsland.topInset,
                  ),
                  child: ChatCard(
                    background: const ChatCardBackground(),
                    // Another chat settles in with a short fade and rise.
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.012),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: chat == null
                          ? const _NoChat(key: ValueKey('none'))
                          : PeerInfoHost(
                              key: ValueKey(chat),
                              chatId: chat,
                              child: ChatView(chatId: chat),
                            ),
                    ),
                  ),
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
            // The sidebar's edge: dragged to resize, double-clicked to
            // bring back the default width.
            Positioned(
              left: sidebarWidth - 5,
              width: 8,
              top: SidebarIsland.topInset + SidebarIsland.titleBarHeight,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (d) => _resize(d.delta.dx),
                  onHorizontalDragEnd: (_) => _endResize(),
                  onHorizontalDragCancel: _endResize,
                  onDoubleTap: _resetWidth,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final settings = _settings;
    return SecretScreenProtection(
      child: LinkHost(
        contentLeft: sidebarWidth,
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
  const _NoChat({super.key});

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
