import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart' show monogramOf;

import '../../l10n/app_localizations.dart';
import '../home/format.dart';
import '../home/workspace.dart';
import '../session/providers.dart';
import '../settings/privacy/passcode.dart';
import 'notification_settings.dart';
import 'system_notifications.dart';

/// Shows TDLib's message notifications in the system notification center,
/// answers their buttons and keeps the dock badge current. It lives while
/// the account is signed in (see [NotificationsHost]); signing out takes
/// every notification and the badge away.
final class NotificationService {
  NotificationService({
    required this._controller,
    required this._system,
    required this._openChat,
    this._settings = const NotificationSettings(),
  });

  final NotificationController _controller;
  final SystemNotifications _system;
  final void Function(int chatId) _openChat;
  final _subscriptions = <StreamSubscription<Object?>>[];
  NotificationSettings _settings;
  AppLocalizations? _l10n;
  String? _badge;
  var _disposed = false;

  NotificationSettings get settings => _settings;

  /// Starts once the app's language is known; later calls only update
  /// the language of new notifications.
  Future<void> start(AppLocalizations l10n) async {
    final first = _l10n == null;
    _l10n = l10n;
    if (!first) return;
    _subscriptions
      ..add(_controller.events.listen(_onEvent))
      ..add(_controller.unreadChanges.listen((_) => _updateBadge()))
      ..add(_system.responses.listen(_onResponse));
    await _guard(
      _system.configure(
        NotificationLabels(
          reply: l10n.notificationReply,
          send: l10n.notificationSend,
          placeholder: l10n.notificationReplyPlaceholder,
          markRead: l10n.notificationMarkRead,
        ),
      ),
    );
    await _applyEnabled();
    await _updateBadge();
  }

  set settings(NotificationSettings next) {
    final previous = _settings;
    if (next == previous) return;
    _settings = next;
    if (_l10n == null) return;
    if (next.enabled != previous.enabled) unawaited(_applyEnabled());
    unawaited(_updateBadge());
  }

  Future<void> _applyEnabled() async {
    final enabled = _settings.enabled;
    if (enabled) {
      await _guard(_system.requestPermission());
    } else {
      await _guard(_system.removeAll());
    }
    if (_disposed) return;
    await _guard(_controller.setEnabled(enabled));
  }

  Future<void> _updateBadge() async {
    final counts = _controller.unreadCounts;
    final count = switch ((
      _settings.badgeCountsMessages,
      _settings.badgeIncludesMuted,
    )) {
      (false, false) => counts.unmutedChats,
      (false, true) => counts.chats,
      (true, false) => counts.unmutedMessages,
      (true, true) => counts.messages,
    };
    final label = _settings.badge && count > 0 ? '$count' : null;
    if (label == _badge || _disposed) return;
    _badge = label;
    await _guard(_system.setBadge(label));
  }

  void _onEvent(NotificationEvent event) {
    switch (event) {
      case NotificationPosted(:final notification):
        if (!_settings.enabled) return;
        if (_l10n case final l10n?) {
          unawaited(_guard(_system.show(present(notification, l10n))));
        }
      case NotificationsRemoved(:final keys):
        unawaited(_guard(_system.remove(keys)));
      case NotificationsSynced(:final keys):
        unawaited(_guard(_system.retain(keys)));
    }
  }

  void _onResponse(NotificationResponse response) {
    switch (response) {
      case NotificationOpened(:final chatId):
        _openChat(chatId);
      case NotificationReplied(:final chatId, :final messageId, :final text):
        unawaited(_guard(_controller.reply(chatId, messageId, text)));
      case NotificationMarkedRead(:final chatId, :final messageId):
        unawaited(_guard(_controller.markRead(chatId, messageId)));
    }
  }

  /// How [notification] reads in the notification center: the chat as the
  /// title, the author of a group message under it, then the text.
  SystemNotification present(
    MessageNotification notification,
    AppLocalizations l10n,
  ) {
    final preview = _settings.showPreview && notification.showPreview;
    return SystemNotification(
      id: notification.key,
      chatId: notification.chatId,
      messageId: notification.messageId,
      title: notification.chatTitle,
      subtitle: preview ? notification.senderName ?? '' : '',
      body: preview
          ? notificationBody(l10n, notification)
          : l10n.notificationHiddenText,
      thread: 'chat:${notification.chatId}',
      sound: _settings.sound && notification.playSound && !notification.isEdit,
      quiet: notification.isEdit,
      canReply: notification.canReply,
      photoPath: notification.photoPath,
      monogram: monogramOf(notification.chatTitle),
    );
  }

  /// Takes every notification and the badge away.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    if (_l10n == null) return;
    await _guard(_system.removeAll());
    await _guard(_system.setBadge(null));
  }

  /// A notification that can't be shown, or a reply TDLib refuses, is not
  /// worth an error dialog; the chat itself shows what happened.
  static Future<void> _guard(Future<Object?> operation) =>
      operation.then<void>((_) {}, onError: (Object _) {});
}

/// The message line: the text, or what kind of message it is, with the
/// caption when there is one.
String notificationBody(AppLocalizations l10n, MessageNotification n) {
  final label = kindLabel(l10n, n.kind);
  final text = n.text.trim();
  if (label.isEmpty) return text.isEmpty ? l10n.previewOther : text;
  if (n.kind == ChatPreviewKind.sticker && text.isNotEmpty) {
    return '$text $label';
  }
  return text.isEmpty ? label : '$label, $text';
}

/// The settings as notifications follow them: while the passcode lock is
/// on, or not yet known, no message text shows, as in TelegramSwift.
NotificationSettings notificationSettingsUnder(
  NotificationSettings settings,
  PasscodeState lock,
) => !lock.loaded || lock.locked
    ? settings.copyWith(showPreview: false)
    : settings;

NotificationSettings _effective(Ref ref) => notificationSettingsUnder(
  ref.read(notificationSettingsProvider),
  ref.read(passcodeLockProvider),
);

final notificationServiceProvider = Provider.autoDispose<NotificationService>((
  ref,
) {
  final session = ref.watch(telegramSessionProvider).requireValue;
  final service = NotificationService(
    controller: session.notifications,
    system: ref.watch(systemNotificationsProvider),
    openChat: (chatId) => ref.read(workspaceControllerProvider).open(chatId),
    settings: _effective(ref),
  );
  ref
    ..listen(
      notificationSettingsProvider,
      (_, _) => service.settings = _effective(ref),
    )
    ..listen(
      passcodeLockProvider.select((lock) => (lock.loaded, lock.locked)),
      (_, _) => service.settings = _effective(ref),
    );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Keeps notifications running while it is in the tree (the signed-in
/// window) and gives them the app's language.
class NotificationsHost extends ConsumerStatefulWidget {
  const NotificationsHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationsHost> createState() => _NotificationsHostState();
}

class _NotificationsHostState extends ConsumerState<NotificationsHost> {
  @override
  Widget build(BuildContext context) {
    // Starting again only passes a changed language on.
    final service = ref.watch(notificationServiceProvider);
    unawaited(service.start(AppLocalizations.of(context)));
    return widget.child;
  }
}
