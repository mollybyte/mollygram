import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The privacy extras: what the app keeps from other people. Each one is
/// off by default; ghost mode is all of them at once.
final class PrivacySettings {
  const PrivacySettings({
    this.hideReadReceipts = false,
    this.hideTyping = false,
    this.stayOffline = false,
    this.hideContentOpened = false,
    this.silentReadChats = const {},
    this.beforeGhost,
  });

  /// All switches on.
  const PrivacySettings.ghost()
    : this(
        hideReadReceipts: true,
        hideTyping: true,
        stayOffline: true,
        hideContentOpened: true,
      );

  /// Messages read here are not reported as read.
  final bool hideReadReceipts;

  /// "typing…", "recording a voice message…" and the like are not sent.
  final bool hideTyping;

  /// The account does not go online from this app.
  final bool stayOffline;

  /// Playing a voice or video message does not report it as listened to.
  final bool hideContentOpened;

  /// Chats read without marking them as read, whatever [hideReadReceipts]
  /// says.
  final Set<int> silentReadChats;

  /// The switches as they were before ghost mode turned them all on, as a
  /// mask of [_switchBits]; ghost mode off puts them back.
  final int? beforeGhost;

  static const _readBit = 1, _typingBit = 2, _offlineBit = 4, _openedBit = 8;

  int get _switchBits =>
      (hideReadReceipts ? _readBit : 0) |
      (hideTyping ? _typingBit : 0) |
      (stayOffline ? _offlineBit : 0) |
      (hideContentOpened ? _openedBit : 0);

  bool get isGhost =>
      hideReadReceipts && hideTyping && stayOffline && hideContentOpened;

  /// Whether any switch is on.
  bool get anyOn => _switchBits != 0;

  /// Ghost mode on turns every switch on and remembers the ones that were
  /// on; off brings that mix back, or turns every switch off.
  PrivacySettings withGhost(bool on) {
    if (on) {
      if (isGhost) return this;
      return _withBits(15, beforeGhost: _switchBits);
    }
    final restore = beforeGhost ?? 0;
    return _withBits(restore == 15 ? 0 : restore);
  }

  PrivacySettings _withBits(int bits, {int? beforeGhost}) => PrivacySettings(
    hideReadReceipts: bits & _readBit != 0,
    hideTyping: bits & _typingBit != 0,
    stayOffline: bits & _offlineBit != 0,
    hideContentOpened: bits & _openedBit != 0,
    silentReadChats: silentReadChats,
    beforeGhost: beforeGhost,
  );

  PrivacySettings copyWith({
    bool? hideReadReceipts,
    bool? hideTyping,
    bool? stayOffline,
    bool? hideContentOpened,
    Set<int>? silentReadChats,
  }) => PrivacySettings(
    hideReadReceipts: hideReadReceipts ?? this.hideReadReceipts,
    hideTyping: hideTyping ?? this.hideTyping,
    stayOffline: stayOffline ?? this.stayOffline,
    hideContentOpened: hideContentOpened ?? this.hideContentOpened,
    silentReadChats: silentReadChats ?? this.silentReadChats,
    beforeGhost: beforeGhost,
  );

  /// The same settings with [chatId] read silently or not.
  PrivacySettings withSilentRead(int chatId, bool silent) => copyWith(
    silentReadChats: silent
        ? {...silentReadChats, chatId}
        : ({...silentReadChats}..remove(chatId)),
  );

  Map<String, Object?> toJson() => {
    'hide_read_receipts': hideReadReceipts,
    'hide_typing': hideTyping,
    'stay_offline': stayOffline,
    'hide_content_opened': hideContentOpened,
    'silent_read_chats': [...silentReadChats],
    'before_ghost': ?beforeGhost,
  };

  /// Reads what [toJson] wrote; anything unexpected reads as off.
  factory PrivacySettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const PrivacySettings();
    bool flag(String key) => json[key] == true;
    final chats = json['silent_read_chats'];
    final before = json['before_ghost'];
    return PrivacySettings(
      hideReadReceipts: flag('hide_read_receipts'),
      hideTyping: flag('hide_typing'),
      stayOffline: flag('stay_offline'),
      hideContentOpened: flag('hide_content_opened'),
      silentReadChats: {
        if (chats is List)
          for (final id in chats)
            if (id is int) id,
      },
      beforeGhost: before is int && before >= 0 && before <= 15 ? before : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrivacySettings &&
      other.hideReadReceipts == hideReadReceipts &&
      other.hideTyping == hideTyping &&
      other.stayOffline == stayOffline &&
      other.hideContentOpened == hideContentOpened &&
      other.beforeGhost == beforeGhost &&
      other.silentReadChats.length == silentReadChats.length &&
      other.silentReadChats.containsAll(silentReadChats);

  @override
  int get hashCode => Object.hash(
    hideReadReceipts,
    hideTyping,
    stayOffline,
    hideContentOpened,
    beforeGhost,
    Object.hashAllUnordered(silentReadChats),
  );
}

/// The one place where the privacy extras act: a filter in front of the
/// TDLib client (see [td.TdClient.filter]) that answers the requests which
/// would tell others what the user does, instead of sending them.
///
/// | Switch | Kept from TDLib |
/// |---|---|
/// | [PrivacySettings.hideReadReceipts] | `viewMessages`, `readAll*`, `readChatList` |
/// | [PrivacySettings.hideTyping] | `sendChatAction` |
/// | [PrivacySettings.stayOffline] | `setOption online=true` |
/// | [PrivacySettings.hideContentOpened] | `openMessageContent` |
///
/// Everything else passes untouched, and so does what the user asks for
/// on purpose through [deliberately], such as "Mark as read" on a
/// notification. Messages kept from being marked read stay unread in
/// TDLib; [readUpTo] remembers what the user has seen, for the chat and
/// sidebar to use.
///
/// The guard also owns the `online` option: online while the app is in
/// the foreground ([foreground]), offline in the background, and always
/// offline with [PrivacySettings.stayOffline].
///
/// What no client filter can hide: Telegram shows the account online for a
/// moment when it sends a message, sending a message marks the chat read on
/// the server, TDLib sends its own upload chat actions while media goes
/// out, and reactions show that a message was seen.
final class PrivacyGuard {
  PrivacyGuard(this._client, {this._settings = const PrivacySettings()}) {
    _client.filter = _filter;
    _subscription = _client.updates.listen(_onUpdate);
  }

  final td.TdClient _client;
  late final StreamSubscription<td.TdObject> _subscription;
  final _seen = <int, int>{};
  // Not sync: a listener must not run inside the filter, where a request
  // of its own would re-enter send().
  final _seenChanges = StreamController<int>.broadcast();
  PrivacySettings _settings;
  var _ready = false;
  var _foreground = true;
  var _deliberate = 0;

  /// The online status last sent, so an unchanged one is not sent again.
  bool? _sentOnline;

  PrivacySettings get settings => _settings;

  set settings(PrivacySettings value) {
    _settings = value;
    _syncOnline();
  }

  /// Whether the app is in the foreground. The account is online then,
  /// unless [PrivacySettings.stayOffline] is on.
  bool get foreground => _foreground;

  set foreground(bool value) {
    _foreground = value;
    _syncOnline();
  }

  /// Sends what [send] sends past the filter: for what the user asks for
  /// on purpose, such as "Mark as read" on a notification.
  Future<R> deliberately<R>(Future<R> Function() send) {
    _deliberate++;
    try {
      return send();
    } finally {
      _deliberate--;
    }
  }

  /// The newest message the user saw in [chatId] while its read receipts
  /// were held back, or 0.
  int readUpTo(int chatId) => _seen[chatId] ?? 0;

  /// The chat ids whose [readUpTo] changed.
  Stream<int> get seenChanges => _seenChanges.stream;

  td.TdObject? _filter(td.TdFunction<td.TdObject> request) {
    if (_deliberate > 0) return null;
    final s = _settings;
    switch (request) {
      case td.ViewMessages(:final chatId, :final messageIds)
          when s.hideReadReceipts || s.silentReadChats.contains(chatId):
        _noteSeen(chatId, messageIds);
        return const td.Ok();
      case td.ReadAllChatMentions(:final chatId) ||
              td.ReadAllChatReactions(:final chatId) ||
              td.ReadAllChatPollVotes(:final chatId) ||
              td.ReadAllForumTopicMentions(:final chatId) ||
              td.ReadAllForumTopicReactions(:final chatId) ||
              td.ReadAllForumTopicPollVotes(:final chatId) ||
              td.ReadAllDirectMessagesChatTopicReactions(:final chatId)
          when s.hideReadReceipts || s.silentReadChats.contains(chatId):
        return const td.Ok();
      case td.ReadChatList() when s.hideReadReceipts:
        return const td.Ok();
      case td.SendChatAction() when s.hideTyping:
        return const td.Ok();
      case td.OpenMessageContent() when s.hideContentOpened:
        return const td.Ok();
      case td.SetOption(
            name: 'online',
            value: td.OptionValueBoolean(value: true),
          )
          when s.stayOffline:
        return const td.Ok();
      default:
        return null;
    }
  }

  void _noteSeen(int chatId, List<int> messageIds) {
    if (messageIds.isEmpty) return;
    final newest = messageIds.reduce((a, b) => a > b ? a : b);
    if (newest <= readUpTo(chatId)) return;
    _seen[chatId] = newest;
    if (!_seenChanges.isClosed) _seenChanges.add(chatId);
  }

  void _onUpdate(td.TdObject update) {
    if (update case td.UpdateAuthorizationState(
      authorizationState: td.AuthorizationStateReady(),
    )) {
      _ready = true;
      _syncOnline();
    }
  }

  /// Tells TDLib whether the account is online, when that changed.
  void _syncOnline() {
    if (!_ready) return;
    final online = _foreground && !_settings.stayOffline;
    if (online == _sentOnline) return;
    _sentOnline = online;
    unawaited(
      deliberately(
        () => _client.send(
          td.SetOption(
            name: 'online',
            value: td.OptionValueBoolean(value: online),
          ),
        ),
      ).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Stops following the session. The filter stays on the client, so
  /// nothing slips through while it closes.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _seenChanges.close();
  }
}
