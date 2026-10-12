import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'icons.dart';
import 'theme.dart';

/// Серая монограмма, как .av в макете.
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.av1, c.av2],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
          height: 1,
        ),
      ),
    );
  }
}

/// Круглая кнопка 32 px с иконкой (.ib), подсветка при наведении.
class IconBtn extends StatefulWidget {
  const IconBtn(
    this.icon, {
    super.key,
    required this.tooltip,
    this.onTap,
    this.on = false,
    this.size = 17,
  });

  final String icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool on;
  final double size;

  @override
  State<IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<IconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = widget.on ? c.accent : (_hover ? c.fg : c.fg2);
    final bg = widget.on ? c.field : (_hover ? c.hover : Colors.transparent);
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap ?? () {},
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: MgIcon(widget.icon, size: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

const _window = MethodChannel('mollygram/window');

/// Пустое место шапки, за которое можно тащить окно (titlebar скрыт).
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
