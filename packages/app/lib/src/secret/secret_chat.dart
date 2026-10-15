import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_shell/mollygram_shell.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../home/workspace.dart';
import '../privacy/privacy_settings.dart';
import '../session/providers.dart';

// Secret chats in the app. Other parts show them through what is exported
// here: [secretChatProvider] for the state, [SecretChatLock] next to the
// title, [secretChatStatusText] as a status line, [SecretChatClosedBar]
// in place of the composer, and the sheets.

SecretChatsController _controller(Ref ref) =>
    ref.watch(telegramSessionProvider).requireValue.secretChats;

/// The secret chat in a chat, following its state; null when the chat is
/// not a secret chat.
final secretChatProvider = StreamProvider.autoDispose
    .family<SecretChatInfo?, int>((ref, chatId) async* {
      if (SecretChatsController.secretChatIdOf(chatId) == null) {
        yield null;
        return;
      }
      final secrets = _controller(ref);
      yield await secrets.load(chatId).catchError((Object _) => null);
      await for (final changed in secrets.changes) {
        if (changed == chatId) yield secrets.forChat(chatId);
      }
    });

/// The self-destruct time of new messages in a secret chat, in seconds.
final selfDestructTimeProvider = StreamProvider.autoDispose.family<int, int>((
  ref,
  chatId,
) async* {
  final secrets = _controller(ref);
  yield secrets.selfDestructTime(chatId);
  await for (final changed in secrets.changes) {
    if (changed == chatId) yield secrets.selfDestructTime(chatId);
  }
});

/// "Waiting for Anna to come online" or "Secret chat closed"; null while
/// the chat works normally.
String? secretChatStatusText(
  SecretChatInfo chat,
  String name,
  AppLocalizations l10n,
) => switch (chat.status) {
  SecretChatStatus.pending when chat.isOutbound => l10n.secretChatWaiting(name),
  SecretChatStatus.pending => l10n.secretChatExchangingKeys,
  SecretChatStatus.ready => null,
  SecretChatStatus.closed => l10n.secretChatClosed,
};

/// "Off", "5 s", "1 h"… for a self-destruct time in seconds.
String selfDestructLabel(int seconds, AppLocalizations l10n) {
  if (seconds == 0) return l10n.selfDestructOff;
  if (seconds < 60) return l10n.selfDestructSeconds(seconds);
  if (seconds < 3600) return l10n.selfDestructMinutes(seconds ~/ 60);
  if (seconds < 86400) return l10n.selfDestructHours(seconds ~/ 3600);
  if (seconds < 604800) return l10n.selfDestructDays(seconds ~/ 86400);
  return l10n.selfDestructWeeks(seconds ~/ 604800);
}

/// The lock drawn before a secret chat's title.
class SecretChatLock extends StatelessWidget {
  const SecretChatLock({super.key, this.size = 13});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context).secretChat,
    child: MgIcon(MgIcons.lock, size: size, color: MgColors.of(context).accent),
  );
}

/// In place of the composer once a secret chat is closed: nothing can be
/// sent any more, only the chat deleted.
class SecretChatClosedBar extends ConsumerWidget {
  const SecretChatClosedBar({super.key, required this.chatId});

  final int chatId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final secrets = ref.read(telegramSessionProvider).requireValue.secretChats;
    final confirmed = await showMgConfirm(
      context,
      title: l10n.deleteSecretChatTitle,
      confirmLabel: l10n.menuDelete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (confirmed == null) return;
    await secrets.delete(chatId).catchError((Object _) {});
    ref.read(workspaceControllerProvider).removeChat(chatId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(secretChatProvider(chatId)).value;
    if (chat?.status != SecretChatStatus.closed) return const SizedBox.shrink();
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SecretChatLock(),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.secretChatClosed,
              style: mgTextStyle(c, color: c.fg2),
            ),
          ),
          MgTextButton(
            key: const ValueKey('deleteSecretChat'),
            label: l10n.deleteChat,
            onPressed: () => unawaited(_delete(context, ref)),
          ),
        ],
      ),
    );
  }
}

/// Asks for the self-destruct time of new messages in [chatId].
Future<void> showSelfDestructPicker(BuildContext context, int chatId) async {
  final l10n = AppLocalizations.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  const times = SecretChatsController.selfDestructTimes;
  final picked = await showMgChoice(
    context,
    title: l10n.selfDestructTitle,
    options: [for (final t in times) selfDestructLabel(t, l10n)],
    cancelLabel: l10n.cancel,
  );
  if (picked == null) return;
  final secrets = container.read(telegramSessionProvider).requireValue;
  await secrets.secretChats
      .setSelfDestructTime(chatId, times[picked])
      .catchError((Object _) {});
}

/// The encryption key of [chatId]: the picture and hex both people
/// compare to know nobody is in between.
Future<void> showSecretKeySheet(
  BuildContext context, {
  required int chatId,
  required String name,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
  barrierColor: const Color(0x00000000),
  transitionDuration: const Duration(milliseconds: 180),
  transitionBuilder: (context, animation, _, child) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.96, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
  pageBuilder: (context, _, _) => Material(
    type: MaterialType.transparency,
    child: Center(
      child: SecretKeySheet(chatId: chatId, name: name),
    ),
  ),
);

class SecretKeySheet extends ConsumerWidget {
  const SecretKeySheet({super.key, required this.chatId, required this.name});

  final int chatId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final chat = ref.watch(secretChatProvider(chatId)).value;
    final hash = chat?.keyHash;
    final ready = hash != null && SecretKeyImage.pixels(hash).isNotEmpty;
    void close() => Navigator.of(context).pop();
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): close,
        const SingleActivator(LogicalKeyboardKey.enter): close,
      },
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 340,
          child: Glass(
            radius: 14,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.encryptionKey,
                  textAlign: TextAlign.center,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                if (ready) ...[
                  Center(child: SecretKeyPicture(keyHash: hash, size: 168)),
                  const SizedBox(height: 16),
                  _HexGrid(hex: SecretKeyImage.hex(hash)),
                  const SizedBox(height: 14),
                  Text(
                    l10n.encryptionKeyHint(name),
                    textAlign: TextAlign.center,
                    style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                  ),
                ] else
                  Text(
                    l10n.encryptionKeyPending,
                    textAlign: TextAlign.center,
                    style: mgTextStyle(c, color: c.fg2),
                  ),
                const SizedBox(height: 14),
                MgPrimaryButton(
                  label: l10n.done,
                  expand: true,
                  onPressed: close,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The key picture: [SecretKeyImage.size]² squares in four colours.
class SecretKeyPicture extends StatelessWidget {
  const SecretKeyPicture({super.key, required this.keyHash, this.size = 120});

  final List<int> keyHash;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(6),
    child: CustomPaint(
      size: Size.square(size),
      painter: _KeyPainter(SecretKeyImage.pixels(Uint8List.fromList(keyHash))),
    ),
  );
}

class _KeyPainter extends CustomPainter {
  _KeyPainter(this.pixels);

  final List<int> pixels;

  @override
  void paint(Canvas canvas, Size size) {
    const n = SecretKeyImage.size;
    final side = size.width / n;
    final paints = [
      for (final color in SecretKeyImage.colors) Paint()..color = Color(color),
    ];
    for (var i = 0; i < pixels.length; i++) {
      final rect = Rect.fromLTWH(
        (i % n) * side,
        (i ~/ n) * side,
        side + 0.5,
        side + 0.5,
      );
      canvas.drawRect(rect, paints[pixels[i]]);
    }
  }

  @override
  bool shouldRepaint(_KeyPainter old) => old.pixels != pixels;
}

/// 32 hex pairs in four rows of eight, in a fixed-width face.
class _HexGrid extends StatelessWidget {
  const _HexGrid({required this.hex});

  final List<String> hex;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(
      c,
      size: MgType.caption,
      color: c.fg2,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      children: [
        for (var row = 0; row * 8 < hex.length; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
              hex.skip(row * 8).take(8).join('  '),
              textAlign: TextAlign.center,
              style: style.copyWith(fontFamily: 'Menlo', letterSpacing: 0.4),
            ),
          ),
      ],
    );
  }
}

/// Palette commands for the focused chat when it is a secret chat:
/// encryption key, self-destruct timer, close.
List<PaletteCommand> secretChatCommands(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  final chatId = ref.read(workspaceControllerProvider).value.focusedChat;
  if (chatId == null) return const [];
  final session = ref.read(telegramSessionProvider).value;
  final chat = session?.secretChats.forChat(chatId);
  if (session == null || chat == null) return const [];
  final name = session.chatLists.store.chat(chatId)?.title ?? '';
  return [
    PaletteCommand(
      id: 'secret.encryptionKey',
      title: l10n.encryptionKey,
      run: () =>
          unawaited(showSecretKeySheet(context, chatId: chatId, name: name)),
    ),
    if (chat.status != SecretChatStatus.closed) ...[
      PaletteCommand(
        id: 'secret.selfDestruct',
        title: l10n.selfDestructTitle,
        run: () => unawaited(showSelfDestructPicker(context, chatId)),
      ),
      PaletteCommand(
        id: 'secret.close',
        title: l10n.closeSecretChat,
        run: () => unawaited(
          session.secretChats.close(chatId).catchError((Object _) {}),
        ),
      ),
    ],
  ];
}

const _window = MethodChannel('mollygram/window');

/// Keeps the window out of screenshots and screen recordings while a
/// secret chat is focused, unless the user allowed it in Privacy extras.
/// macOS only for now; elsewhere the call does nothing.
class SecretScreenProtection extends ConsumerStatefulWidget {
  const SecretScreenProtection({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecretScreenProtection> createState() =>
      _SecretScreenProtectionState();
}

class _SecretScreenProtectionState
    extends ConsumerState<SecretScreenProtection> {
  late final WorkspaceController _workspace = ref.read(
    workspaceControllerProvider,
  );
  var _protected = false;

  @override
  void initState() {
    super.initState();
    _workspace.addListener(_update);
    ref.listenManual(privacySettingsProvider, (_, _) => _update());
    _update();
  }

  @override
  void dispose() {
    _workspace.removeListener(_update);
    if (_protected) _set(false);
    super.dispose();
  }

  void _update() {
    final focused = _workspace.value.focusedChat;
    final allowed = ref.read(privacySettingsProvider).allowSecretScreenshots;
    final protect =
        !allowed &&
        focused != null &&
        SecretChatsController.secretChatIdOf(focused) != null;
    if (protect != _protected) _set(protect);
  }

  void _set(bool protect) {
    _protected = protect;
    _window
        .invokeMethod<void>('setContentProtection', protect)
        .catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The info panel's row for a person: "Encryption key" in their secret
/// chat, "Start secret chat" anywhere else.
String secretChatActionLabel(int chatId, AppLocalizations l10n) =>
    SecretChatsController.secretChatIdOf(chatId) == null
    ? l10n.startSecretChat
    : l10n.encryptionKey;

/// What [secretChatActionLabel]'s row does: shows the key, or starts a
/// secret chat with [userId] and opens it.
Future<void> runSecretChatAction(
  BuildContext context, {
  required int chatId,
  required int userId,
  required String name,
}) async {
  if (SecretChatsController.secretChatIdOf(chatId) != null) {
    return showSecretKeySheet(context, chatId: chatId, name: name);
  }
  final container = ProviderScope.containerOf(context, listen: false);
  final session = container.read(telegramSessionProvider).requireValue;
  final int created;
  try {
    created = await session.secretChats.create(userId);
  } on Object {
    return;
  }
  container.read(workspaceControllerProvider).open(created);
}
