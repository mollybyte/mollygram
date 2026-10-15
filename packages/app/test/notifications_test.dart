import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/notifications/notification_service.dart';
import 'package:mollygram/src/notifications/notification_settings.dart';
import 'package:mollygram/src/notifications/notifications_page.dart';
import 'package:mollygram/src/notifications/system_notifications.dart';
import 'package:mollygram/src/settings/settings_style.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  MessageNotification message({
    String? sender = 'Ada',
    ChatPreviewKind kind = ChatPreviewKind.text,
    String text = 'See you at six',
    bool showPreview = true,
    bool playSound = true,
    bool isEdit = false,
  }) => MessageNotification(
    groupId: 1,
    id: 2,
    chatId: 10,
    messageId: 55,
    date: 0,
    chatTitle: 'Climbing club',
    senderName: sender,
    kind: kind,
    text: text,
    showPreview: showPreview,
    playSound: playSound,
    isEdit: isEdit,
  );

  group('NotificationService', () {
    late _FakeTdJson json;
    late td.Td tdlib;
    late NotificationController controller;
    late _FakeSystem system;
    late List<int> opened;
    late NotificationService service;

    setUp(() async {
      json = _FakeTdJson();
      tdlib = td.Td.custom(json, td.InlineTdEventSource(json));
      controller = NotificationController(tdlib.createClient());
      await controller.start();
      system = _FakeSystem();
      opened = [];
      service = NotificationService(
        controller: controller,
        system: system,
        openChat: opened.add,
      );
    });

    tearDown(() async {
      await service.dispose();
      await controller.dispose();
      await tdlib.close();
    });

    Future<void> settle() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await pumpEventQueue();
    }

    test('presents a group message with its author and text', () {
      final shown = service.present(message(), en);

      expect(shown.id, '1:2');
      expect(shown.title, 'Climbing club');
      expect(shown.subtitle, 'Ada');
      expect(shown.body, 'See you at six');
      expect(shown.thread, 'chat:10');
      expect(shown.sound, isTrue);
      expect(shown.monogram, 'CC');
    });

    test('hides the text when previews are off', () {
      service.settings = const NotificationSettings(showPreview: false);
      final shown = service.present(message(), en);

      expect(shown.title, 'Climbing club');
      expect(shown.subtitle, isEmpty);
      expect(shown.body, en.notificationHiddenText);
    });

    test('hides the text when the chat does', () {
      final shown = service.present(message(showPreview: false), en);
      expect(shown.body, en.notificationHiddenText);
    });

    test('names media and keeps edits quiet', () {
      expect(
        notificationBody(en, message(kind: ChatPreviewKind.photo, text: '')),
        en.previewPhoto,
      );
      expect(
        notificationBody(
          en,
          message(kind: ChatPreviewKind.photo, text: 'Summit'),
        ),
        '${en.previewPhoto}, Summit',
      );
      final edit = service.present(message(isEdit: true), en);
      expect(edit.quiet, isTrue);
      expect(edit.sound, isFalse);
    });

    test('starts TDLib notifications and asks for permission', () async {
      await service.start(en);

      expect(system.labels?.markRead, en.notificationMarkRead);
      expect(system.permissionRequests, 1);
      final count = json.sent.lastWhere(
        (r) => r['name'] == 'notification_group_count_max',
      );
      expect((count['value'] as Map)['value'], '25');
    });

    test('turning notifications off clears them', () async {
      await service.start(en);
      service.settings = const NotificationSettings(enabled: false);
      await settle();

      expect(system.removedAll, isTrue);
      final count = json.sent.lastWhere(
        (r) => r['name'] == 'notification_group_count_max',
      );
      expect((count['value'] as Map)['value'], '0');
    });

    test('keeps the dock badge on the chosen count', () async {
      await service.start(en);
      json.push({
        '@type': 'updateUnreadChatCount',
        'chat_list': {'@type': 'chatListMain'},
        'unread_count': 7,
        'unread_unmuted_count': 3,
      });
      json.push({
        '@type': 'updateUnreadMessageCount',
        'chat_list': {'@type': 'chatListMain'},
        'unread_count': 40,
        'unread_unmuted_count': 12,
      });
      await settle();
      expect(system.badge, '3');

      service.settings = const NotificationSettings(badgeIncludesMuted: true);
      await settle();
      expect(system.badge, '7');

      service.settings = const NotificationSettings(badgeCountsMessages: true);
      await settle();
      expect(system.badge, '12');

      service.settings = const NotificationSettings(badge: false);
      await settle();
      expect(system.badge, isNull);
    });

    test('opens the chat of a tapped notification', () async {
      await service.start(en);
      system.respond(const NotificationOpened(10, 55));
      await settle();

      expect(opened, [10]);
    });

    test('marks the chat read from the button', () async {
      await service.start(en);
      system.respond(const NotificationMarkedRead(10, 55));
      await settle();

      final read = json.sent.lastWhere((r) => r['@type'] == 'viewMessages');
      expect(read['chat_id'], 10);
      expect(read['message_ids'], [55]);
    });
  });

  group('NotificationsPage', () {
    Widget page(MemoryNotificationSettingsStorage storage) => ProviderScope(
      overrides: [
        notificationSettingsStorageProvider.overrideWithValue(storage),
        systemNotificationsProvider.overrideWithValue(_FakeSystem()),
      ],
      child: MaterialApp(
        theme: buildMgTheme(MgColors.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Material(child: NotificationsPage()),
      ),
    );

    testWidgets('a row toggles its setting and saves it', (tester) async {
      final storage = MemoryNotificationSettingsStorage();
      await tester.pumpWidget(page(storage));
      await tester.pumpAndSettle();

      expect(find.text(en.notificationsShow), findsOneWidget);
      await tester.tap(find.text(en.notificationsShow));
      await tester.pumpAndSettle();

      expect(NotificationSettings.fromJson(storage.saved).enabled, isFalse);
    });

    testWidgets('shows the saved settings', (tester) async {
      final storage = MemoryNotificationSettingsStorage(
        const NotificationSettings(sound: false).toJson(),
      );
      await tester.pumpWidget(page(storage));
      await tester.pumpAndSettle();

      bool toggled(String label) => tester
          .widget<SettingsSwitchRow>(
            find.widgetWithText(SettingsSwitchRow, label),
          )
          .value;
      expect(toggled(en.notificationsSound), isFalse);
      expect(toggled(en.notificationsShow), isTrue);
    });
  });
}

final class _FakeSystem implements SystemNotifications {
  final _responses = StreamController<NotificationResponse>.broadcast(
    sync: true,
  );
  NotificationLabels? labels;
  var permissionRequests = 0;
  var removedAll = false;
  String? badge;
  final shown = <SystemNotification>[];

  void respond(NotificationResponse response) => _responses.add(response);

  @override
  Future<void> configure(NotificationLabels labels) async =>
      this.labels = labels;

  @override
  Stream<NotificationResponse> get responses => _responses.stream;

  @override
  Future<NotificationPermission> permission() async =>
      NotificationPermission.authorized;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> show(SystemNotification notification) async =>
      shown.add(notification);

  @override
  Future<void> remove(List<String> ids) async {}

  @override
  Future<void> retain(Set<String> ids) async {}

  @override
  Future<void> removeAll() async => removedAll = true;

  @override
  Future<void> setBadge(String? label) async => badge = label;
}

final class _FakeTdJson implements td.TdJson {
  final _queue = Queue<String>();
  final sent = <Map<String, Object?>>[];
  var _nextClientId = 0;

  @override
  int createClientId() => ++_nextClientId;

  @override
  String? execute(String request) => null;

  @override
  String? receive(double timeout) =>
      _queue.isEmpty ? null : _queue.removeFirst();

  @override
  void send(int clientId, String request) {
    final decoded = jsonDecode(request) as Map<String, Object?>;
    sent.add(decoded);
    _queue.add(
      jsonEncode({
        '@type': 'ok',
        '@client_id': clientId,
        '@extra': decoded['@extra'],
      }),
    );
    if (decoded['@type'] == 'close') {
      push({
        '@type': 'updateAuthorizationState',
        'authorization_state': {'@type': 'authorizationStateClosed'},
      });
    }
  }

  void push(Map<String, Object?> update) =>
      _queue.add(jsonEncode({...update, '@client_id': 1}));
}
