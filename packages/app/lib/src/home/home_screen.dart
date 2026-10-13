import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../ui/theme.dart';
import '../ui/wallpaper.dart';
import '../ui/widgets.dart';
import 'chat_view.dart';
import 'sidebar.dart';

/// The signed-in window: wallpaper, the open chat and the floating sidebar.
///
/// One BackdropGroup covers the window so all glass panels share a single
/// backdrop read.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatId = ref.watch(selectedChatProvider);
    return BackdropGroup(
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          Positioned(
            top: 0,
            bottom: 0,
            left: 320,
            right: 0,
            child: chatId == null
                ? const _NoChat()
                : ChatView(key: ValueKey(chatId), chatId: chatId),
          ),
          const Positioned(
            top: 8,
            left: 8,
            bottom: 8,
            width: 304,
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
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Stack(
      children: [
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 52,
          child: WindowDragArea(),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x33000000),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              AppLocalizations.of(context).selectChat,
              style: mgText(c).copyWith(color: const Color(0xFFFFFFFF)),
            ),
          ),
        ),
      ],
    );
  }
}
