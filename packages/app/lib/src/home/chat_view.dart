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
import 'package:mollygram_shell/mollygram_shell.dart' show primaryShortcut;
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/app_localizations.dart';
import '../avatar/peer_avatar.dart';
import '../chat/attachment_preview.dart';
import '../chat/audio_player_bar.dart';
import '../chat/bot_keyboard.dart';
import '../chat/chat_translation.dart';
import '../chat/contact_picker.dart';
import '../chat/custom_emoji.dart';
import '../chat/describe.dart';
import '../chat/edit_history.dart';
import '../chat/emoji_sticker_panel.dart';
import '../chat/formatted_text.dart';
import '../chat/forum_topics.dart';
import '../chat/forward_picker.dart';
import '../chat/inline_results.dart';
import '../chat/link_preview_bar.dart';
import '../chat/load_spinner.dart';
import '../chat/location_picker.dart';
import '../chat/measured.dart';
import '../chat/media_viewer.dart';
import '../chat/message_actions.dart';
import '../chat/message_tile.dart';
import '../chat/poll_composer.dart';
import '../chat/poll_content.dart';
import '../chat/saved_tags.dart';
import '../chat/saved_topics.dart';
import '../chat/schedule_picker.dart';
import '../chat/send_as.dart';
import '../chat/slow_mode.dart';
import '../chat/sponsored_message.dart';
import '../chat/sticker_suggestions.dart';
import '../chat/timeline.dart';
import '../chat/timeline_scroll.dart';
import '../chat/timeline_view.dart';
import '../chat/topic_sheet.dart';
import '../chat/translate_bar.dart';
import '../chat_search/chat_search_bar.dart';
import '../chat_search/sender_picker.dart';
import '../compose/command_suggester.dart';
import '../compose/emoji_suggester.dart';
import '../compose/inline_suggester.dart';
import '../compose/mention_suggester.dart';
import '../compose/rich_text_bridge.dart';
import '../compose/sticker_suggester.dart';
import '../links/link_router.dart';
import '../profile/peer_info_state.dart';
import '../secret/secret_chat.dart';
import '../session/providers.dart';
import '../settings/preferences.dart';
import '../shared_media/message_jump.dart';
import '../voice/voice_record_composer.dart';
import '../window_drag_area.dart';
import 'chat_status.dart';
import 'format.dart';
import 'workspace.dart';

/// One conversation: messages scroll under the floating header and
/// composer.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.chatId, this.focused = true});

  final int chatId;

  /// Whether this is the pane that has the keyboard; in a split tab only
  /// that one takes the cursor.
  final bool focused;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _draft = RichTextEditingController();
  late final _mentions = MentionSuggester(controller: _draft);
  late final _emojiHints = EmojiSuggester(controller: _draft);
  late final _commands = CommandSuggester(
    controller: _draft,
    onSend: (command) => unawaited(_send(command)),
  );
  late final _stickerHints = StickerSuggester(controller: _draft);
  late final _inline = InlineQuerySuggester(controller: _draft);
  final _focus = FocusNode();

  /// Holds the focus when the chat is clicked outside any field, so typing
  /// still reaches [_typeToComposer].
  final _area = FocusNode(skipTraversal: true, debugLabel: 'chat area');
  late final ConversationController _conversations;

  /// The message the next one answers, shown above the composer.
  ConversationMessage? _replyTo;
  Timer? _draftTimer;

  /// The preview of the first link in the draft, shown above the field,
  /// the link it is for, and how the user wants it: dropped, or above the
  /// text. A new link starts afresh; the same link keeps the choice.
  td.LinkPreview? _preview;
  String _previewUrl = '';
  bool _previewRemoved = false;
  bool _previewAbove = false;
  Timer? _previewTimer;
  int _previewSeq = 0;

  /// The part of [_replyTo]'s text the reply quotes, if any.
  QuoteSelection? _replyQuote;
  QuoteSelection? _quoteAside;

  /// The text selected in the timeline right now, for the Quote command.
  ({ConversationMessage message, QuoteSelection quote})? _textSelection;

  /// The message whose text is in the composer for editing, and the draft
  /// it pushed aside, which comes back when editing ends.
  ConversationMessage? _editing;
  String _setAside = '';
  List<FormatRange> _setAsideRanges = const [];
  ConversationMessage? _replyAside;

  /// Incoming messages already reported to TDLib as viewed.
  final _viewed = <int>{};
  final _toView = <int>{};
  var _viewScheduled = false;

  /// What went wrong last, shown above the composer until the user types.
  _Failure? _failure;

  /// Whether the emoji and sticker panel is open over the composer.
  var _panelOpen = false;

  /// Whether the ⌘F search capsule takes the title's place.
  var _searching = false;

  final _scroll = TimelineScrollController();
  final _pinnedScroll = TimelineScrollController();
  final _timelineKey = GlobalKey();

  /// Where the user was before a jump, so the down button takes them
  /// back there first, as in the official app.
  int? _returnTo;

  /// Where each chat was left: the message just above the composer, so
  /// coming back lands there, as in the official apps. A chat left at
  /// the bottom is forgotten and opens at the newest message.
  static final _positions = <int, int>{};

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

  /// The chat's translation, shown in place of its messages' text while
  /// the user has it on, and whether its bar is under the header.
  late final _translation = ChatTranslation(
    (chatId, messageId, to) =>
        _conversations.translateFormatted(chatId, messageId, to),
  )..onFailure = _translateFailed;
  var _translateShown = false;

  /// The timeline shows only the pinned messages, from the bar's button.
  var _pinnedListOpen = false;

  /// The chat's scheduled messages, shown in place of the timeline while
  /// [_scheduledOpen]; loaded again whenever the store counts a change.
  var _scheduledOpen = false;
  var _scheduled = const <ConversationMessage>[];
  var _scheduledSeen = -1;
  final _scheduledScroll = TimelineScrollController();

  /// The comments of a post, shown in place of the timeline while open.
  MessageThread? _thread;

  /// A channel's sponsored message, asked for once per chat and shown
  /// under the timeline.
  td.SponsoredMessage? _sponsored;
  var _sponsoredAsked = false;

  /// The topics of a forum, shown in the timeline's place until one opens.
  ForumTopicList? _topics;
  StreamSubscription<void>? _topicsSub;
  var _topicsOpening = false;

  /// Set after a failed load of the topics, to try again shortly.
  Timer? _topicsRetry;

  /// Saved Messages shown as the chats they came from, while the list
  /// button in the capsule is on.
  SavedTopicList? _savedTopics;
  StreamSubscription<void>? _savedTopicsSub;
  var _savedTopicsOpening = false;
  var _savedOpen = false;

  /// The tags on Saved Messages, in a bar under the header while there
  /// are any; one opens the messages carrying it in the timeline's place.
  SavedTags? _savedTags;
  StreamSubscription<void>? _savedTagsSub;
  var _savedTagsOpening = false;
  StreamSubscription<void>? _threadSub;
  final _threadScroll = TimelineScrollController();
  final _threadDraft = RichTextEditingController();
  final _threadFocus = FocusNode();

  /// A join or mute request on its way.
  var _actionPending = false;

  /// Messages others deleted that the privacy store kept for this chat,
  /// shown in their place while "Keep deleted messages" is on.
  var _deleted = const <DeletedMessage>[];
  StreamSubscription<List<DeletedMessage>>? _deletedSub;

  TelegramSession get _session =>
      ref.read(telegramSessionProvider).requireValue;

  /// The ids of the selected messages while messages are being selected;
  /// null otherwise.
  Set<int>? _selected;

  /// What the selection allows, from the properties of its messages.
  var _canForwardSelected = false;
  List<td.MessageProperties>? _selectedProperties;

  @override
  void initState() {
    super.initState();
    _conversations = ref
        .read(telegramSessionProvider)
        .requireValue
        .conversations;
    _draft.addListener(_clearSendError);
    _draft.addListener(_draftChanged);
    _draft.addListener(_previewChanged);
    _mentions
      ..search = _mentionSearch()
      ..addListener(_mentionsChanged);
    final stickers = ref.read(telegramSessionProvider).requireValue.stickers;
    _emojiHints.search = (query) =>
        stickers.emojiSuggestions(query, languages: _inputLanguages());
    _emojiHints.addListener(_mentionsChanged);
    _commands.addListener(_mentionsChanged);
    _stickerHints.search = _stickerSearch();
    _stickerHints.addListener(_mentionsChanged);
    _inline
      ..resolveBot = _conversations.inlineBot
      ..search = _inlineSearch()
      ..addListener(_mentionsChanged);
    _scroll.addListener(_followScroll);
    _scroll.addListener(() => _topUp(_scroll));
    _threadScroll.addListener(() {
      _followList(_threadScroll);
      _topUp(_threadScroll);
    });
    _pinnedScroll.addListener(() => _followList(_pinnedScroll));
    _scheduledScroll.addListener(() => _followList(_scheduledScroll));
    _open(widget.chatId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeJump());
    _focusComposer();
  }

  /// Puts the cursor in the composer once the frame is built, as the
  /// official client does whenever a chat comes to the front: on opening
  /// it, on switching back to its tab or pane. A dialog or sheet above the
  /// chat keeps the focus it has.
  void _focusComposer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_onScreen || !widget.focused) return;
      if (_inputFocus.context == null) return;
      if (ModalRoute.of(context)?.isCurrent == false) return;
      _inputFocus.requestFocus();
    });
  }

  /// The field that takes typing: the thread's while comments, a topic or
  /// a saved tag are open, the chat's otherwise.
  FocusNode get _inputFocus => _thread != null ? _threadFocus : _focus;
  RichTextEditingController get _inputDraft =>
      _thread != null ? _threadDraft : _draft;

  /// A click on the chat that lands on no field leaves the focus on the
  /// chat as a whole rather than nowhere, also when it was left on
  /// something outside the chat, such as the workspace after a palette.
  void _claimFocus() {
    scheduleMicrotask(() {
      if (!mounted || _area.hasFocus) return;
      final focused = FocusManager.instance.primaryFocus;
      final context = focused?.context;
      if (context?.findAncestorWidgetOfExactType<EditableText>() != null) {
        return;
      }
      // A control inside the chat keeps the focus it was just given.
      final inside = focused != null && focused.ancestors.contains(_area);
      if (!inside) _area.requestFocus();
    });
  }

  /// Typing anywhere in the chat, with nothing being edited, goes to the
  /// composer: the key that started it is not lost.
  KeyEventResult _typeToComposer(FocusNode node, KeyEvent event) {
    final input = _inputFocus;
    if (event is! KeyDownEvent || input.hasFocus || input.context == null) {
      return KeyEventResult.ignored;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary?.context?.findAncestorWidgetOfExactType<EditableText>() !=
        null) {
      return KeyEventResult.ignored;
    }
    // Escape and Enter belong to a recording in progress.
    if (primary?.debugLabel == VoiceRecordComposer.focusLabel) {
      return KeyEventResult.ignored;
    }
    // Option and AltGr make characters of their own, so Alt alone passes;
    // a shortcut is Control or Command without it.
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || (keys.isControlPressed && !keys.isAltPressed)) {
      return KeyEventResult.ignored;
    }
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.codeUnitAt(0) < 0x20 ||
        character.codeUnitAt(0) == 0x7f) {
      return KeyEventResult.ignored;
    }
    input.requestFocus();
    final draft = _inputDraft;
    final value = draft.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    draft.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, character),
      selection: TextSelection.collapsed(
        offset: selection.start + character.length,
      ),
    );
    return KeyEventResult.handled;
  }

  /// Shows the message another panel asked this chat to show.
  void _takeJump() {
    if (!mounted) return;
    final id = ref.read(messageJumpProvider.notifier).take(widget.chatId);
    if (id != null) unawaited(_jumpTo(id));
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (widget.focused && !old.focused) _focusComposer();
    if (old.chatId == widget.chatId) return;
    _focusComposer();
    // An edit belongs to the old chat: give back the draft it set aside.
    if (_editing != null) _draft.setFormatted(_setAside, _setAsideRanges);
    _editing = null;
    _saveDraft(old.chatId);
    _rememberPosition(old.chatId);
    _close(old.chatId);
    _dropTopics();
    _dropSavedTopics();
    _translation.reset();
    _sponsored = null;
    _sponsoredAsked = false;
    _viewed.clear();
    _toView.clear();
    _draft.clear();
    _mentions
      ..search = _mentionSearch()
      ..reset();
    _emojiHints.reset();
    _commands
      ..commands = const []
      ..reset();
    _stickerHints.search = _stickerSearch();
    _stickerHints.reset();
    _inline
      ..search = _inlineSearch()
      ..reset();
    _failure = null;
    _replyTo = null;
    _replyQuote = null;
    _editing = null;
    _resetPreview();
    _setAside = '';
    _setAsideRanges = const [];
    _replyAside = null;
    _panelOpen = false;
    _searching = false;
    _anchor = null;
    _unreadFrom = null;
    _flashId = null;
    _returnTo = null;
    _pinnedIndex = 0;
    _pinnedListOpen = false;
    _dropThread();
    _scheduledOpen = false;
    _scheduled = const [];
    _scheduledSeen = -1;
    _selected = null;
    _selectedProperties = null;
    _flashTimer?.cancel();
    _scroll.pinToBottom();
    _away.value = false;
    _open(widget.chatId);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _previewTimer?.cancel();
    if (_editing == null) _saveDraft(widget.chatId);
    _rememberPosition(widget.chatId);
    _close(widget.chatId);
    _dropTopics();
    _dropSavedTopics();
    _translation.dispose();
    _deletedSub?.cancel();
    _mentions.dispose();
    _emojiHints.dispose();
    _commands.dispose();
    _stickerHints.dispose();
    _inline.dispose();
    _dropThread();
    _threadScroll.dispose();
    _threadDraft.dispose();
    _threadFocus.dispose();
    _draft.dispose();
    _focus.dispose();
    _area.dispose();
    _scroll.dispose();
    _pinnedScroll.dispose();
    _scheduledScroll.dispose();
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
    _loadDraft(chatId);
    _watchDeleted(chatId);
    // Unread messages come first; otherwise back to where the chat was left.
    final left = _positions[chatId];
    if (!_awaitingUnread && left != null) {
      unawaited(_restorePosition(chatId, left));
    }
  }

  /// Keeps the message above the composer for [_restorePosition], or
  /// forgets the chat when it was left at the bottom.
  void _rememberPosition(int chatId) {
    if (_listOpen || !_scroll.hasClients) return;
    if (_scroll.pinned) {
      _positions.remove(chatId);
      return;
    }
    final viewport = _scroll.position.viewportDimension;
    final hit = TimelineView.rowAt(_timelineKey, viewport - _bottomInset - 4);
    if (hit == null) return;
    _positions[chatId] = hit.messageId;
  }

  /// Puts message [id] back just above the composer, loading the history
  /// around it when the chat was reopened without it.
  Future<void> _restorePosition(int chatId, int id) async {
    final store = _conversations.store;
    if (!store.contains(chatId, id)) {
      try {
        await _conversations.loadAround(chatId, id);
      } on Object {
        return;
      }
      if (!mounted || widget.chatId != chatId) return;
      if (!store.contains(chatId, id)) return;
    }
    _scroll
      ..pinned = false
      ..request((_) => -(_bottomInset + 4));
    setState(() => _anchor = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.chatId == chatId) _followScroll();
    });
  }

  /// Follows the deleted messages kept for [chatId], when any are kept.
  void _watchDeleted(int chatId) {
    _deletedSub?.cancel();
    _deletedSub = null;
    _deleted = const [];
    final capture = _session.capture;
    if (!capture.keepDeleted) return;
    final store = capture.store;
    if (store == null) return;
    _deletedSub = store
        .asStream()
        .asyncExpand((store) => store.deleted.watchChat(chatId))
        .handleError((Object _) {})
        .listen((kept) {
          if (!mounted || widget.chatId != chatId) return;
          setState(() => _deleted = kept);
        });
  }

  /// [list] with the kept deleted messages that fall inside the loaded
  /// history put back where they were, newest first.
  List<ConversationMessage> _withDeleted(
    List<ConversationMessage> list,
    ConversationStore store,
  ) {
    if (_deleted.isEmpty) return list;
    final oldest = list.isEmpty ? null : list.last.id;
    final reachedStart = store.reachedStart(widget.chatId);
    final live = {for (final message in list) message.id};
    // Older than the loaded history, a message waits for that page.
    bool inRange(int id) => reachedStart || (oldest != null && id > oldest);
    final kept = [
      for (final deleted in _deleted)
        if (!live.contains(deleted.messageId) && inRange(deleted.messageId))
          ConversationMessage(deleted.message, deletedAt: deleted.deletedAt),
    ];
    if (kept.isEmpty) return list;
    return [...list, ...kept]..sort((a, b) => b.id.compareTo(a.id));
  }

  /// Opens the earlier versions of [message] from the privacy store.
  void _showEditHistory(ConversationMessage message) {
    final store = _session.capture.store;
    if (store == null) return;
    unawaited(
      showEditHistory(
        context,
        message: message,
        versions: store.then(
          (store) => store.edits.versions(message.chatId, message.id),
        ),
      ),
    );
  }

  /// Puts the draft TDLib keeps for [chatId] into the empty composer: its
  /// text with formatting, and the message it answers when that is loaded.
  void _loadDraft(int chatId) {
    if (_draft.text.isNotEmpty) return;
    final draft = _conversations.store.draft(chatId);
    if (draft == null) return;
    if (draft.content case td.DraftMessageContentText(:final text)) {
      _draft.setFormatted(text.text, draftRanges(text));
    }
    if (draft.replyTo case td.InputMessageReplyToMessage(:final messageId)) {
      _replyTo = _conversations.store.message(chatId, messageId);
    }
    if (draft.content case td.DraftMessageContentText(
      linkPreviewOptions: final options?,
    )) {
      _previewUrl = options.url;
      _previewRemoved = options.isDisabled;
      _previewAbove = options.showAboveText;
    }
  }

  /// Looks the link in the draft up a moment after typing stops, so the
  /// preview appears as it would under the sent message.
  void _previewChanged() {
    if (_editing != null) return;
    _previewTimer?.cancel();
    final text = _draft.text;
    // No dot, no link: nothing to ask TDLib about.
    if (!text.contains('.')) {
      if (_preview != null || _previewUrl.isNotEmpty) {
        _resetPreview(notify: true);
      }
      return;
    }
    _previewTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) unawaited(_lookUpPreview());
    });
  }

  Future<void> _lookUpPreview() async {
    final chatId = widget.chatId;
    final seq = ++_previewSeq;
    final text = formattedDraft(_draft.text, _draft.ranges);
    final preview = await _conversations.linkPreview(text);
    if (!mounted || widget.chatId != chatId || seq != _previewSeq) return;
    if (preview == null) {
      if (_preview != null) setState(() => _preview = null);
      return;
    }
    setState(() {
      // Another link: the choice made for the last one no longer holds.
      if (preview.url != _previewUrl) {
        _previewUrl = preview.url;
        _previewRemoved = false;
        _previewAbove = preview.showAboveText;
      }
      _preview = preview;
    });
  }

  /// How the message carries its link preview, or null for the default:
  /// the preview Telegram makes, under the text.
  td.LinkPreviewOptions? get _previewOptions {
    if (_previewUrl.isEmpty || (!_previewRemoved && !_previewAbove)) {
      return null;
    }
    return td.LinkPreviewOptions(
      isDisabled: _previewRemoved,
      url: _previewRemoved ? '' : _previewUrl,
      forceSmallMedia: false,
      forceLargeMedia: false,
      showAboveText: _previewAbove,
    );
  }

  void _resetPreview({bool notify = false}) {
    _previewTimer?.cancel();
    _previewSeq++;
    void reset() {
      _preview = null;
      _previewUrl = '';
      _previewRemoved = false;
      _previewAbove = false;
    }

    if (notify && mounted) {
      setState(reset);
    } else {
      reset();
    }
  }

  /// Saves the draft a while after the last keystroke, so a chat left or
  /// an app quit loses nothing and the other devices catch up.
  void _draftChanged() {
    if (_editing != null) return;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _saveDraft(widget.chatId);
    });
  }

  void _saveDraft(int chatId) {
    _draftTimer?.cancel();
    final text = _draft.text;
    unawaited(
      _quiet(
        _conversations.saveDraft(
          chatId,
          text: text.trim().isEmpty
              ? null
              : formattedDraft(text, _draft.ranges),
          replyTo: _replyTo?.id,
          linkPreviewOptions: _previewOptions,
        ),
      ),
    );
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
  /// The room the translation bar takes under the header.
  double get _translateInset => _translateShown ? ChatTranslateBar.height : 0;

  void _translateFailed() {
    if (mounted) {
      showMgToast(context, AppLocalizations.of(context).translateFailed);
    }
  }

  /// The bar that translates the whole chat: offered when the chat is in
  /// another language than the one the user reads, and, once it is on,
  /// the way back to the original. Sets [_translateShown], which the
  /// timeline's inset follows.
  Widget? _translateBar(
    AppLocalizations l10n,
    List<ConversationMessage>? list,
  ) {
    final chatId = widget.chatId;
    final choice = ref.watch(
      preferencesProvider.select(
        (p) => (
          p.translateTo,
          p.translateSkip,
          p.translateChats.contains(chatId),
          p.translateHidden.contains(chatId),
        ),
      ),
    );
    final locale = Localizations.localeOf(context).languageCode;
    final to = choice.$1 ?? locale;
    final (_, skip, active, hidden) = choice;
    _translation.configure(to: to, skip: skip, active: active);
    _translateShown = false;
    if (list == null || _listOpen) return null;
    final detected = _translation.chatLanguage(list);
    final source = active ? _translation.language : detected;
    if (!active &&
        (hidden || source == null || source == to || skip.contains(source))) {
      return null;
    }
    _translateShown = true;
    final state = !active
        ? TranslateBarState.offer
        : _translation.working
        ? TranslateBarState.working
        : TranslateBarState.shown;
    return ChatTranslateBar(
      key: const ValueKey('translateBar'),
      state: state,
      primary: switch (state) {
        TranslateBarState.offer => l10n.translateTo(languageName(to, locale)),
        TranslateBarState.working => l10n.translating,
        TranslateBarState.shown => l10n.translateShowOriginal,
      },
      secondary: state == TranslateBarState.shown
          ? source == null
                ? l10n.translated
                : l10n.translatedFrom(languageName(source, locale, from: true))
          : null,
      optionsTooltip: l10n.translateOptions,
      onPrimary: () => _setTranslating(!active),
      onOptions: (position) => _translateMenu(position, source, active),
    );
  }

  void _updateTranslation(Preferences Function(Preferences p) change) =>
      ref.read(preferencesProvider.notifier).update(change);

  void _setTranslating(bool on) {
    final chatId = widget.chatId;
    _updateTranslation(
      (p) => p.copyWith(
        translateChats: on
            ? {...p.translateChats, chatId}
            : ({...p.translateChats}..remove(chatId)),
      ),
    );
  }

  void _translateMenu(Offset position, String? source, bool active) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final chatId = widget.chatId;
    unawaited(
      showMgMenu(
        context,
        position: position,
        items: [
          MgMenuItem(
            label: l10n.translateChooseLanguage,
            icon: MgIcons.translate,
            submenu: [
              for (final code in translateTargets)
                MgMenuItem(
                  label: languageName(code, locale),
                  onSelected: () => _updateTranslation(
                    (p) => p.copyWith(
                      translateTo: code,
                      translateChats: {...p.translateChats, chatId},
                    ),
                  ),
                ),
            ],
          ),
          if (source != null)
            MgMenuItem(
              label: l10n.translateSkipLanguage(languageName(source, locale)),
              icon: MgIcons.close,
              onSelected: () => _updateTranslation(
                (p) => p.copyWith(
                  translateSkip: {...p.translateSkip, source},
                  translateChats: {...p.translateChats}..remove(chatId),
                ),
              ),
            ),
          if (!active)
            MgMenuItem(
              label: l10n.translateHideBar,
              icon: MgIcons.hide,
              onSelected: () => _updateTranslation(
                (p) =>
                    p.copyWith(translateHidden: {...p.translateHidden, chatId}),
              ),
            ),
        ],
      ),
    );
  }

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
      listTooltip: l10n.pinnedList,
      onList: () => setState(() {
        _pinnedListOpen = true;
        _selected = null;
      }),
    );
  }

  void _closePinnedList() {
    if (!_pinnedListOpen) return;
    setState(() => _pinnedListOpen = false);
    _focus.requestFocus();
  }

  /// A list in place of the timeline: the pinned or the scheduled messages.
  bool get _listOpen =>
      _pinnedListOpen ||
      _scheduledOpen ||
      _thread != null ||
      _forum ||
      _savedOpen;

  /// Whether this chat is a forum group, whose timeline is its topics.
  bool get _forum => _conversations.store.isForum(widget.chatId);

  /// Whether this chat is the user's Saved Messages.
  bool get _saved => _conversations.isSavedMessages(widget.chatId);

  /// Switches Saved Messages between its timeline and the list of the
  /// chats the messages came from.
  void _toggleSaved() {
    if (_thread?.isSavedTopic ?? false) _closeThread();
    setState(() => _savedOpen = !_savedOpen);
  }

  /// The Saved Messages topics in the timeline's place, loading them the
  /// first time.
  Widget _savedTopicsView(ConversationStore store) {
    final topics = _savedTopics;
    if (topics == null) {
      if (!_savedTopicsOpening) {
        _savedTopicsOpening = true;
        scheduleMicrotask(() => unawaited(_openSavedTopics()));
      }
      return const SizedBox.shrink();
    }
    return SavedTopicListView(
      key: const ValueKey('savedTopics'),
      topics: topics.topics,
      store: store,
      myId: _conversations.myId,
      topInset: _topInset,
      onOpen: (topic) => unawaited(_openSavedTopic(topic)),
      onNearEnd: () => unawaited(_quiet(topics.loadMore())),
      onMenu: (topic, position) => unawaited(
        showSavedTopicMenu(
          context,
          conversations: _conversations,
          list: topics,
          topic: topic,
          position: position,
        ),
      ),
    );
  }

  Future<void> _openSavedTopics() async {
    final chatId = widget.chatId;
    final list = _conversations.openSavedTopics();
    try {
      await list.load();
    } on td.TdException {
      list.dispose();
      if (mounted && widget.chatId == chatId) _savedTopicsOpening = false;
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      list.dispose();
      return;
    }
    setState(() => _savedTopics = list);
    _savedTopicsSub = list.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  /// Opens Saved Messages [topic] in the list's place, with a composer,
  /// until the back capsule closes it.
  Future<void> _openSavedTopic(td.SavedMessagesTopic topic) async {
    final chatId = widget.chatId;
    final MessageThread thread;
    try {
      thread = await _conversations.openSavedTopic(chatId, topic);
      await thread.load();
    } on td.TdException {
      if (mounted) {
        showMgToast(context, AppLocalizations.of(context).topicUnavailable);
      }
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      thread.dispose();
      return;
    }
    _dropThread();
    setState(() {
      _thread = thread;
      _selected = null;
    });
    _threadSub = thread.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _threadFocus.requestFocus();
  }

  void _dropSavedTopics() {
    _savedTopicsSub?.cancel();
    _savedTopicsSub = null;
    _savedTopics?.dispose();
    _savedTopics = null;
    _savedTopicsOpening = false;
    _savedOpen = false;
    _savedTagsSub?.cancel();
    _savedTagsSub = null;
    _savedTags?.dispose();
    _savedTags = null;
    _savedTagsOpening = false;
  }

  /// The tag whose messages the open thread shows, as a reaction key.
  String? get _selectedTag => switch (_thread?.savedTag) {
    final tag? => reactionKey(tag),
    null => null,
  };

  /// Whether the tag bar has a place: Saved Messages with tags, showing
  /// the timeline or one tag's messages.
  bool get _tagsShown =>
      _saved &&
      (_savedTags?.tags.isNotEmpty ?? false) &&
      (!_listOpen || _selectedTag != null);

  /// The tag bar under the header, loading the tags the first time Saved
  /// Messages shows.
  Widget? _tagBar(AppLocalizations l10n) {
    if (!_saved) return null;
    final tags = _savedTags;
    if (tags == null) {
      if (!_savedTagsOpening) {
        _savedTagsOpening = true;
        scheduleMicrotask(() => unawaited(_openSavedTags()));
      }
      return null;
    }
    if (!_tagsShown) return null;
    return SavedTagBar(
      tags: tags.tags,
      selected: _selectedTag,
      onSelect: (tag) => unawaited(_toggleSavedTag(tag)),
      onMenu: (tag, position) => unawaited(_showTagMenu(l10n, tag, position)),
    );
  }

  Future<void> _openSavedTags() async {
    final chatId = widget.chatId;
    final tags = _conversations.openSavedTags();
    try {
      await tags.load();
    } on td.TdException {
      tags.dispose();
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      tags.dispose();
      return;
    }
    setState(() => _savedTags = tags);
    _savedTagsSub = tags.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  /// Shows the Saved Messages carrying [tag] in the timeline's place, or
  /// the whole timeline again when its chip is clicked once more.
  Future<void> _toggleSavedTag(td.SavedMessagesTag tag) async {
    if (_selectedTag == reactionKey(tag.tag)) {
      _closeThread();
      return;
    }
    final chatId = widget.chatId;
    final MessageThread thread;
    try {
      thread = await _conversations.openSavedTag(chatId, tag.tag);
      await thread.load();
    } on td.TdException {
      if (mounted) {
        showMgToast(context, AppLocalizations.of(context).savedTagFailed);
      }
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      thread.dispose();
      return;
    }
    _dropThread();
    setState(() {
      _thread = thread;
      _savedOpen = false;
      _selected = null;
    });
    _threadSub = thread.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _threadFocus.requestFocus();
  }

  Future<void> _showTagMenu(
    AppLocalizations l10n,
    td.SavedMessagesTag tag,
    Offset position,
  ) async {
    final tags = _savedTags;
    if (tags == null) return;
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.savedTagName,
          icon: MgIcons.tag,
          onSelected: () => unawaited(_nameTag(l10n, tags, tag)),
        ),
        if (tag.label.isNotEmpty)
          MgMenuItem(
            label: l10n.savedTagClearName,
            icon: MgIcons.clear,
            onSelected: () => unawaited(_quiet(tags.setLabel(tag.tag, ''))),
          ),
      ],
    );
  }

  Future<void> _nameTag(
    AppLocalizations l10n,
    SavedTags tags,
    td.SavedMessagesTag tag,
  ) async {
    final label = await showMgPrompt(
      context,
      title: l10n.savedTagName,
      confirmLabel: l10n.save,
      cancelLabel: l10n.cancel,
      hint: tag.label,
    );
    if (label == null || !mounted) return;
    await _quiet(tags.setLabel(tag.tag, label.trim()));
  }

  /// The name of the topic the open thread is, forum or Saved Messages.
  String? _threadTopicName(AppLocalizations l10n) {
    final thread = _thread;
    if (thread == null) return null;
    if (thread.forumTopic case final topic?) return topic.name;
    if (thread.savedTopic case final topic?) {
      return savedTopicName(l10n, _conversations.store, topic);
    }
    if (thread.savedTag case final tag?) {
      final key = reactionKey(tag);
      final named = _savedTags?.tags.where((t) => reactionKey(t.tag) == key);
      return named == null || named.isEmpty ? key : savedTagName(named.first);
    }
    return null;
  }

  /// The topic list in the timeline's place, loading it the first time.
  Widget _topicsView(ConversationStore store) {
    final topics = _topics;
    if (topics == null) {
      if (!_topicsOpening) {
        _topicsOpening = true;
        scheduleMicrotask(() => unawaited(_openTopics()));
      }
      return const Center(child: LoadSpinner());
    }
    return ForumTopicListView(
      key: const ValueKey('forumTopics'),
      topics: topics.topics,
      store: store,
      topInset: _topInset,
      onOpen: (topic) => unawaited(_openTopic(topic)),
      onNearEnd: () => unawaited(_quiet(topics.loadMore())),
      onMenu: (topic, position) => unawaited(
        showTopicMenu(
          context,
          conversations: _conversations,
          list: topics,
          topic: topic,
          position: position,
        ),
      ),
      onCreate: store.canCreateTopics(widget.chatId)
          ? () => unawaited(showTopicSheet(context, widget.chatId))
          : null,
    );
  }

  Future<void> _openTopics() async {
    final chatId = widget.chatId;
    final list = _conversations.openTopics(chatId);
    try {
      await list.load();
    } on Object {
      list.dispose();
      // A chat restored at launch can ask before the session is ready;
      // the list is asked for again after a moment rather than left blank.
      if (mounted && widget.chatId == chatId) {
        _topicsRetry?.cancel();
        _topicsRetry = Timer(const Duration(seconds: 2), () {
          if (!mounted || widget.chatId != chatId) return;
          setState(() => _topicsOpening = false);
        });
      }
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      list.dispose();
      return;
    }
    setState(() => _topics = list);
    _topicsSub = list.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  /// Opens [topic]: its messages take the topic list's place, with a
  /// composer under them, until the back capsule closes it.
  Future<void> _openTopic(td.ForumTopic topic) async {
    final chatId = widget.chatId;
    final MessageThread thread;
    try {
      thread = await _conversations.openTopic(chatId, topic.info.forumTopicId);
      await thread.load();
    } on td.TdException {
      if (mounted) {
        showMgToast(context, AppLocalizations.of(context).topicUnavailable);
      }
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      thread.dispose();
      return;
    }
    _dropThread();
    setState(() {
      _thread = thread;
      _selected = null;
    });
    _threadSub = thread.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _threadFocus.requestFocus();
  }

  /// The sponsored message under a channel's timeline, asked for the
  /// first time the chat shows as a channel.
  Widget? _sponsoredCard(ConversationStore store) {
    final chatId = widget.chatId;
    if (_listOpen || _selected != null || !store.isChannel(chatId)) {
      return null;
    }
    if (!_sponsoredAsked) {
      _sponsoredAsked = true;
      unawaited(_loadSponsored(chatId));
      return null;
    }
    final message = _sponsored;
    if (message == null) return null;
    return SponsoredMessageCard(
      key: ValueKey(('sponsored', chatId, message.messageId)),
      message: message,
      onViewed: () => unawaited(
        _quiet(_conversations.viewSponsored(chatId, message.messageId)),
      ),
      onOpen: () => unawaited(
        _quiet(_conversations.clickSponsored(chatId, message.messageId)),
      ),
    );
  }

  Future<void> _loadSponsored(int chatId) async {
    final messages = await _conversations.sponsoredMessages(chatId);
    if (!mounted || widget.chatId != chatId || messages.isEmpty) return;
    setState(() => _sponsored = messages.first);
  }

  void _dropTopics() {
    _topicsRetry?.cancel();
    _topicsRetry = null;
    _topicsSub?.cancel();
    _topicsSub = null;
    _topics?.dispose();
    _topics = null;
    _topicsOpening = false;
  }

  /// The source of a forward: a channel opens at the original post when
  /// Telegram says which it was, a group or channel posting for itself
  /// opens as it is, and a person opens as their profile.
  Future<void> _openForwardSource(td.MessageOrigin origin) async {
    final workspace = ref.read(workspaceControllerProvider);
    switch (origin) {
      case td.MessageOriginChannel(:final chatId, :final messageId):
        if (messageId != 0) {
          ref.read(messageJumpProvider.notifier).request(chatId, messageId);
        }
        workspace.open(chatId);
      case td.MessageOriginChat(:final senderChatId):
        workspace.open(senderChatId);
      case td.MessageOriginUser(:final senderUserId):
        final peers = ref.read(telegramSessionProvider).requireValue.peers;
        final int chatId;
        try {
          chatId = await peers.privateChatOf(senderUserId);
        } on Object {
          return;
        }
        if (mounted) openPeerInfo(ref, chatId);
      case td.MessageOriginHiddenUser():
    }
  }

  /// Opens the profile of [sender], or the info of the channel it is.
  Future<void> _openSender(MessageSenderId sender) async {
    if (sender.isChat) {
      openPeerInfo(ref, sender.id);
      return;
    }
    final peers = ref.read(telegramSessionProvider).requireValue.peers;
    final int chatId;
    try {
      chatId = await peers.privateChatOf(sender.id);
    } on Object {
      return;
    }
    if (mounted) openPeerInfo(ref, chatId);
  }

  /// Opens the comments under [message], a channel post: its thread in
  /// the discussion group takes the timeline's place.
  Future<void> _openComments(ConversationMessage message) async {
    final chatId = widget.chatId;
    final MessageThread thread;
    try {
      thread = await _conversations.openThread(message.chatId, message.id);
      await thread.load();
    } on td.TdException {
      if (mounted) {
        showMgToast(context, AppLocalizations.of(context).commentsUnavailable);
      }
      return;
    }
    if (!mounted || widget.chatId != chatId) {
      thread.dispose();
      return;
    }
    _dropThread();
    setState(() {
      _thread = thread;
      _selected = null;
    });
    _threadSub = thread.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _threadFocus.requestFocus();
  }

  void _closeThread() {
    if (_thread == null) return;
    setState(_dropThread);
    _focus.requestFocus();
  }

  void _dropThread() {
    _threadSub?.cancel();
    _threadSub = null;
    _thread?.dispose();
    _thread = null;
    _threadReplyTo = null;
    _threadQuote = null;
    _threadEditing = null;
    _threadDraft.clear();
  }

  /// The comment being answered or changed, shown above the composer.
  ConversationMessage? _threadReplyTo;
  QuoteSelection? _threadQuote;
  ConversationMessage? _threadEditing;

  Future<void> _showThreadMenu(MessageRow row, Offset position) {
    final thread = _thread;
    if (thread == null) return Future.value();
    return showMessageMenu(
      context,
      conversations: _conversations,
      row: row,
      position: position,
      isShown: () => mounted && _thread == thread,
      quote: _textSelection,
      handlers: MessageMenuHandlers(
        onReply: _replyInThread,
        onQuote: (message, quote) => _replyInThread(message, quote: quote),
        onEdit: _editInThread,
        onForward: (messages) => unawaited(_forward(messages)),
        recentChats: _recentForwardTargets,
        onForwardTo: (messages, chatId) =>
            unawaited(_forward(messages, toChat: chatId)),
        onSelect: _select,
      ),
    );
  }

  void _replyInThread(ConversationMessage message, {QuoteSelection? quote}) {
    if (_thread?.chatId != message.chatId) return;
    setState(() {
      if (_threadEditing != null) {
        _threadEditing = null;
        _threadDraft.clear();
      }
      _threadReplyTo = message;
      _threadQuote = quote;
    });
    _threadFocus.requestFocus();
  }

  void _editInThread(ConversationMessage message) {
    if (_thread?.chatId != message.chatId) return;
    setState(() {
      _threadEditing = message;
      _threadReplyTo = null;
      _threadQuote = null;
    });
    final text = captionOf(message.content);
    _threadDraft.setFormatted(
      message.text,
      text == null ? const [] : draftRanges(text),
    );
    _threadFocus.requestFocus();
  }

  /// Esc under the comments: drop the edit or the reply first, then go
  /// back to the chat.
  void _cancelInThread() {
    if (_threadEditing != null || _threadReplyTo != null) {
      setState(() {
        if (_threadEditing != null) _threadDraft.clear();
        _threadEditing = null;
        _threadReplyTo = null;
        _threadQuote = null;
      });
    } else {
      _closeThread();
    }
  }

  Future<void> _sendComment(String text) async {
    final thread = _thread;
    if (thread == null) return;
    final editing = _threadEditing;
    if (editing != null && (text.trim().isNotEmpty || _isCaption(editing))) {
      return _saveCommentEdit(editing, text);
    }
    if (text.trim().isEmpty) return;
    final formatted = formattedDraft(text, _threadDraft.ranges);
    if (formatted.text.isEmpty) return;
    final replyTo = _threadReplyTo;
    final quote = _threadQuote;
    _threadDraft.clear();
    setState(() {
      _threadReplyTo = null;
      _threadQuote = null;
    });
    try {
      await thread.send(
        formatted.text,
        entities: formatted.entities,
        replyTo: replyTo?.id,
        quote: quote?.text,
        quotePosition: quote?.position ?? 0,
      );
    } on td.TdException {
      if (mounted) setState(() => _failure = _Failure.send);
    }
  }

  Future<void> _saveCommentEdit(
    ConversationMessage message,
    String text,
  ) async {
    final formatted = formattedDraft(text, _threadDraft.ranges);
    final old = captionOf(message.content);
    final unchanged = old != null && sameDraft(formatted, old);
    if (!unchanged && formatted.text.isEmpty && !_isCaption(message)) return;
    _threadDraft.clear();
    setState(() => _threadEditing = null);
    if (unchanged) return;
    try {
      await _conversations.editText(
        message.chatId,
        message.id,
        formatted.text,
        entities: formatted.entities,
      );
    } on td.TdException {
      if (mounted) setState(() => _failure = _Failure.edit);
    }
  }

  Widget? _threadComposerHeader(AppLocalizations l10n) {
    if (_threadEditing case final editing?) {
      return ComposerContextBar(
        icon: MgIcons.edit,
        title: l10n.editingMessage,
        text: describeContent(l10n, editing.content),
        closeTooltip: l10n.close,
        onClose: _cancelInThread,
      );
    }
    if (_threadReplyTo case final reply?) {
      return ComposerContextBar(
        title: nameOfSender(l10n, _conversations.store, reply.sender),
        text: _threadQuote?.text ?? describeContent(l10n, reply.content),
        closeTooltip: l10n.close,
        onClose: _cancelInThread,
      );
    }
    return null;
  }

  late final _threadActions = MessageRowActions(
    onReaction: _actions.onReaction,
    onNeedReplied: _actions.onNeedReplied,
    onMenu: (row, position) => unawaited(_showThreadMenu(row, position)),
    onSelectToggle: _toggleSelected,
    onViewMedia: _actions.onViewMedia,
    onCancelSend: _actions.onCancelSend,
    onRetrySend: _actions.onRetrySend,
    onTextSelected: _actions.onTextSelected,
    onPollVote: _actions.onPollVote,
    onPollVoters: _actions.onPollVoters,
    onInlineButton: _actions.onInlineButton,
  );

  /// The composer under the comments; Esc cancels the reply or edit, then
  /// goes back to the chat.
  Widget _threadComposer(AppLocalizations l10n, MessageThread thread) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _cancelInThread();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Composer(
      controller: _threadDraft,
      focusNode: _threadFocus,
      labels: ComposerLabels(
        hint: (_thread?.isStandalone ?? false)
            ? l10n.messageHint
            : _thread?.chatId == widget.chatId
            ? l10n.replyHint
            : l10n.commentHint,
        attach: l10n.attach,
        emoji: l10n.emoji,
        record: l10n.record,
        send: l10n.send,
        format: formatLabelsOf(l10n),
      ),
      header: _threadComposerHeader(l10n),
      allowEmpty: _threadEditing != null && _isCaption(_threadEditing!),
      onAttach: () => unawaited(_chooseFiles()),
      onPaste: _paste,
      onSend: (text) => unawaited(_sendComment(text)),
    ),
  );

  void _openScheduled() {
    setState(() {
      _scheduledOpen = true;
      _selected = null;
    });
    unawaited(_loadScheduled());
  }

  void _closeScheduled() {
    if (!_scheduledOpen) return;
    setState(() => _scheduledOpen = false);
    _focus.requestFocus();
  }

  Future<void> _loadScheduled() async {
    final chatId = widget.chatId;
    final store = _conversations.store;
    final version = store.scheduledVersion(chatId);
    _scheduledSeen = version;
    final List<ConversationMessage> messages;
    try {
      messages = await _conversations.scheduledMessages(chatId);
    } on Object {
      return;
    }
    if (!mounted || widget.chatId != chatId) return;
    setState(() => _scheduled = messages);
    // Nothing left to wait for: back to the chat.
    if (messages.isEmpty && !store.hasScheduledMessages(chatId)) {
      _closeScheduled();
    }
  }

  /// The bar under the scheduled list: back to the chat, also on Esc.
  Widget _scheduledBar(AppLocalizations l10n) => Focus(
    autofocus: true,
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _closeScheduled();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: ComposerActionBar(
      label: l10n.backToChat,
      onPressed: _closeScheduled,
    ),
  );

  late final _scheduledActions = MessageRowActions(
    onReaction: (message, reaction, chosen) {},
    onNeedReplied: (reply) =>
        unawaited(_quiet(_conversations.loadReplied(reply.chatId, reply.id))),
    onMenu: (row, position) => unawaited(_scheduledMenu(row, position)),
    onViewMedia: (message) => unawaited(
      showChatMediaViewer(
        context,
        message: message,
        conversations: _conversations,
      ),
    ),
  );

  /// The menu of a scheduled message, as in Telegram for macOS: send it
  /// now, move it, or drop it.
  Future<void> _scheduledMenu(MessageRow row, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final chatId = widget.chatId;
    final ids = [for (final message in row.messages) message.id];
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.menuSendNow,
          icon: MgIcons.send,
          onSelected: () => unawaited(
            _quiet(_conversations.sendScheduledNow(chatId, row.primary.id)),
          ),
        ),
        MgMenuItem(
          label: l10n.menuReschedule,
          icon: MgIcons.recent,
          onSelected: () => unawaited(_rescheduleMessage(row.primary.id)),
        ),
        MgMenuItem(
          label: l10n.menuDelete,
          icon: MgIcons.trash,
          destructive: true,
          onSelected: () =>
              unawaited(_quiet(_conversations.deleteScheduled(chatId, ids))),
        ),
      ],
    );
  }

  Future<void> _rescheduleMessage(int messageId) async {
    final chatId = widget.chatId;
    final when = await pickScheduleTime(context);
    if (when == null || !mounted || widget.chatId != chatId) return;
    await _quiet(_conversations.reschedule(chatId, messageId, when));
  }

  /// The pinned messages, newest first, as the timeline wants them.
  List<ConversationMessage> _pinnedMessages(ConversationStore store) {
    final chatId = widget.chatId;
    return [
      for (final id in store.pinnedIds(chatId)) ?store.message(chatId, id),
    ];
  }

  /// The bar under the pinned list: unpins every message after asking.
  /// Esc goes back to the chat.
  Widget _unpinAllBar(AppLocalizations l10n, ConversationStore store) {
    final count = store.pinnedIds(widget.chatId).length;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _closePinnedList();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ComposerActionBar(
        label: l10n.unpinAll,
        loading: _actionPending,
        onPressed: () => unawaited(_unpinAll(count)),
      ),
    );
  }

  Future<void> _unpinAll(int count) async {
    final l10n = AppLocalizations.of(context);
    final chatId = widget.chatId;
    final confirmed = await showMgConfirm(
      context,
      title: l10n.unpinAllTitle(count),
      confirmLabel: l10n.unpinAll,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null || !mounted || widget.chatId != chatId) return;
    await _chatAction(() => _conversations.unpinAll(chatId));
    if (mounted && widget.chatId == chatId) _closePinnedList();
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
    onPollVote: (message, optionIds) => unawaited(
      _quiet(_conversations.votePoll(message.chatId, message.id, optionIds)),
    ),
    onPollVoters: (message, index, position) =>
        unawaited(_showPollVoters(message, index, position)),
    onChecklistToggle: (message, taskId, done) => unawaited(
      _quiet(
        _conversations.markChecklistTask(
          message.chatId,
          message.id,
          taskId,
          done: done,
        ),
      ),
    ),
    onInlineButton: (message, button) =>
        unawaited(_pressInlineButton(message, button)),
    onComments: (message) => unawaited(_openComments(message)),
    onOpenForwardSource: (origin) => unawaited(_openForwardSource(origin)),
    onOpenSender: (sender) => unawaited(_openSender(sender)),
    onMenu: (row, position) => unawaited(_showMenu(row, position)),
    onCancelSend: (message) => unawaited(
      _quiet(_conversations.cancelSending(message.chatId, [message.id])),
    ),
    onRetrySend: (message) => unawaited(
      _quiet(_conversations.resendMessages(message.chatId, [message.id])),
    ),
    onViewMedia: (message) => unawaited(
      showChatMediaViewer(
        context,
        message: message,
        conversations: _conversations,
        onForward: (message) => unawaited(_forward([message])),
        onShowInChat: (message) => unawaited(_jumpTo(message.id)),
        onDelete: _deleteFromViewer,
      ),
    ),
    onJump: (messageId) => unawaited(_jumpTo(messageId)),
    onSelectToggle: _toggleSelected,
    onTextSelected: (message, quote) => _textSelection = quote == null
        ? null
        : (message: message, quote: quote),
  );

  /// The scroll offset that puts the anchor's row just under the header.
  double _underHeader(double viewport) => -(viewport - _topInset - 8);

  /// Where the timeline starts under the header and the pinned bar.
  double get _topInset =>
      TimelineView.headerInset +
      _translateInset +
      (_tagsShown ? SavedTagBar.height : 0) +
      (_pinnedShown && !_pinnedListOpen ? PinnedBar.height : 0);

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

  /// Lets go of the newest message in a side list (comments, pinned or
  /// scheduled messages) once the user scrolls away from it, and picks it
  /// up again when they come back; without this the view snaps back to the
  /// bottom and the list cannot be read upwards.
  void _followList(TimelineScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    final fromBottom = position.pixels - position.minScrollExtent;
    if (position.isScrollingNotifier.value || fromBottom < 2) {
      controller.pinned = fromBottom < 2;
    }
  }

  /// Rows ask for more history as they are built, but a page that came
  /// back short or empty builds nothing new: the scroll position asks
  /// again, so the top of a chat or of comments is never a dead end.
  void _topUp(ScrollController controller) {
    if (!controller.hasClients) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    if (position.maxScrollExtent - position.pixels > 600) return;
    if (controller == _threadScroll) {
      unawaited(_quiet(_thread?.loadOlder() ?? Future<void>.value()));
    } else if (!_conversations.store.reachedStart(widget.chatId)) {
      _loadOlder();
    }
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
        viewport - _bottomInset - 4,
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
      quote: _textSelection,
      handlers: MessageMenuHandlers(
        onReply: _reply,
        onQuote: (message, quote) => _reply(message, quote: quote),
        onEdit: _edit,
        onForward: (messages) => unawaited(_forward(messages)),
        recentChats: _recentForwardTargets,
        onForwardTo: (messages, chatId) =>
            unawaited(_forward(messages, toChat: chatId)),
        onSelect: _select,
        onEditHistory: _session.capture.keepEdits ? _showEditHistory : null,
      ),
    );
  }

  /// Starts selecting with [row], or adds it when already selecting.
  void _select(MessageRow row) {
    if (row.primary.chatId != _selectionChatId) return;
    final selected = _selected ?? <int>{};
    selected.addAll([for (final message in row.messages) message.id]);
    _setSelection(selected);
  }

  void _toggleSelected(MessageRow row) {
    final selected = _selected;
    if (selected == null) return;
    final ids = [for (final message in row.messages) message.id];
    if (ids.any(selected.contains)) {
      selected.removeAll(ids);
    } else {
      selected.addAll(ids);
    }
    // Taking the last one out ends the selection, as in the official app.
    _setSelection(selected.isEmpty ? null : selected);
  }

  void _setSelection(Set<int>? selected) {
    // A fresh set each time, so a request for properties can tell whether
    // the selection it was made for still stands.
    final fresh = selected == null ? null : Set.of(selected);
    setState(() {
      _selected = fresh;
      _selectedProperties = null;
      _canForwardSelected = false;
    });
    if (fresh == null) {
      _focus.requestFocus();
    } else {
      unawaited(_loadSelectedProperties(fresh));
    }
  }

  void _clearSelection() {
    if (_selected != null) _setSelection(null);
  }

  /// The chat whose messages are selected: the open thread's (comments,
  /// a topic, a Saved Messages tag) or this one.
  int get _selectionChatId => _thread?.chatId ?? widget.chatId;

  /// The selected messages, oldest first.
  List<ConversationMessage> _selectedMessages() {
    final selected = _selected ?? const <int>{};
    final shown =
        _thread?.messages ?? _conversations.store.messagesFor(widget.chatId);
    return [
      for (final message in shown)
        if (selected.contains(message.id)) message,
    ].reversed.toList();
  }

  /// Fetches what may be done with the selection; the bar's commands
  /// enable once it is known. A change of selection meanwhile wins.
  Future<void> _loadSelectedProperties(Set<int> selected) async {
    final chatId = _selectionChatId;
    final ids = selected.toList();
    final List<td.MessageProperties> properties;
    try {
      properties = await Future.wait([
        for (final id in ids) _conversations.propertiesOf(chatId, id),
      ]);
    } on Object {
      return;
    }
    if (!mounted ||
        _selectionChatId != chatId ||
        !identical(_selected, selected)) {
      return;
    }
    setState(() {
      _selectedProperties = properties;
      _canForwardSelected = properties.every((p) => p.canBeForwarded);
    });
  }

  /// Copies the texts of the selected messages, one under another.
  Future<void> _copySelected() async {
    final texts = [
      for (final message in _selectedMessages())
        if (message.text.isNotEmpty) message.text,
    ];
    _clearSelection();
    if (texts.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: texts.join('\n\n')));
  }

  Future<void> _forwardSelected() async {
    final messages = _selectedMessages();
    _clearSelection();
    await _forward(messages);
  }

  /// Delete from the media viewer: asks over it, with [viewer] as the
  /// dialog's context, and tells whether the deletion was requested.
  Future<bool> _deleteFromViewer(
    BuildContext viewer,
    ConversationMessage message,
  ) async {
    final chatId = widget.chatId;
    final td.MessageProperties properties;
    try {
      properties = await _conversations.propertiesOf(
        message.chatId,
        message.id,
      );
    } on Object {
      return false;
    }
    if (!mounted || !viewer.mounted || widget.chatId != chatId) return false;
    final store = _conversations.store;
    final chat = ref.read(chatEntryProvider(chatId)).value;
    final isPrivate = chat != null && !chat.isGroup && !store.isChannel(chatId);
    return confirmDeleteMessages(
      viewer,
      conversations: _conversations,
      messages: [message],
      properties: [properties],
      peerName: isPrivate ? chat.title : null,
      isShown: () => mounted && widget.chatId == chatId,
    );
  }

  Future<void> _deleteSelected() async {
    final properties = _selectedProperties;
    final messages = _selectedMessages();
    if (properties == null || messages.isEmpty) return;
    final store = _conversations.store;
    final chat = ref.read(chatEntryProvider(widget.chatId)).value;
    final isPrivate =
        chat != null && !chat.isGroup && !store.isChannel(widget.chatId);
    final chatId = widget.chatId;
    await confirmDeleteMessages(
      context,
      conversations: _conversations,
      messages: messages,
      properties: properties,
      peerName: isPrivate ? chat.title : null,
      isShown: () => mounted && widget.chatId == chatId,
    );
    if (mounted && widget.chatId == chatId) _clearSelection();
  }

  /// The bar in place of the composer while messages are selected. Esc
  /// ends the selection.
  Widget _selectionBar(AppLocalizations l10n) {
    final selected = _selected!;
    final properties = _selectedProperties;
    final canDelete =
        properties != null &&
        (properties.every((p) => p.canBeDeletedForAllUsers) ||
            properties.every((p) => p.canBeDeletedOnlyForSelf));
    final hasText = _selectedMessages().any((m) => m.text.isNotEmpty);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _clearSelection();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SelectionBar(
        countLabel: l10n.selectedCount(selected.length),
        closeTooltip: l10n.clearSelection,
        onClose: _clearSelection,
        actions: [
          SelectionBarAction(
            label: l10n.copy,
            onPressed: hasText ? () => unawaited(_copySelected()) : null,
          ),
          SelectionBarAction(
            label: l10n.menuForward,
            onPressed: _canForwardSelected
                ? () => unawaited(_forwardSelected())
                : null,
          ),
          SelectionBarAction(
            label: l10n.menuDelete,
            destructive: true,
            onPressed: canDelete ? () => unawaited(_deleteSelected()) : null,
          ),
        ],
      ),
    );
  }

  void _reply(ConversationMessage message, {QuoteSelection? quote}) {
    // The chat may have changed while the menu was open.
    if (message.chatId != widget.chatId) return;
    if (_editing != null) _stopEditing();
    setState(() {
      _replyTo = message;
      _replyQuote = quote;
    });
    _focus.requestFocus();
  }

  void _edit(ConversationMessage message) {
    if (message.chatId != widget.chatId) return;
    if (_editing == null) {
      _setAside = _draft.text;
      _setAsideRanges = _draft.ranges;
      _replyAside = _replyTo;
      _quoteAside = _replyQuote;
    }
    setState(() {
      _editing = message;
      _replyTo = null;
      _replyQuote = null;
    });
    final text = captionOf(message.content);
    _draft.setFormatted(
      message.text,
      text == null ? const [] : draftRanges(text),
    );
    _focus.requestFocus();
  }

  void _stopEditing() {
    final draft = _setAside;
    final ranges = _setAsideRanges;
    _setAside = '';
    _setAsideRanges = const [];
    setState(() {
      _editing = null;
      if (_failure == _Failure.edit) _failure = null;
      _replyTo = _replyAside;
      _replyQuote = _quoteAside;
      _replyAside = null;
      _quoteAside = null;
    });
    _draft.setFormatted(draft, ranges);
  }

  /// Esc: stop editing first, then stop replying.
  void _cancel() {
    if (_panelOpen) {
      setState(() => _panelOpen = false);
    } else if (_editing != null) {
      _stopEditing();
    } else if (_replyTo != null) {
      setState(() {
        _replyTo = null;
        _replyQuote = null;
      });
    }
  }

  /// What a bot's inline button does: open its link, copy its text, or
  /// ask the bot and show what it answers.
  /// Lists who voted for option [index] of the poll in [message], in a
  /// popover at [position]; a click on a voter opens them.
  Future<void> _showPollVoters(
    ConversationMessage message,
    int index,
    Offset position,
  ) async {
    final content = message.content;
    if (content is! td.MessagePoll) return;
    final option = content.poll.options[index];
    final List<MessageSenderId> voters;
    try {
      voters = await _conversations.pollVoters(
        message.chatId,
        message.id,
        index,
      );
    } on td.TdException {
      return;
    }
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final store = _conversations.store;
    await showMgPopover(
      context,
      position: position,
      child: PollVotersList(
        option: option.text.text,
        voterCount: option.voterCount,
        voters: [
          for (final id in voters)
            (
              id: id,
              name: nameOfSender(l10n, store, id),
              photo: store.photoOf(id),
            ),
        ],
        onOpen: (id) {
          Navigator.of(context).pop();
          if (!id.isChat) openLinkFrom(context, 'tg://user?id=${id.id}');
        },
      ),
    );
  }

  Future<void> _pressInlineButton(
    ConversationMessage message,
    td.InlineKeyboardButton button,
  ) async {
    final l10n = AppLocalizations.of(context);
    switch (button.type) {
      case td.InlineKeyboardButtonTypeUrl(:final url):
      case td.InlineKeyboardButtonTypeLoginUrl(:final url):
      case td.InlineKeyboardButtonTypeWebApp(:final url):
        openLinkFrom(context, url);
      case td.InlineKeyboardButtonTypeUser(:final userId):
        openLinkFrom(context, 'tg://user?id=$userId');
      case td.InlineKeyboardButtonTypeCopyText(:final text):
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) showMgToast(context, l10n.copied);
      case td.InlineKeyboardButtonTypeSwitchInline(
        :final query,
        :final targetChat,
      ):
        await _switchInline(message, query, targetChat);
      case td.InlineKeyboardButtonTypeCallback(:final data):
        final td.CallbackQueryAnswer answer;
        try {
          answer = await _conversations.callbackQuery(
            message.chatId,
            message.id,
            data,
          );
        } on td.TdException {
          if (mounted) showMgToast(context, l10n.botNoAnswer);
          return;
        }
        if (!mounted) return;
        if (answer.url.isNotEmpty) openLinkFrom(context, answer.url);
        if (answer.text.isNotEmpty) showMgToast(context, answer.text);
      default:
        break;
    }
  }

  /// Starts an inline query to the bot behind [message] with [query]: in
  /// the composer here, in a chat the user picks, or where an internal
  /// link leads, as [target] says.
  Future<void> _switchInline(
    ConversationMessage message,
    String query,
    td.TargetChat target,
  ) async {
    if (target case td.TargetChatInternalLink(:final link)) {
      if (link case td.InternalLinkTypeBotStart(:final botUsername)) {
        openLinkFrom(context, 'https://t.me/$botUsername');
      }
      return;
    }
    final viaBot = message.message.viaBotUserId;
    final botId = viaBot != 0
        ? viaBot
        : message.sender.isChat
        ? null
        : message.sender.id;
    if (botId == null) return;
    final text = await _conversations.switchInlineText(botId, query);
    if (text == null || !mounted) return;
    switch (target) {
      case td.TargetChatCurrent():
        _draft.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _focus.requestFocus();
      case td.TargetChatChosen():
        final choice = await pickForwardTarget(context);
        if (choice == null || !mounted) return;
        await _quiet(
          _conversations.saveDraft(
            choice.chatId,
            text: td.FormattedText(text: text, entities: const []),
          ),
        );
        if (mounted) openChatFrom(context, choice.chatId);
      case td.TargetChatInternalLink():
        break;
    }
  }

  /// Does what a button of the bot's keyboard under [messageId] asks:
  /// sends its text, shares the phone number after a confirmation, makes
  /// a poll or picks a user to share.
  Future<void> _pressKeyboardButton(
    int messageId,
    td.KeyboardButton button,
  ) async {
    final l10n = AppLocalizations.of(context);
    final chatId = widget.chatId;
    switch (button.type) {
      case td.KeyboardButtonTypeText():
        await _send(button.text);
      case td.KeyboardButtonTypeRequestPhoneNumber():
        final store = _conversations.store;
        final bot =
            store.nameOf(
              MessageSenderId.user(store.botUserIdOf(chatId) ?? 0),
            ) ??
            store.nameOf(MessageSenderId.chat(chatId)) ??
            '';
        final confirmed = await showMgConfirm(
          context,
          title: l10n.sharePhoneTitle,
          message: l10n.sharePhoneMessage(bot),
          confirmLabel: l10n.share,
          cancelLabel: l10n.cancel,
        );
        // Null when dismissed; the option's value, false here, otherwise.
        if (confirmed == null || !mounted) return;
        try {
          final me = await _conversations.me();
          await _conversations.sendContact(
            chatId,
            td.Contact(
              phoneNumber: me.phoneNumber,
              firstName: me.firstName,
              lastName: me.lastName,
              vcard: '',
              userId: me.id,
            ),
          );
        } on td.TdException {
          if (mounted) setState(() => _failure = _Failure.send);
        }
      case td.KeyboardButtonTypeRequestPoll(
        :final forceQuiz,
        :final forceRegular,
      ):
        final poll = await composePoll(
          context,
          quiz: forceQuiz
              ? true
              : forceRegular
              ? false
              : null,
        );
        if (poll == null || !mounted || widget.chatId != chatId) return;
        try {
          await _conversations.sendPoll(chatId, poll);
        } on td.TdException {
          if (mounted) setState(() => _failure = _Failure.send);
        }
      case td.KeyboardButtonTypeRequestUsers(:final id):
        final user = await pickContact(context);
        if (user == null || !mounted || widget.chatId != chatId) return;
        try {
          await _conversations.shareUsersWithBot(chatId, messageId, id, [
            user.id,
          ]);
        } on td.TdException {
          if (mounted) showMgToast(context, l10n.botNoAnswer);
        }
      case td.KeyboardButtonTypeRequestChat(:final id):
        final target = await pickForwardTarget(context);
        if (target == null || !mounted || widget.chatId != chatId) return;
        try {
          await _conversations.shareChatWithBot(
            chatId,
            messageId,
            id,
            target.chatId,
          );
        } on td.TdException {
          if (mounted) showMgToast(context, l10n.botNoAnswer);
        }
      case td.KeyboardButtonTypeRequestLocation():
        await _sendLocation();
      default:
        break;
    }
  }

  /// The id of the message whose keyboard the user hid; 0 for none.
  var _keyboardHiddenFor = 0;

  /// The height of the bot keyboard and the composer together, which the
  /// timeline makes room for; 0 until they are laid out.
  var _bottomHeight = 0.0;

  /// The height of the bot keyboard strip, which the suggestions clear.
  var _keyboardHeight = 0.0;

  /// The space the timeline leaves under its newest message: the composer
  /// and the bot keyboard above it, with a little air.
  double get _bottomInset =>
      _bottomHeight > 0 ? _bottomHeight + 8 : TimelineView.composerInset;

  /// The bot keyboard the chat shows in place of its own, loaded when the
  /// message carrying it isn't at hand yet.
  (int, td.ReplyMarkupShowKeyboard)? _replyKeyboard(ConversationStore store) {
    final chatId = widget.chatId;
    final id = store.replyMarkupMessageId(chatId);
    if (id == 0) return null;
    final message = store.message(chatId, id);
    if (message == null) {
      scheduleMicrotask(
        () => unawaited(_quiet(_conversations.loadMessage(chatId, id))),
      );
      return null;
    }
    return switch (message.message.replyMarkup) {
      final td.ReplyMarkupShowKeyboard keyboard => (id, keyboard),
      _ => null,
    };
  }

  /// The identity the user posts as, before the attach button, where the
  /// chat offers a choice (see [ConversationStore.messageSenderOf]).
  Widget? _sendAsButton(ConversationStore store) {
    final sender = store.messageSenderOf(widget.chatId);
    if (sender == null) return null;
    return SendAsButton(
      chatId: widget.chatId,
      sender: sender,
      store: store,
      conversations: _conversations,
    );
  }

  /// The bot's menu button before the attach one: its commands, or the
  /// Web App it names.
  Widget? _botMenuButton(AppLocalizations l10n, ConversationStore store) {
    final chatId = widget.chatId;
    // A menu is only ever stored for a chat with a bot.
    final botUserId = store.privateUserIdOf(chatId);
    final menu = store.botMenu(chatId);
    if (botUserId == null || menu == null) return null;
    if (menu.isCommands) {
      if (store.botCommands(chatId).isEmpty) return null;
      return BotMenuPill(
        label: l10n.botMenu,
        onPressed: () {
          // A lone slash lists every command in the popup.
          _draft.setFormatted('/', const []);
          _focus.requestFocus();
        },
      );
    }
    return BotMenuPill(
      label: menu.text.isEmpty ? l10n.botMenu : menu.text,
      onPressed: () => unawaited(_openWebApp(botUserId, menu.url)),
    );
  }

  /// Opens a bot's Web App in the browser, signed for this user.
  Future<void> _openWebApp(int botUserId, String url) async {
    final theme = webAppTheme(MgColors.of(context));
    try {
      final signed = await _conversations.webAppUrl(
        botUserId,
        url,
        theme: theme,
      );
      await launchExternal(Uri.parse(signed));
    } on Object {
      if (mounted) {
        showMgToast(context, AppLocalizations.of(context).webAppUnavailable);
      }
    }
  }

  /// The buttons the composer gets besides its own: the bot keyboard
  /// toggle and the scheduled list.
  Widget? _composerExtras(AppLocalizations l10n, ConversationStore store) {
    final keyboard = _replyKeyboard(store);
    final buttons = [
      if (keyboard != null)
        MgIconButton(
          icon: MgIcons.list,
          tooltip: l10n.botKeyboard,
          iconSize: 18,
          selected: _keyboardHiddenFor != keyboard.$1,
          onPressed: () => setState(
            () => _keyboardHiddenFor = _keyboardHiddenFor == keyboard.$1
                ? 0
                : keyboard.$1,
          ),
        ),
      if (store.hasScheduledMessages(widget.chatId))
        MgIconButton(
          icon: MgIcons.recent,
          tooltip: l10n.scheduledList,
          iconSize: 18,
          onPressed: _openScheduled,
        ),
    ];
    return switch (buttons.length) {
      0 => null,
      1 => buttons.single,
      _ => Row(mainAxisSize: MainAxisSize.min, children: buttons),
    };
  }

  /// The bot keyboard above the composer, unless hidden or replaced by
  /// the emoji panel. A one-time keyboard goes away after a press.
  Widget? _replyKeyboardPanel(ConversationStore store) {
    final keyboard = _replyKeyboard(store);
    if (keyboard == null || keyboard.$1 == _keyboardHiddenFor || _panelOpen) {
      return null;
    }
    final (id, markup) = keyboard;
    return ReplyKeyboard(
      rows: markup.rows,
      onPressed: (button) {
        unawaited(_pressKeyboardButton(id, button));
        if (markup.oneTime) setState(() => _keyboardHiddenFor = id);
      },
    );
  }

  void _togglePanel() {
    setState(() => _panelOpen = !_panelOpen);
    _focus.requestFocus();
  }

  void _openSearch() => setState(() => _searching = true);

  void _closeSearch() {
    setState(() => _searching = false);
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

  /// Puts a custom emoji picked in the panel into the draft.
  void _insertCustomEmoji(td.Sticker sticker) {
    if (sticker.fullType case td.StickerFullTypeCustomEmoji(
      :final customEmojiId,
    )) {
      _draft.insertCustomEmoji(sticker.emoji, customEmojiId);
      _focus.requestFocus();
    }
  }

  /// Sends [sticker] at once and closes the panel, as the official apps do.
  Future<void> _sendSticker(td.Sticker sticker) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _panelOpen = false;
      _failure = null;
      _replyTo = null;
      _replyQuote = null;
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

  /// Sends a saved GIF picked in the panel, the way a sticker goes out.
  Future<void> _sendAnimation(td.Animation animation) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _panelOpen = false;
      _failure = null;
      _replyTo = null;
      _replyQuote = null;
    });
    _focus.requestFocus();
    unawaited(_toLatestForSend());
    try {
      await _conversations.sendAnimation(
        chatId,
        animation,
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

  /// Sends a voice message recorded in the composer (lib/src/voice).
  Future<void> _sendVoice(RecordedVoice voice) async {
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    setState(() {
      _failure = null;
      _replyTo = null;
      _replyQuote = null;
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
      _replyQuote = null;
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

  /// The chats the message menu offers under Forward: the latest ones,
  /// the open chat left out.
  List<ChatListEntry> _recentForwardTargets() => [
    for (final chat
        in ref.read(chatListProvider(const ChatListLocation.main())).value ??
            const <ChatListEntry>[])
      if (chat.id != widget.chatId) chat,
  ].take(6).toList();

  Future<void> _forward(
    List<ConversationMessage> messages, {
    int? toChat,
  }) async {
    final hasCaptions = messages.any(
      (message) =>
          message.content is! td.MessageText && message.text.isNotEmpty,
    );
    final choice = toChat != null
        ? ForwardChoice(chatId: toChat, hideSender: false, hideCaptions: false)
        : await pickForwardTarget(
            context,
            hasCaptions: hasCaptions,
            multiple: true,
          );
    if (choice == null || messages.isEmpty) return;
    var failed = false;
    // Each chat on its own, so one that refuses doesn't stop the rest.
    for (final chatId in choice.chatIds) {
      try {
        // The comment goes first, as in Telegram, so it reads above them.
        if (choice.comment.isNotEmpty) {
          await _conversations.sendText(chatId, choice.comment);
        }
        await _conversations.forwardMessages(
          chatId,
          messages.first.chatId,
          [for (final message in messages) message.id],
          hideSender: choice.hideSender,
          hideCaptions: choice.hideCaptions,
        );
      } catch (_) {
        // Such as a channel the user can't post in.
        failed = true;
      }
    }
    if (failed && mounted) setState(() => _failure = _Failure.forward);
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

  void _mentionsChanged() => setState(() {});

  /// The popup over the composer shows one kind of suggestion at a time:
  /// members for an @, then bot commands for a /, then emoji for a :word.
  ({
    List<ComposerSuggestion> suggestions,
    void Function(int index) pick,
    VoidCallback dismiss,
  })
  get _suggester {
    if (_mentions.suggestions.isNotEmpty) {
      return (
        suggestions: _mentions.suggestions,
        pick: _mentions.pick,
        dismiss: _mentions.dismiss,
      );
    }
    if (_commands.suggestions.isNotEmpty) {
      return (
        suggestions: _commands.suggestions,
        pick: _commands.pick,
        dismiss: _commands.dismiss,
      );
    }
    return (
      suggestions: _emojiHints.suggestions,
      pick: _emojiHints.pick,
      dismiss: _emojiHints.dismiss,
    );
  }

  /// Hands the chat's bot commands to the / popup once they are known.
  void _syncCommands(ConversationStore store) {
    final commands = store.botCommands(widget.chatId);
    if (identical(commands, _commands.commands)) return;
    _commands.commands = commands;
    scheduleMicrotask(() {
      if (mounted) _commands.refresh();
    });
  }

  /// Stickers for an emoji, as this chat may see them.
  Future<List<td.Sticker>> Function(String emoji) _stickerSearch() {
    final chatId = widget.chatId;
    final stickers = ref.read(telegramSessionProvider).requireValue.stickers;
    return (emoji) => stickers.stickersFor(emoji, chatId: chatId);
  }

  /// The languages emoji keywords are matched in: the app's, then
  /// English, which Telegram always knows.
  List<String> _inputLanguages() {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'en' ? const ['en'] : [code, 'en'];
  }

  /// Sends a sticker picked from the strip and empties the draft that
  /// asked for it.
  Future<void> _sendSuggestedSticker(td.Sticker sticker) async {
    _draft.clear();
    await _sendSticker(sticker);
  }

  /// An inline bot's results for this chat.
  Future<td.InlineQueryResults> Function(int, String, String) _inlineSearch() {
    final chatId = widget.chatId;
    return (botUserId, query, offset) =>
        _conversations.inlineResults(chatId, botUserId, query, offset: offset);
  }

  /// Sends an inline result picked from the panel, via its bot, and
  /// empties the draft that asked for it.
  Future<void> _sendInlineResult(td.InlineQueryResult result) async {
    final chatId = widget.chatId;
    final queryId = _inline.queryId;
    final replyTo = _replyTo;
    _draft.clear();
    setState(() {
      _failure = null;
      _replyTo = null;
      _replyQuote = null;
    });
    _focus.requestFocus();
    unawaited(_toLatestForSend());
    try {
      await _conversations.sendInlineResult(
        chatId,
        queryId: queryId,
        resultId: inlineResultId(result),
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

  /// Members to offer for an @ in this chat, while it is a group.
  Future<List<MentionCandidate>> Function(String) _mentionSearch() {
    final chatId = widget.chatId;
    return mentionSearchFor(
      ref.read(telegramSessionProvider).requireValue.mentions,
      () => ref.read(chatEntryProvider(chatId)).value?.isGroup ?? false,
      chatId,
    );
  }

  /// The menu under a right click on Send: without sound, or at a chosen
  /// time, as in Telegram for macOS. Not while editing, which only saves.
  Future<void> _sendMenu(String text, Offset position) async {
    if (_editing != null || text.trim().isEmpty) return;
    final l10n = AppLocalizations.of(context);
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.sendWithoutSound,
          icon: MgIcons.muted,
          onSelected: () => unawaited(_send(text, silent: true)),
        ),
        MgMenuItem(
          label: l10n.scheduleMessage,
          icon: MgIcons.recent,
          onSelected: () => unawaited(_schedule(text)),
        ),
        if (_canSendWhenOnline)
          MgMenuItem(
            label: l10n.sendWhenOnline,
            icon: MgIcons.profile,
            onSelected: () => unawaited(_sendWhenOnline(text)),
          ),
      ],
    );
  }

  /// Only a person comes online, so "Send when online" is for private
  /// chats with one, not with a bot, and not for groups or channels.
  bool get _canSendWhenOnline {
    final store = _conversations.store;
    return store.privateUserIdOf(widget.chatId) != null &&
        store.botUserIdOf(widget.chatId) == null;
  }

  Future<void> _sendWhenOnline(String text) async {
    final chatId = widget.chatId;
    final l10n = AppLocalizations.of(context);
    await _send(
      text,
      schedule: const td.MessageSchedulingStateSendWhenOnline(),
    );
    if (!mounted || widget.chatId != chatId || _failure != null) return;
    showMgToast(context, l10n.scheduledWhenOnline);
  }

  Future<void> _schedule(String text) async {
    final chatId = widget.chatId;
    final when = await pickScheduleTime(context);
    if (when == null || !mounted || widget.chatId != chatId) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final seconds = when.millisecondsSinceEpoch ~/ 1000;
    await _send(
      text,
      schedule: td.MessageSchedulingStateSendAtDate(
        sendDate: seconds,
        repeatPeriod: 0,
      ),
    );
    if (!mounted || widget.chatId != chatId || _failure != null) return;
    showMgToast(context, l10n.scheduledFor(formatFullDate(seconds, locale)));
  }

  Future<void> _send(
    String text, {
    bool silent = false,
    td.MessageSchedulingState? schedule,
  }) async {
    // A click on the send button must not take the cursor with it.
    _focus.requestFocus();
    final editing = _editing;
    // A caption may be removed; a text message can't be emptied.
    if (editing != null && (text.trim().isNotEmpty || _isCaption(editing))) {
      return _saveEdit(editing, text);
    }
    if (text.trim().isEmpty) return;
    final chatId = widget.chatId;
    final replyTo = _replyTo;
    final quote = _replyQuote;
    final ranges = _draft.ranges;
    final formatted = formattedDraft(text, ranges);
    if (formatted.text.isEmpty) return;
    final previewOptions = _previewOptions;
    _draft.clear();
    setState(() {
      _failure = null;
      _replyTo = null;
      _replyQuote = null;
    });
    _resetPreview();
    unawaited(_toLatestForSend());
    try {
      await _conversations.sendText(
        chatId,
        formatted.text,
        replyTo: replyTo?.id,
        entities: formatted.entities,
        quote: quote?.text,
        quotePosition: quote?.position ?? 0,
        linkPreviewOptions: previewOptions,
        silent: silent,
        schedule: schedule,
      );
    } catch (error) {
      // TDLib names the wait under slowmode: SLOWMODE_WAIT_27.
      if (error case td.TdException(:final message)
          when message.startsWith('SLOWMODE_WAIT_')) {
        final seconds = int.tryParse(message.substring(14));
        if (seconds != null) _conversations.noteSlowModeWait(chatId, seconds);
      }
      // Give the text back rather than lose it, unless the user has
      // started typing something else or moved to another chat.
      if (!mounted || widget.chatId != chatId) return;
      if (_draft.text.isEmpty) _draft.setFormatted(text, ranges);
      setState(() {
        _failure = _Failure.send;
        if (_replyTo == null) {
          _replyTo = replyTo;
          _replyQuote = quote;
        }
      });
    }
  }

  static bool _isCaption(ConversationMessage message) =>
      message.content is! td.MessageText;

  Future<void> _saveEdit(ConversationMessage message, String text) async {
    final ranges = _draft.ranges;
    final formatted = formattedDraft(text, ranges);
    final old = captionOf(message.content);
    if (old != null && sameDraft(formatted, old)) return _stopEditing();
    if (formatted.text.isEmpty && !_isCaption(message)) return;
    _stopEditing();
    try {
      await _conversations.editText(
        message.chatId,
        message.id,
        formatted.text,
        entities: formatted.entities,
      );
    } catch (_) {
      if (!mounted || widget.chatId != message.chatId) return;
      // Another edit has started meanwhile; keep it and only say so.
      if (_editing != null) {
        setState(() => _failure = _Failure.edit);
        return;
      }
      // Put the edit back so the change is not lost.
      _edit(message);
      _draft.setFormatted(text, ranges);
      setState(() => _failure = _Failure.edit);
    }
  }

  /// The attach button's menu: files, a poll where the chat allows one
  /// (groups and channels), a place and a contact.
  Future<void> _attachMenu(Offset position) async {
    final l10n = AppLocalizations.of(context);
    final store = _conversations.store;
    final chat = ref.read(chatEntryProvider(widget.chatId)).value;
    final canPoll =
        chat != null && (chat.isGroup || store.isChannel(widget.chatId));
    await showMgMenu(
      context,
      position: position,
      items: [
        MgMenuItem(
          label: l10n.attachFile,
          icon: MgIcons.file,
          onSelected: () => unawaited(_chooseFiles()),
        ),
        if (canPoll)
          MgMenuItem(
            label: l10n.attachPoll,
            icon: MgIcons.poll,
            onSelected: () => unawaited(_createPoll()),
          ),
        MgMenuItem(
          label: l10n.attachLocation,
          icon: MgIcons.location,
          onSelected: () => unawaited(_sendLocation()),
        ),
        MgMenuItem(
          label: l10n.attachContact,
          icon: MgIcons.profile,
          onSelected: () => unawaited(_sendContact()),
        ),
      ],
    );
  }

  Future<void> _sendLocation() async {
    final chatId = widget.chatId;
    final choice = await pickLocation(context, chatId: chatId);
    if (choice == null || !mounted || widget.chatId != chatId) return;
    final replyTo = _replyTo;
    setState(() {
      _replyTo = null;
      _replyQuote = null;
      _failure = null;
    });
    try {
      switch (choice) {
        case PointChoice(:final location):
          await _conversations.sendLocation(
            chatId,
            location,
            replyTo: replyTo?.id,
          );
        case VenueChoice(:final venue):
          await _conversations.sendVenue(chatId, venue, replyTo: replyTo?.id);
      }
    } on td.TdException {
      if (mounted) setState(() => _failure = _Failure.send);
    }
  }

  Future<void> _sendContact() async {
    final chatId = widget.chatId;
    final user = await pickContact(context);
    if (user == null || !mounted || widget.chatId != chatId) return;
    final replyTo = _replyTo;
    setState(() {
      _replyTo = null;
      _replyQuote = null;
      _failure = null;
    });
    try {
      await _conversations.sendContact(
        chatId,
        td.Contact(
          phoneNumber: user.phoneNumber,
          firstName: user.firstName,
          lastName: user.lastName,
          vcard: '',
          userId: user.id,
        ),
        replyTo: replyTo?.id,
      );
    } on td.TdException {
      if (mounted) setState(() => _failure = _Failure.send);
    }
  }

  Future<void> _createPoll() async {
    final chatId = widget.chatId;
    final poll = await composePoll(
      context,
      inChannel: _conversations.store.isChannel(chatId),
    );
    if (poll == null || !mounted || widget.chatId != chatId) return;
    final replyTo = _replyTo;
    setState(() {
      _replyTo = null;
      _replyQuote = null;
      _failure = null;
    });
    try {
      await _conversations.sendPoll(chatId, poll, replyTo: replyTo?.id);
    } on td.TdException {
      if (mounted) setState(() => _failure = _Failure.send);
    }
  }

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
    if (_thread case final thread?) return _offerFilesToThread(thread, paths);
    final chatId = widget.chatId;
    // The draft becomes the caption, as in the official apps; not while
    // editing, where the composer holds another message's text.
    final useDraft = _editing == null;
    final draft = useDraft ? _draft.text : '';
    final draftFormats = useDraft ? _draft.ranges : const <FormatRange>[];
    final choice = await showAttachmentPreview(
      context,
      paths: paths,
      caption: draft,
      // Only a person can get self-destructing media, not a bot, and
      // only a person comes online.
      allowSelfDestruct: _canSendWhenOnline,
      allowSendWhenOnline: _canSendWhenOnline,
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
      _replyQuote = null;
    });
    if (useDraft) _draft.clear();
    // The draft's formatting goes with it, unless the caption was
    // rewritten in the preview; Markdown applies either way.
    final captionRanges = choice.caption == draft
        ? draftFormats
        : const <FormatRange>[];
    final caption = formattedDraft(choice.caption, captionRanges);
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
        caption: caption.text,
        captionEntities: caption.entities,
        replyTo: replyTo?.id,
        silent: choice.silent,
        schedule: choice.schedule,
      );
      _toastScheduled(choice.schedule, chatId);
    } catch (_) {
      if (!mounted || widget.chatId != chatId) return;
      // Give the caption and the reply back, as a failed text send does.
      if (useDraft && _draft.text.isEmpty) {
        _draft.setFormatted(choice.caption, captionRanges);
      }
      setState(() {
        _failure = _Failure.attach;
        _replyTo ??= replyTo;
      });
    }
  }

  /// Files dropped, pasted or chosen while the comments are open go into
  /// the thread, the comment draft as their caption.
  Future<void> _offerFilesToThread(
    MessageThread thread,
    List<String> paths,
  ) async {
    final useDraft = _threadEditing == null;
    final draft = useDraft ? _threadDraft.text : '';
    final draftFormats = useDraft ? _threadDraft.ranges : const <FormatRange>[];
    final choice = await showAttachmentPreview(
      context,
      paths: paths,
      caption: draft,
    );
    if (choice == null || !mounted || _thread != thread) return;
    final replyTo = _threadReplyTo;
    setState(() {
      _failure = null;
      _threadReplyTo = null;
      _threadQuote = null;
    });
    if (useDraft) _threadDraft.clear();
    final captionRanges = choice.caption == draft
        ? draftFormats
        : const <FormatRange>[];
    final caption = formattedDraft(choice.caption, captionRanges);
    try {
      final files = <OutgoingFile>[];
      for (final file in choice.files) {
        files.add(await _measure(file));
      }
      await thread.sendFiles(
        files,
        caption: caption.text,
        captionEntities: caption.entities,
        replyTo: replyTo?.id,
        silent: choice.silent,
        schedule: choice.schedule,
      );
      _toastScheduled(choice.schedule, widget.chatId);
    } catch (_) {
      if (!mounted || _thread != thread) return;
      if (useDraft && _threadDraft.text.isEmpty) {
        _threadDraft.setFormatted(choice.caption, captionRanges);
      }
      setState(() {
        _failure = _Failure.attach;
        _threadReplyTo ??= replyTo;
      });
    }
  }

  /// Says when scheduled media goes out, since it leaves the timeline.
  void _toastScheduled(td.MessageSchedulingState? schedule, int chatId) {
    if (schedule is! td.MessageSchedulingStateSendAtDate) return;
    if (!mounted || widget.chatId != chatId) return;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    showMgToast(
      context,
      l10n.scheduledFor(formatFullDate(schedule.sendDate, locale)),
    );
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
        return file.copyWith(width: size.$1, height: size.$2);
      case OutgoingKind.video || OutgoingKind.animation || OutgoingKind.audio:
        // An edited video arrives measured by the editor.
        if (file.duration > 0) return file;
        final info = await probeMedia(file.path);
        if (info == null) return file;
        return file.copyWith(
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
        icon: MgIcons.edit,
        title: l10n.editingMessage,
        text: describeContent(l10n, editing.content),
        closeTooltip: l10n.close,
        onClose: _stopEditing,
      );
    }
    final reply = _replyTo;
    final preview = _previewRemoved ? null : _preview;
    final bars = <Widget>[
      if (reply != null)
        ComposerContextBar(
          title: nameOfSender(l10n, _conversations.store, reply.sender),
          text: _replyQuote?.text ?? describeContent(l10n, reply.content),
          closeTooltip: l10n.close,
          onClose: () => setState(() {
            _replyTo = null;
            _replyQuote = null;
          }),
        ),
      if (preview != null)
        ComposerLinkPreview(
          preview: preview,
          aboveText: _previewAbove,
          onToggleAbove: () => setState(() => _previewAbove = !_previewAbove),
          onRemove: () => setState(() => _previewRemoved = true),
        ),
    ];
    return switch (bars.length) {
      0 => null,
      1 => bars.single,
      _ => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: bars,
      ),
    };
  }

  /// The calendar under a date pill: picking a day goes to its last
  /// message, as in the official app.
  Future<void> _openCalendar(DateTime day, Offset position) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekdayFormat = DateFormat.E(locale);
    final store = _conversations.store;
    final chatId = widget.chatId;
    // The oldest loaded message bounds the calendar once the start of the
    // chat is in.
    final oldest =
        store.reachedStart(chatId) && store.messagesFor(chatId).isNotEmpty
        ? dayOf(store.messagesFor(chatId).last)
        : null;
    DateTime? picked;
    await showMgPopover(
      context,
      position: position,
      child: MgCalendar(
        month: day,
        today: DateTime.now(),
        first: oldest,
        monthTitle: (month) => DateFormat.yMMMM(locale).format(month),
        weekdays: [
          for (var i = 0; i < 7; i++)
            // 2024-01-01 is a Monday.
            weekdayFormat.format(DateTime(2024, 1, 1 + i)).characters.first,
        ],
        previousTooltip: l10n.previousMonth,
        nextTooltip: l10n.nextMonth,
        onPick: (day) {
          picked = day;
          Navigator.of(context).pop();
        },
      ),
    );
    final target = picked;
    if (target == null || !mounted || widget.chatId != chatId) return;
    final ConversationMessage? message;
    try {
      message = await _conversations.messageByDate(chatId, target);
    } on Object {
      return;
    }
    if (message == null || !mounted || widget.chatId != chatId) return;
    await _jumpTo(message.id);
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
    // A bot not yet spoken to starts with its button, not the composer.
    if (store.botUserIdOf(chatId) case final botUserId?
        when store.lastMessageId(chatId) == 0 &&
            store.messagesFor(chatId).isEmpty) {
      return ComposerActionBar(
        label: l10n.startBot,
        loading: _actionPending,
        onPressed: () => unawaited(
          _chatAction(() => _conversations.sendBotStart(chatId, botUserId)),
        ),
      );
    }
    if (store.canPost(chatId)) {
      if (store.canSendText(chatId)) return null;
      // A member the group or an admin keeps from writing sees why.
      final until = store.restrictedUntil(chatId);
      return ComposerActionBar(
        label: until == null
            ? l10n.textNotAllowed
            : l10n.restrictedUntil(
                formatFullDate(
                  until,
                  Localizations.localeOf(context).toLanguageTag(),
                ),
              ),
        onPressed: null,
      );
    }
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
    final wasOnScreen = _onScreen;
    _onScreen = TickerMode.valuesOf(context).enabled;
    if (_onScreen && !wasOnScreen) _focusComposer();
    // A jump or a page of history moves the view without a scroll event.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followScroll();
    });
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(telegramSessionProvider).requireValue;
    final chat = ref.watch(chatEntryProvider(widget.chatId)).value;
    // Null for any other chat; a secret chat's title is the other person.
    final secret = ref.watch(secretChatProvider(widget.chatId)).value;
    ref.listen(messageJumpProvider.select((jumps) => jumps[widget.chatId]), (
      _,
      jump,
    ) {
      if (jump != null) _takeJump();
    });
    final messages = ref.watch(conversationProvider(widget.chatId));
    final store = session.conversations.store;
    _syncCommands(store);
    if (_scheduledOpen &&
        store.scheduledVersion(widget.chatId) != _scheduledSeen) {
      _scheduledSeen = store.scheduledVersion(widget.chatId);
      scheduleMicrotask(() {
        if (mounted) unawaited(_loadScheduled());
      });
    }

    final keyboardPanel = _selected == null && !_listOpen
        ? _replyKeyboardPanel(store)
        : null;
    final translateBar = _translateBar(l10n, messages.value);
    final view = DropTarget(
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
              AsyncData() when _forum && _thread == null => _topicsView(store),
              AsyncData() when _savedOpen && _thread == null =>
                _savedTopicsView(store),
              AsyncData(value: final list)
                  when list.isEmpty && store.reachedStart(widget.chatId) =>
                // Over a picture the pill keeps the note legible; on the
                // plain card or a soft gradient it would read as an alert.
                ref.watch(
                      preferencesProvider.select(
                        (p) =>
                            p.wallpaperKind == WallpaperKind.image &&
                            p.wallpaperImage != null,
                      ),
                    )
                    ? Center(child: DatePill(l10n.noMessages))
                    : MgEmptyState(l10n.noMessages),
              AsyncData() when _thread != null => TimelineView(
                key: const ValueKey('commentsThread'),
                messages: _thread!.messages,
                store: store,
                chatId: _thread!.chatId,
                isGroup: true,
                controller: _threadScroll,
                topInset: _topInset,
                onShown: (message) =>
                    unawaited(_quiet(_thread!.view([message.id]))),
                onNearTop: () => unawaited(_quiet(_thread!.loadOlder())),
                onNearBottom: () {},
                selection: _selected,
                actions: _threadActions,
              ),
              AsyncData() when _scheduledOpen => TimelineView(
                key: const ValueKey('scheduledList'),
                messages: _scheduled,
                store: store,
                chatId: widget.chatId,
                isGroup: chat?.isGroup ?? false,
                controller: _scheduledScroll,
                topInset: _topInset,
                onShown: (_) {},
                onNearTop: () {},
                onNearBottom: () {},
                actions: _scheduledActions,
              ),
              AsyncData() when _pinnedListOpen => TimelineView(
                key: const ValueKey('pinnedList'),
                messages: _pinnedMessages(store),
                store: store,
                chatId: widget.chatId,
                isGroup: chat?.isGroup ?? false,
                controller: _pinnedScroll,
                topInset: _topInset,
                onShown: _shown,
                onNearTop: () {},
                onNearBottom: () {},
                actions: _actions,
              ),
              AsyncData(value: final list) => () {
                _placeUnread(list);
                return TimelineView(
                  key: _timelineKey,
                  messages: _withDeleted(list, store),
                  store: store,
                  chatId: widget.chatId,
                  isGroup: chat?.isGroup ?? false,
                  controller: _scroll,
                  anchor: _anchor,
                  unreadFrom: _unreadFrom,
                  flashId: _flashId,
                  flash: _flash,
                  topInset: _topInset,
                  bottomInset: _bottomInset,
                  selection: _selected,
                  onDateTap: (day, position) =>
                      unawaited(_openCalendar(day, position)),
                  onShown: _shown,
                  onNearTop: _loadOlder,
                  onNearBottom: _loadNewer,
                  actions: _actions,
                );
              }(),
              _ => const SizedBox.shrink(),
            },
          ),
          if (translateBar != null)
            Positioned(
              top: ChatHeaderBar.height,
              left: 0,
              right: 0,
              child: translateBar,
            ),
          if (_tagBar(l10n) case final bar?)
            Positioned(
              top: ChatHeaderBar.height + _translateInset,
              left: 0,
              right: 0,
              child: bar,
            ),
          if (!_listOpen)
            if (_pinnedBar(l10n, store) case final bar?)
              Positioned(
                top:
                    ChatHeaderBar.height +
                    _translateInset +
                    (_tagsShown ? SavedTagBar.height : 0),
                left: 0,
                right: 0,
                child: bar,
              ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ChatHeaderBar(
              title: _searching
                  ? SizedBox(
                      width: double.infinity,
                      child: ChatSearchBar(
                        key: ValueKey(widget.chatId),
                        find: (query, senderUserId, kind) =>
                            session.chatSearch.find(
                              widget.chatId,
                              query,
                              senderUserId: senderUserId,
                              kind: kind,
                            ),
                        onResult: (id) => unawaited(_jumpTo(id)),
                        onClose: _closeSearch,
                        onCalendar: (position) =>
                            unawaited(_openCalendar(DateTime.now(), position)),
                        onPickSender: chat?.isGroup ?? false
                            ? (position) => pickSearchSender(
                                context,
                                position: position,
                                search: (query) => session.mentions.search(
                                  widget.chatId,
                                  query,
                                ),
                              )
                            : null,
                      ),
                    )
                  : _thread != null
                  ? ChatTitleCapsule(
                      title:
                          _threadTopicName(l10n) ??
                          (_thread!.chatId == widget.chatId
                              ? _thread!.replyCount == 0
                                    ? l10n.replies
                                    : l10n.replyCount(_thread!.replyCount)
                              : _thread!.replyCount == 0
                              ? l10n.comments
                              : l10n.commentCount(_thread!.replyCount)),
                      avatar: MgIconButton(
                        icon: MgIcons.back,
                        tooltip: _thread!.isSavedTag
                            ? l10n.savedAllMessages
                            : _thread!.isStandalone
                            ? l10n.backToTopics
                            : l10n.backToChat,
                        onPressed: _closeThread,
                      ),
                      onTap: _closeThread,
                    )
                  : _scheduledOpen
                  ? ChatTitleCapsule(
                      title: l10n.scheduledCount(_scheduled.length),
                      avatar: MgIconButton(
                        icon: MgIcons.back,
                        tooltip: l10n.backToChat,
                        onPressed: _closeScheduled,
                      ),
                      onTap: _closeScheduled,
                    )
                  : _pinnedListOpen
                  ? ChatTitleCapsule(
                      title: l10n.pinnedCount(
                        store.pinnedIds(widget.chatId).length,
                      ),
                      avatar: MgIconButton(
                        icon: MgIcons.back,
                        tooltip: l10n.backToChat,
                        onPressed: _closePinnedList,
                      ),
                      onTap: _closePinnedList,
                    )
                  : ChatHeaderTitle(
                      chatId: widget.chatId,
                      titleIcon: secret == null ? null : const SecretChatLock(),
                      avatar: _saved
                          ? MgIconButton(
                              icon: MgIcons.list,
                              tooltip: _savedOpen
                                  ? l10n.savedShowAsMessages
                                  : l10n.savedShowAsChats,
                              onPressed: _toggleSaved,
                            )
                          : PeerAvatar.chat(
                              name: chat?.title ?? '',
                              size: 32,
                              photo: chat?.photo,
                            ),
                      subtitle: secret == null
                          ? ''
                          : secretChatStatusText(
                                  secret,
                                  chat?.title ?? '',
                                  l10n,
                                ) ??
                                '',
                      onTap: () => togglePeerInfo(ref, widget.chatId),
                    ),
              actions: LayoutBuilder(
                // A narrow pane leaves the room to the player; search stays
                // on ⌘F and info on a click on the title.
                builder: (context, header) => ChatActionsCapsule(
                  children: [
                    AudioPlayerCapsule(chatId: widget.chatId),
                    if (header.maxWidth >= 640 &&
                        !_searching &&
                        _thread == null &&
                        !_scheduledOpen &&
                        !_pinnedListOpen &&
                        !_savedOpen &&
                        !_forum) ...[
                      MgIconButton(
                        icon: MgIcons.search,
                        tooltip: l10n.searchInChat,
                        size: 28,
                        onPressed: _openSearch,
                      ),
                      MgIconButton(
                        icon: MgIcons.panel,
                        tooltip: l10n.peerInfo,
                        size: 28,
                        onPressed: () => togglePeerInfo(ref, widget.chatId),
                      ),
                    ],
                  ],
                ),
              ),
              fill: const WindowDragArea(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_panelOpen && !_listOpen) _jumpButtons(l10n, store),
                      if (store.slowModeUntil(widget.chatId) case final until?)
                        SlowModeNotice(
                          key: ValueKey(until),
                          until: until,
                          label: l10n.slowModeWait,
                        ),
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
                      if (_selected == null &&
                          !_listOpen &&
                          !_panelOpen &&
                          _editing == null &&
                          _stickerHints.stickers.isNotEmpty)
                        StickerSuggestionStrip(
                          stickers: _stickerHints.stickers,
                          onPick: (sticker) =>
                              unawaited(_sendSuggestedSticker(sticker)),
                        ),
                      if (_selected == null &&
                          !_listOpen &&
                          !_panelOpen &&
                          _editing == null &&
                          _inline.active)
                        InlineResultsPanel(
                          results: _inline.results,
                          loading: _inline.loading,
                          onPick: (result) =>
                              unawaited(_sendInlineResult(result)),
                          onMore: _inline.hasMore
                              ? () => unawaited(_inline.loadMore())
                              : null,
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
                                height:
                                    (MediaQuery.sizeOf(context).height - 220)
                                        .clamp(220, 400),
                                onEmoji: _insertEmoji,
                                onCustomEmoji: _insertCustomEmoji,
                                onSticker: (sticker) =>
                                    unawaited(_sendSticker(sticker)),
                                onGif: (gif) => unawaited(_sendAnimation(gif)),
                                onClose: _closePanel,
                              ),
                            ),
                          ),
                        ),
                      ?_sponsoredCard(store),
                    ],
                  ),
                ),
                // The bot keyboard and the composer: measured together, so
                // the timeline leaves room for whatever they grow to.
                Measured(
                  onSize: (size) {
                    if (mounted && size.height != _bottomHeight) {
                      setState(() => _bottomHeight = size.height);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A bot's keyboard is a solid strip above the composer, so
                      // messages never scroll through the gaps between buttons.
                      if (keyboardPanel != null)
                        Measured(
                          onSize: (size) {
                            if (mounted && size.height != _keyboardHeight) {
                              setState(() => _keyboardHeight = size.height);
                            }
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.solid(c.card),
                              border: Border(
                                top: BorderSide(color: c.separator, width: 0.5),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                              child: keyboardPanel,
                            ),
                          ),
                        ),
                      // The composer is the card's own bottom edge; the other
                      // bars still float over the messages.
                      if (_thread case final thread? when _selected == null)
                        _threadComposer(l10n, thread)
                      else if (_thread != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: _selectionBar(l10n),
                        )
                      else if (_forum || _savedOpen)
                        const SizedBox.shrink()
                      else if (switch (null) {
                            _ when _scheduledOpen => _scheduledBar(l10n),
                            _ when _pinnedListOpen => _unpinAllBar(l10n, store),
                            _ when _selected != null => _selectionBar(l10n),
                            _ when secret?.status == SecretChatStatus.closed =>
                              SecretChatClosedBar(chatId: widget.chatId),
                            _ => _actionBar(l10n, store),
                          }
                          case final bar?)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: bar,
                        )
                      else
                        TapRegion(
                          groupId: _EmojiPanelRegion,
                          child: VoiceRecordComposer(
                            onRecorded: _sendVoice,
                            onRecordedVideo: _sendVideoNote,
                            builder: (context, recordButton, recordingBar) =>
                                Composer(
                                  suggestionsLift: keyboardPanel == null
                                      ? 0
                                      : _keyboardHeight,
                                  suggestions: _suggester.suggestions,
                                  onSuggestion: _suggester.pick,
                                  onDismissSuggestions: _suggester.dismiss,
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
                                  onAttachMenu: (position) =>
                                      unawaited(_attachMenu(position)),
                                  onEmoji: _togglePanel,
                                  leading:
                                      _botMenuButton(l10n, store) ??
                                      _sendAsButton(store),
                                  extraButton: _composerExtras(l10n, store),
                                  onPaste: _paste,
                                  allowEmpty:
                                      _editing != null && _isCaption(_editing!),
                                  labels: ComposerLabels(
                                    hint: l10n.messageHint,
                                    attach: l10n.attach,
                                    emoji: l10n.emoji,
                                    record: l10n.record,
                                    send: l10n.send,
                                    format: formatLabelsOf(l10n),
                                  ),
                                  onSend: (text) => unawaited(_send(text)),
                                  onSendMenu: (text, position) =>
                                      unawaited(_sendMenu(text, position)),
                                  recordButton: recordButton,
                                  replacement: recordingBar,
                                ),
                          ),
                        ),
                    ],
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
    return CallbackShortcuts(
      bindings: {primaryShortcut(LogicalKeyboardKey.keyF): _openSearch},
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _claimFocus(),
        child: Focus(
          focusNode: _area,
          onKeyEvent: _typeToComposer,
          child: ChatTranslationScope(translation: _translation, child: view),
        ),
      ),
    );
  }
}

enum _Failure { send, edit, attach, forward, chatAction }

/// Clicks in the panel and the composer keep the emoji panel open.
abstract final class _EmojiPanelRegion {}
