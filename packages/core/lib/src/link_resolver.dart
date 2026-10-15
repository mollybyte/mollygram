import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'proxy_controller.dart';
import 'telegram_links.dart';

/// What a clicked link leads to, once TDLib has looked at it.
sealed class LinkTarget {
  const LinkTarget();
}

/// A web page, mail address or phone number for the system to open.
final class ExternalLinkTarget extends LinkTarget {
  const ExternalLinkTarget(this.uri);
  final Uri uri;
}

/// A chat the user can open right away: one they are in, a private chat or
/// a bot. [messageId] is set for links to a message.
final class ChatLinkTarget extends LinkTarget {
  const ChatLinkTarget(this.chatId, {this.messageId});
  final int chatId;
  final int? messageId;
}

/// A group or channel the user is not in: an invite link, or a public chat
/// by its username. The app asks before joining.
final class JoinLinkTarget extends LinkTarget {
  const JoinLinkTarget(this.preview);
  final ChatJoinPreview preview;
}

/// A `tg://proxy` or `t.me/proxy` link: the app offers to add the proxy.
final class ProxyLinkTarget extends LinkTarget {
  const ProxyLinkTarget(this.proxy);
  final ProxySettings proxy;
}

/// A link that runs one of the app's commands, such as `tg://settings`.
final class CommandLinkTarget extends LinkTarget {
  const CommandLinkTarget(this.commandId);
  final String commandId;
}

/// A Telegram link to something that does not exist or is out of reach: an
/// unknown username, an expired invite, a message in a private chat.
final class MissingLinkTarget extends LinkTarget {
  const MissingLinkTarget();
}

/// A chat the user was banned from: it can be neither opened nor joined.
final class ForbiddenLinkTarget extends LinkTarget {
  const ForbiddenLinkTarget();
}

/// A Telegram link the app cannot handle yet, such as a sticker set or a
/// theme. [webFallback] is the https form, to open in the browser, if any.
final class UnsupportedLinkTarget extends LinkTarget {
  const UnsupportedLinkTarget({this.webFallback});
  final Uri? webFallback;
}

/// What the join sheet shows about a chat before the user joins it.
final class ChatJoinPreview {
  const ChatJoinPreview({
    required this.title,
    required this.isChannel,
    this.chatId = 0,
    this.username,
    this.inviteLink,
    this.description = '',
    this.memberCount = 0,
    this.createsJoinRequest = false,
    this.photo,
  });

  /// The chat photo, when the link or the chat carries one.
  final td.ChatPhotoInfo? photo;

  /// The chat, when TDLib knows it before joining (public chats); 0 for a
  /// private chat behind an invite link.
  final int chatId;
  final String title;
  final bool isChannel;
  final String? username;

  /// Set for invite links: joining goes through the link.
  final String? inviteLink;
  final String description;
  final int memberCount;

  /// Joining only sends a request that admins approve.
  final bool createsJoinRequest;

  /// Whether the chat can be looked at before joining.
  bool get canPreview => chatId != 0;
}

/// How joining went.
sealed class JoinResult {
  const JoinResult();
}

final class ChatJoined extends JoinResult {
  const ChatJoined(this.chatId);
  final int chatId;
}

/// The admins have to approve the request first.
final class JoinRequestSent extends JoinResult {
  const JoinRequestSent();
}

final class JoinFailed extends JoinResult {
  const JoinFailed(this.message);

  /// TDLib's error text, for logs; the UI shows its own words.
  final String message;
}

/// Resolves links with TDLib (`getInternalLinkType` and the calls each kind
/// needs) and joins chats from links.
final class LinkResolver {
  LinkResolver(this._client);

  final td.TdClient _client;

  /// What [raw] leads to: a URL, `@username` or a scheme-less link such as
  /// `t.me/durov`. Returns null for text that is not a link.
  ///
  /// `tg://user?id=` opens the private chat with that user and `t.me/s/`
  /// channel previews lead to the channel. Hashtags and bot commands are
  /// not links: the text knows them by their entities.
  Future<LinkTarget?> resolve(String raw) async {
    final normalized = TelegramLinks.normalize(raw);
    if (normalized == null) return null;
    final uri = TelegramLinks.withoutWebPreview(normalized);
    if (TelegramLinks.userIdOf(uri) case final userId?) return _user(userId);
    if (!TelegramLinks.isTelegram(uri)) {
      return TelegramLinks.isExternal(uri) ? ExternalLinkTarget(uri) : null;
    }
    final web = uri.scheme.toLowerCase() == 'tg' ? null : uri;
    final td.InternalLinkType type;
    try {
      type = await _client.send(td.GetInternalLinkType(link: uri.toString()));
    } on td.TdException {
      // Not a link TDLib knows, such as t.me/ on its own: the site shows it.
      return web == null
          ? const UnsupportedLinkTarget()
          : ExternalLinkTarget(web);
    }
    try {
      return await _target(type, web);
    } on td.TdException {
      return const MissingLinkTarget();
    }
  }

  /// The username of user [userId] when it is a bot; null for people,
  /// bots without one and users TDLib can't find.
  Future<String?> botUsername(int userId) async {
    try {
      final user = await _client.send(td.GetUser(userId: userId));
      if (user.type is! td.UserTypeBot) return null;
      return user.usernames?.activeUsernames.firstOrNull;
    } on td.TdException {
      return null;
    }
  }

  Future<LinkTarget> _target(td.InternalLinkType type, Uri? web) async {
    switch (type) {
      case td.InternalLinkTypePublicChat(:final chatUsername):
        return _publicChat(chatUsername);
      case td.InternalLinkTypeBotStart(:final botUsername):
        // TODO(links): send the start parameter once the chat view has a
        // Start button for bots.
        return _publicChat(botUsername);
      case td.InternalLinkTypeChatInvite(:final inviteLink):
        return _invite(inviteLink);
      case td.InternalLinkTypeMessage(:final url):
        return _message(url);
      case td.InternalLinkTypeSavedMessages():
        return _savedMessages();
      case td.InternalLinkTypeProxy(:final proxy):
        // A proxy of a kind TDLib doesn't describe, as from a newer app.
        return proxy == null
            ? const UnsupportedLinkTarget()
            : ProxyLinkTarget(ProxySettings.fromTd(proxy));
      case td.InternalLinkTypeSettings():
        return const CommandLinkTarget('app.settings');
      default:
        return UnsupportedLinkTarget(webFallback: web);
    }
  }

  Future<LinkTarget> _publicChat(String username) async {
    final td.Chat chat;
    try {
      chat = await _client.send(td.SearchPublicChat(username: username));
    } on td.TdException {
      return const MissingLinkTarget();
    }
    if (chat.type case td.ChatTypeSupergroup(
      :final supergroupId,
      :final isChannel,
    )) {
      final group = await _client.send(
        td.GetSupergroup(supergroupId: supergroupId),
      );
      switch (group.status) {
        case td.ChatMemberStatusBanned():
          return const ForbiddenLinkTarget();
        case td.ChatMemberStatusLeft() ||
            td.ChatMemberStatusRestricted(isMember: false):
          return JoinLinkTarget(
            ChatJoinPreview(
              chatId: chat.id,
              title: chat.title,
              isChannel: isChannel,
              username: username,
              memberCount: group.memberCount,
              description: await _description(supergroupId),
              photo: chat.photo,
            ),
          );
        default:
      }
    }
    return ChatLinkTarget(chat.id);
  }

  /// The channel's description; the sheet does without it when TDLib can't
  /// load it.
  Future<String> _description(int supergroupId) async {
    try {
      final info = await _client.send(
        td.GetSupergroupFullInfo(supergroupId: supergroupId),
      );
      return info.description;
    } on td.TdException {
      return '';
    }
  }

  Future<LinkTarget> _invite(String inviteLink) async {
    final td.ChatInviteLinkInfo info;
    try {
      info = await _client.send(td.CheckChatInviteLink(inviteLink: inviteLink));
    } on td.TdException {
      return const MissingLinkTarget();
    }
    // A chat id with no time limit means the user is already in the chat
    // (or it is public); TDLib has sent the chat then.
    if (info.chatId != 0 && info.accessibleFor == 0) {
      final chat = await _client.send(td.GetChat(chatId: info.chatId));
      if (chat.positions.isNotEmpty) return ChatLinkTarget(info.chatId);
    }
    return JoinLinkTarget(
      ChatJoinPreview(
        chatId: info.chatId,
        title: info.title,
        isChannel: info.type is td.InviteLinkChatTypeChannel,
        inviteLink: inviteLink,
        description: info.description,
        memberCount: info.memberCount,
        createsJoinRequest: info.createsJoinRequest,
        photo: info.photo,
      ),
    );
  }

  Future<LinkTarget> _message(String url) async {
    final td.MessageLinkInfo info;
    try {
      info = await _client.send(td.GetMessageLinkInfo(url: url));
    } on td.TdException {
      return const MissingLinkTarget();
    }
    if (info.chatId == 0) return const MissingLinkTarget();
    return ChatLinkTarget(info.chatId, messageId: info.message?.id);
  }

  Future<LinkTarget> _user(int userId) async {
    try {
      final chat = await _client.send(
        td.CreatePrivateChat(userId: userId, force: false),
      );
      return ChatLinkTarget(chat.id);
    } on td.TdException {
      return const MissingLinkTarget();
    }
  }

  Future<LinkTarget> _savedMessages() async {
    final me = await _client.send(const td.GetMe());
    final chat = await _client.send(
      td.CreatePrivateChat(userId: me.id, force: true),
    );
    return ChatLinkTarget(chat.id);
  }

  /// Joins the chat of [preview]: through its invite link, or as a public
  /// chat.
  Future<JoinResult> join(ChatJoinPreview preview) async {
    final td.ChatJoinResult result;
    try {
      result = await switch (preview.inviteLink) {
        final link? => _client.send(td.JoinChatByInviteLink(inviteLink: link)),
        null => _client.send(td.JoinChat(chatId: preview.chatId)),
      };
    } on td.TdException catch (e) {
      return JoinFailed(e.message);
    }
    return switch (result) {
      td.ChatJoinResultSuccess(:final chatId) => ChatJoined(
        chatId != 0 ? chatId : preview.chatId,
      ),
      td.ChatJoinResultRequestSent() => const JoinRequestSent(),
      td.ChatJoinResultGuardBotApprovalRequired() => const JoinFailed(
        'Guard bot approval is not supported yet',
      ),
      td.ChatJoinResultDeclined() => const JoinFailed('Declined'),
    };
  }
}
