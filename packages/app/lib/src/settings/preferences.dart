import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The app's accent colors, calm ones only. Blue is the system default.
enum AccentChoice { blue, indigo, teal, green, orange, graphite }

/// Media kinds that can download on their own.
enum AutoDownloadKind { photos, videos, files }

/// Whether a kind of media downloads on its own, on Wi-Fi or Ethernet and
/// on other networks such as a phone hotspot.
final class AutoDownload {
  const AutoDownload({required this.wifi, required this.other});

  final bool wifi;
  final bool other;

  AutoDownload copyWith({bool? wifi, bool? other}) =>
      AutoDownload(wifi: wifi ?? this.wifi, other: other ?? this.other);

  Map<String, Object?> toJson() => {'wifi': wifi, 'other': other};

  static AutoDownload fromJson(Object? json, AutoDownload fallback) {
    if (json is! Map) return fallback;
    return AutoDownload(
      wifi: _bool(json['wifi']) ?? fallback.wifi,
      other: _bool(json['other']) ?? fallback.other,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AutoDownload && other.wifi == wifi && other.other == this.other;

  @override
  int get hashCode => Object.hash(wifi, other);
}

/// The user's choices from Appearance and Data and storage. They belong to
/// the app, not to an account, and survive signing out.
final class Preferences {
  const Preferences({
    this.theme = ThemeMode.system,
    this.accent = AccentChoice.blue,
    this.wallpaper = true,
    this.textSize = defaultTextSize,
    this.reduceMotion = false,
    this.autoDownload = defaultAutoDownload,
    this.downloadFolder,
    this.shortcuts = const {},
  });

  static const minTextSize = 12;
  static const maxTextSize = 17;
  static const defaultTextSize = 13;

  /// Photos download everywhere, videos on Wi-Fi, files when asked.
  static const defaultAutoDownload = {
    AutoDownloadKind.photos: AutoDownload(wifi: true, other: true),
    AutoDownloadKind.videos: AutoDownload(wifi: true, other: false),
    AutoDownloadKind.files: AutoDownload(wifi: false, other: false),
  };

  final ThemeMode theme;
  final AccentChoice accent;

  /// The gradient wallpaper behind the chats; off, a plain color.
  final bool wallpaper;

  /// Message text size in points, [minTextSize] to [maxTextSize].
  final int textSize;

  /// Turns animations off, as the macOS "Reduce motion" setting does.
  final bool reduceMotion;
  final Map<AutoDownloadKind, AutoDownload> autoDownload;

  /// Where saved files go; null for the system Downloads folder.
  final String? downloadFolder;

  /// Keyboard shortcuts the user changed, by action id: an encoded
  /// `ShortcutKey`, or null for an action they took the key from.
  final Map<String, String?> shortcuts;

  AutoDownload autoDownloadOf(AutoDownloadKind kind) =>
      autoDownload[kind] ?? defaultAutoDownload[kind]!;

  Preferences copyWith({
    ThemeMode? theme,
    AccentChoice? accent,
    bool? wallpaper,
    int? textSize,
    bool? reduceMotion,
    Map<AutoDownloadKind, AutoDownload>? autoDownload,
    String? downloadFolder,
    Map<String, String?>? shortcuts,
  }) => Preferences(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    wallpaper: wallpaper ?? this.wallpaper,
    textSize: (textSize ?? this.textSize).clamp(minTextSize, maxTextSize),
    reduceMotion: reduceMotion ?? this.reduceMotion,
    autoDownload: autoDownload ?? this.autoDownload,
    downloadFolder: downloadFolder ?? this.downloadFolder,
    shortcuts: shortcuts ?? this.shortcuts,
  );

  /// The same with [kind] changed.
  Preferences withAutoDownload(AutoDownloadKind kind, AutoDownload value) =>
      copyWith(autoDownload: {...autoDownload, kind: value});

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'accent': accent.name,
    'wallpaper': wallpaper,
    'textSize': textSize,
    'reduceMotion': reduceMotion,
    'autoDownload': {
      for (final kind in AutoDownloadKind.values)
        kind.name: autoDownloadOf(kind).toJson(),
    },
    'downloadFolder': ?downloadFolder,
    if (shortcuts.isNotEmpty) 'shortcuts': shortcuts,
  };

  /// Reads what [toJson] wrote. Anything missing or unknown, say from an
  /// older or newer version, falls back to the default.
  factory Preferences.fromJson(Object? json) {
    if (json is! Map) return const Preferences();
    const defaults = Preferences();
    final downloads = json['autoDownload'];
    final size = json['textSize'];
    final folder = json['downloadFolder'];
    final shortcuts = json['shortcuts'];
    return Preferences(
      theme: _byName(ThemeMode.values, json['theme']) ?? defaults.theme,
      accent: _byName(AccentChoice.values, json['accent']) ?? defaults.accent,
      wallpaper: _bool(json['wallpaper']) ?? defaults.wallpaper,
      textSize: size is int
          ? size.clamp(minTextSize, maxTextSize)
          : defaults.textSize,
      reduceMotion: _bool(json['reduceMotion']) ?? defaults.reduceMotion,
      autoDownload: {
        for (final kind in AutoDownloadKind.values)
          kind: AutoDownload.fromJson(
            downloads is Map ? downloads[kind.name] : null,
            defaultAutoDownload[kind]!,
          ),
      },
      downloadFolder: folder is String && folder.isNotEmpty ? folder : null,
      shortcuts: {
        if (shortcuts is Map)
          for (final MapEntry(:key, :value) in shortcuts.entries)
            if (key is String && (value == null || value is String))
              key: value as String?,
      },
    );
  }
}

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

bool? _bool(Object? value) => value is bool ? value : null;

/// Where [Preferences] are kept between launches.
abstract interface class PreferencesStorage {
  /// The saved JSON, or null when there is none or it can't be read.
  Future<Object?> read();

  Future<void> write(Object? json);
}

/// `preferences.json` in the app's support folder, shared by all accounts.
final class FilePreferencesStorage implements PreferencesStorage {
  Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}preferences.json');
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
    await file.parent.create(recursive: true);
    // Renamed into place, so a crash mid-write keeps the old file.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(json), flush: true);
    await temp.rename(file.path);
  }
}

/// A [PreferencesStorage] in memory, for tests.
final class MemoryPreferencesStorage implements PreferencesStorage {
  MemoryPreferencesStorage([this.saved]);

  Object? saved;
  var writes = 0;

  @override
  Future<Object?> read() async => saved;

  @override
  Future<void> write(Object? json) async {
    writes++;
    saved = json;
  }
}

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => FilePreferencesStorage(),
);

/// The preferences read before the first frame (see `main`), so the window
/// opens in the chosen theme instead of flashing the default one.
final initialPreferencesProvider = Provider<Preferences>(
  (ref) => const Preferences(),
);

/// Reads the saved preferences; the defaults when there are none.
Future<Preferences> loadPreferences(PreferencesStorage storage) async =>
    Preferences.fromJson(await storage.read());

final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(
  PreferencesNotifier.new,
);

/// The current preferences. A change applies at once and is written
/// [saveDelay] later, so dragging the text size slider writes once.
class PreferencesNotifier extends Notifier<Preferences> {
  static const saveDelay = Duration(milliseconds: 400);

  Timer? _save;

  /// The change waiting to be written.
  Preferences? _pending;

  // Kept from build: flush also runs as the provider is disposed, when ref
  // can't be read any more.
  late PreferencesStorage _storage;

  @override
  Preferences build() {
    _storage = ref.read(preferencesStorageProvider);
    ref.onDispose(flush);
    return ref.watch(initialPreferencesProvider);
  }

  void update(Preferences Function(Preferences current) change) {
    final next = change(state);
    if (identical(next, state)) return;
    state = next;
    _pending = next;
    _save?.cancel();
    _save = Timer(saveDelay, () => unawaited(flush()));
  }

  /// The chain of writes, so they land in order and [flush] can wait for
  /// one already under way.
  Future<void> _writes = Future.value();

  /// Writes a change that is still waiting, and completes once every
  /// earlier write has finished too. A failed write is dropped: the choice
  /// still applies until the app quits.
  Future<void> flush() {
    _save?.cancel();
    _save = null;
    final pending = _pending;
    if (pending == null) return _writes;
    _pending = null;
    return _writes = _writes.then((_) async {
      try {
        await _storage.write(pending.toJson());
      } on Object {
        // Nothing to tell the user; see above.
      }
    });
  }
}

/// Whether animations should be skipped: the user's "Reduce motion" here,
/// or the system's accessibility setting. Widgets can also read
/// `MediaQuery.disableAnimationsOf`, which the app sets from both.
final reduceMotionProvider = Provider<bool>(
  (ref) =>
      ref.watch(preferencesProvider.select((p) => p.reduceMotion)) ||
      PlatformDispatcher.instance.accessibilityFeatures.disableAnimations,
);

/// Whether [kind] may download on its own. Mollygram can't tell Wi-Fi from
/// a hotspot yet, so the Wi-Fi choice is the one that counts for now.
final autoDownloadProvider = Provider.family<bool, AutoDownloadKind>(
  (ref, kind) =>
      ref.watch(preferencesProvider.select((p) => p.autoDownloadOf(kind).wifi)),
);
