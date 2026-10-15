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
}

enum LinkNotice {
  /// The username, invite or message does not exist or is out of reach.
  missing,

  /// A `tg://` link to something the app cannot show yet.
  unsupported,

  /// A chat the user was banned from.
  forbidden,
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
    this._sendCommand,
  });

  final Future<LinkTarget?> Function(String raw) _resolve;
  final Future<JoinResult> Function(ChatJoinPreview preview) _join;
  final void Function(int chatId) _openChat;
  final bool Function(String commandId) _runCommand;
  final Future<bool> Function(Uri uri) _launch;
  final void Function(int chatId, int messageId)? _openMessage;

  /// Searches messages for a hashtag.
  final void Function(String hashtag)? _search;

  /// Sends a bot command to the chat it was tapped in; false when there
  /// is no such chat.
  final Future<bool> Function(String command)? _sendCommand;

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
      case HashtagLinkTarget(:final hashtag):
        _search?.call(hashtag);
      case BotCommandLinkTarget(:final command):
        await _sendCommand?.call(command);
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
    openMessage: (chatId, messageId) {
      ref.read(messageJumpProvider.notifier).request(chatId, messageId);
      workspace.open(chatId);
    },
    runCommand: commands.run,
    launch: launchExternal,
    // The ⌘K palette searches messages after a "#": "#news" finds the
    // messages with the hashtag, as Telegram's own hashtag search does.
    search: (hashtag) => workspaceShellKey.currentState?.openPalette(
      hashtag.startsWith('#') ? hashtag : '#$hashtag',
    ),
    // A click in a pane focuses it first, so the focused chat is the one
    // the command was tapped in.
    sendCommand: (command) async {
      final chatId = workspace.value.focusedChat;
      if (chatId == null) return false;
      try {
        await session.conversations.sendText(chatId, command);
      } on Object {
        return false;
      }
      return true;
    },
  );
});

/// Opens a link tapped in [context], such as a link or a mention in a
/// message. Outside a signed-in window it falls back to the browser.
void openLinkFrom(BuildContext context, String url) {
  LinkRouter? router;
  try {
    router = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(linkRouterProvider);
  } on Object {
    // No session or no provider scope, as in widget previews.
    router = null;
  }
  if (router != null) {
    unawaited(router.open(url));
    return;
  }
  final uri = TelegramLinks.normalize(url);
  if (uri != null && TelegramLinks.isExternal(uri)) {
    unawaited(launchExternal(uri));
  }
}
