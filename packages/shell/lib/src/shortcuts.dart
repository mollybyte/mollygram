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
  final key = _keyLabel(a.trigger);
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

String _keyLabel(LogicalKeyboardKey key) {
  final mac = usesCommandKey;
  if (key == LogicalKeyboardKey.enter) return mac ? '⏎' : 'Enter';
  if (key == LogicalKeyboardKey.tab) return mac ? '⇥' : 'Tab';
  if (key == LogicalKeyboardKey.arrowLeft) return '←';
  if (key == LogicalKeyboardKey.arrowRight) return '→';
  if (key == LogicalKeyboardKey.arrowUp) return '↑';
  if (key == LogicalKeyboardKey.arrowDown) return '↓';
  if (key == LogicalKeyboardKey.backslash) return r'\';
  return key.keyLabel.toUpperCase();
}
