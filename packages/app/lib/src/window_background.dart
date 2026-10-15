import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

const _window = MethodChannel('mollygram/window');

/// Paints the native window behind Flutter in the frame's colour, so the
/// rounded corners and the edge pixels Flutter's surface leaves uncovered
/// match the window instead of showing the view's black backing.
class WindowBackground extends StatefulWidget {
  const WindowBackground({super.key, required this.child});

  final Widget child;

  @override
  State<WindowBackground> createState() => _WindowBackgroundState();
}

class _WindowBackgroundState extends State<WindowBackground> {
  Color? _sent;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final frame = MgColors.of(context).frame;
    if (frame == _sent) return;
    _sent = frame;
    _window
        .invokeMethod<void>('setBackgroundColor', frame.toARGB32())
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
