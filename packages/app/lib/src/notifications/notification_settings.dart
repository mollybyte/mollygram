import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The app's own notification switches, as in the official client's
/// Notifications and Sounds. Per-chat mute lives in TDLib.
@immutable
final class NotificationSettings {
  const NotificationSettings({
    this.enabled = true,
    this.showPreview = true,
    this.sound = true,
    this.badge = true,
    this.badgeIncludesMuted = false,
    this.badgeCountsMessages = false,
  });

  factory NotificationSettings.fromJson(Object? json) {
    if (json is! Map) return const NotificationSettings();
    bool read(String key, bool fallback) => switch (json[key]) {
      final bool value => value,
      _ => fallback,
    };
    const d = NotificationSettings();
    return NotificationSettings(
      enabled: read('enabled', d.enabled),
      showPreview: read('showPreview', d.showPreview),
      sound: read('sound', d.sound),
      badge: read('badge', d.badge),
      badgeIncludesMuted: read('badgeIncludesMuted', d.badgeIncludesMuted),
      badgeCountsMessages: read('badgeCountsMessages', d.badgeCountsMessages),
    );
  }

  /// Show banners at all.
  final bool enabled;

  /// Show the message text; off leaves only who wrote.
  final bool showPreview;
  final bool sound;

  /// The unread number on the dock icon.
  final bool badge;
  final bool badgeIncludesMuted;

  /// Count unread messages rather than unread chats.
  final bool badgeCountsMessages;

  NotificationSettings copyWith({
    bool? enabled,
    bool? showPreview,
    bool? sound,
    bool? badge,
    bool? badgeIncludesMuted,
    bool? badgeCountsMessages,
  }) => NotificationSettings(
    enabled: enabled ?? this.enabled,
    showPreview: showPreview ?? this.showPreview,
    sound: sound ?? this.sound,
    badge: badge ?? this.badge,
    badgeIncludesMuted: badgeIncludesMuted ?? this.badgeIncludesMuted,
    badgeCountsMessages: badgeCountsMessages ?? this.badgeCountsMessages,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'showPreview': showPreview,
    'sound': sound,
    'badge': badge,
    'badgeIncludesMuted': badgeIncludesMuted,
    'badgeCountsMessages': badgeCountsMessages,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationSettings &&
      other.enabled == enabled &&
      other.showPreview == showPreview &&
      other.sound == sound &&
      other.badge == badge &&
      other.badgeIncludesMuted == badgeIncludesMuted &&
      other.badgeCountsMessages == badgeCountsMessages;

  @override
  int get hashCode => Object.hash(
    enabled,
    showPreview,
    sound,
    badge,
    badgeIncludesMuted,
    badgeCountsMessages,
  );
}

/// Where [NotificationSettings] are kept between launches.
abstract interface class NotificationSettingsStorage {
  Future<Object?> read();
  Future<void> write(Object? json);
}

final notificationSettingsStorageProvider =
    Provider<NotificationSettingsStorage>(
      (ref) => FileNotificationSettingsStorage(),
    );

/// `notifications.json` in the application-support directory.
final class FileNotificationSettingsStorage
    implements NotificationSettingsStorage {
  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}notifications.json');
  }

  @override
  Future<Object?> read() async {
    try {
      return jsonDecode(await (await _file()).readAsString());
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(Object? json) async {
    final file = await _file();
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }
}

/// A [NotificationSettingsStorage] in memory, for tests.
final class MemoryNotificationSettingsStorage
    implements NotificationSettingsStorage {
  MemoryNotificationSettingsStorage([this.saved]);

  Object? saved;

  @override
  Future<Object?> read() async => saved;

  @override
  Future<void> write(Object? json) async => saved = json;
}

final notificationSettingsProvider =
    NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      NotificationSettingsNotifier.new,
    );

/// The current settings: defaults until the saved ones are read, then
/// every change is saved.
class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  var _changed = false;
  Future<void> _saving = Future.value();

  @override
  NotificationSettings build() {
    unawaited(_load());
    return const NotificationSettings();
  }

  Future<void> _load() async {
    final saved = await ref.read(notificationSettingsStorageProvider).read();
    // A switch flipped before the file was read wins.
    if (!_changed && ref.mounted) {
      state = NotificationSettings.fromJson(saved);
    }
  }

  void update(NotificationSettings Function(NotificationSettings) change) {
    final next = change(state);
    if (next == state) return;
    _changed = true;
    state = next;
    final storage = ref.read(notificationSettingsStorageProvider);
    final json = next.toJson();
    _saving = _saving
        .then((_) => storage.write(json))
        .catchError((Object _) {});
  }
}
