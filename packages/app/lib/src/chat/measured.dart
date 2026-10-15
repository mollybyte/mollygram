import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lays out [child] and reports its size through [onSize] after every
/// layout that changes it, so a sibling can make room for it.
class Measured extends SingleChildRenderObjectWidget {
  const Measured({super.key, required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onSize);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _RenderMeasured).onSize = onSize;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    if (_reported == size) return;
    _reported = size;
    final reported = size;
    // Reported after the frame: a setState during layout is not allowed.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && _reported == reported) onSize(reported);
    });
  }
}
