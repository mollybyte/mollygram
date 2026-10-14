import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../chat/attachment_preview.dart';
import '../chat/describe.dart';
import '../chat/forward_picker.dart';
import '../chat/message_actions.dart';
import '../chat/message_tile.dart';
import '../chat/timeline.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';

/// One conversation: messages scroll under the floating header and
/// composer.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.chatId});

  final int chatId;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  late final ConversationController _conversations;

  /// The message the next one answers, shown above the composer.
  ConversationMessage? _replyTo;

  /// The message whose text is in the composer for editing, and the draft
  /// it pushed aside, which comes back when editing ends.
  ConversationMessage? _editing;
  String _setAside = '';
  ConversationMessage? _replyAside;

  /// Incoming messages already reported to TDLib as viewed.
  final _viewed = <int>{};
  final _toView = <int>{};
  var _viewScheduled = false;

  /// What went wrong last, shown above the composer until the user types.
  _Failure? _failure;

  @override
  void initState() {
    super.initState();
    _conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    _draft.addListener(_clearSendError);
    _open(widget.chatId);
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.chatId == widget.chatId) return;
    _close(old.chatId);
    _viewed.clear();
    _toView.clear();
    // An edit belongs to the old chat: give back the draft it set aside.
    if (_editing != null) _draft.text = _setAside;
    _failure = null;
    _replyTo = null;
    _editing = null;
    _setAside = '';
    _replyAside = null;
    _open(widget.chatId);
  }

  @override
  void dispose() {
    _close(widget.chatId);
    _draft.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Supergroups and channels get all their updates only while open.
  void _open(int chatId) => unawaited(_quiet(_conversations.openChat(chatId)));

  void _close(int chatId) =>
      unawaited(_quiet(_conversations.closeChat(chatId)));

  /// The session can close under the view (sign-out, app exit); a request
  /// that no longer matters must not surface as an unhandled error.
  static Future<void> _quiet(Future<void> request) =>
      request.catchError((Object _) {});

  void _clearSendError() {
    if (_failure != null && _draft.text.isNotEmpty) {
      setState(() => _failure = null);
    }
  }

  /// Called for each incoming message as it is laid out on screen; the ids
  /// are sent to TDLib together after the frame.
  void _shown(ConversationMessage message) {
    // A chat in a background tab stays built but is not on screen; its
    // messages count as read once the tab comes forward.
    if (!_onScreen) return;
    if (message.isOutgoing || !_viewed.add(message.id)) return;
    _toView.add(message.id);
    if (_viewScheduled) return;
    _viewScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewScheduled = false;
      if (!mounted || _toView.isEmpty) return;
      final ids = _toView.toList();
      _toView.clear();
      unawaited(_quiet(_conversations.viewMessages(widget.chatId, ids)));
    });
  }

  late final _actions = MessageRowActions(
    onReaction: (message, reaction, chosen) => unawaited(
      _quiet(
        _conversations.toggleReaction(
          message.chatId,
          message.id,
          reaction,
          chosen: chosen,
        ),
      ),
    ),
    onNeedReplied: (reply) =>
        unawaited(_quiet(_conversations.loadReplied(reply.chatId, reply.id))),
    onMenu: (row, position) => unawaited(_showMenu(row, position)),
  );

  Future<void> _showMenu(MessageRow row, Offset position) {
    final store = _conversations.store;
    final chat = ref.read(chatEntryProvider(widget.chatId)).value;
    final isPrivate =
        chat != null && !chat.isGroup && !store.isChannel(widget.chatId);
    return showMessageMenu(
      context,
      conversations: _conversations,
      row: row,
      position: position,
      peerName: isPrivate ? chat.title : null,
      isShown: () => mounted && widget.chatId == row.primary.chatId,
      handlers: MessageMenuHandlers(
        onReply: _reply,
        onEdit: _edit,
        onForward: (messages) => unawaited(_forward(messages)),
      ),
    );
  }

  void _reply(ConversationMessage message) {
    // The chat may have changed while the menu was open.
    if (message.chatId != widget.chatId) return;
    if (_editing != null) _stopEditing();
    setState(() => _replyTo = message);
    _focus.requestFocus();
  }

  void _edit(ConversationMessage message) {
    if (message.chatId != widget.chatId) return;
    if (_editing == null) {
      _setAside = _draft.text;
      _replyAside = _replyTo;
    }
    final text = message.text;
    setState(() {
      _editing = message;
      _replyTo = null;
    });
    _draft.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _focus.requestFocus();
  }

  void _stopEditing() {
    final draft = _setAside;
    _setAside = '';
    setState(() {
      _editing = null;
      if (_failure == _Failure.edit) _failure = null;
      _replyTo = _replyAside;
      _replyAside = null;
    });
    _draft.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  /// Esc: stop editing first, then stop replying.
  void _cancel() {
    if (_editing != null) {
      _stopEditing();
    } else if (_replyTo != null) {
      setState(() => _replyTo = null);
    }
  }

  /// The up arrow in an empty composer edits the last message the user
  /// sent, as in the official apps.
  Future<void> _editLast() async {
    final chatId = widget.chatId;
    final messages = _conversations.store.messagesFor(chatId);
    // Newest first.
    for (final message in messages) {
      if (!message.isOutgoing || message.sendState != MessageSendState.sent) {
        continue;
      }
      if (message.text.isEmpty) return;
      final td.MessageProperties properties;
      try {
        properties = await _conversations.propertiesOf(
          message.chatId,
          message.id,
        );
      } on Object {
        return;
      }
      if (!mounted ||
          widget.chatId != chatId ||
          !properties.canBeEdited ||
          _draft.text.isNotEmpty) {
        return;
      }
      _edit(message);
      return;
    }
  }

  Future<void> _forward(List<ConversationMessage> messages) async {
    final target = await pickForwardTarget(context);
    if (target == null || messages.isEmpty) return;
    try {
      await _conversations.forwardMessages(target, messages.first.chatId, [
        for (final message in messages) message.id,
      ]);
    } catch (_) {
      // Such as a channel the user can't post in.
      if (mounted) setState(() => _failure = _Failure.forward);
    }
  }

  var _olderScheduled = false;

  /// Asks for the page before the oldest message, once per frame.
  void _loadOlder() {
    if (_olderScheduled) return;
    _olderScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _olderScheduled = false;
      if (!mounted) return;
      unawaited(_quiet(_conversations.loadOlder(widget.chatId).then((_) {})));
    });
  }

  Future<void> _send(String text) async {
    final editing = _editing;
    // A caption may be removed; a text message can't be emptied.
    if (editing != null && (text.trim().isNotEmpty || _isCaption(editing))) {
      return _saveEdit(editing, text);
    }
    if (text.trim().isEmpty) return;
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    _draft.clear();
    setState(() {
      _failure = null;
      _replyTo = null;
    });
    try {
      await _conversations.sendText(chatId, text, replyTo: replyTo?.id);
    } catch (_) {
      // Give the text back rather than lose it, unless the user has
      // started typing something else or moved to another chat.
      if (!mounted || widget.chatId != chatId) return;
      if (_draft.text.isEmpty) {
        _draft.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
      setState(() {
        _failure = _Failure.send;
        _replyTo ??= replyTo;
      });
    }
  }

  static bool _isCaption(ConversationMessage message) =>
      message.content is! td.MessageText;

  Future<void> _saveEdit(ConversationMessage message, String text) async {
    if (text == message.text) return _stopEditing();
    _stopEditing();
    try {
      await _conversations.editText(message.chatId, message.id, text);
    } catch (_) {
      if (!mounted || widget.chatId != message.chatId) return;
      // Another edit has started meanwhile; keep it and only say so.
      if (_editing != null) {
        setState(() => _failure = _Failure.edit);
        return;
      }
      // Put the edit back so the change is not lost.
      _edit(message);
      _draft.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      setState(() => _failure = _Failure.edit);
    }
  }

  /// The attach button: pick files, then confirm them in the preview.
  Future<void> _chooseFiles() async {
    final picked = await openFiles();
    if (!mounted || picked.isEmpty) return;
    await _offerFiles([for (final file in picked) file.path]);
  }

  /// Cmd+V: files copied in Finder, or an image with no text beside it,
  /// take the place of text.
  Future<bool> _paste() async {
    List<String> files;
    try {
      // A copied link also comes back here, as a path that is not a file.
      files = _onlyFiles(await Pasteboard.files());
    } on Object {
      files = const [];
    }
    if (files.isEmpty) {
      // Office apps put a picture of the copied text next to it; the text
      // is what the user means.
      if (await Clipboard.hasStrings()) return false;
      final image = await _pastedImage();
      if (image == null) return false;
      if (!mounted) return true;
      await _offerFiles([image], temporary: true);
      return true;
    }
    if (!mounted) return true;
    await _offerFiles(files);
    return true;
  }

  /// Where pasted images are saved. TDLib reads them while uploading,
  /// which may go on after a relaunch, so only day-old ones are removed.
  static Future<Directory> _pasteDirectory() async {
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/Pasted',
    );
    await directory.create(recursive: true);
    final dayAgo = DateTime.now().subtract(const Duration(days: 1));
    await for (final entry in directory.list()) {
      try {
        if (entry is File && (await entry.lastModified()).isBefore(dayAgo)) {
          await entry.delete();
        }
      } on FileSystemException {
        // Gone already, or in use; the next paste tries again.
      }
    }
    return directory;
  }

  /// The image on the clipboard, saved as a PNG file, or null.
  static Future<String?> _pastedImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return null;
      // macOS gives TIFF and Windows BMP; Telegram wants a PNG or JPEG.
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null) return null;
      final directory = await _pasteDirectory();
      final file = File(
        '${directory.path}/Pasted ${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png.buffer.asUint8List());
      return file.path;
    } on Object {
      return null;
    }
  }

  /// [paths] without folders and anything that isn't there.
  static List<String> _onlyFiles(Iterable<String> paths) => [
    for (final path in paths)
      if (path.isNotEmpty && FileSystemEntity.isFileSync(path)) path,
  ];

  /// Offers [picked] for sending. [temporary] files were made for this
  /// offer and are deleted when it is cancelled.
  Future<void> _offerFiles(
    List<String> picked, {
    bool temporary = false,
  }) async {
    final paths = _onlyFiles(picked);
    if (paths.isEmpty) return;
    final chatId = widget.chatId;
    // The draft becomes the caption, as in the official apps; not while
    // editing, where the composer holds another message's text.
    final useDraft = _editing == null;
    final choice = await showAttachmentPreview(
      context,
      paths: paths,
      caption: useDraft ? _draft.text : '',
    );
    if (choice == null && temporary) {
      for (final path in paths) {
        unawaited(File(path).delete().then((_) {}, onError: (Object _) {}));
      }
    }
    if (choice == null || !mounted || widget.chatId != chatId) return;
    final replyTo = _replyTo;
    setState(() {
      _failure = null;
      _replyTo = null;
    });
    if (useDraft) _draft.clear();
    try {
      // One at a time: each video or song opens a player to be measured.
      final files = <OutgoingFile>[];
      for (final file in choice.files) {
        files.add(await _measure(file));
      }
      await _conversations.sendFiles(
        chatId,
        files,
        caption: choice.caption,
        replyTo: replyTo?.id,
      );
    } catch (_) {
      if (!mounted || widget.chatId != chatId) return;
      // Give the caption and the reply back, as a failed text send does.
      if (useDraft && _draft.text.isEmpty) _draft.text = choice.caption;
      setState(() {
        _failure = _Failure.attach;
        _replyTo ??= replyTo;
      });
    }
  }

  /// Adds the pixel size and length the server shows before it has the
  /// file itself. A picture Telegram won't take as a photo goes as a file.
  static Future<OutgoingFile> _measure(OutgoingFile file) async {
    switch (file.kind) {
      case OutgoingKind.photo:
        final size = await _imageSize(file.path);
        final bytes = await File(file.path).length();
        if (size == null ||
            !fitsAsPhoto(width: size.$1, height: size.$2, bytes: bytes)) {
          return OutgoingFile(path: file.path, kind: OutgoingKind.document);
        }
        return OutgoingFile(
          path: file.path,
          kind: file.kind,
          width: size.$1,
          height: size.$2,
        );
      case OutgoingKind.video || OutgoingKind.animation || OutgoingKind.audio:
        final info = await probeMedia(file.path);
        if (info == null) return file;
        return OutgoingFile(
          path: file.path,
          kind: file.kind,
          width: info.width,
          height: info.height,
          duration: info.duration.inSeconds,
        );
      case OutgoingKind.document:
        return file;
    }
  }

  /// The pixel size of the image at [path], read from its header.
  static Future<(int, int)?> _imageSize(String path) async {
    final ui.ImmutableBuffer buffer;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
    } on Object {
      return null;
    }
    try {
      final image = await ui.ImageDescriptor.encoded(buffer);
      try {
        return (image.width, image.height);
      } finally {
        image.dispose();
      }
    } on Object {
      return null;
    } finally {
      buffer.dispose();
    }
  }

  Widget? _composerHeader(AppLocalizations l10n) {
    final editing = _editing;
    if (editing != null) {
      return ComposerContextBar(
        title: l10n.editingMessage,
        text: describeContent(l10n, editing.content),
        closeTooltip: l10n.close,
        onClose: _stopEditing,
      );
    }
    final reply = _replyTo;
    if (reply == null) return null;
    return ComposerContextBar(
      title: nameOfSender(l10n, _conversations.store, reply.sender),
      text: describeContent(l10n, reply.content),
      closeTooltip: l10n.close,
      onClose: () => setState(() => _replyTo = null),
    );
  }

  /// Files are being dragged over the chat.
  var _dragging = false;

  /// False while the chat sits in a background tab (tickers are off there).
  var _onScreen = true;

  @override
  Widget build(BuildContext context) {
    _onScreen = TickerMode.valuesOf(context).enabled;
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final chat = ref.watch(chatEntryProvider(widget.chatId)).value;
    final messages = ref.watch(conversationProvider(widget.chatId));
    final store = session.conversations.store;

    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        unawaited(
          _offerFiles([
            for (final item in details.files)
              if (item is! DropItemDirectory) item.path,
          ]),
        );
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: switch (messages) {
              AsyncData(value: final list)
                  when list.isEmpty && store.reachedStart(widget.chatId) =>
                Center(child: DatePill(l10n.noMessages)),
              AsyncData(value: final list) => _Messages(
                messages: list,
                store: store,
                chatId: widget.chatId,
                isGroup: chat?.isGroup ?? false,
                onShown: _shown,
                onNearTop: _loadOlder,
                actions: _actions,
              ),
              _ => const SizedBox.shrink(),
            },
          ),
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: ChatHeaderBar(
              title: ChatTitleCapsule(title: chat?.title ?? ''),
              actions: const SizedBox.shrink(),
              fill: const WindowDragArea(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_failure case final failure?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      switch (failure) {
                        _Failure.send => l10n.sendFailed,
                        _Failure.edit => l10n.editFailed,
                        _Failure.attach => l10n.attachFailed,
                        _Failure.forward => l10n.forwardFailed,
                      },
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        color: MessageMeta.failedColor,
                      ),
                    ),
                  ),
                Composer(
                  controller: _draft,
                  focusNode: _focus,
                  header: _composerHeader(l10n),
                  onCancel: _editing != null || _replyTo != null
                      ? _cancel
                      : null,
                  onEditLast: () => unawaited(_editLast()),
                  onAttach: () => unawaited(_chooseFiles()),
                  onPaste: _paste,
                  allowEmpty: _editing != null && _isCaption(_editing!),
                  labels: ComposerLabels(
                    hint: l10n.messageHint,
                    attach: l10n.attach,
                    emoji: l10n.emoji,
                    record: l10n.record,
                    send: l10n.send,
                  ),
                  onSend: (text) => unawaited(_send(text)),
                ),
              ],
            ),
          ),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Glass(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    child: Text(l10n.dropFiles, style: mgTextStyle(c)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Failure { send, edit, attach, forward }

/// The timeline, newest at the bottom: rows of messages and albums with a
/// date pill above the first message of each day.
class _Messages extends StatelessWidget {
  const _Messages({
    required this.messages,
    required this.store,
    required this.chatId,
    required this.isGroup,
    required this.onShown,
    required this.onNearTop,
    required this.actions,
  });

  /// Newest first, so the list starts at the bottom.
  final List<ConversationMessage> messages;
  final ConversationStore store;
  final int chatId;
  final bool isGroup;

  /// Called as a message is built, which is when it is on screen or about
  /// to be.
  final void Function(ConversationMessage message) onShown;

  /// Called when the oldest loaded messages come into view.
  final VoidCallback onNearTop;
  final MessageRowActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final items = timelineItems(
      messages,
      reachedStart: store.reachedStart(chatId),
    );
    final isChannel = store.isChannel(chatId);
    final lastReadOutbox = store.lastReadOutbox(chatId);
    return ListView.builder(
      reverse: true,
      // No off-screen cache: a message is built when it enters the
      // viewport, which is when onShown reports it to TDLib as viewed.
      scrollCacheExtent: const ScrollCacheExtent.pixels(0),
      padding: const EdgeInsets.only(top: 72, bottom: 88),
      itemCount: items.length,
      findChildIndexCallback: (key) {
        final value = (key as ValueKey<Object>).value;
        final index = items.indexWhere((item) => item.key == value);
        return index < 0 ? null : index;
      },
      itemBuilder: (context, i) {
        if (i >= items.length - 8) onNearTop();
        final item = items[i];
        final Widget child = switch (item) {
          TimelineDate(:final day) => DatePill(formatDay(l10n, day, locale)),
          TimelineRow(:final row, :final startsRun, :final endsRun) => () {
            row.messages.forEach(onShown);
            return Padding(
              padding: EdgeInsets.only(top: startsRun ? 6 : 2),
              child: MessageTile(
                row: row,
                store: store,
                context: MessageRowContext(
                  isGroup: isGroup,
                  isChannel: isChannel,
                  startsRun: startsRun,
                  endsRun: endsRun,
                  lastReadOutbox: lastReadOutbox,
                ),
                actions: actions,
              ),
            );
          }(),
        };
        return Padding(
          key: ValueKey<Object>(item.key),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        );
      },
    );
  }
}
