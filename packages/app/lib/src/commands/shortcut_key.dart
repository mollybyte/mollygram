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

  /// `meta+shift+107` for ⌘⇧K: the modifiers by name and the key's id,
  /// which stays the same across keyboard layouts and versions.
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
