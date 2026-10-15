import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/settings/appearance.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  MgColors colorsOf(ThemeData theme) => theme.extension<MgColors>()!;

  group('appThemes', () {
    test('a tinted wallpaper changes the glass and secondary text', () {
      final themes = appThemes(
        const Preferences(wallpaperPreset: WallpaperPreset.mist),
      );
      final light = colorsOf(themes.light);
      final dark = colorsOf(themes.dark);
      expect(light.glass, isNot(MgColors.light.glass));
      expect(light.fg2, isNot(MgColors.light.fg2));
      expect(dark.glass, isNot(MgColors.dark.glass));
      expect(dark.fg2, isNot(MgColors.dark.fg2));
      // The accent is the one picked, whatever the wallpaper.
      final plain = colorsOf(
        appThemes(
          const Preferences(wallpaperPreset: WallpaperPreset.classic),
        ).light,
      );
      expect(light.accent, plain.accent);
    });

    test('the classic gradient keeps the design tokens', () {
      final themes = appThemes(
        const Preferences(wallpaperPreset: WallpaperPreset.classic),
      );
      expect(colorsOf(themes.light).glass, MgColors.light.glass);
      expect(colorsOf(themes.dark).fg2, MgColors.dark.fg2);
    });

    test('a plain background or a picture is not tinted', () {
      for (final kind in [WallpaperKind.plain, WallpaperKind.image]) {
        final themes = appThemes(
          Preferences(
            wallpaperKind: kind,
            wallpaperPreset: WallpaperPreset.linen,
            wallpaperImage: kind == WallpaperKind.image ? '/a.png' : null,
          ),
        );
        expect(colorsOf(themes.light).glass, MgColors.light.glass);
      }
    });

    test('the chosen accent still wins over the tint', () {
      final themes = appThemes(
        const Preferences(
          wallpaperPreset: WallpaperPreset.sage,
          accent: AccentChoice.teal,
        ),
      );
      expect(
        colorsOf(themes.light).accent,
        accentColors(AccentChoice.teal).light,
      );
    });
  });

  test('every preset has a gradient for both themes', () {
    for (final preset in WallpaperPreset.values) {
      final colors = wallpaperColors(preset);
      expect(colors.light.colors, hasLength(4), reason: preset.name);
      expect(colors.dark.colors, hasLength(4), reason: preset.name);
    }
  });

  test('Mist is the default wallpaper', () {
    expect(const Preferences().wallpaperPreset, WallpaperPreset.mist);
  });
}
