import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import '../shared_media/message_jump.dart';
import '../shared_media/shared_media_view.dart';
import 'peer_info_panel.dart';
import 'peer_info_state.dart';

/// Puts the info panel of [chatId] at the right edge of [child], one chat
/// pane, when [peerInfoPanelsProvider] says it is open. A pane with room
/// for both is squeezed to make way, so the composer and the messages stay
/// in view, like TelegramSwift; a narrow one is covered.
///
/// The panel slides in and fades, and slides back out when closed by its
/// button or Escape; either move can be reversed halfway. Inside the panel
/// a click on a member shows their info, and "Shared media" the chat's
/// media, files and links, each with a back button to return.
class PeerInfoHost extends ConsumerStatefulWidget {
  const PeerInfoHost({super.key, required this.chatId, required this.child});

  final int chatId;
  final Widget child;

  /// The panel's width when the pane has room for it.
  static const double width = 340;

  /// The least a pane keeps for its chat when the panel squeezes it; a
  /// narrower pane is covered instead.
  static const double minChatWidth = 520;

  @override
  ConsumerState<PeerInfoHost> createState() => _PeerInfoHostState();
}

class _PeerInfoHostState extends ConsumerState<PeerInfoHost>
    with SingleTickerProviderStateMixin {
  late final _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final _curve = CurvedAnimation(
    parent: _slide,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// The chats shown in the panel, the pane's own first; members opened
  /// from a group's list go on top.
  late List<int> _stack = [widget.chatId];

  /// Whether the top of the stack shows its shared media over its info.
  var _media = false;

  late final _panels = ref.read(peerInfoPanelsProvider.notifier);

  @override
  void initState() {
    super.initState();
    _panels.attach(widget.chatId);
    if (_isOpen) _slide.value = 1;
    _slide.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _stack = [widget.chatId];
          _media = false;
        });
      }
    });
  }

  @override
  void didUpdateWidget(PeerInfoHost old) {
    super.didUpdateWidget(old);
    if (old.chatId != widget.chatId) {
      _panels
        ..detach(old.chatId)
        ..attach(widget.chatId);
      _stack = [widget.chatId];
      _media = false;
      _slide.value = _isOpen ? 1 : 0;
    }
  }

  @override
  void dispose() {
    final panels = _panels;
    final chatId = widget.chatId;
    // Providers can't change while the tree is being torn down.
    scheduleMicrotask(() => panels.detach(chatId));
    _curve.dispose();
    _slide.dispose();
    super.dispose();
  }

  bool get _isOpen => ref.read(peerInfoPanelsProvider).contains(widget.chatId);

  void _close() =>
      ref.read(peerInfoPanelsProvider.notifier).close(widget.chatId);

  Future<void> _openMember(int userId) async {
    final peers = ref.read(telegramSessionProvider).requireValue.peers;
    final int chatId;
    try {
      chatId = await peers.privateChatOf(userId);
    } on Object {
      return;
    }
    if (!mounted || !_isOpen) return;
    setState(() => _stack = [..._stack, chatId]);
  }

  void _back() => setState(() {
    if (_media) {
      _media = false;
    } else {
      _stack = _stack.sublist(0, _stack.length - 1);
    }
  });

  /// "Show in chat" from the shared media: the pane's own chat scrolls
  /// to the message with the panel left open, to go on browsing; a
  /// member's chat opens in this pane at it.
  void _showInChat(ConversationMessage message) {
    ref.read(messageJumpProvider.notifier).request(message.chatId, message.id);
    if (message.chatId != widget.chatId) _message(message.chatId);
  }

  /// "Message": the pane already shows its own chat, so the panel just
  /// gets out of the way; a member's chat opens in this pane.
  void _message(int chatId) {
    _close();
    if (chatId != widget.chatId) {
      ref.read(workspaceControllerProvider).open(chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(
      peerInfoPanelsProvider.select((open) => open.contains(widget.chatId)),
    );
    ref.listen(
      peerInfoPanelsProvider.select((open) => open.contains(widget.chatId)),
      (_, open) => unawaited(open ? _slide.forward() : _slide.reverse()),
    );
    final c = MgColors.of(context);
    return CallbackShortcuts(
      bindings: {
        if (open) const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < PeerInfoHost.width
              ? constraints.maxWidth
              : PeerInfoHost.width;
          final squeeze =
              constraints.maxWidth - width >= PeerInfoHost.minChatWidth;
          return ClipRect(
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    right: squeeze ? _curve.value * width : 0,
                    child: child!,
                  ),
                  child: widget.child,
                ),
                AnimatedBuilder(
                  animation: _curve,
                  builder: (context, panel) {
                    final t = _curve.value;
                    if (t == 0) return const SizedBox.shrink();
                    return Positioned(
                      top: 0,
                      bottom: 0,
                      right: -(1 - t) * width,
                      width: width,
                      child: Opacity(
                        opacity: (t * 1.6).clamp(0.0, 1.0),
                        child: panel,
                      ),
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.windowBackground,
                      border: Border(left: BorderSide(color: c.separator)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 24,
                          offset: Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: _media
                        ? PeerInfoPage(
                            key: ValueKey(('media', _stack.last)),
                            title: AppLocalizations.of(context).sharedMedia,
                            onBack: _back,
                            onClose: _close,
                            child: SharedMediaView(
                              chatId: _stack.last,
                              userId:
                                  ref
                                      .watch(peerInfoProvider(_stack.last))
                                      .value
                                      ?.userId ??
                                  0,
                              onOpenMessage: _showInChat,
                              onOpenChat: _message,
                            ),
                          )
                        : PeerInfoPanel(
                            key: ValueKey(_stack.last),
                            chatId: _stack.last,
                            onClose: _close,
                            onBack: _stack.length > 1 ? _back : null,
                            onMember: (userId) =>
                                unawaited(_openMember(userId)),
                            onMessage: () => _message(_stack.last),
                            onSharedMedia: () => setState(() => _media = true),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
