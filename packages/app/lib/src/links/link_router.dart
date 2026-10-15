import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart'
    show WorkspaceShell, WorkspaceShellState;
import 'package:url_launcher/url_launcher.dart';

import '../commands/command_registry.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import '../shared_media/message_jump.dart';

/// What a link needs from the window: the join sheet and short notices.
abstract interface class LinkPresenter {
  /// Shows [preview] and lets the user join with [join]. Completes with the
  /// chat to open, or null when there is nothing to open.
  Future<int?> confirmJoin(
    ChatJoinPreview preview,
    Future<JoinResult> Function() join,
  );

  /// Tells the user why nothing opened.
  void showNotice(LinkNotice notice);

  /// Offers to add [proxy] from a proxy link and connect through it.
  Future<void> offerProxy(ProxySettings proxy);
}

enum LinkNotice {
  /// The username, invite or message does not exist or is out of reach.
  missing,

  /// A `tg://` link to something the app cannot show yet.
  unsupported,

  /// A chat the user was banned from.
  forbidden,

  /// A bot command tapped where the user can't write, or that failed to
  /// send.
  cannotSend,
}

/// What sending a bot command needs from the session.
abstract interface class CommandChats {
  /// Whether the user may write in [chatId]; false for channels, where a
  /// command would be published to every reader.
  bool canSendCommand(int chatId);

  /// Whether [chatId] is a group, where several bots may listen.
  bool isGroup(int chatId);

  /// The username of [userId] when it is a bot.
  Future<String?> botUsername(int userId);

  Future<void> send(int chatId, String text);
}

/// Opens what a link points at: a chat in the workspace, the join sheet
/// for a group or channel, an app command, or the browser.
///
/// Links come from message text, from mentions and from the system
/// (`tg://` URLs opened in other apps).
class LinkRouter {
  LinkRouter({
    required this._resolve,
    required this._join,
    required this._openChat,
    required this._runCommand,
    required this._launch,
    this._openMessage,
    this._search,
    this._commandChats,
  });

  final Future<LinkTarget?> Function(String raw) _resolve;
  final Future<JoinResult> Function(ChatJoinPreview preview) _join;
  final void Function(int chatId) _openChat;
  final bool Function(String commandId) _runCommand;
  final Future<bool> Function(Uri uri) _launch;
  final void Function(int chatId, int messageId)? _openMessage;

  /// Opens the message search with a query.
  final void Function(String query)? _search;

  final CommandChats? _commandChats;

  /// The window that shows sheets; set by [LinkHost]. Without it a link
  /// still opens chats and pages, and skips the sheets.
  LinkPresenter? presenter;

  /// Bumped per link, so a slow lookup cannot act after a newer click.
  int _generation = 0;

  /// Opens [raw]: a URL, a scheme-less link or an `@username`.
  Future<void> open(String raw) async {
    final generation = ++_generation;
    LinkTarget? target;
    try {
      target = await _resolve(raw);
    } on Object {
      // TDLib is closing or failed: a web link still opens on the site.
      final uri = TelegramLinks.normalize(raw);
      target = uri != null && TelegramLinks.isExternal(uri)
          ? ExternalLinkTarget(uri)
          : null;
    }
    if (generation != _generation) return;
    switch (target) {
      case null:
        return;
      case ExternalLinkTarget(:final uri):
        await _launch(uri);
      case ChatLinkTarget(:final chatId, :final messageId):
        if (messageId != null && _openMessage != null) {
          _openMessage(chatId, messageId);
        } else {
          _openChat(chatId);
        }
      case JoinLinkTarget(:final preview):
        final presenter = this.presenter;
        if (presenter == null) {
          if (preview.canPreview) _openChat(preview.chatId);
          return;
        }
        final chat = await presenter.confirmJoin(preview, () => _join(preview));
        if (chat != null && chat != 0) _openChat(chat);
      case ProxyLinkTarget(:final proxy):
        await presenter?.offerProxy(proxy);
      case CommandLinkTarget(:final commandId):
        if (!_runCommand(commandId)) {
          presenter?.showNotice(LinkNotice.unsupported);
        }
      case MissingLinkTarget():
        presenter?.showNotice(LinkNotice.missing);
      case ForbiddenLinkTarget():
        presenter?.showNotice(LinkNotice.forbidden);
      case UnsupportedLinkTarget(:final webFallback):
        if (webFallback != null) {
          await _launch(webFallback);
        } else {
          presenter?.showNotice(LinkNotice.unsupported);
        }
    }
  }

  /// Searches messages for [hashtag], with its `#` or `$`.
  void searchHashtag(String hashtag) {
    ++_generation;
    // The search takes a leading "#" as the switch to messages, so the
    // hashtag keeps its own after it: "##news" finds "#news".
    _search?.call('#$hashtag');
  }

  /// Sends bot [command] to [chatId], where it was tapped in a message
  /// from [senderUserId]. In a group a bare command gets the bot's
  /// username, so it reaches the bot that offered it and only that one.
  Future<void> sendBotCommand(
    String command, {
    required int chatId,
    int? senderUserId,
  }) async {
    final generation = ++_generation;
    final chats = _commandChats;
    if (chats == null) return;
    if (!chats.canSendCommand(chatId)) {
      presenter?.showNotice(LinkNotice.cannotSend);
      return;
    }
    var text = command;
    if (!command.contains('@') &&
        senderUserId != null &&
        chats.isGroup(chatId)) {
      final bot = await chats.botUsername(senderUserId);
      if (generation != _generation) return;
      if (bot != null && bot.isNotEmpty) text = '$command@$bot';
    }
    try {
      await chats.send(chatId, text);
    } on Object {
      presenter?.showNotice(LinkNotice.cannotSend);
    }
  }
}

/// Opens [uri] in the system's handler for it: the browser, Mail, a phone
/// app. Returns false when nothing could open it.
Future<bool> launchExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}

/// The window's workspace, for links that open its search: set as the
/// key of the [WorkspaceShell].
final workspaceShellKey = GlobalKey<WorkspaceShellState>();

/// The window's link router.
final linkRouterProvider = Provider<LinkRouter>((ref) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final workspace = ref.watch(workspaceControllerProvider);
  final commands = ref.watch(commandRegistryProvider);
  return LinkRouter(
    resolve: session.links.resolve,
    join: session.links.join,
    // An open chat is revealed where it is instead of being opened again.
    openChat: workspace.open,
    // The chat's view takes the jump as it opens, or now if it is open.
    // A jump the view never takes expires, see [MessageJumps.take].
    openMessage: (chatId, messageId) {
      final jumps = ref.read(messageJumpProvider.notifier)
        ..request(chatId, messageId);
      try {
        workspace.open(chatId);
      } on Object {
        jumps.take(chatId);
        rethrow;
      }
    },
    runCommand: commands.run,
    launch: launchExternal,
    search: (query) => workspaceShellKey.currentState?.openPalette(query),
    commandChats: _SessionCommandChats(session),
  );
});

final class _SessionCommandChats implements CommandChats {
  _SessionCommandChats(this._session);

  final TelegramSession _session;

  ConversationStore get _store => _session.conversations.store;

  @override
  bool canSendCommand(int chatId) =>
      !_store.isChannel(chatId) && _store.canPost(chatId);

  @override
  bool isGroup(int chatId) => _store.isGroup(chatId);

  @override
  Future<String?> botUsername(int userId) => _session.links.botUsername(userId);

  @override
  Future<void> send(int chatId, String text) =>
      _session.conversations.sendText(chatId, text);
}

LinkRouter? _routerOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(
      context,
      listen: false,
    ).read(linkRouterProvider);
  } on Object {
    // No session or no provider scope, as in widget previews.
    return null;
  }
}

/// Searches messages for a hashtag tapped in [context].
void searchHashtagFrom(BuildContext context, String hashtag) =>
    _routerOf(context)?.searchHashtag(hashtag);

/// Sends a bot command tapped in a message of [chatId] from
/// [senderUserId].
void sendBotCommandFrom(
  BuildContext context,
  String command, {
  required int chatId,
  int? senderUserId,
}) {
  final router = _routerOf(context);
  if (router == null) return;
  unawaited(
    router.sendBotCommand(command, chatId: chatId, senderUserId: senderUserId),
  );
}

/// Opens a link tapped in [context], such as a link or a mention in a
/// message. Outside a signed-in window it falls back to the browser.
void openLinkFrom(BuildContext context, String url) {
  final router = _routerOf(context);
  if (router != null) {
    unawaited(router.open(url));
    return;
  }
  final uri = TelegramLinks.normalize(url);
  if (uri != null && TelegramLinks.isExternal(uri)) {
    unawaited(launchExternal(uri));
  }
}
