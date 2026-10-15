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

  bool get isGhost =>
      hideReadReceipts && hideTyping && stayOffline && hideContentOpened;

  /// Ghost mode on turns every switch on; off turns every switch off.
  PrivacySettings withGhost(bool on) => PrivacySettings(
    hideReadReceipts: on,
    hideTyping: on,
    stayOffline: on,
    hideContentOpened: on,
    silentReadChats: silentReadChats,
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
  };

  /// Reads what [toJson] wrote; anything unexpected reads as off.
  factory PrivacySettings.fromJson(Object? json) {
    if (json is! Map<String, Object?>) return const PrivacySettings();
    bool flag(String key) => json[key] == true;
    final chats = json['silent_read_chats'];
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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrivacySettings &&
      other.hideReadReceipts == hideReadReceipts &&
      other.hideTyping == hideTyping &&
      other.stayOffline == stayOffline &&
      other.hideContentOpened == hideContentOpened &&
      other.silentReadChats.length == silentReadChats.length &&
      other.silentReadChats.containsAll(silentReadChats);

  @override
  int get hashCode => Object.hash(
    hideReadReceipts,
    hideTyping,
    stayOffline,
    hideContentOpened,
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
/// Everything else passes untouched. Messages kept from being marked read
/// stay unread in TDLib; [readUpTo] remembers what the user has seen, for
/// the UI.
///
/// Telegram's servers still show the account online for a moment when it
/// sends a message; no client can prevent that.
final class PrivacyGuard {
  PrivacyGuard(this._client, {this._settings = const PrivacySettings()}) {
    _client.filter = _filter;
    _subscription = _client.updates.listen(_onUpdate);
  }

  final td.TdClient _client;
  late final StreamSubscription<td.TdObject> _subscription;
  final _seen = <int, int>{};
  final _seenChanges = StreamController<int>.broadcast(sync: true);
  PrivacySettings _settings;
  var _ready = false;

  PrivacySettings get settings => _settings;

  set settings(PrivacySettings value) {
    final goOffline = value.stayOffline && !_settings.stayOffline;
    _settings = value;
    if (goOffline && _ready) _sendOffline();
  }

  /// The newest message the user saw in [chatId] while its read receipts
  /// were held back, or 0.
  int readUpTo(int chatId) => _seen[chatId] ?? 0;

  /// The chat ids whose [readUpTo] changed.
  Stream<int> get seenChanges => _seenChanges.stream;

  td.TdObject? _filter(td.TdFunction<td.TdObject> request) {
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
      if (_settings.stayOffline) _sendOffline();
    }
  }

  void _sendOffline() => unawaited(
    _client
        .send(
          const td.SetOption(
            name: 'online',
            value: td.OptionValueBoolean(value: false),
          ),
        )
        .then<void>((_) {}, onError: (Object _) {}),
  );

  Future<void> dispose() async {
    _client.filter = null;
    await _subscription.cancel();
    await _seenChanges.close();
  }
}
