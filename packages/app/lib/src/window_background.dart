import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'settings/appearance.dart';
import 'settings/preferences.dart';

const _window = MethodChannel('mollygram/window');

/// Paints the native window behind Flutter in the frame's colour, so the
/// rounded corners and the edge pixels Flutter's surface leaves uncovered
/// match the window instead of showing the view's black backing, and gives
/// the window the app's light or dark appearance: macOS draws the window's
/// outline for the appearance it has, so a light app in a dark system got
/// the dark outline.
class WindowBackground extends ConsumerStatefulWidget {
  const WindowBackground({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowBackground> createState() => _WindowBackgroundState();
}

class _WindowBackgroundState extends ConsumerState<WindowBackground> {
  Color? _sent;
  bool? _dark;
  bool _blurSent = false;

  void _sync(Color frame, bool dark, bool blur) {
    // The blurred theme's frame is translucent: the window goes clear and
    // a native vibrancy view behind Flutter's surface supplies the blur.
    if (blur != _blurSent) {
      _blurSent = blur;
      // The frame's colour and the appearance go out again after the switch.
      _sent = null;
      _dark = null;
      _window.invokeMethod<void>('setBlurred', blur).catchError((Object _) {});
    }
    if (dark != _dark) {
      _dark = dark;
      _window
          .invokeMethod<void>('setAppearance', dark)
          .catchError((Object _) {});
    }
    final opaque = blur ? frame.withValues(alpha: 1) : frame;
    if (opaque == _sent) return;
    _sent = opaque;
    _window
        .invokeMethod<void>('setBackgroundColor', opaque.toARGB32())
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    _sync(c.frame, c.isDark, blurThemeActive(ref.watch(preferencesProvider)));
    return widget.child;
  }
}
