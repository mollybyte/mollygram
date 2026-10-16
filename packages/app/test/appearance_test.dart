import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/settings/appearance.dart';
import 'package:mollygram/src/settings/preferences.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  MgColors colorsOf(ThemeData theme) => theme.extension<MgColors>()!;

  group('vesperBlur', () {
    double luminanceOver(Color top, Color backdrop) =>
        Color.alphaBlend(top, backdrop).computeLuminance();
    double contrast(Color fg, Color bg) {
      final a = fg.computeLuminance() + 0.05;
      final b = bg.computeLuminance() + 0.05;
      return a > b ? a / b : b / a;
    }

    test('text stays above 4.5:1 on the frame over a bright desktop', () {
      // The native material already darkens the desktop; a mid grey is the
      // brightest the blur shows in practice, white is the extreme.
      for (final opacity in [
        Preferences.minBlurOpacity,
        Preferences.defaultBlurOpacity,
        Preferences.maxBlurOpacity,
      ]) {
        final c = vesperBlur(MgColors.dark, opacity);
        final frame = Color.alphaBlend(c.frame, const Color(0xFF5A5A5A));
        expect(contrast(c.fg, frame), greaterThan(4.5));
        expect(contrast(c.fg2, frame), greaterThan(4.5));
        expect(contrast(c.onAccent, c.accent), greaterThan(4.5));
        expect(luminanceOver(c.frame, const Color(0xFF5A5A5A)), lessThan(0.1));
      }
    });

    test('solid() makes panels opaque over the matte base', () {
      final c = vesperBlur(MgColors.dark, Preferences.minBlurOpacity);
      expect(c.solid(c.card).a, 1);
      expect(c.solid(c.frame).a, 1);
      expect(c.glass.a, greaterThan(0.8));
    });

    test('the frame is translucent by the chosen opacity', () {
      final c = vesperBlur(MgColors.dark, 0.75);
      expect(c.frame.a, closeTo(0.75, 0.01));
      expect(c.card.a, lessThan(c.frame.a));
    });
  });

  group('appThemes', () {
    test('a tinted wallpaper changes the glass and secondary text', () {
      final themes = appThemes(
        const Preferences(
          wallpaperKind: WallpaperKind.gradient,
          wallpaperPreset: WallpaperPreset.sage,
        ),
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
          const Preferences(
            wallpaperKind: WallpaperKind.gradient,
            wallpaperPreset: WallpaperPreset.classic,
          ),
        ).light,
      );
      expect(light.accent, plain.accent);
    });

    test('the classic gradient keeps the design tokens', () {
      final themes = appThemes(
        const Preferences(
          wallpaperKind: WallpaperKind.gradient,
          wallpaperPreset: WallpaperPreset.classic,
        ),
      );
      expect(colorsOf(themes.light).glass, MgColors.light.glass);
      expect(colorsOf(themes.dark).fg2, MgColors.dark.fg2);
    });

    test('a plain background or a picture takes the Mist tokens', () {
      final mist = colorsOf(
        appThemes(
          const Preferences(
            wallpaperKind: WallpaperKind.gradient,
            wallpaperPreset: WallpaperPreset.mist,
          ),
        ).light,
      );
      for (final kind in [WallpaperKind.plain, WallpaperKind.image]) {
        final themes = appThemes(
          Preferences(
            wallpaperKind: kind,
            wallpaperPreset: WallpaperPreset.linen,
            wallpaperImage: kind == WallpaperKind.image ? '/a.png' : null,
          ),
        );
        expect(colorsOf(themes.light).frame, mist.frame);
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
