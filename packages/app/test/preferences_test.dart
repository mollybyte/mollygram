import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/storage_page.dart';

void main() {
  group('Preferences', () {
    test('round-trips the appearance part 2 choices', () {
      final preferences = const Preferences().copyWith(
        wallpaperKind: WallpaperKind.image,
        wallpaperPreset: WallpaperPreset.ocean,
        wallpaperImage: '/Users/anna/wall.jpg',
        wallpaperBlur: true,
        nightSchedule: const NightSchedule(
          enabled: true,
          from: 21 * 60,
          to: 8 * 60,
        ),
        mediaCorner: MediaCorner.large,
        compactLayout: true,
        appIcon: AppIconChoice.graphite,
      );
      final restored = Preferences.fromJson(preferences.toJson());

      expect(restored.wallpaperKind, WallpaperKind.image);
      expect(restored.wallpaperPreset, WallpaperPreset.ocean);
      expect(restored.wallpaperImage, '/Users/anna/wall.jpg');
      expect(restored.wallpaperBlur, isTrue);
      expect(
        restored.nightSchedule,
        const NightSchedule(enabled: true, from: 21 * 60, to: 8 * 60),
      );
      expect(restored.mediaCorner, MediaCorner.large);
      expect(restored.compactLayout, isTrue);
      expect(restored.appIcon, AppIconChoice.graphite);
    });

    test(
      'reads the old wallpaper switch and drops a picture without a path',
      () {
        expect(
          Preferences.fromJson({'wallpaper': false}).wallpaperKind,
          WallpaperKind.plain,
        );
        // The old default, the Mist gradient, is now the plain card.
        expect(
          Preferences.fromJson({'wallpaper': true}).wallpaperKind,
          WallpaperKind.plain,
        );
        expect(
          Preferences.fromJson({'wallpaperKind': 'image'}).wallpaperKind,
          WallpaperKind.plain,
        );
        final cleared = const Preferences()
            .copyWith(wallpaperImage: '/a.png')
            .copyWith(clearWallpaperImage: true);
        expect(cleared.wallpaperImage, isNull);
      },
    );

    test('night schedule knows its window and the next change', () {
      const schedule = NightSchedule(enabled: true, from: 22 * 60, to: 7 * 60);
      expect(schedule.isNight(DateTime(2026, 1, 1, 23)), isTrue);
      expect(schedule.isNight(DateTime(2026, 1, 1, 6, 59)), isTrue);
      expect(schedule.isNight(DateTime(2026, 1, 1, 7)), isFalse);
      expect(schedule.isNight(DateTime(2026, 1, 1, 12)), isFalse);
      expect(
        schedule.nextChange(DateTime(2026, 1, 1, 12)),
        DateTime(2026, 1, 1, 22),
      );
      expect(
        schedule.nextChange(DateTime(2026, 1, 1, 23)),
        DateTime(2026, 1, 2, 7),
      );
      expect(
        const NightSchedule(
          from: 22 * 60,
          to: 7 * 60,
        ).isNight(DateTime(2026, 1, 1, 23)),
        isFalse,
      );
      const day = NightSchedule(enabled: true, from: 9 * 60, to: 17 * 60);
      expect(day.isNight(DateTime(2026, 1, 1, 10)), isTrue);
      expect(day.isNight(DateTime(2026, 1, 1, 18)), isFalse);
    });

    test('round-trips through JSON', () {
      final preferences = const Preferences()
          .copyWith(
            theme: ThemeMode.dark,
            accent: AccentChoice.teal,
            wallpaperKind: WallpaperKind.plain,
            textSize: 15,
            reduceMotion: true,
            downloadFolder: '/Users/anna/Telegram',
          )
          .withAutoDownload(
            AutoDownloadKind.files,
            const AutoDownload(wifi: true, other: true),
          );
      final restored = Preferences.fromJson(preferences.toJson());

      expect(restored.theme, ThemeMode.dark);
      expect(restored.accent, AccentChoice.teal);
      expect(restored.wallpaper, isFalse);
      expect(restored.textSize, 15);
      expect(restored.reduceMotion, isTrue);
      expect(restored.downloadFolder, '/Users/anna/Telegram');
      expect(
        restored.autoDownloadOf(AutoDownloadKind.files),
        const AutoDownload(wifi: true, other: true),
      );
      expect(
        restored.autoDownloadOf(AutoDownloadKind.videos),
        const AutoDownload(wifi: true, other: false),
      );
    });

    test('keeps the translation choices', () {
      final preferences = const Preferences().copyWith(
        translateTo: 'de',
        translateSkip: {'uk', 'be'},
        translateChats: {7, 9},
        translateHidden: {11},
      );
      final restored = Preferences.fromJson(preferences.toJson());
      expect(restored.translateTo, 'de');
      expect(restored.translateSkip, {'uk', 'be'});
      expect(restored.translateChats, {7, 9});
      expect(restored.translateHidden, {11});

      final defaults = Preferences.fromJson(const Preferences().toJson());
      expect(defaults.translateTo, isNull);
      expect(defaults.translateSkip, isEmpty);
      expect(defaults.translateChats, isEmpty);
      expect(
        Preferences.fromJson({
          'translateTo': 3,
          'translateChats': ['x', 5],
        }).translateChats,
        {5},
      );
    });

    test('falls back to defaults for missing or unknown values', () {
      final restored = Preferences.fromJson({
        'theme': 'sepia',
        'accent': 42,
        'textSize': 40,
        'autoDownload': {
          'photos': {'wifi': false},
        },
      });
      expect(restored.theme, ThemeMode.system);
      expect(restored.accent, AccentChoice.violet);
      expect(restored.wallpaperKind, WallpaperKind.plain);
      expect(restored.sidebarWidth, Preferences.defaultSidebarWidth);
      expect(restored.textSize, Preferences.maxTextSize);
      expect(
        restored.autoDownloadOf(AutoDownloadKind.photos),
        const AutoDownload(wifi: false, other: true),
      );
      expect(Preferences.fromJson(null).textSize, 13);
      expect(Preferences.fromJson('broken').accent, AccentChoice.violet);
    });

    test('moves the old default Mist gradient to the plain card once, '
        'then keeps a chosen gradient', () {
      expect(
        Preferences.fromJson({
          'wallpaperKind': 'gradient',
          'wallpaperPreset': 'mist',
        }).wallpaperKind,
        WallpaperKind.plain,
      );
      expect(
        Preferences.fromJson({
          'wallpaperKind': 'gradient',
          'wallpaperPreset': 'sage',
        }).wallpaperKind,
        WallpaperKind.gradient,
      );
      const chosen = Preferences(
        wallpaperKind: WallpaperKind.gradient,
        wallpaperPreset: WallpaperPreset.mist,
      );
      expect(
        Preferences.fromJson(chosen.toJson()).wallpaperKind,
        WallpaperKind.gradient,
      );
    });

    test('keeps the sidebar width within its limits', () {
      expect(
        Preferences.fromJson({'sidebarWidth': 1000}).sidebarWidth,
        Preferences.maxSidebarWidth,
      );
      expect(
        Preferences.fromJson(const Preferences(sidebarWidth: 300).toJson())
            .sidebarWidth,
        300,
      );
    });

    test('moves the old default blue to violet once, then keeps a '
        'chosen blue', () {
      expect(
        Preferences.fromJson({'accent': 'blue'}).accent,
        AccentChoice.violet,
      );
      final chosen = const Preferences().copyWith(accent: AccentChoice.blue);
      expect(Preferences.fromJson(chosen.toJson()).accent, AccentChoice.blue);
      expect(
        Preferences.fromJson({'accent': 'teal'}).accent,
        AccentChoice.teal,
      );
    });

    test('keeps the text size within 12 to 17', () {
      expect(const Preferences().copyWith(textSize: 3).textSize, 12);
      expect(const Preferences().copyWith(textSize: 30).textSize, 17);
    });
  });

  group('PreferencesNotifier', () {
    test('applies at once and writes once after a burst', () async {
      final storage = MemoryPreferencesStorage();
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(preferencesProvider.notifier);

      for (var size = 13; size <= 16; size++) {
        notifier.update((p) => p.copyWith(textSize: size));
      }
      expect(container.read(preferencesProvider).textSize, 16);
      expect(storage.writes, 0);

      await Future<void>.delayed(
        PreferencesNotifier.saveDelay + const Duration(milliseconds: 50),
      );
      // The timed write is under way; this waits for it without adding one.
      await notifier.flush();
      expect(storage.writes, 1);
      expect((storage.saved! as Map)['textSize'], 16);
    });

    test('flush writes a waiting change right away', () async {
      final storage = MemoryPreferencesStorage();
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(preferencesProvider.notifier);
      notifier.update((p) => p.copyWith(wallpaperKind: WallpaperKind.plain));
      await notifier.flush();
      expect((storage.saved! as Map)['wallpaper'], isFalse);

      // Nothing waiting: no second write.
      await notifier.flush();
      expect(storage.writes, 1);
    });

    test('flush waits for a write already under way', () async {
      final storage = _SlowStorage();
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(preferencesProvider.notifier);
      notifier.update((p) => p.copyWith(wallpaperKind: WallpaperKind.plain));
      final first = notifier.flush();
      await Future<void>.delayed(Duration.zero);
      expect(storage.started, 1);

      // Nothing new is waiting, yet flush must not finish before the write.
      var done = false;
      unawaited(notifier.flush().then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      storage.finish.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
      expect((storage.saved! as Map)['wallpaper'], isFalse);
    });

    test('writes a waiting change when the app closes', () async {
      final storage = MemoryPreferencesStorage();
      final container = ProviderContainer(
        overrides: [preferencesStorageProvider.overrideWithValue(storage)],
      );
      container
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(accent: AccentChoice.green));
      container.dispose();
      await Future<void>.delayed(Duration.zero);
      expect((storage.saved! as Map)['accent'], 'green');
    });

    test('starts from what was loaded at launch', () async {
      final storage = MemoryPreferencesStorage({
        'theme': 'light',
        'textSize': 14,
      });
      final loaded = await loadPreferences(storage);
      final container = ProviderContainer(
        overrides: [initialPreferencesProvider.overrideWithValue(loaded)],
      );
      addTearDown(container.dispose);
      expect(container.read(preferencesProvider).theme, ThemeMode.light);
      expect(container.read(preferencesProvider).textSize, 14);
    });

    test('reduce motion follows the preference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(reduceMotionProvider), isFalse);
      container
          .read(preferencesProvider.notifier)
          .update((p) => p.copyWith(reduceMotion: true));
      expect(container.read(reduceMotionProvider), isTrue);
    });
  });

  group('formatBytes', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ru = lookupAppLocalizations(const Locale('ru'));

    test('uses decimal units with one decimal below 10', () {
      expect(formatBytes(0, en, 'en'), '0 B');
      expect(formatBytes(999, en, 'en'), '999 B');
      expect(formatBytes(1000, en, 'en'), '1 KB');
      expect(formatBytes(4250, en, 'en'), '4.3 KB');
      expect(formatBytes(38400000, en, 'en'), '38 MB');
      expect(formatBytes(999999, en, 'en'), '1 MB');
      expect(formatBytes(2500000000, en, 'en'), '2.5 GB');
      expect(formatBytes(1200000000000, en, 'en'), '1200 GB');
    });

    test('writes Russian units and decimal commas', () {
      expect(formatBytes(4250000, ru, 'ru'), '4,3 МБ');
      expect(formatBytes(512, ru, 'ru'), '512 Б');
    });

    test('shortens the home folder to a tilde', () {
      expect(
        displayPath('/Users/anna/Downloads', home: '/Users/anna'),
        '~/Downloads',
      );
      expect(
        displayPath('/Volumes/Disk', home: '/Users/anna'),
        '/Volumes/Disk',
      );
    });
  });

  testWidgets('save panels start in the chosen download folder', (
    tester,
  ) async {
    late BuildContext inside;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialPreferencesProvider.overrideWithValue(
            const Preferences(downloadFolder: '/Users/anna/Telegram'),
          ),
          preferencesStorageProvider.overrideWithValue(
            MemoryPreferencesStorage(),
          ),
        ],
        child: Builder(
          builder: (context) {
            inside = context;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(await downloadFolderOf(inside), '/Users/anna/Telegram');

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          inside = context;
          return const SizedBox();
        },
      ),
    );
    expect(await downloadFolderOf(inside), isNull);
  });
}

/// Storage whose writes finish only when told to.
final class _SlowStorage implements PreferencesStorage {
  final finish = Completer<void>();
  var started = 0;
  Object? saved;

  @override
  Future<Object?> read() async => null;

  @override
  Future<void> write(Object? json) async {
    started++;
    await finish.future;
    saved = json;
  }
}
