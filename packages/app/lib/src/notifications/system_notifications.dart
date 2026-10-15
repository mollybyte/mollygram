import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the system lets the app show notifications.
enum NotificationPermission { authorized, denied, notDetermined }

/// A notification as the system shows it.
final class SystemNotification {
  const SystemNotification({
    required this.id,
    required this.chatId,
    required this.messageId,
    required this.title,
    required this.body,
    this.subtitle = '',
    this.thread = '',
    this.sound = false,
    this.quiet = false,
    this.canReply = false,
    this.photoPath,
    this.monogram = '',
  });

  final String id;
  final int chatId;
  final int messageId;
  final String title;
  final String subtitle;
  final String body;

  /// Notifications with the same thread are stacked together.
  final String thread;
  final bool sound;

  /// Replaces a shown notification without a new banner.
  final bool quiet;
  final bool canReply;
  final String? photoPath;

  /// Drawn on a gray circle when there is no photo.
  final String monogram;
}

/// Labels of the notification buttons, in the app's language.
final class NotificationLabels {
  const NotificationLabels({
    required this.reply,
    required this.send,
    required this.placeholder,
    required this.markRead,
  });

  final String reply;
  final String send;
  final String placeholder;
  final String markRead;
}

/// What the user did with a notification.
sealed class NotificationResponse {
  const NotificationResponse(this.chatId, this.messageId);

  final int chatId;
  final int messageId;
}

final class NotificationOpened extends NotificationResponse {
  const NotificationOpened(super.chatId, super.messageId);
}

final class NotificationReplied extends NotificationResponse {
  const NotificationReplied(super.chatId, super.messageId, this.text);

  final String text;
}

final class NotificationMarkedRead extends NotificationResponse {
  const NotificationMarkedRead(super.chatId, super.messageId);
}

/// The system's notification center and the dock badge.
abstract interface class SystemNotifications {
  /// Registers the buttons and starts delivering [responses]; responses
  /// that came before, such as the tap that launched the app, follow.
  Future<void> configure(NotificationLabels labels);

  Stream<NotificationResponse> get responses;

  Future<NotificationPermission> permission();

  /// Asks once; later calls return the user's answer.
  Future<bool> requestPermission();

  /// Shows [notification], replacing one with the same id.
  Future<void> show(SystemNotification notification);

  Future<void> remove(List<String> ids);

  /// Removes every shown notification whose id is not in [ids].
  Future<void> retain(Set<String> ids);

  Future<void> removeAll();

  /// The number on the dock icon; null or empty hides it.
  Future<void> setBadge(String? label);
}

final systemNotificationsProvider = Provider<SystemNotifications>(
  (ref) => Platform.isMacOS
      ? MacosNotifications()
      : const UnsupportedSystemNotifications(),
);

/// UNUserNotificationCenter and the dock tile, through
/// `macos/Runner/NotificationsChannel.swift`.
final class MacosNotifications implements SystemNotifications {
  MacosNotifications({
    this._channel = const MethodChannel('mollygram/notifications'),
  }) {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  final _responses = StreamController<NotificationResponse>.broadcast();

  @override
  Stream<NotificationResponse> get responses => _responses.stream;

  Future<void> _onCall(MethodCall call) async {
    final args = Map<Object?, Object?>.from(call.arguments as Map? ?? {});
    final chatId = args['chatId'];
    final messageId = args['messageId'];
    if (chatId is! int || messageId is! int) return;
    final response = switch (call.method) {
      'open' => NotificationOpened(chatId, messageId),
      'reply' => NotificationReplied(
        chatId,
        messageId,
        args['text'] as String? ?? '',
      ),
      'markRead' => NotificationMarkedRead(chatId, messageId),
      _ => null,
    };
    if (response != null) _responses.add(response);
  }

  @override
  Future<void> configure(NotificationLabels labels) =>
      _channel.invokeMethod('configure', {
        'reply': labels.reply,
        'send': labels.send,
        'placeholder': labels.placeholder,
        'markRead': labels.markRead,
      });

  @override
  Future<NotificationPermission> permission() async =>
      switch (await _channel.invokeMethod<String>('status')) {
        'denied' => NotificationPermission.denied,
        'notDetermined' => NotificationPermission.notDetermined,
        _ => NotificationPermission.authorized,
      };

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestAuthorization') ?? false;

  @override
  Future<void> show(SystemNotification n) => _channel.invokeMethod('show', {
    'id': n.id,
    'title': n.title,
    'subtitle': n.subtitle,
    'body': n.body,
    'thread': n.thread,
    'sound': n.sound,
    'quiet': n.quiet,
    'canReply': n.canReply,
    'photoPath': ?n.photoPath,
    'monogram': n.monogram,
    'payload': {'chatId': n.chatId, 'messageId': n.messageId},
  });

  @override
  Future<void> remove(List<String> ids) =>
      _channel.invokeMethod('remove', {'ids': ids});

  @override
  Future<void> retain(Set<String> ids) =>
      _channel.invokeMethod('retain', {'ids': ids.toList()});

  @override
  Future<void> removeAll() => _channel.invokeMethod('removeAll');

  @override
  Future<void> setBadge(String? label) =>
      _channel.invokeMethod('setBadge', {'label': label});
}

/// Windows and Linux until their notifications are written: nothing shows.
final class UnsupportedSystemNotifications implements SystemNotifications {
  const UnsupportedSystemNotifications();

  @override
  Future<void> configure(NotificationLabels labels) async {}

  @override
  Stream<NotificationResponse> get responses => const Stream.empty();

  @override
  Future<NotificationPermission> permission() async =>
      NotificationPermission.denied;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show(SystemNotification notification) async {}

  @override
  Future<void> remove(List<String> ids) async {}

  @override
  Future<void> retain(Set<String> ids) async {}

  @override
  Future<void> removeAll() async {}

  @override
  Future<void> setBadge(String? label) async {}
}
