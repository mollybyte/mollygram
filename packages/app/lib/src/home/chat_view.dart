import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../chat/attachment_preview.dart';
import '../chat/describe.dart';
import '../chat/emoji_sticker_panel.dart';
import '../chat/forward_picker.dart';
import '../chat/media_viewer.dart';
import '../chat/message_actions.dart';
import '../chat/message_tile.dart';
import '../chat/timeline_scroll.dart';
import '../chat/timeline_view.dart';
import '../profile/peer_info_state.dart';
import '../session/providers.dart';
import '../voice/voice_record_composer.dart';
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

  /// Whether the emoji and sticker panel is open over the composer.
  var _panelOpen = false;

  final _scroll = TimelineScrollController();
  final _timelineKey = GlobalKey();

  /// Where the user was before a jump, so the down button takes them
  /// back there first, as in the official app.
  int? _returnTo;

  /// The message the timeline grows from: the first unread one when the
  /// chat opened, or where a jump went. Null keeps the newest at the
  /// bottom.
  int? _anchor;

  /// The first message that was unread when the chat opened, with the
  /// unread band above it, and what was read then.
  int? _unreadFrom;
  var _readAtOpen = 0;
  var _awaitingUnread = false;

  /// The message a jump landed on, and a count that lights it up again.
  int? _flashId;
  var _flash = 0;
  Timer? _flashTimer;

  /// Whether the view is away from the newest message, which shows the
  /// button that goes back down.
  final _away = ValueNotifier(false);

  /// Which pinned message the bar shows, 0 for the newest; chats whose bar
  /// the user closed, until the app restarts.
  var _pinnedIndex = 0;
  static final _pinnedHidden = <int>{};
  var _pinnedShown = false;

  /// A join or mute request on its way.
  var _actionPending = false;

  @override
  void initState() {
    super.initState();
    _conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    _draft.addListener(_clearSendError);
    _scroll.addListener(_followScroll);
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
    _panelOpen = false;
    _anchor = null;
    _unreadFrom = null;
    _flashId = null;
    _returnTo = null;
    _pinnedIndex = 0;
    _flashTimer?.cancel();
    _scroll.pinToBottom();
    _away.value = false;
    _open(widget.chatId);
  }

  @override
  void dispose() {
    _close(widget.chatId);
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    _away.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  // Supergroups and channels get all their updates only while open.
  void _open(int chatId) {
    final store = _conversations.store;
    // What was unread is kept from now on: reading moves the band no more.
    _readAtOpen = store.lastReadInbox(chatId);
    _awaitingUnread = store.unreadCount(chatId) > 0;
    unawaited(_quiet(_conversations.openChat(chatId)));
    if (!store.hasPinned(chatId)) {
      unawaited(_quiet(_conversations.loadPinned(chatId)));
    }
  }

  /// The bar's click: to the pinned message it shows, then on to the
  /// previous one, around to the newest after the oldest.
  Future<void> _openPinned(List<int> ids) async {
    final index = _pinnedIndex.clamp(0, ids.length - 1);
    final next = (index + 1) % ids.length;
    setState(() => _pinnedIndex = next);
    await _jumpTo(ids[index]);
  }

  /// The bar under the header, when the chat has pinned messages and the
  /// user hasn't closed it.
  Widget? _pinnedBar(AppLocalizations l10n, ConversationStore store) {
    final chatId = widget.chatId;
    final ids = store.pinnedIds(chatId);
    _pinnedShown = ids.isNotEmpty && !_pinnedHidden.contains(chatId);
    if (!_pinnedShown) return null;
    final index = _pinnedIndex.clamp(0, ids.length - 1);
    final message = store.message(chatId, ids[index]);
    final content = message?.content;
    return PinnedBar(
      title: ids.length > 1
          ? l10n.pinnedMessageNumber(ids.length - index)
          : l10n.pinnedMessage,
      text: content == null ? '' : describeContent(l10n, content),
      thumbnail: content == null ? null : mediaThumbnail(content),
      index: index,
      count: ids.length,
      closeTooltip: l10n.hidePinned,
      onTap: () => unawaited(_openPinned(ids)),
      onClose: () => setState(() => _pinnedHidden.add(chatId)),
    );
  }

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
    // The user's own messages count only for reactions they haven't seen.
    final own = message.isOutgoing && message.message.unreadReactions.isEmpty;
    if (own || !_viewed.add(message.id)) return;
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
    onViewMedia: (message) => unawaited(
      showChatMediaViewer(
        context,
        message: message,
        conversations: _conversations,
        onForward: (message) => unawaited(_forward([message])),
      ),
    ),
    onJump: (messageId) => unawaited(_jumpTo(messageId)),
  );

  /// The scroll offset that puts the anchor's row just under the header.
  double _underHeader(double viewport) => -(viewport - _topInset - 8);

  /// Where the timeline starts under the header and the pinned bar.
  double get _topInset =>
      TimelineView.headerInset + (_pinnedShown ? PinnedBar.height + 8 : 0);

  /// Keeps [_scroll.pinned] and the down button in step with where the
  /// user leaves the view.
  void _followScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final atEnd = _conversations.store.reachedEnd(widget.chatId);
    final fromBottom = position.pixels - position.minScrollExtent;
    if (position.isScrollingNotifier.value || fromBottom < 2) {
      _scroll.pinned = atEnd && fromBottom < 2;
    }
    // Back at the bottom on their own: there is nowhere to return to.
    if (atEnd && fromBottom < 2 && _returnTo != null) {
      setState(() => _returnTo = null);
    }
    _away.value = !atEnd || fromBottom > 360 || _returnTo != null;
  }

  /// Scrolls to [messageId], loading the history around it when it is
  /// outside what is loaded, and lights it up. The first jump away from
  /// a place other than the bottom remembers it for the down button.
  Future<void> _jumpTo(int messageId, {bool remember = true}) async {
    final chatId = widget.chatId;
    final store = _conversations.store;
    if (remember &&
        _returnTo == null &&
        !_scroll.pinned &&
        _scroll.hasClients) {
      final viewport = _scroll.position.viewportDimension;
      _returnTo = TimelineView.rowAt(
        _timelineKey,
        viewport - TimelineView.bottomInset - 4,
      )?.messageId;
    }
    if (!store.contains(chatId, messageId)) {
      try {
        await _conversations.loadAround(chatId, messageId);
      } on Object {
        return;
      }
      if (!mounted || widget.chatId != chatId) return;
      if (!store.contains(chatId, messageId)) return;
    }
    _scroll
      ..pinned = false
      ..request((viewport) => -viewport * 0.6);
    _flashTimer?.cancel();
    setState(() {
      _anchor = messageId;
      _flashId = messageId;
      _flash++;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _flashId = null);
    });
  }

  /// The down button: to the newest message, loading it first when the
  /// timeline stops short of it. A long way is skipped, then the last
  /// screen scrolls, as in the official app.
  Future<void> _toBottom() async {
    final chatId = widget.chatId;
    if (_returnTo case final back?) {
      setState(() => _returnTo = null);
      await _jumpTo(back, remember: false);
      return;
    }
    if (!_conversations.store.reachedEnd(chatId)) {
      try {
        await _conversations.loadHistory(chatId, atUnread: false);
      } on Object {
        return;
      }
      if (!mounted || widget.chatId != chatId) return;
      setState(() => _anchor = null);
      _scroll.pinToBottom();
      return;
    }
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final viewport = position.viewportDimension;
    if (position.pixels - position.minScrollExtent > viewport * 2) {
      position.jumpTo(position.minScrollExtent + viewport);
    }
    await position.animateTo(
      position.minScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted && widget.chatId == chatId) _scroll.pinToBottom();
  }

  /// The mention and reaction buttons: to the oldest one not seen yet.
  Future<void> _nextUnread({required bool reactions}) async {
    final chatId = widget.chatId;
    final ConversationMessage? next;
    try {
      next = await _conversations.firstUnread(chatId, reactions: reactions);
    } on Object {
      return;
    }
    if (next == null || !mounted || widget.chatId != chatId) return;
    await _jumpTo(next.id);
  }

  /// Sending goes back to the newest message, as in the official apps.
  Future<void> _toLatestForSend() async {
    final chatId = widget.chatId;
    if (!_conversations.store.reachedEnd(chatId)) {
      await _quiet(_conversations.loadHistory(chatId, atUnread: false));
      if (!mounted || widget.chatId != chatId) return;
      setState(() => _anchor = null);
    }
    _scroll.pinToBottom();
  }

  /// Picks the first unread message once the history around it is in.
  void _placeUnread(List<ConversationMessage> messages) {
    if (!_awaitingUnread || messages.isEmpty) return;
    // Newest first; the band goes above the oldest unread incoming one.
    ConversationMessage? first;
    for (final message in messages) {
      if (message.id <= _readAtOpen) break;
      if (!message.isOutgoing) first = message;
    }
    if (first == null) {
      // Nothing unread is loaded: wait, unless the timeline already holds
      // everything up to the newest message.
      if (_conversations.store.reachedEnd(widget.chatId)) {
        _awaitingUnread = false;
      }
      return;
    }
    _awaitingUnread = false;
    _anchor = first.id;
    _unreadFrom = first.id;
    _scroll
      ..pinned = false
      ..request(_underHeader);
  }

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
    if (_panelOpen) {
      setState(() => _panelOpen = false);
    } else if (_editing != null) {
      _stopEditing();
    } else if (_replyTo != null) {
      setState(() => _replyTo = null);
    }
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    _focus.requestFocus();
  }

  void _closePanel() {
    if (!_panelOpen) return;
    setState(() => _panelOpen = false);
    _focus.requestFocus();
  }

  /// Puts [emoji] in place of the selection, or at the end when the field
  /// has never had the caret, and leaves the caret after it.
  void _insertEmoji(String emoji) {
    final value = _draft.value;
    final text = value.text;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    _draft.value = TextEditingValue(
      text: text.replaceRange(selection.start, selection.end, emoji),
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
    _focus.requestFocus();
  }

  /// Sends [sticker] at once and closes the panel, as the official apps do.
  Future<void> _sendSticker(td.Sticker sticker) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _panelOpen = false;
      _failure = null;
      _replyTo = null;
    });
    _focus.requestFocus();
    unawaited(_toLatestForSend());
    try {
      await _conversations.sendSticker(chatId, sticker, replyTo: replyTo?.id);
    } catch (_) {
      if (!mounted || widget.chatId != chatId) return;
      setState(() {
        _failure = _Failure.send;
        _replyTo ??= replyTo;
      });
    }
  }

  /// Sends a voice message recorded in the composer (lib/src/voice).
  Future<void> _sendVoice(RecordedVoice voice) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _failure = null;
      _replyTo = null;
    });
    try {
      await _conversations.sendVoiceNote(
        chatId,
        path: voice.path,
        duration: voice.duration,
        waveform: voice.waveform,
        replyTo: replyTo?.id,
      );
    } catch (_) {
      if (!mounted || widget.chatId != chatId) return;
      setState(() {
        _failure = _Failure.send;
        _replyTo ??= replyTo;
      });
    }
  }

  /// Sends a video message recorded in the composer (lib/src/voice).
  Future<void> _sendVideoNote(RecordedVideoNote note) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _failure = null;
      _replyTo = null;
    });
    try {
      await _conversations.sendVideoNote(
        chatId,
        path: note.path,
        duration: note.duration,
        side: note.side,
        replyTo: replyTo?.id,
      );
    } catch (_) {
      if (!mounted || widget.chatId != chatId) return;
      setState(() {
        _failure = _Failure.send;
        _replyTo ??= replyTo;
      });
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

  var _newerScheduled = false;

  /// Asks for the page after the newest loaded message, once per frame.
  void _loadNewer() {
    if (_newerScheduled) return;
    _newerScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newerScheduled = false;
      if (!mounted) return;
      unawaited(_quiet(_conversations.loadNewer(widget.chatId).then((_) {})));
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
    unawaited(_toLatestForSend());
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
    unawaited(_toLatestForSend());
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

  /// Down to the newest message, the next mention and the next reaction,
  /// stacked over the composer's right end like in the official app.
  Widget _jumpButtons(AppLocalizations l10n, ConversationStore store) {
    final chatId = widget.chatId;
    final mentions = store.unreadMentionCount(chatId);
    final reactions = store.unreadReactionCount(chatId);
    final unread = store.unreadCount(chatId);
    final compact = NumberFormat.compact(
      locale: Localizations.localeOf(context).toLanguageTag(),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (mentions > 0)
              JumpButton(
                icon: MgIcons.mention,
                tooltip: l10n.nextMention,
                count: mentions,
                countLabel: compact.format(mentions),
                onPressed: () => unawaited(_nextUnread(reactions: false)),
              ),
            if (reactions > 0)
              JumpButton(
                icon: MgIcons.heart,
                tooltip: l10n.nextReaction,
                count: reactions,
                countLabel: compact.format(reactions),
                onPressed: () => unawaited(_nextUnread(reactions: true)),
              ),
            ValueListenableBuilder(
              valueListenable: _away,
              builder: (context, away, _) => JumpButton(
                icon: MgIcons.arrowDown,
                tooltip: _returnTo != null
                    ? l10n.backToPrevious
                    : l10n.scrollToBottom,
                visible: away,
                count: unread,
                countLabel: compact.format(unread),
                onPressed: () => unawaited(_toBottom()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The bar in place of the composer when the user can't write here:
  /// Join when they are not in the chat, Mute or Unmute in a channel they
  /// only read. Null when the composer belongs.
  Widget? _actionBar(AppLocalizations l10n, ConversationStore store) {
    final chatId = widget.chatId;
    if (store.canPost(chatId)) return null;
    final isChannel = store.isChannel(chatId);
    switch (store.membership(chatId)) {
      case ChatMembership.member:
        if (!isChannel) return null;
        final muted = store.isMuted(chatId);
        return ComposerActionBar(
          label: muted ? l10n.unmuteChat : l10n.muteChat,
          loading: _actionPending,
          onPressed: () => unawaited(
            _chatAction(() => _conversations.setMuted(chatId, muted: !muted)),
          ),
        );
      case ChatMembership.left:
        return ComposerActionBar(
          label: isChannel ? l10n.joinChannel : l10n.joinGroup,
          loading: _actionPending,
          onPressed: () =>
              unawaited(_chatAction(() => _conversations.joinChat(chatId))),
        );
      case ChatMembership.banned:
        return ComposerActionBar(label: l10n.chatUnavailable, onPressed: null);
      case ChatMembership.unknown:
        return const SizedBox(height: 44);
    }
  }

  Future<void> _chatAction(Future<void> Function() action) async {
    final chatId = widget.chatId;
    setState(() {
      _actionPending = true;
      _failure = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted && widget.chatId == chatId) {
        setState(() => _failure = _Failure.chatAction);
      }
    } finally {
      if (mounted) setState(() => _actionPending = false);
    }
  }

  /// Files are being dragged over the chat.
  var _dragging = false;

  /// False while the chat sits in a background tab (tickers are off there).
  var _onScreen = true;

  @override
  Widget build(BuildContext context) {
    _onScreen = TickerMode.valuesOf(context).enabled;
    // A jump or a page of history moves the view without a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followScroll();
    });
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
              AsyncData(value: final list) => () {
                _placeUnread(list);
                return TimelineView(
                  key: _timelineKey,
                  messages: list,
                  store: store,
                  chatId: widget.chatId,
                  isGroup: chat?.isGroup ?? false,
                  controller: _scroll,
                  anchor: _anchor,
                  unreadFrom: _unreadFrom,
                  flashId: _flashId,
                  flash: _flash,
                  topInset: _topInset,
                  onShown: _shown,
                  onNearTop: _loadOlder,
                  onNearBottom: _loadNewer,
                  actions: _actions,
                );
              }(),
              _ => const SizedBox.shrink(),
            },
          ),
          if (_pinnedBar(l10n, store) case final bar?)
            Positioned(
              top: 10 + ChatHeaderBar.height + 8,
              left: 14,
              right: 14,
              child: bar,
            ),
          Positioned(
            top: 10,
            left: 14,
            right: 14,
            child: ChatHeaderBar(
              title: ChatTitleCapsule(
                title: chat?.title ?? '',
                onTap: () => togglePeerInfo(ref, widget.chatId),
              ),
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
                if (!_panelOpen) _jumpButtons(l10n, store),
                if (_failure case final failure?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      switch (failure) {
                        _Failure.send => l10n.sendFailed,
                        _Failure.edit => l10n.editFailed,
                        _Failure.attach => l10n.attachFailed,
                        _Failure.forward => l10n.forwardFailed,
                        _Failure.chatAction => l10n.chatActionFailed,
                      },
                      textAlign: TextAlign.center,
                      style: mgTextStyle(
                        c,
                        size: MgType.small,
                        color: MessageMeta.failedColor,
                      ),
                    ),
                  ),
                if (_panelOpen)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TapRegion(
                        groupId: _EmojiPanelRegion,
                        onTapOutside: (_) => _closePanel(),
                        child: EmojiStickerPanel(
                          height: (MediaQuery.sizeOf(context).height - 220)
                              .clamp(220, 400),
                          onEmoji: _insertEmoji,
                          onSticker: (sticker) =>
                              unawaited(_sendSticker(sticker)),
                          onClose: _closePanel,
                        ),
                      ),
                    ),
                  ),
                if (_actionBar(l10n, store) case final bar?)
                  bar
                else
                  TapRegion(
                    groupId: _EmojiPanelRegion,
                    child: VoiceRecordComposer(
                      onRecorded: _sendVoice,
                      onRecordedVideo: _sendVideoNote,
                      builder: (context, recordButton, recordingBar) =>
                          Composer(
                            controller: _draft,
                            focusNode: _focus,
                            header: _composerHeader(l10n),
                            onCancel:
                                _panelOpen ||
                                    _editing != null ||
                                    _replyTo != null
                                ? _cancel
                                : null,
                            onEditLast: () => unawaited(_editLast()),
                            onAttach: () => unawaited(_chooseFiles()),
                            onEmoji: _togglePanel,
                            onPaste: _paste,
                            allowEmpty:
                                _editing != null && _isCaption(_editing!),
                            labels: ComposerLabels(
                              hint: l10n.messageHint,
                              attach: l10n.attach,
                              emoji: l10n.emoji,
                              record: l10n.record,
                              send: l10n.send,
                            ),
                            onSend: (text) => unawaited(_send(text)),
                            recordButton: recordButton,
                            replacement: recordingBar,
                          ),
                    ),
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

enum _Failure { send, edit, attach, forward, chatAction }

/// Clicks in the panel and the composer keep the emoji panel open.
abstract final class _EmojiPanelRegion {}
