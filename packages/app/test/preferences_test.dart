import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/l10n/app_localizations.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram/src/settings/storage_page.dart';

void main() {
  group('Preferences', () {
    test('round-trips through JSON', () {
      final preferences = const Preferences()
          .copyWith(
            theme: ThemeMode.dark,
            accent: AccentChoice.teal,
            wallpaper: false,
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
      expect(restored.accent, AccentChoice.blue);
      expect(restored.wallpaper, isTrue);
      expect(restored.textSize, Preferences.maxTextSize);
      expect(
        restored.autoDownloadOf(AutoDownloadKind.photos),
        const AutoDownload(wifi: false, other: true),
      );
      expect(Preferences.fromJson(null).textSize, 13);
      expect(Preferences.fromJson('broken').accent, AccentChoice.blue);
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
      notifier.update((p) => p.copyWith(wallpaper: false));
      await notifier.flush();
      expect((storage.saved! as Map)['wallpaper'], isFalse);

      // Nothing waiting: no second write.
      await notifier.flush();
      expect(storage.writes, 1);
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
}
