import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The trim timeline of the video editor: frames of the whole video with
/// the kept range framed between two handles, a playhead that scrubs, and
/// a mark on the cover frame.
///
/// Drags inside the strip move the playhead; drags on a handle move that
/// end of the range and take the playhead with it, so the frame on the
/// stage is always the one under the pointer.
class Filmstrip extends StatefulWidget {
  const Filmstrip({
    super.key,
    required this.duration,
    required this.start,
    required this.end,
    required this.playhead,
    required this.cover,
    required this.frames,
    required this.onScrub,
    required this.onTrim,
    required this.onTrimEnd,
    this.width = 400,
    this.height = 44,
  });

  final Duration duration;
  final Duration start;
  final Duration end;
  final Duration playhead;
  final Duration? cover;

  /// Thumbnails spread evenly over the video; null where one has not
  /// arrived yet.
  final List<ui.Image?> frames;

  final ValueChanged<Duration> onScrub;

  /// A handle moved: the new range.
  final void Function(Duration start, Duration end) onTrim;
  final VoidCallback onTrimEnd;

  final double width;
  final double height;

  /// The shortest range a video can be trimmed to.
  static const minLength = Duration(seconds: 1);

  /// The width of the handles, in pixels.
  static const handleWidth = 14.0;

  @override
  State<Filmstrip> createState() => _FilmstripState();
}

enum _Drag { playhead, start, end }

class _FilmstripState extends State<Filmstrip> {
  _Drag? _drag;
  _Drag? _hover;

  /// Where the pointer took a handle, relative to its edge, so the handle
  /// does not jump under it.
  var _grab = 0.0;

  double get _trackLeft => Filmstrip.handleWidth;
  double get _trackWidth => widget.width - 2 * Filmstrip.handleWidth;

  double _x(Duration t) => widget.duration == Duration.zero
      ? _trackLeft
      : _trackLeft +
            _trackWidth * t.inMicroseconds / widget.duration.inMicroseconds;

  Duration _time(double x) {
    final f = ((x - _trackLeft) / _trackWidth).clamp(0.0, 1.0);
    return Duration(microseconds: (widget.duration.inMicroseconds * f).round());
  }

  _Drag? _hit(Offset p) {
    const slack = 8.0;
    final startX = _x(widget.start);
    final endX = _x(widget.end);
    if (p.dx >= startX - Filmstrip.handleWidth - slack && p.dx <= startX + 4) {
      return _Drag.start;
    }
    if (p.dx <= endX + Filmstrip.handleWidth + slack && p.dx >= endX - 4) {
      return _Drag.end;
    }
    return _Drag.playhead;
  }

  void _onDown(DragDownDetails d) {
    _drag = _hit(d.localPosition);
    _grab = switch (_drag) {
      _Drag.start => d.localPosition.dx - _x(widget.start),
      _Drag.end => d.localPosition.dx - _x(widget.end),
      _ => 0,
    };
    _apply(d.localPosition);
  }

  void _apply(Offset p) {
    final drag = _drag;
    if (drag == null) return;
    final min = widget.duration < Filmstrip.minLength
        ? widget.duration
        : Filmstrip.minLength;
    switch (drag) {
      case _Drag.playhead:
        final t = _time(p.dx);
        widget.onScrub(_clamp(t, widget.start, widget.end));
      case _Drag.start:
        final t = _clamp(_time(p.dx - _grab), Duration.zero, widget.end - min);
        widget.onTrim(t, widget.end);
      case _Drag.end:
        final t = _clamp(
          _time(p.dx - _grab),
          widget.start + min,
          widget.duration,
        );
        widget.onTrim(widget.start, t);
    }
  }

  void _onEnd() {
    if (_drag == _Drag.start || _drag == _Drag.end) widget.onTrimEnd();
    setState(() => _drag = null);
  }

  Duration _clamp(Duration t, Duration low, Duration high) =>
      t < low ? low : (t > high ? high : t);

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final active = _drag ?? _hover;
    return Semantics(
      slider: true,
      label: 'Timeline',
      value: '${widget.start.inMilliseconds}-${widget.end.inMilliseconds}',
      child: MouseRegion(
        cursor: switch (active) {
          _Drag.start || _Drag.end => SystemMouseCursors.resizeLeftRight,
          _Drag.playhead => SystemMouseCursors.click,
          null => MouseCursor.defer,
        },
        onHover: (e) {
          final hit = _hit(e.localPosition);
          if (hit != _hover) setState(() => _hover = hit);
        },
        onExit: (_) => setState(() => _hover = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: _onDown,
          onPanUpdate: (d) => _apply(d.localPosition),
          onPanEnd: (_) => _onEnd(),
          onPanCancel: _onEnd,
          child: SizedBox(
            width: widget.width,
            height: widget.height + 12,
            child: CustomPaint(
              painter: _FilmstripPainter(
                frames: widget.frames,
                startX: _x(widget.start),
                endX: _x(widget.end),
                playheadX: _x(widget.playhead),
                coverX: widget.cover == null ? null : _x(widget.cover!),
                trackLeft: _trackLeft,
                trackWidth: _trackWidth,
                stripHeight: widget.height,
                accent: c.accent,
                dragging: _drag == _Drag.start || _drag == _Drag.end,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilmstripPainter extends CustomPainter {
  _FilmstripPainter({
    required this.frames,
    required this.startX,
    required this.endX,
    required this.playheadX,
    required this.coverX,
    required this.trackLeft,
    required this.trackWidth,
    required this.stripHeight,
    required this.accent,
    required this.dragging,
  });

  final List<ui.Image?> frames;
  final double startX;
  final double endX;
  final double playheadX;
  final double? coverX;
  final double trackLeft;
  final double trackWidth;
  final double stripHeight;
  final Color accent;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final top = (size.height - stripHeight) / 2;
    final strip = Rect.fromLTWH(trackLeft, top, trackWidth, stripHeight);
    final radius = const Radius.circular(8);

    // The frames, tiled and clipped to the rounded strip.
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(strip, radius))
      ..drawRect(strip, Paint()..color = const Color(0xFF2A2A2E));
    if (frames.isNotEmpty) {
      final cell = strip.width / frames.length;
      for (final (i, frame) in frames.indexed) {
        final dest = Rect.fromLTWH(
          strip.left + i * cell,
          strip.top,
          cell + 0.5,
          strip.height,
        );
        if (frame == null) continue;
        final src = Rect.fromLTWH(
          0,
          0,
          frame.width.toDouble(),
          frame.height.toDouble(),
        );
        final fitted = _cover(src.size, dest.size);
        canvas.drawImageRect(
          frame,
          Rect.fromCenter(
            center: src.center,
            width: fitted.width,
            height: fitted.height,
          ),
          dest,
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    }
    // Dim what is cut away.
    final dim = Paint()..color = const Color(0x99000000);
    canvas
      ..drawRect(
        Rect.fromLTRB(strip.left, strip.top, startX, strip.bottom),
        dim,
      )
      ..drawRect(Rect.fromLTRB(endX, strip.top, strip.right, strip.bottom), dim)
      ..restore();

    // The kept range: a frame in the accent with the two handles.
    final kept = Rect.fromLTRB(
      startX - Filmstrip.handleWidth,
      top,
      endX + Filmstrip.handleWidth,
      top + stripHeight,
    );
    final frame = Path()
      ..addRRect(RRect.fromRectAndRadius(kept, const Radius.circular(9)))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(startX, top + 2.5, endX, top + stripHeight - 2.5),
          const Radius.circular(2),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(frame, Paint()..color = accent);
    // Grips on the handles.
    final grip = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final x in [
      startX - Filmstrip.handleWidth / 2,
      endX + Filmstrip.handleWidth / 2,
    ]) {
      canvas.drawLine(
        Offset(x, top + stripHeight / 2 - 6),
        Offset(x, top + stripHeight / 2 + 6),
        grip,
      );
    }

    // The cover mark: a small accent flag over the strip.
    final coverX = this.coverX;
    if (coverX != null) {
      final flag = Path()
        ..moveTo(coverX - 5, top - 6)
        ..lineTo(coverX + 5, top - 6)
        ..lineTo(coverX, top - 1)
        ..close();
      canvas
        ..drawPath(
          flag,
          Paint()
            ..color = const Color(0x66000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
        )
        ..drawPath(flag, Paint()..color = const Color(0xFFFFFFFF));
    }

    // The playhead, hidden under a dragged handle.
    if (!dragging) {
      final head = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(playheadX, top + stripHeight / 2),
          width: 3,
          height: stripHeight + 8,
        ),
        const Radius.circular(1.5),
      );
      canvas
        ..drawRRect(
          head.inflate(1),
          Paint()
            ..color = const Color(0x66000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        )
        ..drawRRect(head, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  /// The part of a frame of [source] size that fills [dest] without
  /// distortion.
  Size _cover(Size source, Size dest) {
    final scale = math.max(
      dest.width / source.width,
      dest.height / source.height,
    );
    return Size(dest.width / scale, dest.height / scale);
  }

  @override
  bool shouldRepaint(_FilmstripPainter old) =>
      old.frames != frames ||
      old.startX != startX ||
      old.endX != endX ||
      old.playheadX != playheadX ||
      old.coverX != coverX ||
      old.trackWidth != trackWidth ||
      old.accent != accent ||
      old.dragging != dragging;
}
