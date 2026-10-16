import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../l10n/app_localizations.dart';
import '../settings/storage_page.dart' show downloadFolderOf;
import 'describe.dart';
import 'formatted_text.dart';
import 'media_gallery.dart';
import 'message_tile.dart' show SenderAvatar;
import 'td_file.dart';

export 'media_gallery.dart' show MediaViewerItem;

/// Opens [item] on its own, for media outside a chat's history.
Future<void> showMediaViewer(BuildContext context, MediaViewerItem item) =>
    _open(context, MediaGallery.single(item), store: null);

/// Opens a profile's [photos], newest first, at [index]: the viewer pages
/// through them with [title] and when each was set on top.
Future<void> showProfilePhotos(
  BuildContext context, {
  required List<ProfilePhoto> photos,
  required String title,
  int index = 0,
}) => _open(
  context,
  MediaGallery.list([
    for (final photo in photos)
      GalleryEntry(PhotoItem(photo.photo), date: photo.date),
  ], index: index),
  store: null,
  title: title,
);

/// Opens the media of [message] in the viewer, which pages through the
/// rest of the chat's photos and videos with the arrows. [onForward]
/// forwards the one on screen and [onShowInChat] scrolls to it, both once
/// the viewer has closed; [onDelete] asks over the viewer and returns
/// whether the deletion was requested, which closes the viewer.
Future<void> showChatMediaViewer(
  BuildContext context, {
  required ConversationMessage message,
  required ConversationController conversations,
  void Function(ConversationMessage message)? onForward,
  void Function(ConversationMessage message)? onShowInChat,
  MediaDeleteHandler? onDelete,
}) {
  final gallery = MediaGallery.chat(
    message,
    load: (from, {newer = 0, limit = 30}) => conversations.mediaAround(
      message.chatId,
      from,
      newer: newer,
      limit: limit,
    ),
  );
  unawaited(gallery.start());
  return _open(
    context,
    gallery,
    store: conversations.store,
    onForward: onForward,
    onShowInChat: onShowInChat,
    onDelete: onDelete,
  );
}

/// Asks whether to delete [message], over the viewer whose [context] is
/// given, and returns whether the deletion was requested.
typedef MediaDeleteHandler = Future<bool> Function(
  BuildContext context,
  ConversationMessage message,
);

Future<void> _open(
  BuildContext context,
  MediaGallery gallery, {
  required ConversationStore? store,
  String? title,
  void Function(ConversationMessage message)? onForward,
  void Function(ConversationMessage message)? onShowInChat,
  MediaDeleteHandler? onDelete,
}) async {
  ConversationMessage? forward;
  ConversationMessage? show;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      pageBuilder: (context, animation, secondary) => _MediaViewer(
        gallery: gallery,
        store: store,
        title: title,
        animation: animation,
        onForward: onForward == null
            ? null
            : (message) {
                forward = message;
                Navigator.of(context).maybePop();
              },
        onShowInChat: onShowInChat == null
            ? null
            : (message) {
                show = message;
                Navigator.of(context).maybePop();
              },
        onDelete: onDelete,
      ),
    ),
  );
  gallery.dispose();
  if (forward case final message?) onForward?.call(message);
  if (show case final message?) onShowInChat?.call(message);
}

/// The dark full-window viewer: the media in the middle, who sent it and
/// when on top, the caption and the video controls at the bottom, and
/// arrows to page through the chat's media.
class _MediaViewer extends StatefulWidget {
  const _MediaViewer({
    required this.gallery,
    required this.store,
    required this.animation,
    this.title,
    this.onForward,
    this.onShowInChat,
    this.onDelete,
  });

  final MediaGallery gallery;
  final ConversationStore? store;

  /// Whose media this is, shown on top when the entries have no message.
  final String? title;
  final Animation<double> animation;
  final void Function(ConversationMessage message)? onForward;
  final void Function(ConversationMessage message)? onShowInChat;
  final MediaDeleteHandler? onDelete;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  final _focus = FocusNode();

  /// The direction of the last page turn, for the slide between pages.
  var _direction = 1;

  /// The chrome (bars and arrows) hides while a video plays and the
  /// pointer rests.
  var _chrome = true;
  Timer? _idle;
  VideoPlayback? _playback;
  String? _notice;
  Timer? _noticeTimer;

  /// Quarter turns clockwise of the page on screen; back to 0 on a page
  /// turn.
  var _quarterTurns = 0;

  /// Whether the photo on screen is zoomed in: a two-finger swipe then
  /// pans it instead of turning the page.
  var _zoomed = false;

  /// The two-finger swipe in progress, and whether it turned the page.
  var _swipe = Offset.zero;
  var _swiped = false;

  /// How far two fingers travel sideways to turn the page.
  static const double _swipeDistance = 48;

  MediaGallery get _gallery => widget.gallery;

  @override
  void initState() {
    super.initState();
    _gallery.addListener(_changed);
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _gallery.removeListener(_changed);
    _idle?.cancel();
    _noticeTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  void _go(int delta) {
    if (delta < 0 && !_gallery.hasPrevious) return;
    if (delta > 0 && !_gallery.hasNext) return;
    setState(() {
      _direction = delta.sign;
      _playback = null;
      _quarterTurns = 0;
      _zoomed = false;
    });
    _gallery.go(delta);
    _wake();
  }

  void _rotate() {
    setState(() => _quarterTurns++);
    _wake();
  }

  void _swipeStart(PointerPanZoomStartEvent event) {
    _swipe = Offset.zero;
    _swiped = false;
  }

  void _swipeUpdate(PointerPanZoomUpdateEvent event) {
    if (_swiped || _zoomed) return;
    _swipe += event.panDelta;
    if (_swipe.dx.abs() < _swipeDistance || _swipe.dx.abs() < _swipe.dy.abs()) {
      return;
    }
    _swiped = true;
    // Natural scrolling: the content follows the fingers, so a swipe to
    // the left brings the next page.
    _go(_swipe.dx < 0 ? 1 : -1);
  }

  void _swipeEnd(PointerPanZoomEndEvent event) {
    _swipe = Offset.zero;
    _swiped = false;
  }

  void _close() => Navigator.of(context).maybePop();

  /// Asks over the viewer; a requested deletion closes it.
  Future<void> _delete() async {
    final message = _gallery.current.message;
    final onDelete = widget.onDelete;
    if (message == null || onDelete == null) return;
    final deleted = await onDelete(context, message);
    if (deleted && mounted) _close();
  }

  /// The pointer moved: show the chrome, and hide it again later while a
  /// video plays.
  void _wake() {
    if (!_chrome) setState(() => _chrome = true);
    _idle?.cancel();
    _idle = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      final playing = _playback?.state.value.playing ?? false;
      if (playing) setState(() => _chrome = false);
    });
  }

  void _show(String notice) {
    _noticeTimer?.cancel();
    setState(() => _notice = notice);
    _noticeTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  bool get _canSave => _gallery.current.message?.message.canBeSaved ?? true;

  /// The downloaded file of the page on screen, or null.
  td.File? get _file => switch (_gallery.current.item) {
    PhotoItem(:final photo) => _largest(photo)?.photo,
    VideoItem(:final video) => video.video,
    AnimationItem(:final animation) => animation.animation,
  };

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    final path = file == null ? null : downloadedPath(file);
    if (path == null || !_canSave) return;
    final name = _fileName(_gallery.current, path);
    final location = await getSaveLocation(
      suggestedName: name,
      initialDirectory: await downloadFolderOf(context),
    );
    if (location == null) return;
    try {
      await File(path).copy(location.path);
      if (mounted) _show(l10n.mediaSaved);
    } on FileSystemException {
      if (mounted) _show(l10n.mediaSaveFailed);
    }
  }

  Future<void> _copy() async {
    final l10n = AppLocalizations.of(context);
    final file = _file;
    final path = file == null ? null : downloadedPath(file);
    if (path == null || !_canSave || _gallery.current.item is! PhotoItem) {
      return;
    }
    await Pasteboard.writeImage(await File(path).readAsBytes());
    if (mounted) _show(l10n.mediaCopied);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final command =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (key == LogicalKeyboardKey.escape) {
      _close();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _go(1);
    } else if (!command && key == LogicalKeyboardKey.keyR && _rotatable) {
      _rotate();
    } else if (key == LogicalKeyboardKey.space && _playback != null) {
      unawaited(_playback!.playOrPause());
    } else if (command && key == LogicalKeyboardKey.keyS) {
      unawaited(_save());
    } else if (command && key == LogicalKeyboardKey.keyC) {
      unawaited(_copy());
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      unawaited(_delete());
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  bool get _rotatable => _gallery.current.item is! AnimationItem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entry = _gallery.current;
    final message = entry.message;
    final caption = message == null ? null : captionOf(message.content);
    final hasCaption = caption != null && caption.text.isNotEmpty;
    final isVideo = entry.item is VideoItem;
    final entries = _gallery.entries;
    final curved = CurvedAnimation(
      parent: widget.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final key = message?.id ?? -1 - _gallery.index;

    final page = _Page(
      key: ValueKey(key),
      entry: entry,
      onPlayback: (playback) {
        _playback = playback;
        playback?.state.addListener(_wakeOnPause);
      },
      onZoom: (zoomed) => _zoomed = zoomed,
    );

    // The route has no Material above it: without a text style of its
    // own, every label would come out large and underlined.
    return DefaultTextStyle(
      style: const TextStyle(
        color: _onDark,
        fontSize: MgType.body,
        height: 1.35,
        decoration: TextDecoration.none,
      ),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => _wake(),
          child: Listener(
            onPointerPanZoomStart: _swipeStart,
            onPointerPanZoomUpdate: _swipeUpdate,
            onPointerPanZoomEnd: _swipeEnd,
            child: Stack(
              children: [
                // The backdrop: a click on it closes the viewer.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: FadeTransition(
                      opacity: curved,
                      child: const ColoredBox(color: Color(0xF0080809)),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      72,
                      68,
                      72,
                      (isVideo ? 76 : 24) +
                          (hasCaption ? 56 : 0) +
                          (entries.length > 1 ? _Thumbnails.height + 12 : 0),
                    ),
                    child: ScaleTransition(
                      scale: Tween(begin: 0.94, end: 1.0).animate(curved),
                      child: FadeTransition(
                        opacity: curved,
                        child: _Rotated(
                          quarterTurns: _quarterTurns,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final incoming = child.key == ValueKey(key);
                              final offset = Tween(
                                begin: Offset(
                                  0.06 * _direction * (incoming ? 1 : -1),
                                  0,
                                ),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: offset,
                                  child: child,
                                ),
                              );
                            },
                            child: page,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _Chrome(
                  visible: _chrome,
                  animation: curved,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _TopBar(
                          message: message,
                          store: widget.store,
                          title: widget.title,
                          date: entry.date,
                          counter: entries.length > 1
                              ? l10n.mediaCounter(
                                  _gallery.index + 1,
                                  entries.length,
                                )
                              : null,
                          actions: [
                            if (_rotatable)
                              _BarButton(
                                icon: _rotateIcon,
                                label: l10n.mediaRotate,
                                onTap: _rotate,
                              ),
                            if (_canSave && entry.item is PhotoItem)
                              _BarButton(
                                icon: MgIcons.copy,
                                label: l10n.mediaCopy,
                                onTap: () => unawaited(_copy()),
                              ),
                            if (_canSave)
                              _BarButton(
                                icon: MgIcons.download,
                                label: l10n.mediaSave,
                                onTap: () => unawaited(_save()),
                              ),
                            if (_canSave &&
                                message != null &&
                                widget.onForward != null)
                              _BarButton(
                                icon: MgIcons.forward,
                                label: l10n.menuForward,
                                onTap: () => widget.onForward!(message),
                              ),
                            if (message != null && widget.onShowInChat != null)
                              _BarButton(
                                icon: MgIcons.chat,
                                label: l10n.showInChat,
                                onTap: () => widget.onShowInChat!(message),
                              ),
                            if (message != null && widget.onDelete != null)
                              _BarButton(
                                icon: MgIcons.trash,
                                label: l10n.menuDelete,
                                onTap: () => unawaited(_delete()),
                              ),
                            _BarButton(
                              icon: MgIcons.close,
                              label: l10n.close,
                              onTap: _close,
                            ),
                          ],
                        ),
                      ),
                      if (_gallery.hasPrevious)
                        Positioned(
                          left: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _Arrow(
                              icon: MgIcons.back,
                              label: l10n.mediaPrevious,
                              onTap: () => _go(-1),
                            ),
                          ),
                        ),
                      if (_gallery.hasNext)
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: _Arrow(
                              icon: MgIcons.chevron,
                              label: l10n.mediaNext,
                              onTap: () => _go(1),
                            ),
                          ),
                        ),
                      Positioned(
                        left: 72,
                        right: 72,
                        bottom: 18,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasCaption)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 640,
                                    maxHeight: 48,
                                  ),
                                  child: DefaultTextStyle.merge(
                                    style: const TextStyle(
                                      color: _onDark,
                                      fontSize: MgType.body,
                                      height: 1.35,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    child: FormattedTextView(
                                      text: caption,
                                      style: const TextStyle(
                                        color: _onDark,
                                        fontSize: MgType.body,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_playback case final playback? when isVideo)
                              _VideoControls(playback: playback),
                            if (entries.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _Thumbnails(
                                  key: const ValueKey('viewer-thumbnails'),
                                  gallery: _gallery,
                                  onPick: (index) =>
                                      _go(index - _gallery.index),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (_notice case final notice?)
                  Positioned(
                    top: 72,
                    left: 0,
                    right: 0,
                    child: Center(child: _Notice(notice)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pausing a video brings the chrome back.
  void _wakeOnPause() {
    final playing = _playback?.state.value.playing ?? false;
    if (!playing && !_chrome && mounted) setState(() => _chrome = true);
  }
}

td.PhotoSize? _largest(td.Photo photo) {
  if (photo.sizes.isEmpty) return null;
  return photo.sizes.reduce((a, b) => a.width >= b.width ? a : b);
}

td.PhotoSize? _smallest(td.Photo photo) {
  if (photo.sizes.isEmpty) return null;
  return photo.sizes.reduce((a, b) => a.width <= b.width ? a : b);
}

/// A name for the saved copy: the file's own name, or the kind and when it
/// was sent.
String _fileName(GalleryEntry entry, String path) {
  final extension = path.contains('.') ? path.split('.').last : '';
  switch (entry.item) {
    case VideoItem(:final video) when video.fileName.isNotEmpty:
      return video.fileName;
    case AnimationItem(:final animation) when animation.fileName.isNotEmpty:
      return animation.fileName;
    default:
  }
  final date = entry.message == null
      ? DateTime.now()
      : DateTime.fromMillisecondsSinceEpoch(entry.message!.date * 1000);
  final stamp = DateFormat('yyyy-MM-dd HH.mm.ss').format(date);
  final kind = entry.item is PhotoItem ? 'Photo' : 'Video';
  return extension.isEmpty ? '$kind $stamp' : '$kind $stamp.$extension';
}

/// The chat's media as a strip of small thumbnails under the page, the
/// one on screen a little larger with a light frame and kept centered as
/// the pages turn; a click on another goes to it.
class _Thumbnails extends StatefulWidget {
  const _Thumbnails({super.key, required this.gallery, required this.onPick});

  final MediaGallery gallery;
  final void Function(int index) onPick;

  static const double height = 52;
  static const double side = 40;
  static const double gap = 6;

  @override
  State<_Thumbnails> createState() => _ThumbnailsState();
}

class _ThumbnailsState extends State<_Thumbnails> {
  final _scroll = ScrollController();
  int? _index;
  int? _messageId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _center(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant _Thumbnails oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(animate: true));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the page on screen to the middle: smoothly when the page
  /// turned, at once when the same page shifted because more media loaded
  /// before it.
  void _center({required bool animate}) {
    if (!mounted || !_scroll.hasClients) return;
    final gallery = widget.gallery;
    final index = gallery.index;
    final id = gallery.current.message?.id;
    final samePage = id == null ? index == _index : id == _messageId;
    if (index == _index && samePage) return;
    _index = index;
    _messageId = id;
    final target = (index * (_Thumbnails.side + _Thumbnails.gap)).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    if (!animate || samePage || MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(target);
    } else {
      unawaited(
        _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gallery = widget.gallery;
    final entries = gallery.entries;
    return SizedBox(
      height: _Thumbnails.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = math.max(
            0.0,
            (constraints.maxWidth - _Thumbnails.side) / 2,
          );
          return ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: inset),
            itemCount: entries.length,
            itemBuilder: (context, index) => _Thumbnail(
              key: ValueKey('viewer-thumbnail-$index'),
              entry: entries[index],
              current: index == gallery.index,
              onTap: () => widget.onPick(index),
            ),
          );
        },
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    super.key,
    required this.entry,
    required this.current,
    required this.onTap,
  });

  final GalleryEntry entry;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: animate ? 200 : 0);
    final side = _Thumbnails.side;
    final image = switch (entry.item) {
      PhotoItem(:final photo) => TdImage(
        file: _smallest(photo)?.photo,
        minithumbnail: photo.minithumbnail,
        cacheWidth: (side * 1.3 * MediaQuery.devicePixelRatioOf(context))
            .round(),
      ),
      VideoItem(:final video) => TdImage(
        thumbnail: video.thumbnail?.file,
        minithumbnail: video.minithumbnail,
      ),
      AnimationItem(:final animation) => TdImage(
        thumbnail: animation.thumbnail?.file,
        minithumbnail: animation.minithumbnail,
      ),
    };
    return Padding(
      padding: EdgeInsets.only(right: _Thumbnails.gap),
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              scale: current ? 1.25 : 1,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: duration,
                width: side,
                height: side,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: current
                        ? const Color(0xFFF2F2F5)
                        : const Color(0x00000000),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5.5),
                  child: AnimatedOpacity(
                    duration: duration,
                    opacity: current ? 1 : 0.7,
                    child: image,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades the bars and arrows in with the viewer and out while a video
/// plays undisturbed.
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.visible,
    required this.animation,
    required this.child,
  });

  final bool visible;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: FadeTransition(
      opacity: animation,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),
      ),
    ),
  );
}

const _onDark = Color(0xFFF2F2F5);
const _onDarkSecondary = Color(0x99F2F2F5);

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.message,
    required this.store,
    required this.actions,
    this.title,
    this.date,
    this.counter,
  });

  final ConversationMessage? message;
  final ConversationStore? store;

  /// For an entry with no message: whose photo it is and when it was set.
  final String? title;
  final int? date;
  final String? counter;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final message = this.message;
    final store = this.store;
    Widget? who;
    final (String? name, int? seconds, td.File? photo) = switch ((
      message,
      store,
    )) {
      (final message?, final store?) => (
        nameOfSender(l10n, store, message.sender),
        message.date,
        store.photoOf(message.sender),
      ),
      _ => (title, date, null),
    };
    if (name != null) {
      final when = seconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      who = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null) ...[
            SenderAvatar(name: name, photo: photo, size: 32),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _onDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (when != null)
                  Text(
                    '${DateFormat.yMMMMd(locale).format(when)}, '
                    '${DateFormat.Hm(locale).format(when)}',
                    maxLines: 1,
                    style: const TextStyle(
                      color: _onDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              // Clear of the window's traffic lights, which end about 75 px
              // in, with a comfortable gap before the avatar.
              padding: const EdgeInsets.only(left: 80, right: 220),
              child: who ?? const SizedBox.shrink(),
            ),
          ),
          if (counter case final counter?)
            Text(
              counter,
              style: const TextStyle(
                color: _onDarkSecondary,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      ),
    );
  }
}

/// A round button on the viewer's dark chrome.
class _BarButton extends StatefulWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = 34,
    this.iconSize = 18,
  });

  final MgIconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  State<_BarButton> createState() => _BarButtonState();
}

class _BarButtonState extends State<_BarButton> {
  var _hover = false;
  var _down = false;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: widget.label,
    waitDuration: const Duration(milliseconds: 600),
    child: Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = _down = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _down ? 0.92 : 1,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: widget.size,
              height: widget.size,
              margin: const EdgeInsets.only(left: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hover
                    ? const Color(0x26FFFFFF)
                    : const Color(0x00FFFFFF),
              ),
              child: MgIcon(widget.icon, size: widget.iconSize, color: _onDark),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The previous and next arrows at the sides.
class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.label, required this.onTap});

  final MgIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0x1FFFFFFF),
    ),
    child: _BarButton(
      icon: icon,
      label: label,
      onTap: onTap,
      size: 44,
      iconSize: 22,
    ),
  );
}

/// A short confirmation, such as "Saved".
class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 160),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, -6 * (1 - t)), child: child),
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC2A2A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: const TextStyle(color: _onDark, fontSize: 13)),
    ),
  );
}

/// A circular arrow, for the rotate button.
const _rotateIcon = MgIconData(
  'rotate',
  '<path d="M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5"/>',
);

/// Turns [child] by [quarterTurns] clockwise, gliding between turns, and
/// shrinks it so a sideways page still fits the box it was laid out for.
class _Rotated extends StatelessWidget {
  const _Rotated({required this.quarterTurns, required this.child});

  final int quarterTurns;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final sideways = quarterTurns.isOdd;
      final fit = size.isEmpty || !sideways
          ? 1.0
          : math.min(size.width / size.height, size.height / size.width);
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260);
      return AnimatedScale(
        scale: fit,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedRotation(
          turns: quarterTurns / 4,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: child,
        ),
      );
    },
  );
}

/// One page: a zoomable photo, a video or a looping GIF.
class _Page extends StatelessWidget {
  const _Page({
    super.key,
    required this.entry,
    required this.onPlayback,
    required this.onZoom,
  });

  final GalleryEntry entry;

  /// The video's playback once it opens, for the controls; null for
  /// photos and GIFs.
  final ValueChanged<VideoPlayback?> onPlayback;

  /// Whether the photo is zoomed in, as it changes.
  final ValueChanged<bool> onZoom;

  @override
  Widget build(BuildContext context) => switch (entry.item) {
    PhotoItem(:final photo) => _Photo(photo, onZoom: onZoom),
    VideoItem(:final video) => _Video(
      file: video.video,
      width: video.width,
      height: video.height,
      cover: TdImage(
        thumbnail: video.thumbnail?.file,
        minithumbnail: video.minithumbnail,
        fit: BoxFit.contain,
        background: const Color(0x00000000),
      ),
      onPlayback: onPlayback,
    ),
    AnimationItem(:final animation) => _Video(
      file: animation.animation,
      width: animation.width,
      height: animation.height,
      loop: true,
      muted: true,
      cover: TdImage(
        thumbnail: animation.thumbnail?.file,
        minithumbnail: animation.minithumbnail,
        fit: BoxFit.contain,
        background: const Color(0x00000000),
      ),
      onPlayback: (_) => onPlayback(null),
    ),
  };
}

/// A photo that zooms with a pinch, the scroll wheel or a double click,
/// and pans while zoomed.
class _Photo extends StatefulWidget {
  const _Photo(this.photo, {required this.onZoom});

  final td.Photo photo;
  final ValueChanged<bool> onZoom;

  @override
  State<_Photo> createState() => _PhotoState();
}

class _PhotoState extends State<_Photo> with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final _zoom = AnimationController(vsync: this);
  Animation<Matrix4>? _tween;
  Offset _doubleTapAt = Offset.zero;

  static const double _doubleTapScale = 2.5;

  var _zoomed = false;

  @override
  void initState() {
    super.initState();
    _zoom.addListener(() {
      if (_tween case final tween?) _transform.value = tween.value;
    });
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed == _zoomed) return;
      _zoomed = zoomed;
      widget.onZoom(zoomed);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce motion (the system's or the app's, see ReduceMotionScope):
    // the zoom jumps instead of gliding.
    _zoom.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 260);
  }

  @override
  void dispose() {
    _zoom.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    final Matrix4 target;
    if (zoomed) {
      target = Matrix4.identity();
    } else {
      final p = _doubleTapAt;
      target = Matrix4.identity()
        ..translateByDouble(
          -p.dx * (_doubleTapScale - 1),
          -p.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    _tween = Matrix4Tween(
      begin: _transform.value,
      end: target,
    ).animate(CurvedAnimation(parent: _zoom, curve: Curves.easeOutCubic));
    unawaited(_zoom.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final sizes = [...photo.sizes]..sort((a, b) => a.width.compareTo(b.width));
    if (sizes.isEmpty) return const SizedBox.shrink();
    final largest = sizes.last;
    return Center(
      child: AspectRatio(
        aspectRatio: largest.width / math.max(1, largest.height),
        child: GestureDetector(
          // Clicks on the photo don't reach the backdrop, which closes.
          onTap: () {},
          onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
          onDoubleTap: _toggleZoom,
          child: InteractiveViewer(
            transformationController: _transform,
            maxScale: 8,
            clipBehavior: Clip.none,
            child: TdImage(
              file: largest.photo,
              thumbnail: sizes.length > 1
                  ? sizes[sizes.length - 2].photo
                  : null,
              minithumbnail: photo.minithumbnail,
              fit: BoxFit.contain,
              background: const Color(0x00000000),
            ),
          ),
        ),
      ),
    );
  }
}

/// A video, or a GIF with [loop] and [muted], once downloaded; its cover
/// and the download progress until then.
class _Video extends StatefulWidget {
  const _Video({
    required this.file,
    required this.width,
    required this.height,
    required this.cover,
    required this.onPlayback,
    this.loop = false,
    this.muted = false,
  });

  final td.File file;
  final int width;
  final int height;
  final Widget cover;
  final ValueChanged<VideoPlayback?> onPlayback;
  final bool loop;
  final bool muted;

  @override
  State<_Video> createState() => _VideoState();
}

class _VideoState extends State<_Video> {
  VideoPlayback? _playback;

  @override
  void dispose() {
    final playback = _playback;
    if (playback != null) unawaited(playback.dispose());
    super.dispose();
  }

  void _start(String path) {
    if (_playback != null) return;
    final playback = VideoPlayback(loop: widget.loop, muted: widget.muted);
    _playback = playback;
    unawaited(playback.open(path).catchError((Object _) {}));
    // Reported after the frame, as the viewer rebuilds for the controls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPlayback(playback);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.width > 0 && widget.height > 0
        ? widget.width / widget.height
        : 16 / 9;
    return Center(
      child: AspectRatio(
        aspectRatio: ratio,
        child: GestureDetector(
          onTap: () => unawaited(_playback?.playOrPause()),
          child: TdFileBuilder(
            file: widget.file,
            download: true,
            priority: DownloadPriority.requested,
            builder: (context, file) {
              final path = downloadedPath(file);
              if (path != null) {
                _start(path);
                return VideoSurface(playback: _playback!);
              }
              final total = file.size > 0 ? file.size : file.expectedSize;
              final progress = total > 0
                  ? file.local.downloadedSize / total
                  : null;
              return Stack(
                fit: StackFit.expand,
                children: [
                  widget.cover,
                  Center(
                    child: MediaActionButton(
                      icon: MgIcons.download,
                      size: 52,
                      progress: progress,
                      background: const Color(0x80000000),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Play and pause, the position with a scrubber, speed, loop and sound,
/// on a dark rounded bar under the video.
class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.playback});

  final VideoPlayback playback;

  static const _rates = [1.0, 1.5, 2.0, 0.5];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: playback.state,
      builder: (context, state, _) {
        final rate = state.rate;
        final next = _rates[(_rates.indexOf(rate) + 1) % _rates.length];
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xB31C1C1F),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x14FFFFFF), width: 0.5),
            ),
            child: Row(
              children: [
                _BarButton(
                  icon: state.playing ? MgIcons.pause : MgIcons.play,
                  label: state.playing ? l10n.mediaPause : l10n.mediaPlay,
                  onTap: () => unawaited(playback.playOrPause()),
                  size: 32,
                  iconSize: 16,
                ),
                const SizedBox(width: 8),
                _Time(state.position),
                const SizedBox(width: 10),
                Expanded(
                  child: _Scrubber(
                    state: state,
                    onSeek: (position) => unawaited(playback.seek(position)),
                  ),
                ),
                const SizedBox(width: 10),
                _Time(state.duration),
                const SizedBox(width: 6),
                _RateButton(
                  rate: rate,
                  label: l10n.mediaSpeed,
                  onTap: () => unawaited(playback.setRate(next)),
                ),
                _Toggle(
                  on: state.loop,
                  child: _BarButton(
                    icon: MgIcons.loop,
                    label: l10n.mediaLoop,
                    onTap: () => unawaited(playback.setLoop(!state.loop)),
                    size: 32,
                    iconSize: 16,
                  ),
                ),
                _BarButton(
                  icon: state.volume == 0 ? MgIcons.muted : MgIcons.volume,
                  label: state.volume == 0 ? l10n.mediaUnmute : l10n.mediaMute,
                  onTap: () =>
                      unawaited(playback.setVolume(state.volume == 0 ? 1 : 0)),
                  size: 32,
                  iconSize: 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dims a control that is off, such as loop.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: on ? 1 : 0.45,
    duration: const Duration(milliseconds: 140),
    child: child,
  );
}

class _RateButton extends StatelessWidget {
  const _RateButton({
    required this.rate,
    required this.label,
    required this.onTap,
  });

  final double rate;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = rate == rate.roundToDouble()
        ? '${rate.toInt()}×'
        : '${NumberFormat('0.##').format(rate)}×';
    return Tooltip(
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 32,
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: rate == 1 ? _onDarkSecondary : _onDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time(this.value);

  final Duration value;

  @override
  Widget build(BuildContext context) => Text(
    formatDuration(value.inSeconds),
    style: const TextStyle(
      color: _onDark,
      fontSize: 12,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );
}

/// A thin track that grows under the pointer: played in white, loaded in
/// grey. Clicking or dragging seeks.
class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.state, required this.onSeek});

  final VideoPlaybackState state;
  final ValueChanged<Duration> onSeek;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  var _hover = false;

  /// Where a drag is, 0 to 1, shown instead of the position meanwhile.
  double? _drag;

  double _fraction(Duration value) {
    final total = widget.state.duration.inMilliseconds;
    if (total <= 0) return 0;
    return (value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void _seekTo(double x, double width) {
    final fraction = (x / width).clamp(0.0, 1.0);
    setState(() => _drag = fraction);
    widget.onSeek(widget.state.duration * fraction);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final played = _drag ?? _fraction(widget.state.position);
        final buffered = _fraction(widget.state.buffered);
        final thick = _hover || _drag != null;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seekTo(d.localPosition.dx, width),
            onTapUp: (_) => setState(() => _drag = null),
            onHorizontalDragUpdate: (d) => _seekTo(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) => setState(() => _drag = null),
            child: SizedBox(
              height: 24,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  height: thick ? 5 : 3,
                  child: CustomPaint(
                    size: Size(width, thick ? 5 : 3),
                    painter: _TrackPainter(played: played, buffered: buffered),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.played, required this.buffered});

  final double played;
  final double buffered;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    void bar(double fraction, Color color) {
      if (fraction <= 0) return;
      canvas.drawRRect(
        RRect.fromLTRBR(0, 0, size.width * fraction, size.height, radius),
        Paint()..color = color,
      );
    }

    bar(1, const Color(0x33FFFFFF));
    bar(buffered, const Color(0x4DFFFFFF));
    bar(played, const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.played != played || old.buffered != buffered;
}
