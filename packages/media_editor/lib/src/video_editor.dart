import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'model/crop_geometry.dart';
import 'model/video_edit.dart';
import 'render/render.dart';
import 'strings.dart';
import 'ui/backdrop.dart';
import 'ui/controls.dart';
import 'ui/editor_icons.dart';
import 'ui/filmstrip.dart';
import 'video/video_engine.dart';

/// What [showVideoEditor] hands back.
@immutable
final class VideoEditResult {
  const VideoEditResult({
    required this.path,
    required this.originalPath,
    required this.edit,
    this.width = 0,
    this.height = 0,
    this.duration = Duration.zero,
    this.coverPath,
    this.thumbnailPath,
  });

  /// The file to send: a new file with the edit applied, or [originalPath]
  /// when the edit changes nothing.
  final String path;

  /// The file the editor was opened with. Pass it back with [edit] to keep
  /// editing without losing quality.
  final String originalPath;

  /// Everything the user did, relative to [originalPath].
  final VideoEdit edit;

  /// Pixel size and length of [path]; 0 when it is the untouched original.
  final int width;
  final int height;
  final Duration duration;

  /// A JPEG of the frame the user chose as the cover; null when they chose
  /// none or nothing was exported.
  final String? coverPath;

  /// A small JPEG of the first kept frame (or the cover), for the message
  /// thumbnail; null when nothing was exported.
  final String? thumbnailPath;

  bool get isEdited => path != originalPath;
}

/// Opens the editor over the window for the video at [path], reading and
/// writing it through [engine].
///
/// [initial] restores an earlier edit of the same file. The edited file is
/// written under [outputDirectory], the system temp folder by default.
/// Completes with null when the user cancels.
Future<VideoEditResult?> showVideoEditor(
  BuildContext context, {
  required String path,
  required VideoEngine engine,
  VideoEdit initial = const VideoEdit(),
  String? outputDirectory,
}) => Navigator.of(context).push(
  PageRouteBuilder<VideoEditResult>(
    opaque: false,
    barrierColor: const Color(0x00000000),
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => VideoEditorPage(
      path: path,
      engine: engine,
      initial: initial,
      outputDirectory: outputDirectory,
    ),
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  ),
);

/// The video editor screen. Use [showVideoEditor] to open it.
class VideoEditorPage extends StatefulWidget {
  const VideoEditorPage({
    super.key,
    required this.path,
    required this.engine,
    this.initial = const VideoEdit(),
    this.outputDirectory,
  });

  final String path;
  final VideoEngine engine;
  final VideoEdit initial;
  final String? outputDirectory;

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

const _ease = Cubic(0.2, 0.8, 0.2, 1);

/// The longest side of a frame decoded for the stage.
const _frameSide = 1280;

/// Frames are cached by their time rounded to this, so scrubbing back over
/// a stretch does not decode it again.
const _frameStep = Duration(milliseconds: 40);

/// How many frames stay decoded.
const _frameCacheSize = 48;

/// The timeline's width and height, in pixels.
const _stripWidth = 400.0;
const _stripHeight = 44.0;

class _VideoEditorPageState extends State<VideoEditorPage>
    with SingleTickerProviderStateMixin {
  VideoInfo? _info;
  var _loadFailed = false;
  var _saving = false;
  var _saveFailed = false;

  late VideoEdit _edit = widget.initial;
  var _playhead = Duration.zero;

  /// The frame on the stage.
  ui.Image? _frame;

  /// Decoded frames by their step, most recently used last.
  final _frames = <int, ui.Image>{};
  Duration? _wanted;
  var _fetching = false;

  /// The timeline's thumbnails, filled in as they arrive.
  var _thumbs = <ui.Image?>[];

  late final _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  Duration get _duration => _info?.duration ?? Duration.zero;
  Duration get _end => _edit.endIn(_duration);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final info = await widget.engine.probe(widget.path);
      if (!mounted) return;
      setState(() {
        _info = info;
        _playhead = _edit.coverIn(info.duration);
        _edit = _edit.copyWith(
          start: _edit.start > info.duration ? Duration.zero : _edit.start,
          end: _edit.end != null && _edit.end! >= info.duration
              ? null
              : _edit.end,
        );
      });
      _seek(_playhead);
      await _loadThumbs(info);
    } on Object {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _loadThumbs(VideoInfo info) async {
    final aspect = info.width > 0 && info.height > 0
        ? info.width / info.height
        : 16 / 9;
    final count = (_stripWidth / (_stripHeight * aspect)).ceil().clamp(6, 16);
    _thumbs = List<ui.Image?>.filled(count, null);
    for (var i = 0; i < count; i++) {
      final at = Duration(
        microseconds: (info.duration.inMicroseconds * (i + 0.5) / count)
            .round(),
      );
      final ui.Image image;
      try {
        final bytes = await widget.engine.frame(widget.path, at, maxSide: 160);
        (image, _) = await decodePicture(bytes);
      } on Object {
        continue;
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _thumbs = [..._thumbs]..[i] = image);
    }
  }

  @override
  void dispose() {
    _appear.dispose();
    for (final frame in _frames.values) {
      frame.dispose();
    }
    for (final thumb in _thumbs) {
      thumb?.dispose();
    }
    super.dispose();
  }

  // Frames.

  int _step(Duration at) => at.inMicroseconds ~/ _frameStep.inMicroseconds;

  /// Shows the frame at [at], decoding it first when needed. Decoding is
  /// one at a time; a newer wish replaces an older one still waiting.
  void _seek(Duration at) {
    _playhead = at;
    final cached = _frames.remove(_step(at));
    if (cached != null) {
      _frames[_step(at)] = cached;
      _wanted = null;
      setState(() => _frame = cached);
      return;
    }
    _wanted = at;
    if (!_fetching) unawaited(_fetch());
  }

  Future<void> _fetch() async {
    _fetching = true;
    try {
      while (_wanted != null && mounted) {
        final at = _wanted!;
        _wanted = null;
        try {
          final bytes = await widget.engine.frame(
            widget.path,
            at,
            maxSide: _frameSide,
          );
          final (image, _) = await decodePicture(bytes);
          if (!mounted) {
            image.dispose();
            return;
          }
          _frames[_step(at)] = image;
          while (_frames.length > _frameCacheSize) {
            final oldest = _frames.keys.first;
            final old = _frames.remove(oldest);
            if (!identical(old, _frame)) old?.dispose();
          }
          // The playhead may have moved on while this frame decoded; it
          // is still the closest one to show.
          setState(() => _frame = image);
          if (_appear.value == 0) unawaited(_appear.forward());
        } on Object {
          if (_frame == null && mounted) setState(() => _loadFailed = true);
        }
      }
    } finally {
      _fetching = false;
    }
  }

  // Editing.

  void _trim(Duration start, Duration end) {
    final startMoved = start != _edit.start;
    final edit = _edit.copyWith(
      start: start,
      end: end >= _duration ? null : end,
    );
    final cover = _edit.cover;
    setState(() {
      _edit = cover != null && (cover < start || cover > end)
          ? edit.copyWith(cover: null)
          : edit;
    });
    // The frame follows the handle that moved.
    _seek(startMoved ? start : end);
  }

  void _toggleMute() {
    if (_saving || _info == null) return;
    setState(() => _edit = _edit.copyWith(muted: !_edit.muted));
  }

  bool get _playheadIsCover {
    final cover = _edit.cover;
    return cover != null && (cover - _playhead).abs() < _frameStep;
  }

  void _toggleCover() {
    if (_saving || _info == null) return;
    setState(
      () => _edit = _edit.copyWith(cover: _playheadIsCover ? null : _playhead),
    );
  }

  void _stepBy(Duration delta) {
    if (_info == null) return;
    var at = _playhead + delta;
    if (at < _edit.start) at = _edit.start;
    if (at > _end) at = _end;
    setState(() => _seek(at));
  }

  // Leaving.

  void _cancel() {
    if (_saving) return;
    Navigator.of(context).pop();
  }

  Future<void> _done() async {
    final info = _info;
    if (_saving || info == null) return;
    if (_edit.isIdentity) {
      Navigator.of(context).pop(
        VideoEditResult(
          path: widget.path,
          originalPath: widget.path,
          edit: _edit,
          width: info.width,
          height: info.height,
          duration: info.duration,
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final out = await widget.engine.export(
        widget.path,
        _edit,
        outputDirectory: widget.outputDirectory,
      );
      if (!mounted) return;
      Navigator.of(context).pop(
        VideoEditResult(
          path: out.path,
          originalPath: widget.path,
          edit: _edit,
          width: out.width,
          height: out.height,
          duration: out.duration,
          coverPath: _edit.cover == null ? null : out.coverPath,
          thumbnailPath: out.thumbnailPath,
        ),
      );
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = MediaEditorStrings.of(context);
    final ctrl = defaultTargetPlatform != TargetPlatform.macOS;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
        const SingleActivator(LogicalKeyboardKey.enter): _done,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _done,
        const SingleActivator(LogicalKeyboardKey.keyM): _toggleMute,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _stepBy(const Duration(seconds: -1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _stepBy(const Duration(seconds: 1)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
            _stepBy(const Duration(milliseconds: -100)),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
            _stepBy(const Duration(milliseconds: 100)),
        SingleActivator(LogicalKeyboardKey.keyM, meta: !ctrl, control: ctrl):
            _toggleMute,
      },
      child: Focus(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(child: EditorBackdrop(colors: c)),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 32, 32, 112),
                  child: _buildStage(context),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Center(child: _bar(c, s)),
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
    final frame = _frame;
    if (frame == null) return const SizedBox.expand();
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, _) {
        final appear = _ease.transform(_appear.value);
        return Opacity(
          opacity: appear,
          child: Transform.scale(
            scale: ui.lerpDouble(0.97, 1, appear),
            child: CustomPaint(
              size: Size.infinite,
              painter: _FramePainter(frame),
            ),
          ),
        );
      },
    );
  }

  Widget _bar(MgColors c, MediaEditorStrings s) {
    final info = _info;
    final ready = info != null && !_saving;
    final length = _edit.lengthIn(_duration);
    final readout = mgTextStyle(
      c,
      size: MgType.caption,
      height: 1,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          MgTextButton(label: s.cancel, onPressed: _saving ? null : _cancel),
          const SizedBox(width: 8),
          MgIconButton(
            icon: _edit.muted ? MgIcons.muted : MgIcons.volume,
            tooltip: _edit.muted ? s.unmute : s.mute,
            selected: _edit.muted,
            onPressed: ready && info.hasAudio ? _toggleMute : null,
          ),
          MgIconButton(
            icon: EditorIcons.cover,
            tooltip: _playheadIsCover ? s.coverFrame : s.setCover,
            selected: _playheadIsCover,
            onPressed: ready ? _toggleCover : null,
          ),
          const EditorDivider(),
          Filmstrip(
            duration: _duration,
            start: _edit.start,
            end: _end,
            playhead: _playhead,
            cover: _edit.cover,
            frames: _thumbs,
            width: _stripWidth,
            height: _stripHeight,
            onScrub: ready ? (at) => setState(() => _seek(at)) : (_) {},
            onTrim: ready ? _trim : (_, _) {},
            onTrimEnd: () {},
          ),
          const EditorDivider(),
          SizedBox(
            width: 118,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${formatTime(_edit.start)} – ${formatTime(_end)}',
                  style: readout.copyWith(color: c.fg),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(length.inMilliseconds / 1000).toStringAsFixed(1)} '
                  '${s.secondsShort}',
                  style: readout.copyWith(color: c.fg2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
    );
  }
}

/// [t] as `m:ss.d`.
String formatTime(Duration t) {
  final tenths = (t.inMilliseconds / 100).round();
  final minutes = tenths ~/ 600;
  final seconds = (tenths ~/ 10) % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.${tenths % 10}';
}

/// Draws one frame fitted inside the stage.
class _FramePainter extends CustomPainter {
  _FramePainter(this.frame);

  final ui.Image frame;

  @override
  void paint(Canvas canvas, Size size) {
    final source = Size(frame.width.toDouble(), frame.height.toDouble());
    final dest = fitInside(source, Offset.zero & size);
    canvas.drawImageRect(
      frame,
      Offset.zero & source,
      dest,
      Paint()
        ..filterQuality = FilterQuality.high
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.frame != frame;
}
