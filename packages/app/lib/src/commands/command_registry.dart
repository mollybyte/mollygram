import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

import '../settings/preferences.dart';
import 'shortcut_key.dart';

/// Lists the commands of one part of the app as they are right now: titles
/// follow the language, and some commands only exist in some layouts.
typedef CommandSource = Iterable<PaletteCommand> Function();

/// Lists the actions of one part of the app that take a key but are not
/// palette commands, such as the shell's "Go to tab 3".
typedef ShortcutSource = Iterable<ShortcutAction> Function();

/// An action a key can be bound to, as the shortcuts list shows it.
@immutable
class BindableAction {
  const BindableAction({
    required this.id,
    required this.owner,
    required this.title,
    this.defaultKey,
    this.keywords = const [],
  });

  final String id;

  /// Who registered it: `app`, `shell`, `plugins`.
  final String owner;
  final String title;
  final ShortcutKey? defaultKey;
  final List<String> keywords;
}

/// The app's commands in one place: the ⌘K palette lists them, shortcuts
/// and `tg://` links run them by id, and menus and plugins will too.
///
/// Parts of the app add a [CommandSource] under an owner name (`app`,
/// `shell`, a plugin id) instead of adding commands one by one, so a
/// command is always built from the current state.
///
/// It also keeps the keys: each command's own shortcut is its default,
/// [overrides] are the user's changes, and a default that another action
/// already uses is dropped, so a key never runs two things. It notifies
/// when the keys or the registered sources change.
class CommandRegistry extends ChangeNotifier {
  final _sources = <String, CommandSource>{};
  final _shortcutSources = <String, ShortcutSource>{};
  var _overrides = const <String, ShortcutKey?>{};

  /// [effectiveKeys] until the keys or the sources change.
  Map<String, ShortcutKey?>? _keys;
  var _notifyPending = false;
  var _disposed = false;

  /// A source came or went: listeners hear of it after the current build,
  /// since sources are often registered while widgets build.
  void _sourcesChanged() {
    _keys = null;
    if (_notifyPending) return;
    _notifyPending = true;
    scheduleMicrotask(() {
      _notifyPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Defaults for commands that come without one, by id, so they are
  /// bound as soon as their owner registers them.
  static Map<String, ShortcutKey> get extraDefaults => {
    // ⌃⌘1…⌃⌘3 switch accounts (Ctrl+Alt off macOS); ⌘1…⌘9 stay on the
    // tabs, as in a browser.
    for (final (n, key) in [
      (1, LogicalKeyboardKey.digit1),
      (2, LogicalKeyboardKey.digit2),
      (3, LogicalKeyboardKey.digit3),
    ])
      'app.account.$n': ShortcutKey(
        key,
        meta: usesCommandKey,
        control: true,
        alt: !usesCommandKey,
      ),
  };

  /// Adds the commands of [owner], replacing what it registered before.
  void register(String owner, CommandSource source) {
    _sources
      ..remove(owner)
      ..[owner] = source;
    _sourcesChanged();
  }

  /// Removes the commands of [owner]. With [source], only when that is
  /// still the registered one, so a widget that was replaced does not take
  /// its successor's commands away.
  void unregister(String owner, [CommandSource? source]) {
    if (source != null && !identical(_sources[owner], source)) return;
    if (_sources.remove(owner) != null) _sourcesChanged();
  }

  /// Adds actions of [owner] that take a key but are not commands.
  void registerShortcuts(String owner, ShortcutSource source) {
    _shortcutSources[owner] = source;
    _sourcesChanged();
  }

  void unregisterShortcuts(String owner, [ShortcutSource? source]) {
    if (source != null && !identical(_shortcutSources[owner], source)) return;
    if (_shortcutSources.remove(owner) != null) _sourcesChanged();
  }

  /// The user's keys by action id; null removes an action's key.
  Map<String, ShortcutKey?> get overrides => _overrides;

  set overrides(Map<String, ShortcutKey?> value) {
    if (mapEquals(value, _overrides)) return;
    _overrides = Map.unmodifiable(value);
    _keys = null;
    notifyListeners();
  }

  /// The id whose key a command uses: closing split view shares the key
  /// of opening it.
  static String keyIdOf(String commandId) =>
      shellShortcutAliases[commandId] ?? commandId;

  /// Every action that takes a key, the app's first, then other owners',
  /// the shell's, and plugins' last: an earlier one keeps a key that a
  /// later one also asks for.
  List<BindableAction> get actions {
    final byId = <String, BindableAction>{};
    for (final MapEntry(key: owner, value: source)
        in _shortcutSources.entries) {
      for (final action in source()) {
        byId.putIfAbsent(
          action.id,
          () => BindableAction(
            id: action.id,
            owner: owner,
            title: action.title,
            keywords: action.keywords,
            defaultKey: action.shortcut == null
                ? null
                : ShortcutKey.of(action.shortcut!),
          ),
        );
      }
    }
    for (final MapEntry(key: owner, value: source) in _sources.entries) {
      for (final command in source()) {
        final id = keyIdOf(command.id);
        final shortcut = command.shortcut;
        byId.putIfAbsent(
          id,
          () => BindableAction(
            id: id,
            owner: owner,
            title: command.title,
            keywords: [?command.subtitle, ...command.keywords],
            defaultKey: shortcut == null
                ? extraDefaults[id]
                : ShortcutKey.of(shortcut),
          ),
        );
      }
    }
    final list = byId.values.toList();
    // Stable: within an owner the registration order stays.
    mergeSort(list, compare: (a, b) => _rank(a).compareTo(_rank(b)));
    return list;
  }

  static int _rank(BindableAction action) => switch (action.owner) {
    'app' => 0,
    'shell' => 2,
    'plugins' => 3,
    _ when action.id.startsWith('plugin.') => 3,
    _ => 1,
  };

  /// The key of every action: the user's, or the default when no action
  /// before it took that key. A key the user gave an action that is not
  /// registered now (a plugin that is off) stays taken too.
  Map<String, ShortcutKey?> effectiveKeys() => _keys ??= _resolveKeys();

  Map<String, ShortcutKey?> _resolveKeys() {
    final actions = this.actions;
    final taken = <ShortcutKey>{for (final value in _overrides.values) ?value};
    return {
      for (final action in actions)
        action.id: _overrides.containsKey(action.id)
            ? _overrides[action.id]
            : switch (action.defaultKey) {
                final key? when taken.add(key) => key,
                _ => null,
              },
    };
  }

  /// The action other than [except] that has [key], if any, including
  /// one the user gave it that is not registered right now.
  String? whoUses(ShortcutKey key, {String? except}) {
    for (final keys in [effectiveKeys(), _overrides]) {
      for (final MapEntry(key: id, value: bound) in keys.entries) {
        if (id != except && bound == key) return id;
      }
    }
    return null;
  }

  /// Every command, in the order the owners registered, with the keys as
  /// the user set them. When two owners use the same id, the first one
  /// wins.
  List<PaletteCommand> get commands => _withKeys(_collect(_sources.values));

  /// The commands of [owner] alone.
  List<PaletteCommand> commandsOf(String owner) =>
      _withKeys(_collect([?_sources[owner]]));

  static List<PaletteCommand> _collect(Iterable<CommandSource> sources) {
    final seen = <String>{};
    return [
      for (final source in sources)
        for (final command in source())
          if (seen.add(command.id)) command,
    ];
  }

  List<PaletteCommand> _withKeys(List<PaletteCommand> commands) {
    final keys = effectiveKeys();
    return [for (final command in commands) _withKey(command, keys)];
  }

  PaletteCommand _withKey(
    PaletteCommand command,
    Map<String, ShortcutKey?> keys,
  ) {
    final id = keyIdOf(command.id);
    // A command that has no key in this layout (Close tab in split view,
    // where ⌘W closes the pane) shows none unless the user gave it one.
    final shows =
        command.shortcut != null ||
        _overrides.containsKey(id) ||
        extraDefaults.containsKey(id);
    return PaletteCommand(
      id: command.id,
      title: command.title,
      subtitle: command.subtitle,
      shortcut: shows ? keys[id]?.activator : null,
      glyph: command.glyph,
      keywords: command.keywords,
      run: command.run,
    );
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

/// Reads the keys saved in the preferences; unreadable ones are skipped.
Map<String, ShortcutKey?> decodeShortcutOverrides(Map<String, String?> saved) =>
    {
      for (final MapEntry(:key, :value) in saved.entries)
        if (value == null) key: null else key: ?ShortcutKey.decode(value),
    };

Map<String, String?> encodeShortcutOverrides(
  Map<String, ShortcutKey?> overrides,
) => {
  for (final MapEntry(:key, :value) in overrides.entries) key: value?.encode(),
};

/// The one registry of the window. It takes the user's keys from the
/// preferences, at start and on every change.
final commandRegistryProvider = Provider<CommandRegistry>((ref) {
  final registry = CommandRegistry();
  ref
    ..onDispose(registry.dispose)
    ..listen(
      preferencesProvider.select((p) => p.shortcuts),
      (_, saved) => registry.overrides = decodeShortcutOverrides(saved),
      fireImmediately: true,
    );
  return registry;
});
