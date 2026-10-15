import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the primary modifier is ⌘ (Apple platforms) or Ctrl.
bool get usesCommandKey =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// A shortcut with the platform's primary modifier: ⌘ on macOS, Ctrl
/// elsewhere.
SingleActivator primaryShortcut(
  LogicalKeyboardKey key, {
  bool shift = false,
  bool alt = false,
}) {
  final mac = usesCommandKey;
  return SingleActivator(key, meta: mac, control: !mac, shift: shift, alt: alt);
}

/// The window's keyboard shortcuts, in one place so the palette shows the
/// same keys that the shell handles.
abstract final class ShellShortcuts {
  static SingleActivator get palette =>
      primaryShortcut(LogicalKeyboardKey.keyK);
  static SingleActivator get newTab => primaryShortcut(LogicalKeyboardKey.keyT);
  static SingleActivator get close => primaryShortcut(LogicalKeyboardKey.keyW);
  static SingleActivator get split =>
      primaryShortcut(LogicalKeyboardKey.backslash);
  static SingleActivator get nextTab =>
      const SingleActivator(LogicalKeyboardKey.tab, control: true);
  static SingleActivator get previousTab =>
      const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true);
  static SingleActivator get focusLeft =>
      primaryShortcut(LogicalKeyboardKey.arrowLeft, alt: true);
  static SingleActivator get focusRight =>
      primaryShortcut(LogicalKeyboardKey.arrowRight, alt: true);

  static const _digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  /// ⌘1…⌘9 select tabs.
  static SingleActivator tab(int number) =>
      primaryShortcut(_digits[number - 1]);
}

/// A shortcut as it is written in menus: `⌘⇧T` on macOS, `Ctrl+Shift+T`
/// elsewhere.
String shortcutLabel(SingleActivator a) {
  final key = shortcutKeyLabel(a.trigger);
  if (usesCommandKey) {
    return [
      if (a.control) '⌃',
      if (a.alt) '⌥',
      if (a.shift) '⇧',
      if (a.meta) '⌘',
      key,
    ].join();
  }
  return [
    if (a.control) 'Ctrl',
    if (a.alt) 'Alt',
    if (a.shift) 'Shift',
    if (a.meta) 'Win',
    key,
  ].join('+');
}

/// The modifier label for ⌘⏎-style hints.
String get primaryModifierLabel => usesCommandKey ? '⌘' : 'Ctrl+';

/// The modifier label for ⌥⏎-style hints.
String get altModifierLabel => usesCommandKey ? '⌥' : 'Alt+';

/// How [key] is written on a key cap or in a menu.
String shortcutKeyLabel(LogicalKeyboardKey key) {
  final mac = usesCommandKey;
  if (key == LogicalKeyboardKey.enter) return mac ? '⏎' : 'Enter';
  if (key == LogicalKeyboardKey.tab) return mac ? '⇥' : 'Tab';
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.backslash) return r'\';
  if (key == LogicalKeyboardKey.escape) return mac ? '⎋' : 'Esc';
  if (key == LogicalKeyboardKey.backspace) return mac ? '⌫' : 'Backspace';
  if (key == LogicalKeyboardKey.delete) return mac ? '⌦' : 'Delete';
  if (key == LogicalKeyboardKey.space) return mac ? '␣' : 'Space';
  if (key == LogicalKeyboardKey.pageUp) return mac ? '⇞' : 'PgUp';
  if (key == LogicalKeyboardKey.pageDown) return mac ? '⇟' : 'PgDn';
  if (key == LogicalKeyboardKey.home) return mac ? '↖' : 'Home';
  if (key == LogicalKeyboardKey.end) return mac ? '↘' : 'End';
  // A key unknown to this Flutter version, say from a newer one's saved
  // settings, has no label.
  final label = key.keyLabel;
  if (label.isEmpty) return key.debugName ?? '?';
  return label.toUpperCase();
}
