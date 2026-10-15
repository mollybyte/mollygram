import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

/// Lists the commands of one part of the app as they are right now: titles
/// follow the language, and some commands only exist in some layouts.
typedef CommandSource = Iterable<PaletteCommand> Function();

/// The app's commands in one place: the ⌘K palette lists them, shortcuts
/// and `tg://` links run them by id, and menus and plugins will too.
///
/// Parts of the app add a [CommandSource] under an owner name (`app`,
/// `shell`, a plugin id) instead of adding commands one by one, so a
/// command is always built from the current state.
class CommandRegistry {
  final _sources = <String, CommandSource>{};

  /// Adds the commands of [owner], replacing what it registered before.
  void register(String owner, CommandSource source) {
    _sources
      ..remove(owner)
      ..[owner] = source;
  }

  /// Removes the commands of [owner]. With [source], only when that is
  /// still the registered one, so a widget that was replaced does not take
  /// its successor's commands away.
  void unregister(String owner, [CommandSource? source]) {
    if (source != null && !identical(_sources[owner], source)) return;
    _sources.remove(owner);
  }

  /// Every command, in the order the owners registered. When two owners
  /// use the same id, the first one wins.
  List<PaletteCommand> get commands => _collect(_sources.values);

  /// The commands of [owner] alone.
  List<PaletteCommand> commandsOf(String owner) => _collect([?_sources[owner]]);

  static List<PaletteCommand> _collect(Iterable<CommandSource> sources) {
    final seen = <String>{};
    return [
      for (final source in sources)
        for (final command in source())
          if (seen.add(command.id)) command,
    ];
  }

  /// The command with [id], if one is available right now.
  PaletteCommand? find(String id) {
    for (final source in _sources.values) {
      for (final command in source()) {
        if (command.id == id) return command;
      }
    }
    return null;
  }

  /// Runs the command with [id]. Returns false when there is none, for
  /// example a link to a screen this build does not have.
  bool run(String id) {
    final command = find(id);
    if (command == null) return false;
    command.run();
    return true;
  }

  /// Keyboard bindings for the commands of [owner] that have a shortcut.
  Map<ShortcutActivator, VoidCallback> shortcutsOf(String owner) => {
    for (final command in commandsOf(owner)) ?command.shortcut: command.run,
  };
}

/// The one registry of the window.
final commandRegistryProvider = Provider<CommandRegistry>(
  (ref) => CommandRegistry(),
);
