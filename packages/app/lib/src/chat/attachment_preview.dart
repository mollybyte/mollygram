import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../media/native_video_engine.dart';
import 'describe.dart';

/// What the user confirmed in [showAttachmentPreview].
typedef AttachmentChoice = ({List<OutgoingFile> files, String caption});

/// Shows the files about to be sent, with a caption field and, for photos
/// and videos, the choice to send them untouched as files. [caption]
/// starts with the composer's draft. Completes with null when cancelled.
Future<AttachmentChoice?> showAttachmentPreview(
  BuildContext context, {
  required List<String> paths,
  String caption = '',
}) => showGeneralDialog<AttachmentChoice>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: _Preview(
        files: [
          for (final path in paths)
            OutgoingFile(path: path, kind: outgoingKindOf(path)),
        ],
        caption: caption,
      ),
    ),
  ),
);

class _Preview extends StatefulWidget {
  const _Preview({required this.files, required this.caption});

  final List<OutgoingFile> files;
  final String caption;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  late final _caption = TextEditingController(text: widget.caption);
  final _focus = FocusNode();
  var _asFiles = false;

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
    for (final file in widget.files)
      _asFiles && file.isMedia ? file.asDocument() : _withEdit(file),
  ];

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
    );
    if (result == null || !mounted) return;
    setState(() => _edited[file.path] = result);
    _focus.requestFocus();
  }

  void _send() =>
      Navigator.of(context).pop((files: _files, caption: _caption.text));

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
    final anyMedia = widget.files.any((file) => file.isMedia);
    final allPhotos = files.every((file) => file.kind == OutgoingKind.photo);
    final style = mgTextStyle(c, size: MgType.title);
    return SizedBox(
      width: 420,
      child: Glass(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              allPhotos
                  ? l10n.attachPhotosTitle(files.length)
                  : l10n.attachTitle(files.length),
              style: mgTextStyle(c, weight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (i, file) in files.indexed)
                      switch (file.kind) {
                        OutgoingKind.photo => _Thumbnail(
                          key: ValueKey(file.path),
                          image: Image.file(
                            File(file.path),
                            fit: BoxFit.cover,
                            cacheWidth: 250,
                            errorBuilder: (context, _, _) =>
                                ColoredBox(color: c.field),
                          ),
                          onEdit: () => _edit(widget.files[i]),
                        ),
                        OutgoingKind.video => _VideoThumbnail(
                          key: ValueKey(file.path),
                          path: file.path,
                          engine: _videoEngine,
                          onEdit: () => _edit(widget.files[i]),
                        ),
                        _ => _FileLine(file: file),
                      },
                  ],
                ),
              ),
            ),
            if (anyMedia) ...[
              const SizedBox(height: 10),
              MergeSemantics(
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: Checkbox(
                        value: _asFiles,
                        activeColor: c.accent,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onChanged: (value) =>
                            setState(() => _asFiles = value ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _asFiles = !_asFiles),
                      child: Text(l10n.sendAsFiles, style: mgTextStyle(c)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MgTextButton(
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                MgPrimaryButton(label: l10n.send, height: 28, onPressed: _send),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A photo with an edit button that appears on hover.
class _Thumbnail extends StatefulWidget {
  const _Thumbnail({
    super.key,
    required this.image,
    required this.onEdit,
    this.badge,
  });

  final Widget image;

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
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 125,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.image,
              if (widget.badge != null)
                Positioned(left: 6, bottom: 6, child: widget.badge!),
              if (widget.onEdit != null)
                Positioned(
                  right: 6,
                  top: 6,
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
}

/// A video's first frame with a play mark; the edit button appears once
/// the frame is read, since the editor needs the same engine.
class _VideoThumbnail extends StatefulWidget {
  const _VideoThumbnail({
    super.key,
    required this.path,
    required this.engine,
    required this.onEdit,
  });

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
