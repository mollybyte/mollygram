import 'package:flutter/widgets.dart';

import '../data/chat_directory.dart';
import '../l10n/shell_strings.dart';
import '../model/workspace.dart';
import '../palette/palette_search.dart';
import '../shortcuts.dart';
import 'command_palette.dart';
import 'tab_strip.dart';
import 'workspace_view.dart';

/// The window content: the sidebar, the tab strip, one or two chat panes,
/// the ⌘K palette and the window shortcuts.
class WorkspaceShell extends StatefulWidget {
  const WorkspaceShell({
    super.key,
    required this.controller,
    required this.directory,
    required this.paneBuilder,
    this.sidebar,
    this.sidebarWidth = 0,
    this.strings,
    this.commands = const [],
    this.commandSource,
    this.onOpenMessage,
    this.chatAvatar,
    this.shortcuts,
  });

  final WorkspaceController controller;
  final ChatDirectory directory;
  final PaneBuilder paneBuilder;

  /// The floating chat list. It owns its own insets and glass.
  final Widget? sidebar;

  /// Horizontal space reserved for [sidebar] on the left.
  final double sidebarWidth;

  /// Defaults to the language of the nearest [Localizations].
  final ShellStrings? strings;

  /// Commands from the rest of the app and from plugins, listed before the
  /// shell's own tab and split commands.
  final List<PaletteCommand> commands;

  /// Where the palette reads its commands each time it is built, such as
  /// the app's command registry. When set, it replaces [commands] and the
  /// shell's own commands, so it lists those itself (see [shellCommands]).
  final List<PaletteCommand> Function()? commandSource;

  final void Function(MessageHit message, OpenTarget target)? onOpenMessage;

  /// Draws a palette chat row's avatar; see [CommandPalette.chatAvatar].
  final Widget Function(ChatSummary chat, double size)? chatAvatar;

  /// The keys of the shell's actions (see [shellShortcutActions]) as the
  /// user set them. Without it the defaults apply.
  final ShortcutResolver? shortcuts;

  @override
  State<WorkspaceShell> createState() => WorkspaceShellState();
}

class WorkspaceShellState extends State<WorkspaceShell> {
  final FocusNode _focus = FocusNode(debugLabel: 'workspace');
  bool _paletteOpen = false;
  String _paletteQuery = '';

  bool get paletteOpen => _paletteOpen;

  /// Opens the palette, optionally with a prefix such as `>`.
  void openPalette([String query = '']) => setState(() {
    _paletteOpen = true;
    _paletteQuery = query;
  });

  void closePalette() {
    if (!_paletteOpen) return;
    setState(() => _paletteOpen = false);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  ShellStrings get _strings =>
      widget.strings ??
      ShellStrings.forLocale(Localizations.maybeLocaleOf(context));

  Map<ShortcutActivator, VoidCallback> _bindings() {
    final c = widget.controller;
    final resolve = widget.shortcuts;
    final actions = <String, VoidCallback>{
      'shell.palette': () => _paletteOpen ? closePalette() : openPalette(),
      'shell.newTab': c.newTab,
      'shell.closeTab': c.closeFocused,
      'shell.split': c.toggleSplit,
      'shell.swapPanes': c.swapPanes,
      'shell.nextTab': c.nextTab,
      'shell.previousTab': c.previousTab,
      'shell.closeOtherTabs': () => c.closeOtherTabs(c.value.active),
      'shell.focusLeft': () => c.focusPane(0),
      'shell.focusRight': () => c.focusPane(1),
      for (var n = 1; n <= 9; n++) 'shell.tab.$n': () => c.selectTabByNumber(n),
    };
    return {
      for (final action in shellShortcutActions(_strings))
        ?(resolve == null ? action.shortcut : resolve(action.id)):
            actions[action.id]!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    return CallbackShortcuts(
      bindings: _bindings(),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final workspace = widget.controller.value;
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (workspace.tabs.length > 1)
                  _DirectoryListener(
                    directory: widget.directory,
                    builder: (context) => TabStrip(
                      controller: widget.controller,
                      directory: widget.directory,
                      strings: strings,
                    ),
                  ),
                Expanded(
                  child: WorkspaceView(
                    controller: widget.controller,
                    paneBuilder: widget.paneBuilder,
                    strings: strings,
                  ),
                ),
              ],
            );
            return Stack(
              children: [
                Positioned.fill(left: widget.sidebarWidth, child: content),
                if (widget.sidebar case final sidebar?)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: widget.sidebarWidth,
                    child: sidebar,
                  ),
                if (_paletteOpen) ...[
                  // Catches clicks outside the palette. Transparent: the
                  // window is not dimmed.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: closePalette,
                    ),
                  ),
                  Positioned.fill(
                    left: widget.sidebarWidth,
                    child: _PalettePlacement(
                      child: CommandPalette(
                        directory: widget.directory,
                        commands:
                            widget.commandSource?.call() ??
                            [
                              ...widget.commands,
                              ...shellCommands(widget.controller, strings),
                            ],
                        strings: strings,
                        initialQuery: _paletteQuery,
                        onOpenChat: (chat, target) =>
                            widget.controller.open(chat, target: target),
                        onOpenMessage: widget.onOpenMessage,
                        chatAvatar: widget.chatAvatar,
                        onClose: closePalette,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Builds again when the directory is a [Listenable] and changes, so tab
/// titles follow chat renames.
class _DirectoryListener extends StatelessWidget {
  const _DirectoryListener({required this.directory, required this.builder});

  final ChatDirectory directory;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => switch (directory) {
    final Listenable listenable => ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => builder(context),
    ),
    _ => builder(context),
  };
}

/// Centers the palette over the chat area, 120 px from the top.
class _PalettePlacement extends StatelessWidget {
  const _PalettePlacement({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 32).clamp(
          0.0,
          CommandPalette.width,
        );
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: CommandPalette.top),
            child: SizedBox(width: width, child: child),
          ),
        );
      },
    );
  }
}

/// The shell's own palette commands for the current layout.
List<PaletteCommand> shellCommands(
  WorkspaceController controller,
  ShellStrings s,
) {
  final other = identical(s, ShellStrings.ru)
      ? ShellStrings.en
      : ShellStrings.ru;
  final w = controller.value;
  final split = w.activeTab.isSplit;
  final many = w.tabs.length > 1;
  return [
    if (!split)
      PaletteCommand(
        id: 'shell.split',
        title: s.cmdSplit,
        keywords: [other.cmdSplit],
        glyph: PaletteGlyph.split,
        shortcut: ShellShortcuts.split,
        run: controller.toggleSplit,
      )
    else ...[
      PaletteCommand(
        id: 'shell.closeSplit',
        title: s.cmdCloseSplit,
        keywords: [other.cmdCloseSplit],
        glyph: PaletteGlyph.split,
        shortcut: ShellShortcuts.split,
        run: controller.toggleSplit,
      ),
      PaletteCommand(
        id: 'shell.swapPanes',
        title: s.cmdSwapPanes,
        keywords: [other.cmdSwapPanes],
        glyph: PaletteGlyph.swap,
        run: controller.swapPanes,
      ),
    ],
    PaletteCommand(
      id: 'shell.newTab',
      title: s.cmdNewTab,
      keywords: [other.cmdNewTab],
      glyph: PaletteGlyph.tab,
      shortcut: ShellShortcuts.newTab,
      run: controller.newTab,
    ),
    if (many) ...[
      PaletteCommand(
        id: 'shell.nextTab',
        title: s.cmdNextTab,
        keywords: [other.cmdNextTab],
        glyph: PaletteGlyph.next,
        shortcut: ShellShortcuts.nextTab,
        run: controller.nextTab,
      ),
      PaletteCommand(
        id: 'shell.previousTab',
        title: s.cmdPreviousTab,
        keywords: [other.cmdPreviousTab],
        glyph: PaletteGlyph.previous,
        shortcut: ShellShortcuts.previousTab,
        run: controller.previousTab,
      ),
    ],
    PaletteCommand(
      id: 'shell.closeTab',
      title: s.cmdCloseTab,
      keywords: [other.cmdCloseTab],
      glyph: PaletteGlyph.closeTab,
      shortcut: split ? null : ShellShortcuts.close,
      run: () => controller.closeTab(controller.value.active),
    ),
    if (many)
      PaletteCommand(
        id: 'shell.closeOtherTabs',
        title: s.cmdCloseOtherTabs,
        keywords: [other.cmdCloseOtherTabs],
        glyph: PaletteGlyph.closeTab,
        run: () => controller.closeOtherTabs(controller.value.active),
      ),
  ];
}

/// Finds the key of an action by its id; null when it has none.
typedef ShortcutResolver = SingleActivator? Function(String id);

/// An action a key can be bound to, with the key it has by default.
@immutable
class ShortcutAction {
  const ShortcutAction({
    required this.id,
    required this.title,
    this.shortcut,
    this.keywords = const [],
  });

  final String id;
  final String title;
  final SingleActivator? shortcut;
  final List<String> keywords;
}

/// Palette commands that share the key of another action: closing split
/// view is the same key as opening it.
const shellShortcutAliases = {'shell.closeSplit': 'shell.split'};

/// Every action of the shell that takes a key, whatever the layout, in
/// the order a list of shortcuts shows them.
List<ShortcutAction> shellShortcutActions(ShellStrings s) {
  final other = identical(s, ShellStrings.ru)
      ? ShellStrings.en
      : ShellStrings.ru;
  ShortcutAction action(
    String id,
    String Function(ShellStrings s) title, [
    SingleActivator? shortcut,
  ]) => ShortcutAction(
    id: id,
    title: title(s),
    keywords: [title(other)],
    shortcut: shortcut,
  );
  return [
    action('shell.palette', (s) => s.palette, ShellShortcuts.palette),
    action('shell.newTab', (s) => s.cmdNewTab, ShellShortcuts.newTab),
    action('shell.closeTab', (s) => s.cmdCloseTab, ShellShortcuts.close),
    action('shell.closeOtherTabs', (s) => s.cmdCloseOtherTabs),
    action('shell.nextTab', (s) => s.cmdNextTab, ShellShortcuts.nextTab),
    action(
      'shell.previousTab',
      (s) => s.cmdPreviousTab,
      ShellShortcuts.previousTab,
    ),
    action('shell.split', (s) => s.cmdSplit, ShellShortcuts.split),
    action('shell.swapPanes', (s) => s.cmdSwapPanes),
    action('shell.focusLeft', (s) => s.cmdFocusLeft, ShellShortcuts.focusLeft),
    action(
      'shell.focusRight',
      (s) => s.cmdFocusRight,
      ShellShortcuts.focusRight,
    ),
    for (var n = 1; n <= 9; n++)
      action('shell.tab.$n', (s) => s.cmdTab(n), ShellShortcuts.tab(n)),
  ];
}
