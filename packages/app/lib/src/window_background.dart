import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

const _window = MethodChannel('mollygram/window');

/// Paints the native window behind Flutter in the frame's colour, so the
/// rounded corners and the edge pixels Flutter's surface leaves uncovered
/// match the window instead of showing the view's black backing, and gives
/// the window the app's light or dark appearance: macOS draws the window's
/// outline for the appearance it has, so a light app in a dark system got
/// the dark outline.
class WindowBackground extends StatefulWidget {
  const WindowBackground({super.key, required this.child});

  final Widget child;

  @override
  State<WindowBackground> createState() => _WindowBackgroundState();
}

class _WindowBackgroundState extends State<WindowBackground> {
  Color? _sent;
  bool? _dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = MgColors.of(context);
    if (c.isDark != _dark) {
      _dark = c.isDark;
      _window
          .invokeMethod<void>('setAppearance', c.isDark)
          .catchError((Object _) {});
    }
    final frame = c.frame;
    if (frame == _sent) return;
    _sent = frame;
    _window
        .invokeMethod<void>('setBackgroundColor', frame.toARGB32())
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
