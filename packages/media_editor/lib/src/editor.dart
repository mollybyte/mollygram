import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'model/crop_geometry.dart';
import 'model/media_edit.dart';
import 'render/render.dart';
import 'strings.dart';
import 'ui/controls.dart';
import 'ui/editor_icons.dart';
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
enum EditorTool { none, crop }

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
  Size _source = Size.zero;
  var _loadFailed = false;
  var _saving = false;
  var _saveFailed = false;

  late MediaEdit _edit = widget.initial;
  final _undo = <MediaEdit>[];
  final _redo = <MediaEdit>[];
  var _tool = EditorTool.none;

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
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _cropMode.dispose();
    _grid.dispose();
    _appear.dispose();
    _cropMove.dispose();
    _turn.dispose();
    super.dispose();
  }

  // History.

  void _commit(MediaEdit next, {bool glide = true}) {
    if (next == _edit) return;
    _undo.add(_edit);
    _redo.clear();
    _show(next, glide: glide);
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
    setState(() => _tool = _tool == tool ? EditorTool.none : tool);
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
    if (_tool != EditorTool.none) {
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

  // Crop dragging.

  bool get _cropping => _tool == EditorTool.crop && !_saving;

  void _onPanStart(DragStartDetails details) {
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
    final crop = _liveCrop;
    if (_dragHandle == null || crop == null) return;
    _grid.animateTo(0.35, curve: Curves.easeOut);
    setState(() {
      _dragHandle = null;
      _liveCrop = null;
    });
    _commit(_edit.copyWith(crop: crop), glide: false);
  }

  void _onHover(PointerHoverEvent event) {
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
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(child: _Backdrop(colors: c)),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 132),
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
                    _ToolPanel(
                      visible: _tool == EditorTool.crop,
                      child: _cropPanel(s),
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
          cursor: _cropping
              ? cursorFor(
                  _dragHandle ?? _hoverHandle,
                  dragging: _dragHandle != null,
                )
              : MouseCursor.defer,
          onHover: _onHover,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                      painter: StagePainter(
                        image: image,
                        source: _source,
                        edit: _edit,
                        layout: _layoutFor(_edit, mode, _shownCrop),
                        outsideOpacity: mode * (c.isDark ? 0.3 : 0.38),
                        frameOpacity: mode,
                        gridOpacity: _grid.value,
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
        width: 460,
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

/// The blurred, dimmed window behind the editor: dark in the dark theme, a
/// calm light gray in the light one, like Photos.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.colors});

  final MgColors colors;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: ColoredBox(
        color: colors.isDark
            ? const Color(0xEE141416)
            : const Color(0xEEEDEDF0),
      ),
    ),
  );
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
