/// The Mollygram window shell: chat tabs, split view and the ⌘K palette.
///
/// The layout is a [Workspace] (tabs, each with one or two panes) instead of
/// a route stack. The shell reads chats through [ChatDirectory], so it does
/// not depend on TDLib.
library;

export 'src/data/chat_directory.dart';
export 'src/l10n/shell_strings.dart';
export 'src/model/workspace.dart';
export 'src/palette/palette_search.dart';
export 'src/shortcuts.dart'
    show ShellShortcuts, primaryShortcut, shortcutLabel, usesCommandKey;
export 'src/widgets/command_palette.dart' show CommandPalette;
export 'src/widgets/tab_strip.dart' show TabStrip, tabTitle;
export 'src/widgets/workspace_shell.dart';
export 'src/widgets/workspace_view.dart';
