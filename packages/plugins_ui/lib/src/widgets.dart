import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'strings.dart';

const monoFamily = 'Menlo';
const monoFallback = [
  'SF Mono',
  'Consolas',
  'DejaVu Sans Mono',
  'Liberation Mono',
  'monospace',
];

const _ease = Cubic(0.23, 1, 0.32, 1);

/// The Telegram four-point gradient wallpaper behind the glass list.
class Wallpaper extends StatelessWidget {
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _WallpaperPainter(PluginsColors.of(context)));
}

class _WallpaperPainter extends CustomPainter {
  _WallpaperPainter(this.c);

  final PluginsColors c;

  // CSS radial-gradient(rx% ry% at x% y%, color 0, transparent 70%).
  static const _points = [
    (x: .12, y: .18, rx: .60, ry: .55),
    (x: .88, y: .12, rx: .55, ry: .55),
    (x: .82, y: .88, rx: .60, ry: .60),
    (x: .18, y: .90, rx: .55, ry: .60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.wallBase);
    // CSS paints the first gradient on top.
    for (var i = _points.length - 1; i >= 0; i--) {
      final p = _points[i];
      final color = c.wall[i];
      canvas.save();
      canvas.translate(size.width * p.x, size.height * p.y);
      canvas.scale(size.width * p.rx, size.height * p.ry);
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          1,
          [color, color.withValues(alpha: 0)],
          [0, .7],
        );
      canvas.drawCircle(Offset.zero, 1, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WallpaperPainter old) => old.c != c;
}

/// CSS saturate(190%) as a color matrix.
List<double> _saturate(double s) => [
  0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
  0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
  0, 0, 0, 1, 0, //
];

final ui.ImageFilter _glassFilter = ui.ImageFilter.compose(
  outer: ui.ColorFilter.matrix(_saturate(1.9)),
  inner: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30, tileMode: TileMode.clamp),
);

/// A glass island of the floating layer: blur 30, saturate 190%, a light
/// rim, inner glow and a top highlight.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final r = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(color: Color(0x0F000000), spreadRadius: .5),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: _glassFilter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.glass,
              borderRadius: r,
              border: Border.all(color: c.rim),
            ),
            child: Stack(
              children: [
                // The inner glow along the top edge.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: r,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.glow, c.glow.withValues(alpha: 0)],
                        stops: const [0, .08],
                      ),
                    ),
                  ),
                ),
                child,
                // The 1px top highlight.
                Positioned(
                  left: radius / 2,
                  right: radius / 2,
                  top: 0,
                  height: 1,
                  child: ColoredBox(color: c.hi),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales to 0.97 while pressed and shows a hover fill, like `.press`.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.label,
    this.hover,
    this.radius = 8,
    this.button = true,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? label;

  /// The fill under the pointer; null for none.
  final Color? hover;
  final double radius;
  final bool button;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  var _down = false;
  var _over = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.button,
      enabled: enabled,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onShowHoverHighlight: (v) => setState(() => _over = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => widget.onTap?.call(),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? .97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: _ease,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: _over && widget.hover != null
                    ? widget.hover
                    : const Color(0x00000000),
                borderRadius: BorderRadius.circular(widget.radius),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A macOS switch, 34×20.
class MgSwitch extends StatelessWidget {
  const MgSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    return Semantics(
      toggled: value,
      label: label,
      child: Pressable(
        button: false,
        radius: 10,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 34,
          height: 20,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? c.accent : c.off,
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: _ease,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 28 px push button: `.btn`.
class MgButton extends StatelessWidget {
  const MgButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final bg = primary
        ? c.accent
        : danger
        ? const Color(0x00000000)
        : c.field;
    final fg = primary
        ? const Color(0xFFFFFFFF)
        : danger
        ? PluginsColors.danger
        : c.fg;
    return Pressable(
      onTap: onTap,
      label: label,
      radius: 7,
      child: Container(
        height: 28,
        width: expand ? double.infinity : null,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: danger ? 0 : 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// A rounded square with the plugin's glyph.
class PluginIcon extends StatelessWidget {
  const PluginIcon({
    super.key,
    required this.glyph,
    required this.color,
    required this.size,
  });

  final String glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * .24),
      ),
      child: Text(
        glyph,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w700,
          fontSize: size * .45,
          height: 1,
        ),
      ),
    ),
  );
}

/// A grouped list like macOS System Settings: `.grp` with `.ln` rows.
class Group extends StatelessWidget {
  const Group({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: c.sep, spreadRadius: .5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: c.sep, width: .5)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: children[i],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A section caption: `.cap`.
class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: PluginsColors.of(context).fg2,
        ),
      ),
    ),
  );
}

/// A one-line text field on the `--field` fill.
class MgTextField extends StatefulWidget {
  const MgTextField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder,
    this.leading,
    this.semanticLabel,
    this.commitOnly = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? placeholder;
  final Widget? leading;
  final String? semanticLabel;

  /// Reports only on Enter and when focus leaves, not on every key.
  final bool commitOnly;

  @override
  State<MgTextField> createState() => _MgTextFieldState();
}

class _MgTextFieldState extends State<MgTextField> {
  late final _text = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && widget.commitOnly) _commit();
    });
  }

  @override
  void didUpdateWidget(MgTextField old) {
    super.didUpdateWidget(old);
    if (widget.value != _text.text && !_focus.hasFocus) {
      _text.text = widget.value;
    }
  }

  void _commit() {
    if (_text.text != widget.value) widget.onChanged(_text.text);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    final style = DefaultTextStyle.of(context).style
        .copyWith(fontSize: 13, color: c.fg);
    return Semantics(
      textField: true,
      label: widget.semanticLabel ?? widget.placeholder,
      child: GestureDetector(
        onTap: _focus.requestFocus,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: c.field,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (widget.placeholder != null)
                      ListenableBuilder(
                        listenable: _text,
                        builder: (context, _) => _text.text.isEmpty
                            ? ExcludeSemantics(
                                child: Text(
                                  widget.placeholder!,
                                  maxLines: 1,
                                  style: style.copyWith(color: c.fg2),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    EditableText(
                      controller: _text,
                      focusNode: _focus,
                      style: style,
                      cursorColor: c.accent,
                      backgroundCursorColor: c.fg2,
                      selectionColor: c.accent.withValues(alpha: .3),
                      maxLines: 1,
                      onChanged: widget.commitOnly ? null : widget.onChanged,
                      onSubmitted: (_) => _commit(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A macOS pop-up button: the current value and up and down chevrons.
class MgSelect extends StatefulWidget {
  const MgSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.label,
  });

  final String? value;
  final List<({String value, String label})> options;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  State<MgSelect> createState() => _MgSelectState();
}

class _MgSelectState extends State<MgSelect> {
  final _portal = OverlayPortalController();
  final _link = LayerLink();

  String get _current =>
      widget.options
          .where((o) => o.value == widget.value)
          .map((o) => o.label)
          .firstOrNull ??
      '';

  void _pick(String v) {
    _portal.hide();
    if (v != widget.value) widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _portal.hide,
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 4),
              child: _Menu(
                options: widget.options,
                value: widget.value,
                onPick: _pick,
                onClose: _portal.hide,
              ),
            ),
          ],
        ),
        child: Pressable(
          onTap: _portal.toggle,
          label: '${widget.label}: $_current',
          radius: 6,
          hover: c.hover,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_current, style: TextStyle(color: c.fg2)),
                const SizedBox(width: 4),
                CustomPaint(
                  size: const Size(9, 12),
                  painter: _ChevronsPainter(c.fg2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({
    required this.options,
    required this.value,
    required this.onPick,
    required this.onClose,
  });

  final List<({String value, String label})> options;
  final String? value;
  final ValueChanged<String> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = PluginsColors.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: FocusScope(
        autofocus: true,
        child: Container(
          constraints: const BoxConstraints(minWidth: 180, maxHeight: 320),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: c.sep, spreadRadius: .5),
              BoxShadow(
                color: c.dark
                    ? const Color(0x73000000)
                    : const Color(0x24000000),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final o in options)
                    Pressable(
                      onTap: () => onPick(o.value),
                      label: o.label,
                      radius: 5,
                      hover: c.hover,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: o.value == value
                                  ? CustomPaint(
                                      size: const Size(10, 8),
                                      painter: _CheckPainter(c.fg),
                                    )
                                  : null,
                            ),
                            Text(o.label),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _ChevronsPainter extends CustomPainter {
  _ChevronsPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _stroke(color, 1.4);
    canvas.drawPath(
      Path()
        ..moveTo(1.5, 4.5)
        ..lineTo(s.width / 2, 1.5)
        ..lineTo(s.width - 1.5, 4.5)
        ..moveTo(1.5, s.height - 4.5)
        ..lineTo(s.width / 2, s.height - 1.5)
        ..lineTo(s.width - 1.5, s.height - 4.5),
      p,
    );
  }

  @override
  bool shouldRepaint(_ChevronsPainter old) => old.color != color;
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) => canvas.drawPath(
    Path()
      ..moveTo(0.5, s.height * .55)
      ..lineTo(s.width * .38, s.height - .5)
      ..lineTo(s.width - .5, .5),
    _stroke(color, 1.6),
  );

  @override
  bool shouldRepaint(_CheckPainter old) => old.color != color;
}

/// The disclosure chevron of the "Manifest" section: rotates 90° when open.
class Disclosure extends StatelessWidget {
  const Disclosure({super.key, required this.open, required this.color});

  final bool open;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? .25 : 0,
    duration: const Duration(milliseconds: 160),
    curve: _ease,
    child: CustomPaint(
      size: const Size(10, 10),
      painter: _DisclosurePainter(color),
    ),
  );
}

class _DisclosurePainter extends CustomPainter {
  _DisclosurePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 24;
    canvas.drawPath(
      Path()
        ..moveTo(9 * k, 5 * k)
        ..lineTo(16 * k, 12 * k)
        ..lineTo(9 * k, 19 * k),
      _stroke(color, 3 * k),
    );
  }

  @override
  bool shouldRepaint(_DisclosurePainter old) => old.color != color;
}

/// The magnifier in the search field.
class SearchGlyph extends StatelessWidget {
  const SearchGlyph({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(13, 13),
    painter: _IconPainter(null, color, search: true),
  );
}

/// An 18 px line icon for an access row, drawn like the mockup's SVGs on a
/// 24-unit grid.
class AccessIconView extends StatelessWidget {
  const AccessIconView(this.icon, {super.key, required this.color});

  final AccessIcon icon;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(18, 18), painter: _IconPainter(icon, color));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, {this.search = false});

  final AccessIcon? icon;
  final Color color;
  final bool search;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final p = _stroke(color, search ? 2.2 : 1.8);
    Rect circle(double cx, double cy, double r) =>
        Rect.fromCircle(center: Offset(cx, cy), radius: r);
    if (search) {
      canvas.drawCircle(const Offset(11, 11), 7, p);
      canvas.drawLine(const Offset(20, 20), const Offset(16.5, 16.5), p);
      return;
    }
    switch (icon!) {
      case AccessIcon.messages:
        // M4 5h16v11H9l-5 4z
        canvas.drawPath(
          Path()
            ..moveTo(4, 5)
            ..lineTo(20, 5)
            ..lineTo(20, 16)
            ..lineTo(9, 16)
            ..lineTo(4, 20)
            ..close(),
          p,
        );
      case AccessIcon.network:
        canvas.drawCircle(const Offset(12, 12), 9, p);
        canvas.drawLine(const Offset(3, 12), const Offset(21, 12), p);
        canvas.drawOval(
          Rect.fromCenter(center: const Offset(12, 12), width: 9, height: 18),
          p,
        );
      case AccessIcon.storage:
        canvas.drawOval(Rect.fromLTRB(5, 3, 19, 9), p);
        canvas.drawPath(
          Path()
            ..moveTo(5, 6)
            ..lineTo(5, 18)
            ..arcTo(Rect.fromLTRB(5, 15, 19, 21), math.pi, -math.pi, false)
            ..lineTo(19, 6),
          p,
        );
      case AccessIcon.notifications:
        // M6 16V11a6 6 0 0 1 12 0v5l2 2H4zM10 20h4
        canvas.drawPath(
          Path()
            ..moveTo(6, 16)
            ..lineTo(6, 11)
            ..arcTo(circle(12, 11, 6), math.pi, math.pi, false)
            ..lineTo(18, 16)
            ..lineTo(20, 18)
            ..lineTo(4, 18)
            ..close(),
          p,
        );
        canvas.drawLine(const Offset(10, 21), const Offset(14, 21), p);
      case AccessIcon.media:
        // M9 3h6v11H9zM5 11a7 7 0 0 0 14 0M12 18v3
        canvas.drawRRect(
          RRect.fromLTRBR(9, 3, 15, 14, const Radius.circular(3)),
          p,
        );
        canvas.drawArc(circle(12, 11, 7), 0, math.pi, false, p);
        canvas.drawLine(const Offset(12, 18), const Offset(12, 21), p);
      case AccessIcon.composer:
        // A pencil.
        canvas.drawPath(
          Path()
            ..moveTo(4, 20)
            ..lineTo(4.5, 16)
            ..lineTo(15.5, 5)
            ..lineTo(19, 8.5)
            ..lineTo(8, 19.5)
            ..close()
            ..moveTo(13, 7.5)
            ..lineTo(16.5, 11),
          p,
        );
      case AccessIcon.render:
        // M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 9a3 3 0 1 0 0 6
        canvas.drawPath(
          Path()
            ..moveTo(2, 12)
            ..quadraticBezierTo(6, 5, 12, 5)
            ..quadraticBezierTo(18, 5, 22, 12)
            ..quadraticBezierTo(18, 19, 12, 19)
            ..quadraticBezierTo(6, 19, 2, 12)
            ..close(),
          p,
        );
        canvas.drawCircle(const Offset(12, 12), 3, p);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}
