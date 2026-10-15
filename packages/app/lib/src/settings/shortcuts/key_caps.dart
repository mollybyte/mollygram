import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../commands/shortcut_key.dart';
import '../settings_style.dart';

/// A shortcut as raised key caps: ⌘ ⇧ K, each on its own cap.
class KeyCaps extends StatelessWidget {
  const KeyCaps(this.shortcut, {super.key});

  final ShortcutKey shortcut;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: shortcut.label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, cap) in shortcut.caps.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? const Color(0x1FFFFFFF) : const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: dark
                      ? const Color(0x1AFFFFFF)
                      : const Color(0x1F000000),
                  width: 0.5,
                ),
                // The cap's lower edge, as on a real key.
                boxShadow: [
                  BoxShadow(
                    color: dark
                        ? const Color(0x66000000)
                        : const Color(0x24000000),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                cap,
                style: mgTextStyle(
                  c,
                  size: MgType.small,
                  weight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Listens for the next shortcut: takes the keyboard while it is shown,
/// and gives up when it loses focus.
class ShortcutRecorder extends StatefulWidget {
  const ShortcutRecorder({
    super.key,
    required this.hint,
    required this.onKey,
    required this.onCancel,
  });

  final String hint;
  final ValueChanged<RecordedKey> onKey;
  final VoidCallback onCancel;

  @override
  State<ShortcutRecorder> createState() => _ShortcutRecorderState();
}

class _ShortcutRecorderState extends State<ShortcutRecorder> {
  final _focus = FocusNode(debugLabel: 'shortcut recorder');

  @override
  void initState() {
    super.initState();
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus && mounted) widget.onCancel();
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      // Every key is the shortcut being typed, not a command to run.
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) widget.onKey(recordKeyEvent(event));
        return KeyEventResult.handled;
      },
      child: AnimatedContainer(
        duration: settingsMotionOf(context),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: c.accent, width: 1),
        ),
        child: Text(
          widget.hint,
          style: mgTextStyle(c, size: MgType.small, color: c.accent),
        ),
      ),
    );
  }
}
