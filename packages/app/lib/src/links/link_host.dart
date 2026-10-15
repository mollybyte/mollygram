import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace.dart';
import '../proxy/proxy_editor.dart';
import 'join_sheet.dart';
import 'link_router.dart';

/// `tg://` URLs the system hands to the app, including the one it was
/// launched with. The scheme is registered in the macOS Info.plist; other
/// platforms get nothing yet.
final incomingLinksProvider = Provider<Stream<Uri>>((ref) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
    return const Stream.empty();
  }
  return AppLinks().uriLinkStream;
});

/// Gives the [LinkRouter] a window to show its sheets in and feeds it the
/// links other apps open. Wraps the signed-in window.
///
/// The system keeps a link that arrives before sign-in until this widget
/// listens, so it opens once the chats are there.
///
/// A group or channel opened with View in the join sheet gets a [JoinBar]
/// over its composer while it is the focused chat.
class LinkHost extends ConsumerStatefulWidget {
  const LinkHost({
    super.key,
    required this.child,
    this.contentLeft = 0,
    this.covered = false,
  });

  final Widget child;

  /// Where the chat panes start: the width of the sidebar.
  final double contentLeft;

  /// A screen covers the chats, so the join bar hides.
  final bool covered;

  @override
  ConsumerState<LinkHost> createState() => _LinkHostState();
}

class _LinkHostState extends ConsumerState<LinkHost> implements LinkPresenter {
  LinkRouter? _router;
  StreamSubscription<Uri>? _incoming;

  /// Chats being looked at before joining, with how to join each.
  final _previews =
      <int, (ChatJoinPreview, Future<JoinResult> Function() join)>{};

  @override
  void initState() {
    super.initState();
    _incoming = ref
        .read(incomingLinksProvider)
        .listen(
          (uri) => unawaited(_router?.open(uri.toString())),
          // A link the plugin could not read is dropped.
          onError: (Object _) {},
        );
  }

  @override
  void dispose() {
    unawaited(_incoming?.cancel());
    if (identical(_router?.presenter, this)) _router?.presenter = null;
    super.dispose();
  }

  @override
  Future<int?> confirmJoin(
    ChatJoinPreview preview,
    Future<JoinResult> Function() join,
  ) async {
    if (!mounted) return null;
    final result = await showJoinSheet(context, preview: preview, join: join);
    if (result == null || !mounted) return null;
    setState(() {
      if (result.joined) {
        _previews.remove(result.chatId);
      } else {
        _previews[result.chatId] = (preview, join);
      }
    });
    return result.chatId;
  }

  void _endPreview(int chatId) {
    if (mounted) setState(() => _previews.remove(chatId));
  }

  @override
  void showNotice(LinkNotice notice) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    unawaited(
      showLinkNoticeSheet(context, switch (notice) {
        LinkNotice.missing => l10n.linkMissing,
        LinkNotice.unsupported => l10n.linkUnsupported,
        LinkNotice.forbidden => l10n.linkForbidden,
      }),
    );
  }

  @override
  Future<void> offerProxy(ProxySettings proxy) async {
    if (!mounted) return;
    await showProxyEditor(context, initial: proxy, fromLink: true);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(linkRouterProvider);
    if (!identical(router, _router)) {
      if (identical(_router?.presenter, this)) _router?.presenter = null;
      _router = router..presenter = this;
    }
    final workspace = ref.watch(workspaceControllerProvider);
    // One shape whether or not a bar shows, so the window below keeps its
    // state when one appears.
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        if (_previews.isNotEmpty && !widget.covered)
          Positioned.fill(
            left: widget.contentLeft,
            child: ListenableBuilder(
              listenable: workspace,
              builder: (context, _) => _joinBar(workspace.value.activeTab),
            ),
          ),
      ],
    );
  }

  /// The join bar over the composer of the focused pane, when its chat is
  /// a preview.
  Widget _joinBar(WorkspaceTab tab) {
    final chat = tab.focusedChat;
    final entry = chat == null ? null : _previews[chat];
    if (chat == null || entry == null) return const SizedBox.shrink();
    final (preview, join) = entry;
    return LayoutBuilder(
      builder: (context, box) {
        var left = 0.0;
        var width = box.maxWidth;
        if (tab.isSplit) {
          // The same split as WorkspaceView draws.
          final usable = width - WorkspaceView.dividerHitWidth;
          final first = usable * tab.split;
          if (tab.focus == 0) {
            width = first;
          } else {
            left = first + WorkspaceView.dividerHitWidth;
            width = usable - first;
          }
        }
        return Stack(
          children: [
            // Over the composer, which sits 24 px in and 12 px up.
            Positioned(
              left: left + 24,
              width: (width - 48).clamp(0.0, double.infinity),
              bottom: 12,
              child: JoinBar(
                key: ValueKey(chat),
                preview: preview,
                join: join,
                onDone: () => _endPreview(chat),
              ),
            ),
          ],
        );
      },
    );
  }
}
