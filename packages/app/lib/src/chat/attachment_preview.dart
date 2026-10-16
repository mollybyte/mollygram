import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../media/native_video_engine.dart';
import '../secret/secret_chat.dart' show selfDestructLabel;
import 'describe.dart';
import 'schedule_picker.dart';
import 'sticker_picker.dart';

/// What the user confirmed in [showAttachmentPreview].
/// What the preview sends back: the files, their caption, and whether
/// they go without sound or at a later time.
typedef AttachmentChoice = ({
  List<OutgoingFile> files,
  String caption,
  bool silent,
  td.MessageSchedulingState? schedule,
});

/// Shows the files about to be sent, with a caption field and, for photos
/// and videos, the choice to send them untouched as files or hidden
/// behind a spoiler, and in a private chat a self-destruct timer. [caption]
/// starts with the composer's draft. Completes with null when cancelled.
Future<AttachmentChoice?> showAttachmentPreview(
  BuildContext context, {
  required List<String> paths,
  String caption = '',
  bool allowSelfDestruct = false,
  bool allowSendWhenOnline = false,
}) => showMgSheet<AttachmentChoice>(
  context,
  _Preview(
    files: [
      for (final path in paths)
        OutgoingFile(path: path, kind: outgoingKindOf(path)),
    ],
    caption: caption,
    allowSelfDestruct: allowSelfDestruct,
    allowSendWhenOnline: allowSendWhenOnline,
  ),
  barrierColor: const Color(0x33000000),
);

class _Preview extends StatefulWidget {
  const _Preview({
    required this.files,
    required this.caption,
    required this.allowSelfDestruct,
    required this.allowSendWhenOnline,
  });

  final List<OutgoingFile> files;
  final String caption;

  /// Whether a self-destruct timer is offered: in private chats only.
  final bool allowSelfDestruct;

  /// Whether the send menu offers "Send when online": private chats with
  /// a person.
  final bool allowSendWhenOnline;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final _caption = TextEditingController(text: widget.caption);
  final _focus = FocusNode();
  late final _items = _mediaFirst(widget.files);
  var _asFiles = false;
  var _grouped = true;
  int? _dragging;
  var _spoiler = false;
  var _selfDestruct = 0;

  /// The timers offered, in seconds; view once first after Off.
  static const _timers = [0, OutgoingFile.viewOnce, 3, 5, 10, 30, 60];

  /// Photos and videos the user edited, by their original path.
  final _edited = <String, MediaEditResult>{};
  final _editedVideos = <String, VideoEditResult>{};
  static const _videoEngine = NativeVideoEngine();

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _caption.dispose();
    _focus.dispose();
    super.dispose();
  }

  List<OutgoingFile> get _files => [
    for (final file in _items)
      _asFiles && file.isMedia
          ? file.asDocument()
          : _withEdit(file).copyWith(
              alone: !_grouped,
              spoiler: _spoiler && file.isMedia,
              selfDestruct: file.isMedia ? _selfDestruct : 0,
            ),
  ];

  String _timerLabel(AppLocalizations l10n, int seconds) => switch (seconds) {
    OutgoingFile.viewOnce => l10n.viewOnce,
    _ => selfDestructLabel(seconds, l10n),
  };

  Future<void> _pickTimer(BuildContext anchor) async {
    final l10n = AppLocalizations.of(context);
    await showMgDropdown(
      context,
      anchor: mgAnchorOf(anchor),
      items: [
        for (final seconds in _timers)
          MgMenuItem(
            label: _timerLabel(l10n, seconds),
            onSelected: () => setState(() => _selfDestruct = seconds),
          ),
      ],
    );
  }

  OutgoingFile _withEdit(OutgoingFile file) {
    final video = _editedVideos[file.path];
    if (video != null && video.isEdited) {
      return file.copyWith(
        path: video.path,
        width: video.width,
        height: video.height,
        duration: video.duration.inSeconds,
        thumbnail: video.thumbnailPath,
        cover: video.coverPath,
      );
    }
    final edit = _edited[file.path];
    if (edit == null || !edit.isEdited) return file;
    return OutgoingFile(
      path: edit.path,
      kind: file.kind,
      width: edit.width,
      height: edit.height,
    );
  }

  /// Photos and videos first, each group in its own order, as the tray
  /// lists them, so the order shown is the order sent.
  static List<OutgoingFile> _mediaFirst(List<OutgoingFile> files) => [
    for (final file in files)
      if (_isVisual(file)) file,
    for (final file in files)
      if (!_isVisual(file)) file,
  ];

  static bool _isVisual(OutgoingFile file) =>
      file.kind == OutgoingKind.photo || file.kind == OutgoingKind.video;

  void _remove(int index) {
    // The last one stays: an empty tray has nothing to send.
    if (_items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _items.removeAt(index));
  }

  void _move(int from, int to) {
    if (from == to) return;
    setState(() {
      _items.insert(to, _items.removeAt(from));
      _items.replaceRange(0, _items.length, _mediaFirst(_items));
    });
  }

  Future<void> _addMore() async {
    final picked = await openFiles();
    if (!mounted || picked.isEmpty) return;
    setState(() {
      for (final file in picked) {
        if (_items.any((item) => item.path == file.path)) continue;
        _items.add(
          OutgoingFile(path: file.path, kind: outgoingKindOf(file.path)),
        );
      }
      _items.replaceRange(0, _items.length, _mediaFirst(_items));
    });
    _focus.requestFocus();
  }

  Future<void> _edit(OutgoingFile file) async {
    if (file.kind == OutgoingKind.video) {
      final previous = _editedVideos[file.path];
      final result = await showVideoEditor(
        context,
        path: file.path,
        engine: _videoEngine,
        initial: previous?.edit ?? const VideoEdit(),
      );
      if (result == null || !mounted) return;
      setState(() => _editedVideos[file.path] = result);
      _focus.requestFocus();
      return;
    }
    final previous = _edited[file.path];
    final result = await showMediaEditor(
      context,
      path: file.path,
      initial: previous?.edit ?? const MediaEdit(),
      stickerPicker: showStickerPicker,
    );
    if (result == null || !mounted) return;
    setState(() => _edited[file.path] = result);
    _focus.requestFocus();
  }

  void _send({bool silent = false, td.MessageSchedulingState? schedule}) =>
      Navigator.of(context).pop((
        files: _files,
        caption: _caption.text,
        silent: silent,
        schedule: schedule,
      ));

  /// A right click on Send: without sound, or at a day and time, as the
  /// composer's send button offers.
  Future<void> _sendMenu(Offset position) async {
    final l10n = AppLocalizations.of(context);
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.sendWithoutSound,
          icon: MgIcons.muted,
          onSelected: () => _send(silent: true),
        ),
        MgMenuItem(
          label: l10n.scheduleMessage,
          icon: MgIcons.recent,
          onSelected: () => unawaited(_schedule()),
        ),
        if (widget.allowSendWhenOnline)
          MgMenuItem(
            label: l10n.sendWhenOnline,
            icon: MgIcons.profile,
            onSelected: () => _send(
              schedule: const td.MessageSchedulingStateSendWhenOnline(),
            ),
          ),
      ],
    );
  }

  Future<void> _schedule() async {
    final when = await pickScheduleTime(context);
    if (when == null || !mounted) return;
    _send(
      schedule: td.MessageSchedulingStateSendAtDate(
        sendDate: when.millisecondsSinceEpoch ~/ 1000,
        repeatPeriod: 0,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final files = _files;
    final anyMedia = _items.any((file) => file.isMedia);
    final allPhotos = files.every((file) => file.kind == OutgoingKind.photo);
    final style = mgTextStyle(c, size: MgType.title);
    final media = [
      for (final (i, file) in files.indexed)
        if (file.kind == OutgoingKind.photo || file.kind == OutgoingKind.video)
          (i, file),
    ];
    final others = [
      for (final (i, file) in files.indexed)
        if (file.kind != OutgoingKind.photo && file.kind != OutgoingKind.video)
          (i, file),
    ];
    final single = media.length == 1 && others.isEmpty;
    Widget tile((int, OutgoingFile) entry, {required double? side}) {
      final (i, file) = entry;
      return _Reorderable(
        key: ValueKey('tile-${file.path}'),
        index: i,
        dragging: _dragging,
        onDragStarted: () => setState(() => _dragging = i),
        onDragEnd: () => setState(() => _dragging = null),
        onMove: _move,
        removeTooltip: l10n.removeFromSend,
        onRemove: () => _remove(i),
        child: switch (file.kind) {
          OutgoingKind.photo => _Thumbnail(
            key: ValueKey(file.path),
            side: side,
            image: Image.file(
              File(file.path),
              fit: side == null ? BoxFit.contain : BoxFit.cover,
              cacheWidth: side == null ? 900 : 300,
              errorBuilder: (context, _, _) => ColoredBox(color: c.field),
            ),
            onEdit: () => _edit(_items[i]),
          ),
          _ => _VideoThumbnail(
            key: ValueKey(file.path),
            side: side,
            path: file.path,
            engine: _videoEngine,
            onEdit: () => _edit(_items[i]),
          ),
        },
      );
    }

    const gap = 6.0;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: 440,
        maxWidth: 440,
        maxHeight: MediaQuery.sizeOf(context).height - 48,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.solid(c.card),
          borderRadius: BorderRadius.circular(MgRadius.popover),
          border: Border.all(color: c.separator, width: 0.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 40,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      allPhotos
                          ? l10n.attachPhotosTitle(files.length)
                          : l10n.attachTitle(files.length),
                      style: mgTextStyle(
                        c,
                        size: MgType.title,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  MgIconButton(
                    icon: MgIcons.close,
                    iconSize: 14,
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (single)
                          Center(child: tile(media.single, side: null))
                        else if (media.isNotEmpty)
                          LayoutBuilder(
                            builder: (context, box) {
                              final columns = media.length == 2 ? 2 : 3;
                              final side =
                                  (box.maxWidth - gap * (columns - 1)) /
                                  columns;
                              return Wrap(
                                spacing: gap,
                                runSpacing: gap,
                                children: [
                                  for (final entry in media)
                                    tile(entry, side: side),
                                ],
                              );
                            },
                          ),
                        if (media.isNotEmpty && others.isNotEmpty)
                          const SizedBox(height: 10),
                        for (final (n, (i, file)) in others.indexed) ...[
                          if (n > 0) const SizedBox(height: 8),
                          _Reorderable(
                            key: ValueKey('line-${file.path}'),
                            index: i,
                            dragging: _dragging,
                            onDragStarted: () => setState(() => _dragging = i),
                            onDragEnd: () => setState(() => _dragging = null),
                            onMove: _move,
                            removeTooltip: l10n.removeFromSend,
                            onRemove: () => _remove(i),
                            child: _FileLine(file: file),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: MgTextButton(
                  label: l10n.attachAddMore,
                  onPressed: _addMore,
                ),
              ),
              if (media.length > 1 && !_asFiles)
                _OptionRow(
                  label: l10n.groupAlbum,
                  value: _grouped,
                  onChanged: (value) => setState(() => _grouped = value),
                ),
              if (anyMedia) ...[
                const SizedBox(height: 4),
                _OptionRow(
                  label: l10n.sendAsFiles,
                  value: _asFiles,
                  onChanged: (value) => setState(() => _asFiles = value),
                ),
                // A file can't hide behind a spoiler or burn; only media can.
                if (!_asFiles) ...[
                  _OptionRow(
                    label: l10n.hideWithSpoiler,
                    value: _spoiler,
                    onChanged: (value) => setState(() => _spoiler = value),
                  ),
                  if (widget.allowSelfDestruct)
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Text(l10n.selfDestructTitle, style: mgTextStyle(c)),
                          const Spacer(),
                          Builder(
                            builder: (anchor) => MgTextButton(
                              label: _timerLabel(l10n, _selfDestruct),
                              onPressed: () => _pickTimer(anchor),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: c.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Focus(
                  onKeyEvent: _onKey,
                  skipTraversal: true,
                  child: TextField(
                    controller: _caption,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    style: style,
                    decoration: InputDecoration.collapsed(
                      hintText: l10n.captionHint,
                      hintStyle: style.copyWith(color: c.fg2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  MgTextButton(
                    label: l10n.cancel,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onSecondaryTapUp: (details) =>
                        unawaited(_sendMenu(details.globalPosition)),
                    child: MgPrimaryButton(
                      label: l10n.send,
                      height: 30,
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An option: its label on the left and a switch on the right; the whole
/// row toggles it.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Semantics(
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                Expanded(child: Text(label, style: mgTextStyle(c))),
                MgSwitch(value: value),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatefulWidget {
  const _Thumbnail({
    super.key,
    required this.image,
    required this.onEdit,
    this.badge,
    this.side,
  });

  final Widget image;

  /// The edge of a square tile in a grid; null shows the picture whole,
  /// in its own proportions, as large as the dialog allows.
  final double? side;

  /// Null hides the edit button.
  final VoidCallback? onEdit;

  /// Shown in the bottom left corner, such as a play mark on a video.
  final Widget? badge;

  @override
  State<_Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<_Thumbnail> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final side = widget.side;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(side == null ? 12 : 10),
        child: _sized(
          Stack(
            fit: side == null ? StackFit.loose : StackFit.expand,
            children: [
              if (side == null)
                widget.image
              else
                Positioned.fill(child: widget.image),
              if (widget.badge != null)
                Positioned(left: 8, bottom: 8, child: widget.badge!),
              if (widget.onEdit != null)
                Positioned(
                  right: 8,
                  top: 8,
                  child: AnimatedOpacity(
                    opacity: _hover ? 1 : 0,
                    duration: const Duration(milliseconds: 120),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.mediaPill,
                        shape: BoxShape.circle,
                      ),
                      child: MgIconButton(
                        icon: EditorIcons.edit,
                        tooltip: MediaEditorStrings.of(context).edit,
                        onPressed: widget.onEdit,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sized(Widget child) {
    final side = widget.side;
    return side == null
        ? ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: child,
          )
        : SizedBox.square(dimension: side, child: child);
  }
}

/// A video's first frame with a play mark; the edit button appears once
/// the frame is read, since the editor needs the same engine.
class _VideoThumbnail extends StatefulWidget {
  const _VideoThumbnail({
    super.key,
    required this.path,
    required this.engine,
    required this.onEdit,
    this.side,
  });

  final double? side;
  final String path;
  final VideoEngine engine;
  final VoidCallback onEdit;

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  Uint8List? _frame;
  var _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final frame = await widget.engine.frame(
        widget.path,
        Duration.zero,
        maxSide: 320,
      );
      if (mounted) setState(() => _frame = frame);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final frame = _frame;
    return _Thumbnail(
      side: widget.side,
      image: frame == null
          ? ColoredBox(
              color: c.field,
              child: _failed
                  ? Center(child: MgIcon(MgIcons.video, size: 24, color: c.fg2))
                  : null,
            )
          : Image.memory(frame, fit: BoxFit.cover, gaplessPlayback: true),
      onEdit: frame == null ? null : widget.onEdit,
      badge: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: c.mediaPill, shape: BoxShape.circle),
        child: MgIcon(MgIcons.play, size: 12, color: Colors.white),
      ),
    );
  }
}

class _FileLine extends StatelessWidget {
  const _FileLine({required this.file});

  final OutgoingFile file;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = file.path.split(RegExp(r'[/\\]')).last;
    int? size;
    try {
      size = File(file.path).lengthSync();
    } on FileSystemException {
      size = null;
    }
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: MgIcon(MgIcons.file, size: 18, color: c.onAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, weight: FontWeight.w500),
                ),
                if (size != null)
                  Text(
                    formatFileSize(l10n, size, locale),
                    style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A tray item that can be dragged onto another to take its place, and
/// removed with a button that appears on hover.
class _Reorderable extends StatefulWidget {
  const _Reorderable({
    super.key,
    required this.index,
    required this.dragging,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onMove,
    required this.onRemove,
    required this.removeTooltip,
    required this.child,
  });

  final int index;

  /// The index being dragged, if any item is.
  final int? dragging;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final void Function(int from, int to) onMove;
  final VoidCallback onRemove;
  final String removeTooltip;
  final Widget child;

  @override
  State<_Reorderable> createState() => _ReorderableState();
}

class _ReorderableState extends State<_Reorderable> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final dragging = widget.dragging == widget.index;
    final body = MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedOpacity(
        opacity: dragging ? 0.35 : 1,
        duration: MgMotion.fast,
        child: Stack(
          children: [
            widget.child,
            Positioned(
              left: 6,
              top: 6,
              child: AnimatedOpacity(
                opacity: _hover && !dragging ? 1 : 0,
                duration: MgMotion.fast,
                child: IgnorePointer(
                  ignoring: !_hover,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.mediaPill,
                      shape: BoxShape.circle,
                    ),
                    child: MgIconButton(
                      icon: MgIcons.close,
                      iconSize: 12,
                      size: 24,
                      tooltip: widget.removeTooltip,
                      onPressed: widget.onRemove,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => details.data != widget.index,
      onAcceptWithDetails: (details) =>
          widget.onMove(details.data, widget.index),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: MgMotion.standard,
        curve: MgMotion.standardCurve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MgRadius.control),
          border: Border.all(
            color: candidates.isEmpty ? Colors.transparent : c.accent,
            width: 2,
          ),
        ),
        child: Draggable<int>(
          data: widget.index,
          onDragStarted: widget.onDragStarted,
          onDragEnd: (_) => widget.onDragEnd(),
          onDraggableCanceled: (_, _) => widget.onDragEnd(),
          feedback: Opacity(
            opacity: 0.85,
            child: SizedBox(
              width: 96,
              child: Material(
                type: MaterialType.transparency,
                child: widget.child,
              ),
            ),
          ),
          childWhenDragging: body,
          child: body,
        ),
      ),
    );
  }
}
