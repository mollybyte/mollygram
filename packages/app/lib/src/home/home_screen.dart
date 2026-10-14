import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../window_drag_area.dart';
import 'chat_view.dart';
import 'sidebar.dart';

/// The signed-in window: wallpaper, the open chat and the floating sidebar.
/// [GlassScope] gives all glass panels one shared backdrop read.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(selectedChatProvider);
    return GlassScope(
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          Positioned(
            top: 0,
            bottom: 0,
            left: SidebarIsland.width + 16,
            right: 0,
            child: chatId == null
                ? const _NoChat()
                : ChatView(key: ValueKey(chatId), chatId: chatId),
          ),
          const Positioned(
            top: 8,
            left: 8,
            bottom: 8,
            width: SidebarIsland.width,
            child: Sidebar(),
          ),
        ],
      ),
    );
  }
}

class _NoChat extends StatelessWidget {
  const _NoChat();

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: 52,
        child: WindowDragArea(),
      ),
      Center(child: DatePill(AppLocalizations.of(context).selectChat)),
    ],
  );
}
