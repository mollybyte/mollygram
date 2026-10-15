import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Who sent a message: a user, or a chat (a channel, or a group posting
/// anonymously).
final class MessageSenderId {
  const MessageSenderId.user(this.id) : isChat = false;
  const MessageSenderId.chat(this.id) : isChat = true;

  factory MessageSenderId.of(td.MessageSender sender) => switch (sender) {
    td.MessageSenderUser(:final userId) => MessageSenderId.user(userId),
    td.MessageSenderChat(:final chatId) => MessageSenderId.chat(chatId),
  };

  final int id;
  final bool isChat;

  @override
  bool operator ==(Object other) =>
      other is MessageSenderId && other.id == id && other.isChat == isChat;

  @override
  int get hashCode => Object.hash(id, isChat);
}

/// Where an outgoing message is on its way to the server.
enum MessageSendState {
  /// On the server; incoming messages are always here.
  sent,

  /// Waiting to be sent.
  pending,

  /// The server rejected it.
  failed,
}

/// One message of a conversation timeline.
///
/// It wraps the TDLib message as is, so every kind of content reaches the
/// chat view; the getters cover what the timeline itself needs.
final class ConversationMessage {
  const ConversationMessage(this.message, {this.deletedAt, this.stableId});

  final td.Message message;

  /// The id this message was first drawn under, when it has changed since:
  /// a sent message gets its server id in place of the temporary one, and
  /// the timeline keeps its row under the first so nothing is rebuilt.
  final int? stableId;

  /// What the timeline keys the row by.
  int get keyId => stableId ?? message.id;

  /// When someone deleted the message for everyone, for one kept in the
  /// privacy store and shown in its place; null for a live message.
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  int get id => message.id;
  int get chatId => message.chatId;
  int get date => message.date;

  /// When the message was last edited, or 0.
  int get editDate => message.editDate;
  bool get isOutgoing => message.isOutgoing;

  /// What to show: an ephemeral payload, when TDLib sends one, replaces
  /// the regular content.
  td.MessageContent get content =>
      message.ephemeralContent?.content ?? message.content;

  /// Messages sent together as an album share a non-zero id.
  int get albumId => message.mediaAlbumId;

  /// The text of a text message, or the caption of a media one.
  String get text => captionOf(content)?.text ?? '';

  /// Who sent the message.
  MessageSenderId get sender => MessageSenderId.of(message.senderId);

  MessageSendState get sendState => switch (message.sendingState) {
    td.MessageSendingStatePending() => MessageSendState.pending,
    td.MessageSendingStateFailed() => MessageSendState.failed,
    null => MessageSendState.sent,
  };

  /// A chat event ("joined the group", "pinned a message") rather than
  /// something a person wrote; drawn centered, without a bubble.
  bool get isService => isServiceContent(content);

  /// The same message with some of its JSON fields replaced, for the
  /// updates TDLib sends about a single field.
  ConversationMessage patched(Map<String, Object?> fields) =>
      ConversationMessage(
        td.Message.fromJson({...message.toJson(), ...fields}),
        deletedAt: deletedAt,
        stableId: stableId,
      );
}

/// The text of a text message, or the caption of media; null when the
/// content has neither.
td.FormattedText? captionOf(td.MessageContent content) => switch (content) {
  td.MessageText(:final text) => text,
  td.MessagePhoto(:final caption) ||
  td.MessageVideo(:final caption) ||
  td.MessageAnimation(:final caption) ||
  td.MessageDocument(:final caption) ||
  td.MessageAudio(:final caption) ||
  td.MessageVoiceNote(:final caption) ||
  td.MessagePaidMedia(:final caption) => caption,
  _ => null,
};

/// Whether [content] is a chat event rather than a message someone wrote.
bool isServiceContent(td.MessageContent content) => switch (content) {
  td.MessageText() ||
  td.MessageRichMessage() ||
  td.MessageAnimation() ||
  td.MessageAudio() ||
  td.MessageDocument() ||
  td.MessagePaidMedia() ||
  td.MessagePhoto() ||
  td.MessageSticker() ||
  td.MessageVideo() ||
  td.MessageVideoNote() ||
  td.MessageVoiceNote() ||
  td.MessageExpiredPhoto() ||
  td.MessageExpiredVideo() ||
  td.MessageExpiredVideoNote() ||
  td.MessageExpiredVoiceNote() ||
  td.MessageLiveLocation() ||
  td.MessageLocation() ||
  td.MessageVenue() ||
  td.MessageContact() ||
  td.MessageAnimatedEmoji() ||
  td.MessageDice() ||
  td.MessageGame() ||
  td.MessagePoll() ||
  td.MessageStakeDice() ||
  td.MessageStory() ||
  td.MessageChecklist() ||
  td.MessageInvoice() ||
  td.MessageCall() ||
  td.MessageGiveaway() ||
  td.MessageGiveawayWinners() ||
  td.MessageUnsupported() => false,
  _ => true,
};

/// Whether the user is in a group or channel.
enum ChatMembership { member, left, banned, unknown }

/// Holds the loaded timelines for chats, the messages they reply to, and
/// the names of the people and chats that sent them.
///
/// TDLib sends history and live updates separately. Messages are keyed by
/// their per-chat IDs, so either source can safely replace an earlier value.
final class ConversationStore {
  final _byChat = <int, Map<int, ConversationMessage>>{};
  final _referenced = <(int, int), ConversationMessage>{};
  final _missing = <(int, int)>{};
  final _reachedStart = <int>{};
  final _userNames = <int, String>{};
  final _chatTitles = <int, String>{};
  final _colors = <MessageSenderId, int>{};
  final _photos = <MessageSenderId, td.File>{};
  final _messageSenders = <int, td.MessageSender>{};
  final _readInbox = <int, int>{};
  final _readOutbox = <int, int>{};
  final _channels = <int>{};
  final _atLatest = <int>{};
  final _lastMessage = <int, int>{};
  final _unread = <int, int>{};
  final _unreadMentions = <int, int>{};
  final _unreadReactions = <int, int>{};
  final _pinned = <int, List<int>>{};
  final _supergroupOf = <int, int>{};
  final _basicGroupOf = <int, int>{};
  final _supergroupStatus = <int, td.ChatMemberStatus>{};

  /// The supergroups that are forums, whose chat shows topics.
  final _forums = <int>{};
  final _basicGroupStatus = <int, td.ChatMemberStatus>{};
  final _muteFor = <int, int>{};
  final _permissions = <int, td.ChatPermissions>{};
  final _drafts = <int, td.DraftMessage>{};
  final _slowMode = <int, ({int delay, DateTime until})>{};
  final _replyMarkup = <int, int>{};
  final _privateUserOf = <int, int>{};
  final _bots = <int>{};
  final _botCommands = <int, List<BotCommand>>{};
  final _botMenus = <int, BotMenu>{};
  final _hasScheduled = <int>{};
  final _scheduledVersion = <int, int>{};

  /// Replaces the timeline of [chatId] with [messages], keeping the ones in
  /// [keep] that are still present (messages that arrived while the history
  /// was loading). [latest] says the page is the newest one; otherwise the
  /// timeline is a window around an older message, with a gap after it
  /// until newer pages load ([reachedEnd]).
  void replaceHistory(
    int chatId,
    List<ConversationMessage> messages, {
    Set<int> keep = const {},
    bool latest = true,
  }) {
    final previous = _byChat[chatId] ?? const {};
    _reachedStart.remove(chatId);
    latest ? _atLatest.add(chatId) : _atLatest.remove(chatId);
    _byChat[chatId] = {
      for (final id in keep) id: ?previous[id],
      for (final message in messages) message.id: message,
    };
  }

  /// Adds a page of newer history. Returns how many of [messages] were not
  /// in the timeline yet.
  int addNewer(int chatId, List<ConversationMessage> messages) =>
      addOlder(chatId, messages);

  /// Whether the timeline of [chatId] goes up to the newest message, so
  /// new messages join it as they arrive.
  bool reachedEnd(int chatId) {
    if (_atLatest.contains(chatId)) return true;
    final last = _lastMessage[chatId] ?? 0;
    final newest = newestId(chatId);
    return last != 0 && newest != null && newest >= last;
  }

  void markReachedEnd(int chatId) => _atLatest.add(chatId);

  /// The newest loaded message of [chatId], or null when none is.
  int? newestId(int chatId) {
    final ids = _byChat[chatId]?.keys;
    if (ids == null || ids.isEmpty) return null;
    return ids.reduce((a, b) => a > b ? a : b);
  }

  /// Whether the timeline of [chatId] holds [messageId].
  bool contains(int chatId, int messageId) =>
      _byChat[chatId]?.containsKey(messageId) ?? false;

  /// The id of the newest message of [chatId], 0 while unknown or when the
  /// chat is empty.
  int lastMessageId(int chatId) => _lastMessage[chatId] ?? 0;

  void setLastMessageId(int chatId, int messageId) =>
      _lastMessage[chatId] = messageId;

  /// How many messages of [chatId] the user hasn't read.
  int unreadCount(int chatId) => _unread[chatId] ?? 0;

  /// How many unread messages of [chatId] mention the user or answer them.
  int unreadMentionCount(int chatId) => _unreadMentions[chatId] ?? 0;

  /// How many of the user's messages in [chatId] got reactions they haven't
  /// seen.
  int unreadReactionCount(int chatId) => _unreadReactions[chatId] ?? 0;

  /// Each returns whether the count changed.
  bool setUnreadCount(int chatId, int count) =>
      _setCount(_unread, chatId, count);

  bool setUnreadMentionCount(int chatId, int count) =>
      _setCount(_unreadMentions, chatId, count);

  bool setUnreadReactionCount(int chatId, int count) =>
      _setCount(_unreadReactions, chatId, count);

  /// The pinned messages of [chatId], newest first, once [setPinned] ran;
  /// the messages themselves are kept as referenced ones.
  List<int> pinnedIds(int chatId) => _pinned[chatId] ?? const [];

  /// Whether the pinned messages of [chatId] have been loaded.
  bool hasPinned(int chatId) => _pinned.containsKey(chatId);

  void setPinned(int chatId, List<int> ids) =>
      _pinned[chatId] = [...ids]..sort((a, b) => b.compareTo(a));

  /// Adds or removes one pinned message. Returns whether the list changed.
  bool markPinned(int chatId, int messageId, {required bool pinned}) {
    final ids = _pinned[chatId];
    if (ids == null) return false;
    if (pinned) {
      if (ids.contains(messageId)) return false;
      ids
        ..add(messageId)
        ..sort((a, b) => b.compareTo(a));
      return true;
    }
    return ids.remove(messageId);
  }

  static bool _setCount(Map<int, int> counts, int chatId, int count) {
    if ((counts[chatId] ?? 0) == count) return false;
    counts[chatId] = count;
    return true;
  }

  /// Adds a page of older history. Returns how many of [messages] were not
  /// in the timeline yet.
  int addOlder(int chatId, List<ConversationMessage> messages) {
    final timeline = _byChat[chatId] ??= {};
    var added = 0;
    for (final message in messages) {
      if (timeline.containsKey(message.id)) continue;
      timeline[message.id] = message;
      added++;
    }
    return added;
  }

  /// Whether the timeline of [chatId] goes back to the first message.
  bool reachedStart(int chatId) => _reachedStart.contains(chatId);

  void markReachedStart(int chatId) => _reachedStart.add(chatId);

  /// The oldest loaded message of [chatId], or null when none is.
  int? oldestId(int chatId) {
    final ids = _byChat[chatId]?.keys;
    if (ids == null || ids.isEmpty) return null;
    return ids.reduce((a, b) => a < b ? a : b);
  }

  void upsert(ConversationMessage message) {
    final byId = _byChat[message.chatId] ??= {};
    // Keep the row's first key when a newer copy of the message arrives.
    final old = byId[message.id];
    if (old?.stableId != null && message.stableId == null) {
      message = ConversationMessage(
        message.message,
        deletedAt: message.deletedAt,
        stableId: old!.stableId,
      );
    }
    byId[message.id] = message;
    final key = (message.chatId, message.id);
    if (_referenced.containsKey(key)) _referenced[key] = message;
  }

  /// Replaces JSON [fields] of a message, wherever the store holds it.
  /// Returns whether it did.
  bool patch(int chatId, int messageId, Map<String, Object?> fields) {
    var found = false;
    final messages = _byChat[chatId];
    final message = messages?[messageId];
    if (message != null) {
      messages![messageId] = message.patched(fields);
      found = true;
    }
    final key = (chatId, messageId);
    final referenced = _referenced[key];
    if (referenced != null) {
      _referenced[key] = referenced.patched(fields);
      found = true;
    }
    return found;
  }

  /// Puts the new state of [poll] into every loaded message that carries
  /// it. Returns whether any did.
  bool patchPoll(td.Poll poll) {
    var found = false;
    // The rest of the content (description, media) stays as it was.
    ConversationMessage? withPoll(ConversationMessage message) =>
        switch (message.content) {
          td.MessagePoll(poll: final own) && final content
              when own.id == poll.id =>
            message.patched({
              'content': {...content.toJson(), 'poll': poll.toJson()},
            }),
          _ => null,
        };
    for (final messages in _byChat.values) {
      for (final id in messages.keys.toList()) {
        final patched = withPoll(messages[id]!);
        if (patched == null) continue;
        messages[id] = patched;
        found = true;
      }
    }
    for (final key in _referenced.keys.toList()) {
      final patched = withPoll(_referenced[key]!);
      if (patched == null) continue;
      _referenced[key] = patched;
      found = true;
    }
    return found;
  }

  void remove(int chatId, Iterable<int> messageIds) {
    final messages = _byChat[chatId];
    for (final id in messageIds) {
      messages?.remove(id);
      _referenced.remove((chatId, id));
    }
  }

  List<ConversationMessage> messagesFor(int chatId) {
    final messages = _byChat[chatId]?.values.toList() ?? [];
    messages.sort((a, b) => b.id.compareTo(a.id));
    return List.unmodifiable(messages);
  }

  /// A message of [chatId], from the timeline or from the messages loaded
  /// because something replies to them.
  ConversationMessage? message(int chatId, int messageId) =>
      _byChat[chatId]?[messageId] ?? _referenced[(chatId, messageId)];

  /// Whether TDLib said the message [messageId] of [chatId] doesn't exist,
  /// such as the deleted original of a reply.
  bool isMissing(int chatId, int messageId) =>
      _missing.contains((chatId, messageId));

  void markMissing(int chatId, int messageId) =>
      _missing.add((chatId, messageId));

  /// Keeps a message outside the loaded timeline, such as an old one a
  /// reply quotes.
  void addReferenced(ConversationMessage message) =>
      _referenced[(message.chatId, message.id)] = message;

  /// Returns whether the name changed.
  bool setUserName(int userId, String name) {
    if (_userNames[userId] == name) return false;
    _userNames[userId] = name;
    return true;
  }

  /// Returns whether the title changed.
  bool setChatTitle(int chatId, String title) {
    if (_chatTitles[chatId] == title) return false;
    _chatTitles[chatId] = title;
    return true;
  }

  /// The display name of [sender], or null while TDLib hasn't sent it.
  String? nameOf(MessageSenderId sender) =>
      sender.isChat ? _chatTitles[sender.id] : _userNames[sender.id];

  /// The accent color id of [sender] (0 to 6 are the built-in colors),
  /// which colors their name; 0 while unknown.
  int colorOf(MessageSenderId sender) => _colors[sender] ?? 0;

  /// Returns whether the colour changed.
  bool setColor(MessageSenderId sender, int colorId) {
    if (_colors[sender] == colorId) return false;
    _colors[sender] = colorId;
    return true;
  }

  /// The small profile photo of [sender], if they have one.
  td.File? photoOf(MessageSenderId sender) => _photos[sender];

  /// Returns whether a different photo, or none, is shown now.
  bool setPhoto(MessageSenderId sender, td.File? photo) {
    final changed = _photos[sender]?.id != photo?.id;
    photo == null ? _photos.remove(sender) : _photos[sender] = photo;
    return changed;
  }

  /// Who the user posts as in [chatId]: set only where Telegram offers a
  /// choice, as in a channel's comments or a group the user owns a channel
  /// in; null everywhere else.
  td.MessageSender? messageSenderOf(int chatId) => _messageSenders[chatId];

  bool setMessageSender(int chatId, td.MessageSender? sender) {
    final before = _messageSenders[chatId];
    final changed =
        (before == null) != (sender == null) ||
        (before != null &&
            sender != null &&
            MessageSenderId.of(before) != MessageSenderId.of(sender));
    sender == null
        ? _messageSenders.remove(chatId)
        : _messageSenders[chatId] = sender;
    return changed;
  }

  /// The newest message of [chatId] the user has read.
  int lastReadInbox(int chatId) => _readInbox[chatId] ?? 0;

  /// The newest outgoing message of [chatId] the other side has read; the
  /// ones up to it get two ticks.
  int lastReadOutbox(int chatId) => _readOutbox[chatId] ?? 0;

  void setReadInbox(int chatId, int messageId) =>
      _readInbox[chatId] = messageId;

  void setReadOutbox(int chatId, int messageId) =>
      _readOutbox[chatId] = messageId;

  /// Whether [chatId] is a channel, where posts come from the channel and
  /// events read differently.
  bool isChannel(int chatId) => _channels.contains(chatId);

  /// Whether [chatId] is a basic group or a supergroup that is not a
  /// channel, as far as the store has seen it.
  bool isGroup(int chatId) =>
      (_supergroupOf.containsKey(chatId) ||
          _basicGroupOf.containsKey(chatId)) &&
      !isChannel(chatId);

  /// Remembers which group or channel [chat] is, so its member status
  /// ([setSupergroupStatus], [setBasicGroupStatus]) can be found.
  void setChatType(int chatId, td.ChatType type) {
    _supergroupOf.remove(chatId);
    _basicGroupOf.remove(chatId);
    _privateUserOf.remove(chatId);
    switch (type) {
      case td.ChatTypeSupergroup(:final supergroupId):
        _supergroupOf[chatId] = supergroupId;
      case td.ChatTypeBasicGroup(:final basicGroupId):
        _basicGroupOf[chatId] = basicGroupId;
      case td.ChatTypePrivate(:final userId):
        _privateUserOf[chatId] = userId;
      default:
        break;
    }
  }

  int? basicGroupIdOf(int chatId) => _basicGroupOf[chatId];

  int? chatOfSupergroup(int supergroupId) =>
      _chatOf(_supergroupOf, supergroupId);

  int? chatOfBasicGroup(int basicGroupId) =>
      _chatOf(_basicGroupOf, basicGroupId);

  int? chatOfPrivateUser(int userId) => _chatOf(_privateUserOf, userId);

  static int? _chatOf(Map<int, int> ids, int id) {
    for (final entry in ids.entries) {
      if (entry.value == id) return entry.key;
    }
    return null;
  }

  /// The user of a private chat; null for groups, channels and secret
  /// chats.
  int? privateUserIdOf(int chatId) => _privateUserOf[chatId];

  /// Remembers whether [userId] is a bot; true when that changed.
  bool setBot(int userId, bool isBot) =>
      isBot ? _bots.add(userId) : _bots.remove(userId);

  /// The bot of a private chat with one; null elsewhere.
  int? botUserIdOf(int chatId) {
    final userId = _privateUserOf[chatId];
    return userId != null && _bots.contains(userId) ? userId : null;
  }

  /// The commands the bots of [chatId] offer, for the `/` popup.
  List<BotCommand> botCommands(int chatId) => _botCommands[chatId] ?? const [];

  /// Remembers the commands of [chatId]; true when they changed.
  bool setBotCommands(int chatId, List<BotCommand> commands) {
    final same =
        _botCommands[chatId]?.toString() == commands.toString() ||
        (commands.isEmpty && !_botCommands.containsKey(chatId));
    if (same) return false;
    if (commands.isEmpty) {
      _botCommands.remove(chatId);
    } else {
      _botCommands[chatId] = List.unmodifiable(commands);
    }
    return true;
  }

  /// The menu button of the bot in [chatId]; null for other chats.
  BotMenu? botMenu(int chatId) => _botMenus[chatId];

  /// Remembers the bot's menu button; true when it changed.
  bool setBotMenu(int chatId, BotMenu? menu) {
    if (_botMenus[chatId] == menu) return false;
    if (menu == null) {
      _botMenus.remove(chatId);
    } else {
      _botMenus[chatId] = menu;
    }
    return true;
  }

  /// Remembers whether supergroup [supergroupId] is a forum; true when
  /// that changed.
  bool setForum(int supergroupId, bool isForum) =>
      isForum ? _forums.add(supergroupId) : _forums.remove(supergroupId);

  /// Whether the user may pin, close, rename or delete topics in
  /// [chatId]: the creator, or an admin with that right.
  bool canManageTopics(int chatId) => switch (_statusOf(chatId)) {
    td.ChatMemberStatusCreator() => true,
    td.ChatMemberStatusAdministrator(:final rights) => rights.canManageTopics,
    _ => false,
  };

  /// Whether the user may start a topic in [chatId].
  bool canCreateTopics(int chatId) =>
      canManageTopics(chatId) ||
      (_permissions[chatId]?.canCreateTopics ?? false);

  /// Whether [chatId] is a forum group, shown as a list of topics.
  bool isForum(int chatId) {
    final supergroupId = _supergroupOf[chatId];
    return supergroupId != null && _forums.contains(supergroupId);
  }

  /// Returns the chat the supergroup belongs to when its status changed.
  int? setSupergroupStatus(int supergroupId, td.ChatMemberStatus status) {
    final same =
        _supergroupStatus[supergroupId]?.toJson().toString() ==
        status.toJson().toString();
    _supergroupStatus[supergroupId] = status;
    if (same) return null;
    for (final entry in _supergroupOf.entries) {
      if (entry.value == supergroupId) return entry.key;
    }
    return null;
  }

  int? setBasicGroupStatus(int basicGroupId, td.ChatMemberStatus status) {
    final same =
        _basicGroupStatus[basicGroupId]?.toJson().toString() ==
        status.toJson().toString();
    _basicGroupStatus[basicGroupId] = status;
    if (same) return null;
    for (final entry in _basicGroupOf.entries) {
      if (entry.value == basicGroupId) return entry.key;
    }
    return null;
  }

  /// The unsent draft of [chatId] as TDLib keeps it, synced across the
  /// user's devices; null when there is none.
  td.DraftMessage? draft(int chatId) => _drafts[chatId];

  /// Whether [chatId] has messages waiting to be sent later.
  bool hasScheduledMessages(int chatId) => _hasScheduled.contains(chatId);

  /// Remembers whether [chatId] has scheduled messages; true when changed.
  /// The message whose reply markup (a bot's keyboard) the composer shows
  /// in [chatId]; 0 for none.
  int replyMarkupMessageId(int chatId) => _replyMarkup[chatId] ?? 0;

  bool setReplyMarkupMessageId(int chatId, int messageId) {
    if ((_replyMarkup[chatId] ?? 0) == messageId) return false;
    if (messageId == 0) {
      _replyMarkup.remove(chatId);
    } else {
      _replyMarkup[chatId] = messageId;
    }
    return true;
  }

  bool setHasScheduled(int chatId, bool has) {
    final changed = has
        ? _hasScheduled.add(chatId)
        : _hasScheduled.remove(chatId);
    if (changed) bumpScheduled(chatId);
    return changed;
  }

  /// Counts up whenever the scheduled messages of [chatId] may have
  /// changed, so a view of them knows to load them again.
  int scheduledVersion(int chatId) => _scheduledVersion[chatId] ?? 0;

  void bumpScheduled(int chatId) =>
      _scheduledVersion[chatId] = scheduledVersion(chatId) + 1;

  /// Remembers the draft of [chatId]; true when it changed.
  bool setDraft(int chatId, td.DraftMessage? draft) {
    final same =
        _drafts[chatId]?.toJson().toString() == draft?.toJson().toString();
    if (draft == null) {
      _drafts.remove(chatId);
    } else {
      _drafts[chatId] = draft;
    }
    return !same;
  }

  /// The supergroup behind [chatId], when it is one.
  int? supergroupIdOf(int chatId) => _supergroupOf[chatId];

  /// Remembers what plain members may do in [chatId]; true when changed.
  bool setPermissions(int chatId, td.ChatPermissions permissions) {
    final same =
        _permissions[chatId]?.toJson().toString() ==
        permissions.toJson().toString();
    _permissions[chatId] = permissions;
    return !same;
  }

  /// Remembers the slowmode of [supergroupId]: one message every [delay]
  /// seconds, the next one allowed in [expiresIn] seconds.
  void setSlowMode(
    int supergroupId, {
    required int delay,
    double expiresIn = 0,
  }) {
    if (delay <= 0) {
      _slowMode.remove(supergroupId);
      return;
    }
    _slowMode[supergroupId] = (
      delay: delay,
      until: DateTime.now().add(
        Duration(milliseconds: (expiresIn * 1000).round()),
      ),
    );
  }

  bool _isAdmin(int chatId) => switch (_statusOf(chatId)) {
    td.ChatMemberStatusCreator() || td.ChatMemberStatusAdministrator() => true,
    _ => false,
  };

  /// Whether the user may write text in [chatId]: the chat's permissions
  /// and the user's own restrictions apply to plain members of a group,
  /// never to its admins.
  bool canSendText(int chatId) {
    if (!canPost(chatId)) return false;
    if (isChannel(chatId) || _isAdmin(chatId)) return true;
    if (_statusOf(chatId) case td.ChatMemberStatusRestricted(:final permissions)
        when !permissions.canSendBasicMessages) {
      return false;
    }
    final isGroup =
        _supergroupOf.containsKey(chatId) || _basicGroupOf.containsKey(chatId);
    return !isGroup || (_permissions[chatId]?.canSendBasicMessages ?? true);
  }

  /// When the user's own restriction on writing in [chatId] ends, in Unix
  /// seconds; null when it has no end or there is no such restriction.
  int? restrictedUntil(int chatId) {
    if (_statusOf(chatId)
        case td.ChatMemberStatusRestricted(
          :final permissions,
          :final restrictedUntilDate,
        )
        when !permissions.canSendBasicMessages && restrictedUntilDate > 0) {
      return restrictedUntilDate;
    }
    return null;
  }

  /// Seconds between messages in [chatId] for plain members, 0 without
  /// slowmode.
  int slowModeDelay(int chatId) {
    final supergroupId = _supergroupOf[chatId];
    if (supergroupId == null || _isAdmin(chatId)) return 0;
    return _slowMode[supergroupId]?.delay ?? 0;
  }

  /// When the user may send the next message in [chatId] under slowmode;
  /// null when they may send now or slowmode doesn't bind them.
  DateTime? slowModeUntil(int chatId) {
    if (slowModeDelay(chatId) == 0) return null;
    final until = _slowMode[_supergroupOf[chatId]!]!.until;
    return until.isAfter(DateTime.now()) ? until : null;
  }

  td.ChatMemberStatus? _statusOf(int chatId) {
    final supergroup = _supergroupOf[chatId];
    if (supergroup != null) return _supergroupStatus[supergroup];
    final basic = _basicGroupOf[chatId];
    if (basic != null) return _basicGroupStatus[basic];
    return null;
  }

  /// Whether the user is in [chatId]; a private chat counts as a member.
  ChatMembership membership(int chatId) {
    if (!_supergroupOf.containsKey(chatId) &&
        !_basicGroupOf.containsKey(chatId)) {
      return ChatMembership.member;
    }
    return switch (_statusOf(chatId)) {
      null => ChatMembership.unknown,
      td.ChatMemberStatusLeft() => ChatMembership.left,
      td.ChatMemberStatusBanned() => ChatMembership.banned,
      td.ChatMemberStatusRestricted(:final isMember) =>
        isMember ? ChatMembership.member : ChatMembership.left,
      _ => ChatMembership.member,
    };
  }

  /// Whether the user may post in [chatId]: in a channel only its creator
  /// and the admins who may post can.
  bool canPost(int chatId) {
    if (membership(chatId) != ChatMembership.member) return false;
    if (!isChannel(chatId)) return true;
    return switch (_statusOf(chatId)) {
      td.ChatMemberStatusCreator() => true,
      td.ChatMemberStatusAdministrator(:final rights) => rights.canPostMessages,
      _ => false,
    };
  }

  /// Whether notifications of [chatId] are muted.
  bool isMuted(int chatId) => (_muteFor[chatId] ?? 0) > 0;

  /// Returns whether the muted state changed.
  bool setMuteFor(int chatId, int muteFor) {
    final was = isMuted(chatId);
    _muteFor[chatId] = muteFor;
    return was != isMuted(chatId);
  }

  void setChannel(int chatId, bool isChannel) =>
      isChannel ? _channels.add(chatId) : _channels.remove(chatId);
}

/// The button at the left of the composer in a chat with a bot: its
/// commands by default, or a Web App the bot names.
final class BotMenu {
  const BotMenu({required this.text, required this.url});

  /// The button's label; empty for the plain commands menu.
  final String text;

  /// The Web App to open; empty for the commands menu.
  final String url;

  bool get isCommands => url.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is BotMenu && other.text == text && other.url == url;

  @override
  int get hashCode => Object.hash(text, url);
}

/// A command a bot offers, with the bot it belongs to.
final class BotCommand {
  const BotCommand({
    required this.botUserId,
    required this.command,
    required this.description,
  });

  final int botUserId;

  /// Without the leading slash.
  final String command;
  final String description;

  @override
  String toString() => '$botUserId/$command:$description';
}
