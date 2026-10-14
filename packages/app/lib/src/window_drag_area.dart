import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _window = MethodChannel('mollygram/window');

/// Empty header space that drags the window (the title bar is hidden).
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _window.invokeMethod('startDrag').ignore(),
      onDoubleTap: () => _window.invokeMethod('zoom').ignore(),
      child: child ?? const SizedBox.expand(),
    );
  }
}
