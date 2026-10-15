import 'dart:math' as math;
import 'dart:ui';

/// What a drag on the crop frame moves.
enum CropHandle {
  topLeft(-1, -1),
  top(0, -1),
  topRight(1, -1),
  right(1, 0),
  bottomRight(1, 1),
  bottom(0, 1),
  bottomLeft(-1, 1),
  left(-1, 0),
  move(0, 0);

  const CropHandle(this.x, this.y);

  /// Which vertical edge moves: -1 left, 1 right, 0 none.
  final int x;

  /// Which horizontal edge moves: -1 top, 1 bottom, 0 none.
  final int y;

  bool get isCorner => x != 0 && y != 0;
}

/// The crop rectangle after dragging [handle] of [start] by [delta], all in
/// pixels of the oriented picture of [bounds].
///
/// Keeps the rectangle inside [bounds], no smaller than [minSize] on either
/// side and, when [ratio] is given, at that width over height. A corner
/// drag keeps the opposite corner in place; an edge drag with a locked
/// ratio grows the other side evenly around its center.
Rect resizeCrop({
  required Rect start,
  required CropHandle handle,
  required Offset delta,
  required Size bounds,
  double? ratio,
  double minSize = 1,
}) {
  if (handle == CropHandle.move) {
    final dx = delta.dx.clamp(-start.left, bounds.width - start.right);
    final dy = delta.dy.clamp(-start.top, bounds.height - start.bottom);
    return start.shift(Offset(dx, dy));
  }
  if (ratio == null) return _resizeFree(start, handle, delta, bounds, minSize);
  return handle.isCorner
      ? _resizeCorner(start, handle, delta, bounds, ratio, minSize)
      : _resizeEdge(start, handle, delta, bounds, ratio, minSize);
}

Rect _resizeFree(Rect r, CropHandle h, Offset d, Size bounds, double minSize) {
  var left = r.left, top = r.top, right = r.right, bottom = r.bottom;
  if (h.x < 0) left = (left + d.dx).clamp(0.0, right - minSize);
  if (h.x > 0) right = (right + d.dx).clamp(left + minSize, bounds.width);
  if (h.y < 0) top = (top + d.dy).clamp(0.0, bottom - minSize);
  if (h.y > 0) bottom = (bottom + d.dy).clamp(top + minSize, bounds.height);
  return Rect.fromLTRB(left, top, right, bottom);
}

Rect _resizeCorner(
  Rect r,
  CropHandle h,
  Offset d,
  Size bounds,
  double ratio,
  double minSize,
) {
  // The corner that stays put.
  final ax = h.x < 0 ? r.right : r.left;
  final ay = h.y < 0 ? r.bottom : r.top;
  final wanted = math.max(
    r.width + d.dx * h.x,
    (r.height + d.dy * h.y) * ratio,
  );
  final roomX = h.x < 0 ? ax : bounds.width - ax;
  final roomY = h.y < 0 ? ay : bounds.height - ay;
  final maxWidth = math.min(roomX, roomY * ratio);
  final minWidth = math.min(math.max(minSize, minSize * ratio), maxWidth);
  final width = wanted.clamp(minWidth, maxWidth);
  final height = width / ratio;
  final left = h.x < 0 ? ax - width : ax;
  final top = h.y < 0 ? ay - height : ay;
  return Rect.fromLTWH(left, top, width, height);
}

Rect _resizeEdge(
  Rect r,
  CropHandle h,
  Offset d,
  Size bounds,
  double ratio,
  double minSize,
) {
  if (h.x != 0) {
    // Left or right edge: the width follows the drag, the height grows
    // around the vertical center.
    final ax = h.x < 0 ? r.right : r.left;
    final cy = r.center.dy;
    final roomX = h.x < 0 ? ax : bounds.width - ax;
    final roomH = 2 * math.min(cy, bounds.height - cy);
    final maxWidth = math.min(roomX, roomH * ratio);
    final minWidth = math.min(math.max(minSize, minSize * ratio), maxWidth);
    final width = (r.width + d.dx * h.x).clamp(minWidth, maxWidth);
    final height = width / ratio;
    final left = h.x < 0 ? ax - width : ax;
    return Rect.fromLTWH(left, cy - height / 2, width, height);
  }
  final ay = h.y < 0 ? r.bottom : r.top;
  final cx = r.center.dx;
  final roomY = h.y < 0 ? ay : bounds.height - ay;
  final roomW = 2 * math.min(cx, bounds.width - cx);
  final maxHeight = math.min(roomY, roomW / ratio);
  final minHeight = math.min(math.max(minSize, minSize / ratio), maxHeight);
  final height = (r.height + d.dy * h.y).clamp(minHeight, maxHeight);
  final width = height * ratio;
  final top = h.y < 0 ? ay - height : ay;
  return Rect.fromLTWH(cx - width / 2, top, width, height);
}

/// [inner] scaled to fit inside [outer], centered.
Rect fitInside(Size inner, Rect outer) {
  if (inner.isEmpty) {
    return Rect.fromCenter(center: outer.center, width: 0, height: 0);
  }
  final scale = math.min(
    outer.width / inner.width,
    outer.height / inner.height,
  );
  return Rect.fromCenter(
    center: outer.center,
    width: inner.width * scale,
    height: inner.height * scale,
  );
}
