import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';

import '../../l10n/app_localizations.dart';
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
class LinkHost extends ConsumerStatefulWidget {
  const LinkHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LinkHost> createState() => _LinkHostState();
}

class _LinkHostState extends ConsumerState<LinkHost> implements LinkPresenter {
  LinkRouter? _router;
  StreamSubscription<Uri>? _incoming;

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
    return showJoinSheet(context, preview: preview, join: join);
  }

  @override
  void showNotice(LinkNotice notice) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    unawaited(
      showLinkNoticeSheet(context, switch (notice) {
        LinkNotice.missing => l10n.linkMissing,
        LinkNotice.unsupported => l10n.linkUnsupported,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(linkRouterProvider);
    if (!identical(router, _router)) {
      if (identical(_router?.presenter, this)) _router?.presenter = null;
      _router = router..presenter = this;
    }
    return widget.child;
  }
}
