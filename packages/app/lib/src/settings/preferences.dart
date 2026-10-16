import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart' show MediaDownloadKind;
import 'package:path_provider/path_provider.dart';

/// The app's accent colors, calm ones only. Violet is the Stage window's
/// own; blue is the system one.
enum AccentChoice { violet, blue, indigo, teal, green, orange, graphite }

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

/// The chat background: one of the gradient wallpapers, a plain color or
/// a picture of the user's own.
enum WallpaperKind { gradient, plain, image }

/// The built-in four-point gradients. Classic is Telegram's own.
/// The gradient behind the chats. The first three also tint the glass
/// and the secondary text to match (see `surfaceTint`); the rest keep the
/// classic tokens and only swap the gradient.
enum WallpaperPreset {
  mist,
  sage,
  linen,
  classic,
  ocean,
  lavender,
  sand,
  graphite,
}

/// How round photos, videos and cards are in messages.
enum MediaCorner {
  small(4),
  medium(8),
  large(12);

  const MediaCorner(this.radius);

  final double radius;
}

/// The Dock icon on macOS. Crimson is the brand icon the app ships with.
enum AppIconChoice { crimson, blue, graphite }

/// Dark theme by the clock, as Telegram's scheduled night mode.
final class NightSchedule {
  const NightSchedule({
    this.enabled = false,
    this.from = 22 * 60,
    this.to = 7 * 60,
  });

  final bool enabled;

  /// Minutes after midnight when the dark theme starts and ends. A window
  /// across midnight (22:00 to 07:00) is the usual case.
  final int from;
  final int to;

  /// Whether [time] falls in the dark window.
  bool isNight(DateTime time) {
    if (!enabled) return false;
    final now = time.hour * 60 + time.minute;
    if (from == to) return true;
    return from < to ? now >= from && now < to : now >= from || now < to;
  }

  /// The next moment the answer of [isNight] changes, after [time].
  DateTime nextChange(DateTime time) {
    final today = DateTime(time.year, time.month, time.day);
    final now = time.hour * 60 + time.minute;
    final candidates = [from, to]..sort();
    for (final minutes in candidates) {
      if (minutes > now) return today.add(Duration(minutes: minutes));
    }
    return today.add(Duration(days: 1, minutes: candidates.first));
  }

  NightSchedule copyWith({bool? enabled, int? from, int? to}) => NightSchedule(
    enabled: enabled ?? this.enabled,
    from: from ?? this.from,
    to: to ?? this.to,
  );

  Map<String, Object?> toJson() => {'enabled': enabled, 'from': from, 'to': to};

  static NightSchedule fromJson(Object? json) {
    if (json is! Map) return const NightSchedule();
    const defaults = NightSchedule();
    final from = json['from'];
    final to = json['to'];
    return NightSchedule(
      enabled: _bool(json['enabled']) ?? defaults.enabled,
      from: from is int ? from.clamp(0, 24 * 60 - 1) : defaults.from,
      to: to is int ? to.clamp(0, 24 * 60 - 1) : defaults.to,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NightSchedule &&
      other.enabled == enabled &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(enabled, from, to);
}

/// The language the app speaks: the system's, or one chosen in Language.
enum AppLanguage {
  system(null),
  english(Locale('en')),
  russian(Locale('ru'));

  const AppLanguage(this.locale);

  /// Null follows the system.
  final Locale? locale;
}

/// The user's choices from Appearance and Data and storage. They belong to
/// the app, not to an account, and survive signing out.
final class Preferences {
  const Preferences({
    this.theme = ThemeMode.system,
    this.accent = AccentChoice.violet,
    this.wallpaperKind = WallpaperKind.plain,
    this.wallpaperPreset = WallpaperPreset.mist,
    this.wallpaperImage,
    this.wallpaperBlur = false,
    this.nightSchedule = const NightSchedule(),
    this.blurTheme = false,
    this.blurOpacity = defaultBlurOpacity,
    this.mediaCorner = MediaCorner.medium,
    this.compactLayout = false,
    this.appIcon = AppIconChoice.crimson,
    this.textSize = defaultTextSize,
    this.sidebarWidth = defaultSidebarWidth,
    this.reduceMotion = false,
    this.autoDownload = defaultAutoDownload,
    this.downloadFolder,
    this.shortcuts = const {},
    this.language = AppLanguage.system,
    this.largeEmoji = true,
    this.loopStickers = true,
    this.hideArchive = false,
    this.translateTo,
    this.translateSkip = const {},
    this.translateChats = const {},
    this.translateHidden = const {},
  });

  static const minTextSize = 12;
  static const maxTextSize = 17;
  static const defaultTextSize = 13;

  /// How opaque the window stays in the blurred theme.
  static const minBlurOpacity = 0.4;
  static const maxBlurOpacity = 0.95;
  static const defaultBlurOpacity = 0.62;

  /// Photos download everywhere, videos on Wi-Fi, files when asked.
  static const defaultAutoDownload = {
    AutoDownloadKind.photos: AutoDownload(wifi: true, other: true),
    AutoDownloadKind.videos: AutoDownload(wifi: true, other: false),
    AutoDownloadKind.files: AutoDownload(wifi: false, other: false),
  };

  final ThemeMode theme;
  final AccentChoice accent;

  /// What is behind the chats; see [WallpaperKind].
  final WallpaperKind wallpaperKind;

  /// The gradient shown when [wallpaperKind] is [WallpaperKind.gradient].
  final WallpaperPreset wallpaperPreset;

  /// The user's picture when [wallpaperKind] is [WallpaperKind.image], as
  /// a path on this computer.
  final String? wallpaperImage;

  /// Blurs the picture a little, so the glass and the text read well.
  final bool wallpaperBlur;

  /// Dark theme by the clock, on top of [theme].
  final NightSchedule nightSchedule;

  /// The Vesper Blur theme (macOS only): a dark, matte window that blurs
  /// what lies under it. Takes over the theme above while on.
  final bool blurTheme;

  /// How opaque the blurred window is, between [minBlurOpacity] and
  /// [maxBlurOpacity]; less shows more of the desktop behind it.
  final double blurOpacity;
  final MediaCorner mediaCorner;

  /// Tighter chat list rows and less air between messages.
  final bool compactLayout;
  final AppIconChoice appIcon;

  /// Something other than a plain color is behind the chats.
  bool get wallpaper => wallpaperKind != WallpaperKind.plain;

  /// Message text size in points, [minTextSize] to [maxTextSize].
  final int textSize;

  /// How wide the chat list is, [minSidebarWidth] to [maxSidebarWidth];
  /// dragged at its edge.
  final double sidebarWidth;

  static const double minSidebarWidth = 280;
  static const double maxSidebarWidth = 480;
  static const double defaultSidebarWidth = 340;

  /// Turns animations off, as the macOS "Reduce motion" setting does.
  final bool reduceMotion;
  final Map<AutoDownloadKind, AutoDownload> autoDownload;

  /// Where saved files go; null for the system Downloads folder.
  final String? downloadFolder;

  /// Keyboard shortcuts the user changed, by action id: an encoded
  /// `ShortcutKey`, or null for an action they took the key from.
  final Map<String, String?> shortcuts;
  final AppLanguage language;

  /// A message of one to three emoji is shown large, without text around.
  final bool largeEmoji;

  /// Animated stickers play on; off, they play once.
  final bool loopStickers;

  /// The Archive row is out of the chat list; the archive stays reachable
  /// from the rail and from search.
  final bool hideArchive;

  /// The language chats are translated into, as a code such as `en`; null
  /// follows the app's language.
  final String? translateTo;

  /// Languages the translation bar leaves alone, as codes.
  final Set<String> translateSkip;

  /// The chats shown translated, and those whose translation bar the
  /// user hid, by chat id.
  final Set<int> translateChats;
  final Set<int> translateHidden;

  AutoDownload autoDownloadOf(AutoDownloadKind kind) =>
      autoDownload[kind] ?? defaultAutoDownload[kind]!;

  Preferences copyWith({
    ThemeMode? theme,
    AccentChoice? accent,
    WallpaperKind? wallpaperKind,
    WallpaperPreset? wallpaperPreset,
    String? wallpaperImage,
    bool clearWallpaperImage = false,
    bool? wallpaperBlur,
    NightSchedule? nightSchedule,
    bool? blurTheme,
    double? blurOpacity,
    MediaCorner? mediaCorner,
    bool? compactLayout,
    AppIconChoice? appIcon,
    int? textSize,
    double? sidebarWidth,
    bool? reduceMotion,
    Map<AutoDownloadKind, AutoDownload>? autoDownload,
    String? downloadFolder,
    Map<String, String?>? shortcuts,
    AppLanguage? language,
    bool? largeEmoji,
    bool? loopStickers,
    bool? hideArchive,
    String? translateTo,
    bool clearTranslateTo = false,
    Set<String>? translateSkip,
    Set<int>? translateChats,
    Set<int>? translateHidden,
  }) => Preferences(
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    wallpaperKind: wallpaperKind ?? this.wallpaperKind,
    wallpaperPreset: wallpaperPreset ?? this.wallpaperPreset,
    wallpaperImage: clearWallpaperImage
        ? null
        : wallpaperImage ?? this.wallpaperImage,
    wallpaperBlur: wallpaperBlur ?? this.wallpaperBlur,
    nightSchedule: nightSchedule ?? this.nightSchedule,
    blurTheme: blurTheme ?? this.blurTheme,
    blurOpacity: blurOpacity ?? this.blurOpacity,
    mediaCorner: mediaCorner ?? this.mediaCorner,
    compactLayout: compactLayout ?? this.compactLayout,
    appIcon: appIcon ?? this.appIcon,
    textSize: (textSize ?? this.textSize).clamp(minTextSize, maxTextSize),
    sidebarWidth: (sidebarWidth ?? this.sidebarWidth).clamp(
      minSidebarWidth,
      maxSidebarWidth,
    ),
    reduceMotion: reduceMotion ?? this.reduceMotion,
    autoDownload: autoDownload ?? this.autoDownload,
    downloadFolder: downloadFolder ?? this.downloadFolder,
    shortcuts: shortcuts ?? this.shortcuts,
    language: language ?? this.language,
    largeEmoji: largeEmoji ?? this.largeEmoji,
    loopStickers: loopStickers ?? this.loopStickers,
    hideArchive: hideArchive ?? this.hideArchive,
    translateTo: clearTranslateTo ? null : translateTo ?? this.translateTo,
    translateSkip: translateSkip ?? this.translateSkip,
    translateChats: translateChats ?? this.translateChats,
    translateHidden: translateHidden ?? this.translateHidden,
  );

  /// The same with [kind] changed.
  Preferences withAutoDownload(AutoDownloadKind kind, AutoDownload value) =>
      copyWith(autoDownload: {...autoDownload, kind: value});

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'accent': accent.name,
    'accentVersion': 2,
    'wallpaper': wallpaper,
    'wallpaperKind': wallpaperKind.name,
    'wallpaperVersion': 2,
    'wallpaperPreset': wallpaperPreset.name,
    'wallpaperImage': ?wallpaperImage,
    'wallpaperBlur': wallpaperBlur,
    'nightSchedule': nightSchedule.toJson(),
    'blurTheme': blurTheme,
    'blurOpacity': blurOpacity,
    'mediaCorner': mediaCorner.name,
    'compactLayout': compactLayout,
    'appIcon': appIcon.name,
    'textSize': textSize,
    'sidebarWidth': sidebarWidth,
    'reduceMotion': reduceMotion,
    'autoDownload': {
      for (final kind in AutoDownloadKind.values)
        kind.name: autoDownloadOf(kind).toJson(),
    },
    'downloadFolder': ?downloadFolder,
    if (shortcuts.isNotEmpty) 'shortcuts': shortcuts,
    'language': language.name,
    'largeEmoji': largeEmoji,
    'loopStickers': loopStickers,
    'hideArchive': hideArchive,
    'translateTo': ?translateTo,
    if (translateSkip.isNotEmpty) 'translateSkip': translateSkip.toList(),
    if (translateChats.isNotEmpty) 'translateChats': translateChats.toList(),
    if (translateHidden.isNotEmpty) 'translateHidden': translateHidden.toList(),
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
    final image = json['wallpaperImage'];
    // Before wallpaper kinds there was one switch; off meant plain.
    final saved =
        _byName(WallpaperKind.values, json['wallpaperKind']) ??
        (_bool(json['wallpaper']) == false
            ? WallpaperKind.plain
            : defaults.wallpaperKind);
    // The Mist gradient was the default before gradients were drawn on the
    // chat card and was saved as such; it moves to the plain card once.
    final kind =
        saved == WallpaperKind.gradient &&
            json['wallpaperVersion'] != 2 &&
            (json['wallpaperPreset'] ?? 'mist') == 'mist'
        ? WallpaperKind.plain
        : saved;
    return Preferences(
      theme: _byName(ThemeMode.values, json['theme']) ?? defaults.theme,
      accent: switch (_byName(AccentChoice.values, json['accent'])) {
        // Blue was the default before the Stage window and was saved as
        // such; it moves to the new default once.
        AccentChoice.blue when json['accentVersion'] != 2 => defaults.accent,
        final choice? => choice,
        null => defaults.accent,
      },
      wallpaperKind: kind == WallpaperKind.image && image is! String
          ? defaults.wallpaperKind
          : kind,
      wallpaperPreset:
          _byName(WallpaperPreset.values, json['wallpaperPreset']) ??
          defaults.wallpaperPreset,
      wallpaperImage: image is String && image.isNotEmpty ? image : null,
      wallpaperBlur: _bool(json['wallpaperBlur']) ?? defaults.wallpaperBlur,
      nightSchedule: NightSchedule.fromJson(json['nightSchedule']),
      blurTheme: _bool(json['blurTheme']) ?? defaults.blurTheme,
      blurOpacity: switch (json['blurOpacity']) {
        final num v => v.toDouble().clamp(
          Preferences.minBlurOpacity,
          Preferences.maxBlurOpacity,
        ),
        _ => defaults.blurOpacity,
      },
      mediaCorner:
          _byName(MediaCorner.values, json['mediaCorner']) ??
          defaults.mediaCorner,
      compactLayout: _bool(json['compactLayout']) ?? defaults.compactLayout,
      appIcon:
          _byName(AppIconChoice.values, json['appIcon']) ?? defaults.appIcon,
      textSize: size is int
          ? size.clamp(minTextSize, maxTextSize)
          : defaults.textSize,
      sidebarWidth: switch (json['sidebarWidth']) {
        final num width => width.toDouble().clamp(
          minSidebarWidth,
          maxSidebarWidth,
        ),
        _ => defaults.sidebarWidth,
      },
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
      language:
          _byName(AppLanguage.values, json['language']) ?? defaults.language,
      largeEmoji: _bool(json['largeEmoji']) ?? defaults.largeEmoji,
      loopStickers: _bool(json['loopStickers']) ?? defaults.loopStickers,
      hideArchive: _bool(json['hideArchive']) ?? defaults.hideArchive,
      translateTo:
          json['translateTo'] is String &&
              (json['translateTo'] as String).isNotEmpty
          ? json['translateTo'] as String
          : null,
      translateSkip: {
        if (json['translateSkip'] is List)
          for (final code in json['translateSkip'] as List)
            if (code is String && code.isNotEmpty) code,
      },
      translateChats: _ids(json['translateChats']),
      translateHidden: _ids(json['translateHidden']),
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

Set<int> _ids(Object? value) => {
  if (value is List)
    for (final id in value)
      if (id is int) id,
};

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

/// The kinds that may download on their own, for `FileController`.
final autoDownloadKindsProvider = Provider<Set<MediaDownloadKind>>((ref) {
  final p = ref.watch(preferencesProvider.select((p) => p.autoDownload));
  const kinds = {
    AutoDownloadKind.photos: MediaDownloadKind.photos,
    AutoDownloadKind.videos: MediaDownloadKind.videos,
    AutoDownloadKind.files: MediaDownloadKind.files,
  };
  return {
    for (final MapEntry(key: kind, value: media) in kinds.entries)
      if ((p[kind] ?? Preferences.defaultAutoDownload[kind]!).wifi) media,
  };
});
