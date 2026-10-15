import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:path_provider/path_provider.dart';

import '../session/providers.dart';

/// Where the privacy extras are kept between launches.
abstract interface class PrivacySettingsStorage {
  /// The saved settings as decoded JSON, or null when there are none.
  Future<Object?> read();

  Future<void> write(Object? json);
}

final privacySettingsStorageProvider = Provider<PrivacySettingsStorage>(
  (ref) => FilePrivacySettingsStorage(),
);

/// `privacy.json` in the application-support directory.
final class FilePrivacySettingsStorage implements PrivacySettingsStorage {
  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}privacy.json');
  }

  @override
  Future<Object?> read() async {
    try {
      return jsonDecode(await (await _file()).readAsString());
    } on Object {
      // Missing or broken: every switch off.
      return null;
    }
  }

  @override
  Future<void> write(Object? json) async {
    final file = await _file();
    // Written next to the file and renamed, so a crash mid-write never
    // leaves half a file behind.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }
}

/// A [PrivacySettingsStorage] in memory, for tests.
final class MemoryPrivacySettingsStorage implements PrivacySettingsStorage {
  MemoryPrivacySettingsStorage([this.saved]);

  Object? saved;

  @override
  Future<Object?> read() async => saved;

  @override
  Future<void> write(Object? json) async => saved = json;
}

final privacySettingsProvider =
    NotifierProvider<PrivacySettingsNotifier, PrivacySettings>(
      PrivacySettingsNotifier.new,
    );

/// The privacy extras: every switch off until the saved ones are read,
/// then every change goes to the running session and to disk.
///
/// The session waits for [loaded] before it starts, so nothing reaches
/// TDLib under the wrong settings.
class PrivacySettingsNotifier extends Notifier<PrivacySettings> {
  var _changed = false;
  Future<void> _saving = Future.value();
  late Future<void> _loaded;

  /// Completes once the saved settings are in [state].
  Future<void> get loaded => _loaded;

  @override
  PrivacySettings build() {
    _loaded = _load();
    return const PrivacySettings();
  }

  Future<void> _load() async {
    Object? saved;
    try {
      saved = await ref.read(privacySettingsStorageProvider).read();
    } on Object {
      saved = null;
    }
    // A switch flipped before the file was read wins.
    if (!_changed && ref.mounted) state = PrivacySettings.fromJson(saved);
  }

  void update(PrivacySettings Function(PrivacySettings) change) {
    final next = change(state);
    if (next == state) return;
    _changed = true;
    state = next;
    ref.read(telegramSessionProvider).value?.privacy.settings = next;
    final storage = ref.read(privacySettingsStorageProvider);
    final json = next.toJson();
    _saving = _saving
        .then((_) => storage.write(json))
        .catchError((Object _) {});
  }

  void setGhost(bool on) => update((s) => s.withGhost(on));

  /// Reads [chatId] without marking it as read, or stops doing so.
  void setSilentRead(int chatId, bool silent) =>
      update((s) => s.withSilentRead(chatId, silent));
}
