import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'settings/appearance.dart';
import 'settings/preferences.dart';

const _window = MethodChannel('mollygram/window');

/// Paints the native window behind Flutter in the frame's colour, so the
/// rounded corners and the edge pixels Flutter's surface leaves uncovered
/// match the window instead of showing the view's black backing.
class WindowBackground extends ConsumerStatefulWidget {
  const WindowBackground({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<WindowBackground> createState() => _WindowBackgroundState();
}

class _WindowBackgroundState extends ConsumerState<WindowBackground> {
  Color? _sent;
  bool _blurSent = false;

  void _sync(Color frame, bool blur) {
    // The blurred theme's frame is translucent: the window goes clear and
    // a native vibrancy view behind Flutter's surface supplies the blur.
    if (blur != _blurSent) {
      _blurSent = blur;
      _sent = null; // the frame's colour goes out again after the switch
      _window.invokeMethod<void>('setBlurred', blur).catchError((Object _) {});
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
    _sync(
      MgColors.of(context).frame,
      blurThemeActive(ref.watch(preferencesProvider)),
    );
    return widget.child;
  }
}
