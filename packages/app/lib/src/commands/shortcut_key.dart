import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

/// A key with its modifiers, comparable and storable, unlike a
/// [SingleActivator].
@immutable
final class ShortcutKey {
  const ShortcutKey(
    this.key, {
    this.meta = false,
    this.control = false,
    this.alt = false,
    this.shift = false,
  });

  /// [key] with the platform's primary modifier: ⌘ on macOS, Ctrl
  /// elsewhere.
  factory ShortcutKey.primary(LogicalKeyboardKey key, {bool shift = false}) =>
      ShortcutKey.of(primaryShortcut(key, shift: shift));

  factory ShortcutKey.of(SingleActivator activator) => ShortcutKey(
    activator.trigger,
    meta: activator.meta,
    control: activator.control,
    alt: activator.alt,
    shift: activator.shift,
  );

  /// Reads what [encode] wrote; null for anything else.
  static ShortcutKey? decode(Object? text) {
    if (text is! String) return null;
    final parts = text.split('+');
    final id = int.tryParse(parts.last);
    if (id == null) return null;
    final modifiers = parts.sublist(0, parts.length - 1).toSet();
    if (!modifiers.every(_modifierNames.contains)) return null;
    return ShortcutKey(
      LogicalKeyboardKey.findKeyByKeyId(id) ?? LogicalKeyboardKey(id),
      meta: modifiers.contains('meta'),
      control: modifiers.contains('control'),
      alt: modifiers.contains('alt'),
      shift: modifiers.contains('shift'),
    );
  }

  static const _modifierNames = {'meta', 'control', 'alt', 'shift'};

  final LogicalKeyboardKey key;
  final bool meta;
  final bool control;
  final bool alt;
  final bool shift;

  SingleActivator get activator => SingleActivator(
    key,
    meta: meta,
    control: control,
    alt: alt,
    shift: shift,
  );

  /// `meta+shift+107` for ⌘⇧K: the modifiers by name and the key's id.
  /// Ids are stable across versions; for keys whose character depends on
  /// the layout (signs, accented letters) the same key may read
  /// differently on another layout.
  String encode() => [
    if (meta) 'meta',
    if (control) 'control',
    if (alt) 'alt',
    if (shift) 'shift',
    '${key.keyId}',
  ].join('+');

  /// The key caps, modifiers first, in the order macOS menus use.
  List<String> get caps => usesCommandKey
      ? [
          if (control) '⌃',
          if (alt) '⌥',
          if (shift) '⇧',
          if (meta) '⌘',
          shortcutKeyLabel(key),
        ]
      : [
          if (control) 'Ctrl',
          if (alt) 'Alt',
          if (shift) 'Shift',
          if (meta) 'Win',
          shortcutKeyLabel(key),
        ];

  /// As menus write it: `⌘⇧K`, or `Ctrl+Shift+K` off macOS.
  String get label => shortcutLabel(activator);

  /// Reads a key as plugin manifests write it: `Mod+Shift+S` (Mod is ⌘
  /// on macOS, Ctrl elsewhere), `Cmd+K`, `Ctrl+Alt+P`, `⌥⌘K`. Null for
  /// anything it can't read.
  static ShortcutKey? parse(String text) {
    var rest = text.trim();
    var meta = false, control = false, alt = false, shift = false;
    // Glyphs come first and without separators.
    while (rest.length > 1 && '⌘⌃⌥⇧'.contains(rest[0])) {
      switch (rest[0]) {
        case '⌘':
          meta = true;
        case '⌃':
          control = true;
        case '⌥':
          alt = true;
        default:
          shift = true;
      }
      rest = rest.substring(1);
    }
    final parts = rest.split('+').map((p) => p.trim()).toList();
    if (parts.any((p) => p.isEmpty)) return null;
    for (final part in parts.sublist(0, parts.length - 1)) {
      switch (part.toLowerCase()) {
        case 'mod' || 'primary':
          if (usesCommandKey) {
            meta = true;
          } else {
            control = true;
          }
        case 'cmd' || 'command' || 'meta':
          meta = true;
        case 'ctrl' || 'control':
          control = true;
        case 'alt' || 'option' || 'opt':
          alt = true;
        case 'shift':
          shift = true;
        default:
          return null;
      }
    }
    final key = _keyNamed(parts.last);
    if (key == null) return null;
    return ShortcutKey(
      key,
      meta: meta,
      control: control,
      alt: alt,
      shift: shift,
    );
  }

  static LogicalKeyboardKey? _keyNamed(String name) {
    final lower = name.toLowerCase();
    final named = switch (lower) {
      'enter' || 'return' => LogicalKeyboardKey.enter,
      'tab' => LogicalKeyboardKey.tab,
      'space' => LogicalKeyboardKey.space,
      'esc' || 'escape' => LogicalKeyboardKey.escape,
      'backspace' => LogicalKeyboardKey.backspace,
      'delete' => LogicalKeyboardKey.delete,
      'up' => LogicalKeyboardKey.arrowUp,
      'down' => LogicalKeyboardKey.arrowDown,
      'left' => LogicalKeyboardKey.arrowLeft,
      'right' => LogicalKeyboardKey.arrowRight,
      _ => null,
    };
    if (named != null) return named;
    final function = RegExp(r'^f([1-9]|1[0-2])$').firstMatch(lower);
    if (function != null) {
      // F1…F12 have consecutive ids.
      return LogicalKeyboardKey.findKeyByKeyId(
        LogicalKeyboardKey.f1.keyId + int.parse(function[1]!) - 1,
      );
    }
    // Letters, digits and signs: the logical key is the character.
    if (lower.runes.length != 1 || lower.codeUnitAt(0) > 0x7e) return null;
    return LogicalKeyboardKey.findKeyByKeyId(lower.codeUnitAt(0));
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutKey &&
      other.key == key &&
      other.meta == meta &&
      other.control == control &&
      other.alt == alt &&
      other.shift == shift;

  @override
  int get hashCode => Object.hash(key, meta, control, alt, shift);

  @override
  String toString() => 'ShortcutKey($label)';
}

/// Keys the system keeps for itself: quitting, hiding, switching apps,
/// Spotlight. Binding them would never reach the app.
bool isReservedShortcut(ShortcutKey key) {
  bool only(LogicalKeyboardKey k, {bool meta = false, bool alt = false}) =>
      key.key == k &&
      key.meta == meta &&
      key.alt == alt &&
      !key.control &&
      !key.shift;
  if (usesCommandKey) {
    return only(LogicalKeyboardKey.keyQ, meta: true) ||
        only(LogicalKeyboardKey.keyH, meta: true) ||
        only(LogicalKeyboardKey.keyH, meta: true, alt: true) ||
        only(LogicalKeyboardKey.keyM, meta: true) ||
        only(LogicalKeyboardKey.tab, meta: true) ||
        only(LogicalKeyboardKey.space, meta: true) ||
        only(LogicalKeyboardKey.backquote, meta: true);
  }
  return only(LogicalKeyboardKey.f4, alt: true) ||
      only(LogicalKeyboardKey.tab, alt: true);
}

/// What a key press means to the shortcut recorder.
sealed class RecordedKey {
  const RecordedKey();
}

/// Only modifiers so far: the recorder keeps listening.
final class RecordingContinues extends RecordedKey {
  const RecordingContinues();
}

/// Esc: the shortcut stays as it was.
final class RecordingCancelled extends RecordedKey {
  const RecordingCancelled();
}

/// Delete or Backspace: the action loses its shortcut.
final class RecordingCleared extends RecordedKey {
  const RecordingCleared();
}

/// A letter, digit or sign without ⌘, ⌃ or ⌥, which would take the key
/// from typing.
final class RecordingNeedsModifier extends RecordedKey {
  const RecordingNeedsModifier();
}

final class RecordingDone extends RecordedKey {
  const RecordingDone(this.key);
  final ShortcutKey key;
}

final _modifierKeys = {
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
  LogicalKeyboardKey.capsLock,
  LogicalKeyboardKey.fn,
};

/// Keys that may be bound without a modifier: they type nothing.
final _standalone = {
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
};

/// Reads one key press with the modifiers held down at that moment.
RecordedKey recordKey(
  LogicalKeyboardKey key, {
  bool meta = false,
  bool control = false,
  bool alt = false,
  bool shift = false,
}) {
  if (_modifierKeys.contains(key)) return const RecordingContinues();
  final bare = !meta && !control && !alt;
  if (bare && !shift) {
    if (key == LogicalKeyboardKey.escape) return const RecordingCancelled();
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      return const RecordingCleared();
    }
  }
  if (bare && !_standalone.contains(key)) {
    return const RecordingNeedsModifier();
  }
  return RecordingDone(
    ShortcutKey(key, meta: meta, control: control, alt: alt, shift: shift),
  );
}

/// [recordKey] for an event, with the modifiers the keyboard holds now.
RecordedKey recordKeyEvent(KeyEvent event) {
  if (event is KeyUpEvent) return const RecordingContinues();
  final keyboard = HardwareKeyboard.instance;
  return recordKey(
    event.logicalKey,
    meta: keyboard.isMetaPressed,
    control: keyboard.isControlPressed,
    alt: keyboard.isAltPressed,
    shift: keyboard.isShiftPressed,
  );
}
