import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../session/providers.dart';

/// Asks which chat to forward to. Completes with its id, or null when the
/// user closes the picker.
Future<int?> pickForwardTarget(BuildContext context) => showGeneralDialog<int>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: Duration.zero,
  pageBuilder: (context, _, _) => const Material(
    type: MaterialType.transparency,
    child: Center(child: _ForwardPicker()),
  ),
);

class _ForwardPicker extends ConsumerStatefulWidget {
  const _ForwardPicker();

  @override
  ConsumerState<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends ConsumerState<_ForwardPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final loaded = ref
        .watch(chatListProvider(const ChatListLocation.main()))
        .value;
    final chats = loaded ?? const <ChatListEntry>[];
    final query = _query.trim().toLowerCase();
    final matches = [
      for (final chat in chats)
        if (query.isEmpty || chat.title.toLowerCase().contains(query)) chat,
    ];
    return SizedBox(
      width: 360,
      height: 480,
      child: Glass(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                l10n.forwardTitle,
                style: mgTextStyle(c, weight: FontWeight.w600),
              ),
            ),
            Focus(
              autofocus: true,
              child: MgSearchField(
                hintText: l10n.forwardSearch,
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (_) {
                  if (matches.isNotEmpty) {
                    Navigator.of(context).pop(matches.first.id);
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: loaded == null
                  ? const SizedBox.shrink()
                  : matches.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noChatsFound,
                        style: mgTextStyle(c, color: c.fg2),
                      ),
                    )
                  : ListView.builder(
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final chat = matches[i];
                        return ChatListTile(
                          key: ValueKey(chat.id),
                          title: chat.title,
                          subtitle: formatPreview(l10n, chat.lastMessage),
                          onTap: () => Navigator.of(context).pop(chat.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
