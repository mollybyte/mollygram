import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'model/adjustments.dart';
import 'model/crop_geometry.dart';
import 'model/media_edit.dart';
import 'model/overlay.dart';
import 'model/stroke.dart';
import 'render/overlays.dart';
import 'render/render.dart';
import 'strings.dart';
import 'ui/adjust_panel.dart';
import 'ui/backdrop.dart';
import 'ui/controls.dart';
import 'ui/draw_panel.dart';
import 'ui/editor_icons.dart';
import 'ui/overlay_panels.dart';
import 'ui/selection.dart';
import 'ui/stage.dart';

/// What [showMediaEditor] hands back.
@immutable
final class MediaEditResult {
  const MediaEditResult({
    required this.path,
    required this.originalPath,
    required this.edit,
    this.width = 0,
    this.height = 0,
  });

  /// The file to send: a new file with the edit applied, or [originalPath]
  /// when the edit changes nothing.
  final String path;

  /// The file the editor was opened with. Pass it back with [edit] to keep
  /// editing without losing quality.
  final String originalPath;

  /// Everything the user did, relative to [originalPath].
  final MediaEdit edit;

  /// Pixel size of [path]; 0 when it is the untouched original.
  final int width;
  final int height;

  bool get isEdited => path != originalPath;
}

/// Opens the editor over the window for the picture at [path].
///
/// [initial] restores an earlier edit of the same file. The edited file is
/// written under [outputDirectory], the system temp folder by default.
/// Completes with null when the user cancels.
Future<MediaEditResult?> showMediaEditor(
  BuildContext context, {
  required String path,
  MediaEdit initial = const MediaEdit(),
  String? outputDirectory,
}) => Navigator.of(context).push(
  PageRouteBuilder<MediaEditResult>(
    opaque: false,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => MediaEditorPage(
      path: path,
      initial: initial,
      outputDirectory: outputDirectory,
    ),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  ),
);

/// The editor's tools. [none] shows the result.
enum EditorTool { none, crop, draw, text, emoji, shapes, adjust }

/// The editor screen. Use [showMediaEditor] to open it.
class MediaEditorPage extends StatefulWidget {
  const MediaEditorPage({
    super.key,
    required this.path,
    this.initial = const MediaEdit(),
    this.outputDirectory,
  });

  final String path;
  final MediaEdit initial;
  final String? outputDirectory;

  @override
  State<MediaEditorPage> createState() => _MediaEditorPageState();
}

/// The longest side of the picture decoded for the screen.
const _previewSide = 3072;

const _ease = Cubic(0.2, 0.8, 0.2, 1);

class _MediaEditorPageState extends State<MediaEditorPage>
    with TickerProviderStateMixin {
  ui.Image? _image;
  ui.Image? _pixelated;
  Size _source = Size.zero;
  var _loadFailed = false;
  var _saving = false;
  var _saveFailed = false;

  late MediaEdit _edit = widget.initial;
  final _undo = <MediaEdit>[];
  final _redo = <MediaEdit>[];
  var _tool = EditorTool.none;

  // Drawing.
  var _brush = BrushTool.pen;
  var _color = brushColors[1];

  /// Line width, 0 thin to 1 thick.
  var _thickness = 0.35;
  List<Offset>? _livePoints;

  // Overlays: text, emoji and shapes.
  int? _selected;
  OverlayHandle? _overlayDrag;
  MediaOverlay? _overlayStart;
  Offset _overlayPointer = Offset.zero;

  /// The edit before a live change (a drag, typing), pushed to history
  /// when the change ends.
  MediaEdit? _before;
  final _text = TextEditingController();
  final _textFocus = FocusNode();
  var _shapeColor = brushColors[1];
  var _shapeThickness = 0.35;
  var _adjustment = Adjustment.brightness;
  late final _selection = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  /// The crop while a handle is dragged, before it lands in history.
  Rect? _liveCrop;
  CropHandle? _dragHandle;
  CropHandle? _hoverHandle;
  Rect _dragStart = Rect.zero;
  Offset _dragOrigin = Offset.zero;

  Size _stage = Size.zero;

  /// 0 shows the crop filling the stage, 1 the whole picture with the frame.
  late final _cropMode = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _grid = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 0.35,
  );
  late final _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  /// Glides the crop from [_cropFrom] to the committed one.
  late final _cropMove = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  Rect _cropFrom = unitRect;

  /// Rotation and mirroring: the new orientation is shown turned back by
  /// [_turnFrom] radians, scaled by [_scaleFrom] and swung around the
  /// vertical axis by [_swingFrom], and settles into place.
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
    value: 1,
  );
  double _turnFrom = 0;
  double _scaleFrom = 1;
  double _swingFrom = 0;

  @override
  void initState() {
    super.initState();
    _cropFrom = _edit.crop;
    _text.addListener(_onTextChanged);
    _textFocus.addListener(_onTextFocus);
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      final (image, source) = await decodePicture(bytes, maxSide: _previewSide);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _source = source;
      });
      await _appear.forward();
      final pixelated = await pixelatedCopy(image);
      if (!mounted) {
        pixelated.dispose();
        return;
      }
      setState(() => _pixelated = pixelated);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _pixelated?.dispose();
    _cropMode.dispose();
    _grid.dispose();
    _appear.dispose();
    _cropMove.dispose();
    _turn.dispose();
    _selection.dispose();
    _text.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  // History.

  void _commit(MediaEdit next, {bool glide = true}) {
    if (next == _edit) return;
    // During a live change (typing) everything folds into one step.
    if (_before == null) {
      _undo.add(_edit);
      _redo.clear();
    }
    _show(next, glide: glide);
  }

  /// Starts a live change: later [_show] calls replace the edit without
  /// touching history until [_endLive].
  void _beginLive() => _before ??= _edit;

  /// Ends a live change, recording the edit before it as one undo step.
  void _endLive() {
    final before = _before;
    _before = null;
    if (before == null || before == _edit) return;
    _undo.add(before);
    _redo.clear();
  }

  void _undoEdit() {
    if (_undo.isEmpty || _saving) return;
    _redo.add(_edit);
    _show(_undo.removeLast());
  }

  void _redoEdit() {
    if (_redo.isEmpty || _saving) return;
    _undo.add(_edit);
    _show(_redo.removeLast());
  }

  /// Makes [next] current, animating whatever changed: a turn, a mirror or
  /// the crop.
  void _show(MediaEdit next, {bool glide = true}) {
    final previous = _edit;
    final turns = (next.quarterTurns - previous.quarterTurns) % 4;
    final mirrored = next.flipped != previous.flipped;
    if (turns != 0 || mirrored) {
      _startTurn(previous, next, turns, mirrored);
      _cropFrom = next.crop;
      _cropMove.value = 1;
    } else if (glide && next.crop != previous.crop) {
      _cropFrom = _shownCrop;
      _cropMove.forward(from: 0);
    } else {
      _cropFrom = next.crop;
      _cropMove.value = 1;
    }
    setState(() => _edit = next);
  }

  void _startTurn(MediaEdit from, MediaEdit to, int turns, bool mirrored) {
    final t = _ease.transform(_turn.value);
    final angle = _turnFrom * (1 - t);
    final scale = ui.lerpDouble(_scaleFrom, 1, t)!;
    final swing = _swingFrom * (1 - t);

    // Screen-space rotation from the old picture to the new one. With the
    // mirror on, turning the source clockwise turns the screen counter-
    // clockwise.
    final screenTurns = turns == 3 ? -1 : turns;
    final direction = from.flipped && !mirrored ? -1 : 1;
    final oldDest = _layoutFor(from, _cropMode.value).dest;
    final newDest = _layoutFor(to, _cropMode.value).dest;
    final odd = turns.isOdd;
    final ratio = newDest.isEmpty
        ? 1.0
        : (odd
              ? oldDest.width / newDest.height
              : oldDest.width / newDest.width);

    _turnFrom = angle - direction * screenTurns * math.pi / 2;
    _scaleFrom = scale * ratio;
    _swingFrom = mirrored ? swing + math.pi : swing;
    _turn.forward(from: 0);
  }

  // Tools.

  void _setTool(EditorTool tool) {
    if (_saving) return;
    _textFocus.unfocus();
    setState(() {
      _tool = _tool == tool ? EditorTool.none : tool;
      _hoverHandle = null;
    });
    if (_tool == EditorTool.text) {
      if (_edit.overlay(_selected) is! TextOverlay) _addText();
      _textFocus.requestFocus();
    } else if (_tool == EditorTool.shapes) {
      if (_edit.overlay(_selected) is! ShapeOverlay) _select(null);
    } else if (_tool != EditorTool.emoji) {
      _select(null);
    }
    if (_tool == EditorTool.crop) {
      _cropMode.animateTo(1, curve: _ease);
    } else {
      _cropMode.animateBack(0, curve: _ease);
    }
  }

  void _rotate() {
    if (_image == null || _saving) return;
    _commit(_edit.rotatedLeft());
  }

  void _flip() {
    if (_image == null || _saving) return;
    _commit(_edit.flippedHorizontally());
  }

  void _setAspect(AspectPreset preset) {
    if (_image == null) return;
    final portrait = preset == _edit.aspect && preset.hasOrientation
        ? _edit.portrait
        : null;
    _commit(_edit.withAspect(preset, _source, portrait: portrait));
  }

  void _toggleOrientation() {
    if (!_edit.aspect.hasOrientation) return;
    _commit(_edit.withAspect(_edit.aspect, _source, portrait: !_edit.portrait));
  }

  void _reset() => _commit(const MediaEdit());

  // Saving.

  Future<void> _done() async {
    if (_saving || _image == null) return;
    if (_textFocus.hasFocus) {
      // Enter in the text field finishes the text, not the edit.
      _textFocus.unfocus();
      return;
    }
    final edit = _edit;
    if (edit.isIdentity) {
      Navigator.of(context).pop(
        MediaEditResult(
          path: widget.path,
          originalPath: widget.path,
          edit: edit,
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final out = await exportEdit(
        widget.path,
        edit,
        outputDirectory: widget.outputDirectory,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        MediaEditResult(
          path: out.path,
          originalPath: widget.path,
          edit: edit,
          width: out.width,
          height: out.height,
        ),
      );
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  void _cancel() => Navigator.of(context).maybePop();

  void _escape() {
    if (_textFocus.hasFocus) {
      _textFocus.unfocus();
    } else if (_selected != null) {
      _select(null);
    } else if (_tool != EditorTool.none) {
      _setTool(_tool);
    } else {
      _cancel();
    }
  }

  // Layout.

  Rect get _shownCrop {
    if (_liveCrop != null) return _liveCrop!;
    return Rect.lerp(_cropFrom, _edit.crop, _ease.transform(_cropMove.value))!;
  }

  StageLayout _layoutFor(MediaEdit edit, double cropMode, [Rect? crop]) {
    final oriented = edit.orientedSize(_source);
    return StageLayout.compute(
      stage: _stage,
      oriented: oriented,
      crop: denormalize(crop ?? edit.crop, oriented),
      cropMode: cropMode,
    );
  }

  StageLayout get _layout =>
      _layoutFor(_edit, _ease.transform(_cropMode.value), _shownCrop);

  // Drawing.

  bool get _drawing => _tool == EditorTool.draw && !_saving;

  /// The width of a stroke of [_brush] as a fraction of the picture's
  /// shorter side.
  double get _strokeWidth {
    final base = ui.lerpDouble(0.003, 0.03, _thickness)!;
    return switch (_brush) {
      BrushTool.pen || BrushTool.arrow => base,
      BrushTool.marker => base * 2.4,
      BrushTool.eraser => base * 2.6,
      BrushTool.blur || BrushTool.pixelate => base * 3,
    };
  }

  Stroke? get _liveStroke {
    final points = _livePoints;
    if (points == null) return null;
    return Stroke(
      tool: _brush,
      color: _color,
      width: _strokeWidth,
      points: points,
    );
  }

  /// [point] on the stage as a normalized point of the oriented picture.
  Offset _toPicture(Offset point) {
    final layout = _layout;
    final oriented = _edit.orientedSize(_source);
    final scale = layout.scale;
    if (scale <= 0) return Offset.zero;
    final px = (point - layout.dest.topLeft) / scale + layout.viewport.topLeft;
    return Offset(
      (px.dx / oriented.width).clamp(0.0, 1.0),
      (px.dy / oriented.height).clamp(0.0, 1.0),
    );
  }

  void _onDrawStart(Offset point) =>
      setState(() => _livePoints = [_toPicture(point)]);

  void _onDrawUpdate(Offset point) {
    final points = _livePoints;
    if (points == null) return;
    final next = _toPicture(point);
    // Skip points closer than a pixel: they only add noise to the curve.
    final scale = _layout.scale;
    final oriented = _edit.orientedSize(_source);
    final last = points.last;
    final moved = Offset(
      (next.dx - last.dx) * oriented.width,
      (next.dy - last.dy) * oriented.height,
    );
    if (moved.distance * scale < 1) return;
    setState(() => _livePoints = [...points, next]);
  }

  void _onDrawEnd() {
    final stroke = _liveStroke;
    if (stroke == null) return;
    setState(() => _livePoints = null);
    _commit(_edit.withStroke(stroke));
  }

  void _setBrush(BrushTool brush) => setState(() => _brush = brush);
  void _setColor(Color color) => setState(() => _color = color);
  void _setThickness(double value) => setState(() => _thickness = value);

  // Overlays.

  bool get _placing =>
      !_saving &&
      (_tool == EditorTool.text ||
          _tool == EditorTool.emoji ||
          _tool == EditorTool.shapes);

  MediaOverlay? get _selectedOverlay => _edit.overlay(_selected);

  SelectionFrame? get _selectionFrame {
    final overlay = _selectedOverlay;
    if (overlay == null || _stage.isEmpty) return null;
    return SelectionFrame.of(overlay, _edit.orientedSize(_source), _layout);
  }

  void _select(int? id) {
    if (id == _selected) return;
    setState(() => _selected = id);
    if (id == null) {
      _selection.reverse();
    } else {
      _selection.forward(from: 0);
    }
    final overlay = _edit.overlay(id);
    if (overlay is TextOverlay && _text.text != overlay.text) {
      _text.text = overlay.text;
    }
    if (overlay is ShapeOverlay) {
      _shapeColor = overlay.color;
      _shapeThickness = (overlay.strokeWidth - 0.003) / 0.03;
    }
  }

  /// Replaces the selected overlay with [f] of it, live or as one step.
  void _updateSelected(
    MediaOverlay Function(MediaOverlay) f, {
    bool live = false,
  }) {
    final overlay = _selectedOverlay;
    if (overlay == null) return;
    final next = _edit.withOverlay(f(overlay));
    if (live) {
      _beginLive();
      setState(() => _edit = next);
    } else {
      _commit(next);
    }
  }

  void _addOverlay(MediaOverlay Function(int id) make) {
    final overlay = make(_edit.nextOverlayId);
    _commit(_edit.withOverlay(overlay));
    _select(overlay.id);
  }

  void _addText() {
    _text.text = '';
    // Not a history step yet: the text lands in history once typed, and
    // goes away untouched when left empty.
    _beginLive();
    final overlay = TextOverlay(
      id: _edit.nextOverlayId,
      center: _edit.crop.center,
      text: '',
      color: brushColors.first,
    );
    setState(() => _edit = _edit.withOverlay(overlay));
    _select(overlay.id);
  }

  void _addEmoji(String emoji) => _addOverlay(
    (id) => EmojiOverlay(id: id, center: _edit.crop.center, emoji: emoji),
  );

  void _addShape(ShapeKind kind) => _addOverlay(
    (id) => ShapeOverlay(
      id: id,
      center: _edit.crop.center,
      kind: kind,
      color: _shapeColor,
      strokeWidth: 0.003 + _shapeThickness * 0.03,
      aspect: kind == ShapeKind.line || kind == ShapeKind.arrow ? 8 : 1.5,
      scale: kind == ShapeKind.line || kind == ShapeKind.arrow ? 0.5 : 0.4,
    ),
  );

  void _deleteSelected() {
    final id = _selected;
    if (id == null) return;
    _textFocus.unfocus();
    _select(null);
    _commit(_edit.withoutOverlay(id));
  }

  void _onTextChanged() {
    final overlay = _selectedOverlay;
    if (overlay is! TextOverlay || overlay.text == _text.text) return;
    _updateSelected(
      (o) => (o as TextOverlay).copyWith(text: _text.text),
      live: true,
    );
  }

  void _onTextFocus() {
    if (_textFocus.hasFocus) return;
    // Typing ends: one undo step, and an empty text goes away.
    final overlay = _selectedOverlay;
    if (overlay is TextOverlay && overlay.text.trim().isEmpty) {
      final before = _before;
      _before = null;
      setState(() {
        _edit = (before ?? _edit).withoutOverlay(overlay.id);
        _selected = null;
      });
      _selection.reverse();
      return;
    }
    _endLive();
  }

  void _setTextLook(TextLook look) =>
      _updateSelected((o) => (o as TextOverlay).copyWith(look: look));

  void _setTextColor(Color color) =>
      _updateSelected((o) => (o as TextOverlay).copyWith(color: color));

  void _setTextScale(double scale) =>
      _updateSelected((o) => o.placed(scale: scale), live: true);

  void _setPreset(FilterPreset preset) =>
      _commit(_edit.copyWith(adjustments: preset.look));

  void _setAdjustment(double value) {
    _beginLive();
    setState(
      () => _edit = _edit.copyWith(
        adjustments: _edit.adjustments.set(_adjustment, value),
      ),
    );
  }

  void _setShapeColor(Color color) {
    setState(() => _shapeColor = color);
    if (_selectedOverlay is ShapeOverlay) {
      _updateSelected((o) => (o as ShapeOverlay).copyWith(color: color));
    }
  }

  void _setShapeFilled(bool filled) =>
      _updateSelected((o) => (o as ShapeOverlay).copyWith(filled: filled));

  void _setShapeThickness(double value) {
    setState(() => _shapeThickness = value);
    if (_selectedOverlay is ShapeOverlay) {
      _updateSelected(
        (o) => (o as ShapeOverlay).copyWith(strokeWidth: 0.003 + value * 0.03),
        live: true,
      );
    }
  }

  /// [point] on the stage in pixels of the oriented picture.
  Offset _toPicturePx(Offset point) {
    final layout = _layout;
    final scale = layout.scale;
    if (scale <= 0) return Offset.zero;
    return (point - layout.dest.topLeft) / scale + layout.viewport.topLeft;
  }

  /// A press at [point] in an overlay tool: selects what is under it and
  /// arms a drag, or deletes through the delete handle.
  void _onOverlayPress(Offset point) {
    final frame = _selectionFrame;
    final handle = frame?.hit(point);
    if (handle == OverlayHandle.delete) {
      _deleteSelected();
      return;
    }
    if (handle != null) {
      _startOverlayDrag(handle, point);
      return;
    }
    final oriented = _edit.orientedSize(_source);
    final hit = hitOverlay(
      _toPicturePx(point),
      _edit.overlays,
      oriented,
      slack: 10 / math.max(_layout.scale, 0.001),
    );
    if (hit == null) {
      _textFocus.unfocus();
      _select(null);
      return;
    }
    _textFocus.unfocus();
    _select(hit.id);
    _startOverlayDrag(OverlayHandle.move, point);
  }

  void _startOverlayDrag(OverlayHandle handle, Offset point) {
    setState(() {
      _overlayDrag = handle;
      _overlayStart = _selectedOverlay;
      _overlayPointer = point;
    });
  }

  void _onOverlayDrag(Offset point) {
    final start = _overlayStart;
    final handle = _overlayDrag;
    if (start == null || handle == null) return;
    final oriented = _edit.orientedSize(_source);
    final scale = _layout.scale;
    if (scale <= 0) return;
    switch (handle) {
      case OverlayHandle.move:
        final d = (point - _overlayPointer) / scale;
        final center = Offset(
          (start.center.dx + d.dx / oriented.width).clamp(0.0, 1.0),
          (start.center.dy + d.dy / oriented.height).clamp(0.0, 1.0),
        );
        _updateSelected((o) => o.placed(center: center), live: true);
      case OverlayHandle.transform:
        final frame = SelectionFrame.of(start, oriented, _layout);
        final v0 = _overlayPointer - frame.center;
        final v = point - frame.center;
        if (v0.distance < 1 || v.distance < 1) return;
        var rotation =
            start.rotation + math.atan2(v.dy, v.dx) - math.atan2(v0.dy, v0.dx);
        // Snap to the quarter turns.
        final quarter = math.pi / 2;
        final nearest = (rotation / quarter).round() * quarter;
        if ((rotation - nearest).abs() < 0.04) rotation = nearest;
        final factor = (v.distance / v0.distance).clamp(0.05, 20.0);
        _updateSelected(
          (o) => o.placed(
            scale: (start.scale * factor).clamp(0.01, 3.0),
            rotation: rotation,
          ),
          live: true,
        );
      case OverlayHandle.delete:
        break;
    }
  }

  void _onOverlayDragEnd() {
    if (_overlayDrag == null) return;
    setState(() {
      _overlayDrag = null;
      _overlayStart = null;
    });
    _endLive();
  }

  // Crop dragging.

  bool get _cropping => _tool == EditorTool.crop && !_saving;

  void _onPanDown(DragDownDetails details) {
    // Overlays are grabbed on the press itself, so a drag measures from
    // where the pointer went down, not from where the drag was accepted.
    if (_placing) _onOverlayPress(details.localPosition);
  }

  void _onPanStart(DragStartDetails details) {
    if (_placing) {
      // The drag was armed on the press; the accepted start already
      // carries the first movement.
      if (_overlayDrag != null) _onOverlayDrag(details.localPosition);
      return;
    }
    if (_drawing) return _onDrawStart(details.localPosition);
    if (!_cropping) return;
    final layout = _layout;
    final handle = hitCropHandle(details.localPosition, layout.crop);
    if (handle == null) return;
    final oriented = _edit.orientedSize(_source);
    setState(() {
      _dragHandle = handle;
      _dragOrigin = details.localPosition;
      _dragStart = denormalize(_shownCrop, oriented);
      _liveCrop = _shownCrop;
    });
    _cropMove.value = 1;
    _grid.animateTo(1, curve: Curves.easeOut);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_overlayDrag != null) return _onOverlayDrag(details.localPosition);
    if (_drawing) return _onDrawUpdate(details.localPosition);
    final handle = _dragHandle;
    if (handle == null) return;
    final layout = _layout;
    final oriented = _edit.orientedSize(_source);
    final scale = layout.scale;
    if (scale <= 0) return;
    final delta = (details.localPosition - _dragOrigin) / scale;
    final rect = resizeCrop(
      start: _dragStart,
      handle: handle,
      delta: delta,
      bounds: oriented,
      ratio: _edit.ratioFor(_source),
      minSize: math.max(48 / scale, 8),
    );
    setState(() => _liveCrop = normalize(rect, oriented));
  }

  void _onPanEnd([Object? _]) {
    if (_overlayDrag != null) return _onOverlayDragEnd();
    if (_livePoints != null) return _onDrawEnd();
    final crop = _liveCrop;
    if (_dragHandle == null || crop == null) return;
    _grid.animateTo(0.35, curve: Curves.easeOut);
    setState(() {
      _dragHandle = null;
      _liveCrop = null;
    });
    _commit(_edit.copyWith(crop: crop), glide: false);
  }

  OverlayHandle? _overlayHover;

  void _onHover(PointerHoverEvent event) {
    if (_placing) {
      final frame = _selectionFrame;
      var handle = frame?.hit(event.localPosition);
      if (handle == null && _layout.scale > 0) {
        final hit = hitOverlay(
          _toPicturePx(event.localPosition),
          _edit.overlays,
          _edit.orientedSize(_source),
          slack: 10 / _layout.scale,
        );
        if (hit != null) handle = OverlayHandle.move;
      }
      if (handle != _overlayHover) setState(() => _overlayHover = handle);
      return;
    }
    if (!_cropping) {
      if (_hoverHandle != null) setState(() => _hoverHandle = null);
      return;
    }
    final handle = hitCropHandle(event.localPosition, _layout.crop);
    if (handle != _hoverHandle) setState(() => _hoverHandle = handle);
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = MediaEditorStrings.of(context);
    final ctrl = Platform.isMacOS;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
        const SingleActivator(LogicalKeyboardKey.enter): _done,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _done,
        SingleActivator(LogicalKeyboardKey.keyZ, meta: ctrl, control: !ctrl):
            _undoEdit,
        SingleActivator(
          LogicalKeyboardKey.keyZ,
          meta: ctrl,
          control: !ctrl,
          shift: true,
        ): _redoEdit,
        SingleActivator(LogicalKeyboardKey.keyR, meta: ctrl, control: !ctrl):
            _rotate,
        SingleActivator(
          LogicalKeyboardKey.keyD,
          meta: ctrl,
          control: !ctrl,
        ): () =>
            _setTool(EditorTool.draw),
        SingleActivator(
          LogicalKeyboardKey.keyT,
          meta: ctrl,
          control: !ctrl,
        ): () =>
            _setTool(EditorTool.text),
        const SingleActivator(LogicalKeyboardKey.delete): _deleteSelected,
        const SingleActivator(LogicalKeyboardKey.backspace): _deleteSelected,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(child: EditorBackdrop(colors: c)),
              Positioned.fill(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 260),
                  curve: _ease,
                  // The adjust panel has two rows, so the stage gives way.
                  padding: EdgeInsets.fromLTRB(
                    32,
                    32,
                    32,
                    _tool == EditorTool.adjust ? 170 : 132,
                  ),
                  child: _buildStage(context),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The panels sit on top of each other: only the
                    // current tool's one is visible.
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        _ToolPanel(
                          visible: _tool == EditorTool.crop,
                          child: _cropPanel(s),
                        ),
                        _ToolPanel(
                          visible: _tool == EditorTool.draw,
                          child: DrawPanel(
                            brush: _brush,
                            color: _color,
                            thickness: _thickness,
                            onBrush: _setBrush,
                            onColor: _setColor,
                            onThickness: _setThickness,
                          ),
                        ),
                        _ToolPanel(
                          visible: _tool == EditorTool.text,
                          child: TextPanel(
                            controller: _text,
                            focusNode: _textFocus,
                            overlay: _selectedOverlay is TextOverlay
                                ? _selectedOverlay! as TextOverlay
                                : null,
                            onLook: _setTextLook,
                            onColor: _setTextColor,
                            onScale: _setTextScale,
                          ),
                        ),
                        _ToolPanel(
                          visible: _tool == EditorTool.emoji,
                          child: EmojiGridPanel(onEmoji: _addEmoji),
                        ),
                        _ToolPanel(
                          visible: _tool == EditorTool.adjust,
                          child: AdjustPanel(
                            values: _edit.adjustments,
                            selected: _adjustment,
                            onPreset: _setPreset,
                            onSelect: (a) => setState(() => _adjustment = a),
                            onChanged: _setAdjustment,
                            onChangeStart: _beginLive,
                            onChangeEnd: _endLive,
                          ),
                        ),
                        _ToolPanel(
                          visible: _tool == EditorTool.shapes,
                          child: ShapePanel(
                            overlay: _selectedOverlay is ShapeOverlay
                                ? _selectedOverlay! as ShapeOverlay
                                : null,
                            color: _shapeColor,
                            thickness: _shapeThickness,
                            onAdd: _addShape,
                            onColor: _setShapeColor,
                            onFilled: _setShapeFilled,
                            onThickness: _setShapeThickness,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _mainBar(c, s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStage(BuildContext context) {
    final s = MediaEditorStrings.of(context);
    final c = MgColors.of(context);
    if (_loadFailed) {
      return Center(
        child: Text(s.failed, style: mgTextStyle(c, color: c.fg2)),
      );
    }
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        _stage = constraints.biggest;
        return MouseRegion(
          cursor: _placing
              ? (_overlayDrag == OverlayHandle.move
                    ? SystemMouseCursors.grabbing
                    : _overlayHover == OverlayHandle.move
                    ? SystemMouseCursors.grab
                    : _overlayHover != null
                    ? SystemMouseCursors.click
                    : MouseCursor.defer)
              : _drawing
              ? SystemMouseCursors.precise
              : _cropping
              ? cursorFor(
                  _dragHandle ?? _hoverHandle,
                  dragging: _dragHandle != null,
                )
              : MouseCursor.defer,
          onHover: _onHover,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _placing ? (_) => _onOverlayDragEnd() : null,
            onPanDown: _onPanDown,
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            onPanCancel: _onPanEnd,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _cropMode,
                _grid,
                _cropMove,
                _turn,
                _appear,
                _selection,
              ]),
              builder: (context, _) {
                final mode = _ease.transform(_cropMode.value);
                final t = _ease.transform(_turn.value);
                final appear = _ease.transform(_appear.value);
                final scale =
                    ui.lerpDouble(_scaleFrom, 1, t)! *
                    ui.lerpDouble(0.97, 1, appear)!;
                final transform = Matrix4.identity()
                  ..setEntry(3, 2, 0.0011)
                  ..rotateY(_swingFrom * (1 - t))
                  ..rotateZ(_turnFrom * (1 - t))
                  ..scaleByDouble(scale, scale, 1, 1);
                return Opacity(
                  opacity: appear,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: CustomPaint(
                      size: Size.infinite,
                      foregroundPainter: SelectionPainter(
                        frame: _selectionFrame,
                        accent: c.accent,
                        opacity: _ease.transform(_selection.value),
                      ),
                      painter: StagePainter(
                        image: image,
                        source: _source,
                        edit: _edit,
                        layout: _layoutFor(_edit, mode, _shownCrop),
                        outsideOpacity: mode * (c.isDark ? 0.3 : 0.38),
                        frameOpacity: mode,
                        gridOpacity: _grid.value,
                        liveStroke: _liveStroke,
                        pixelated: _pixelated,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _mainBar(MgColors c, MediaEditorStrings s) {
    final ready = _image != null && !_saving;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SizedBox(
        width: 560,
        child: Row(
          children: [
            const SizedBox(width: 4),
            MgTextButton(label: s.cancel, onPressed: _saving ? null : _cancel),
            const Spacer(),
            MgIconButton(
              icon: EditorIcons.undo,
              tooltip: s.undo,
              onPressed: ready && _undo.isNotEmpty ? _undoEdit : null,
            ),
            MgIconButton(
              icon: EditorIcons.redo,
              tooltip: s.redo,
              onPressed: ready && _redo.isNotEmpty ? _redoEdit : null,
            ),
            const EditorDivider(),
            MgIconButton(
              icon: EditorIcons.crop,
              tooltip: s.crop,
              selected: _tool == EditorTool.crop,
              onPressed: ready ? () => _setTool(EditorTool.crop) : null,
            ),
            MgIconButton(
              icon: EditorIcons.pen,
              tooltip: s.draw,
              selected: _tool == EditorTool.draw,
              onPressed: ready ? () => _setTool(EditorTool.draw) : null,
            ),
            MgIconButton(
              icon: EditorIcons.text,
              tooltip: s.text,
              selected: _tool == EditorTool.text,
              onPressed: ready ? () => _setTool(EditorTool.text) : null,
            ),
            MgIconButton(
              icon: EditorIcons.emoji,
              tooltip: s.emoji,
              selected: _tool == EditorTool.emoji,
              onPressed: ready ? () => _setTool(EditorTool.emoji) : null,
            ),
            MgIconButton(
              icon: EditorIcons.shapes,
              tooltip: s.shapes,
              selected: _tool == EditorTool.shapes,
              onPressed: ready ? () => _setTool(EditorTool.shapes) : null,
            ),
            MgIconButton(
              icon: EditorIcons.adjust,
              tooltip: s.adjust,
              selected: _tool == EditorTool.adjust,
              onPressed: ready ? () => _setTool(EditorTool.adjust) : null,
            ),
            const Spacer(),
            if (_saveFailed) ...[
              Text(
                s.failed,
                style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
              ),
              const SizedBox(width: 10),
            ],
            MgPrimaryButton(
              label: _saving ? s.saving : s.done,
              height: 28,
              onPressed: ready ? _done : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _cropPanel(MediaEditorStrings s) {
    final aspect = _edit.aspect;
    String label(AspectPreset preset) => switch (preset) {
      AspectPreset.free => s.free,
      AspectPreset.original => s.original,
      AspectPreset.square => s.square,
      AspectPreset.ratio3x2 => _edit.portrait ? '2:3' : '3:2',
      AspectPreset.ratio4x3 => _edit.portrait ? '3:4' : '4:3',
      AspectPreset.ratio16x9 => _edit.portrait ? '9:16' : '16:9',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MgIconButton(
          icon: EditorIcons.rotate,
          tooltip: s.rotate,
          onPressed: _rotate,
        ),
        MgIconButton(icon: EditorIcons.flip, tooltip: s.flip, onPressed: _flip),
        const EditorDivider(),
        for (final preset in AspectPreset.values) ...[
          EditorChip(
            label: label(preset),
            selected: aspect == preset,
            onPressed: () => _setAspect(preset),
          ),
          const SizedBox(width: 2),
        ],
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: _ease,
          child: aspect.hasOrientation
              ? MgIconButton(
                  icon: _edit.portrait
                      ? EditorIcons.portrait
                      : EditorIcons.landscape,
                  tooltip: _edit.portrait ? s.portrait : s.landscape,
                  onPressed: _toggleOrientation,
                )
              : const SizedBox(height: 32),
        ),
        const EditorDivider(),
        MgTextButton(
          label: s.reset,
          onPressed: _edit == const MediaEdit() ? null : _reset,
        ),
        const SizedBox(width: 6),
      ],
    );
  }
}

/// A floating glass panel with a tool's options. It fades and slides in
/// when its tool is picked, and away when it is put down.
class _ToolPanel extends StatelessWidget {
  const _ToolPanel({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.25),
      duration: const Duration(milliseconds: 260),
      curve: _ease,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: child,
        ),
      ),
    ),
  );
}
