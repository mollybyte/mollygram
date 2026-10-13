import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  group('MgColors', () {
    test('glass fill is .42 opaque in both themes', () {
      expect(MgColors.light.glass.a, closeTo(0.42, 0.005));
      expect(MgColors.dark.glass.a, closeTo(0.42, 0.005));
    });

    test('accent and bubbles follow the mockup', () {
      expect(MgColors.light.accent, const Color(0xFF0071E3));
      expect(MgColors.dark.accent, const Color(0xFF0A84FF));
      expect(MgColors.light.bubbleOut, const Color(0xFFEFFDDE));
      expect(MgColors.light.wallpaper, const [
        Color(0xFFDBDDBB),
        Color(0xFF6BA587),
        Color(0xFFD5D88D),
        Color(0xFF88B884),
      ]);
    });

    test('lerp ends at both themes', () {
      final a = MgColors.light.lerp(MgColors.dark, 0);
      final b = MgColors.light.lerp(MgColors.dark, 1);
      expect(a.fg, MgColors.light.fg);
      expect(b.fg, MgColors.dark.fg);
      expect(b.brightness, Brightness.dark);
      expect(b.wallpaper, MgColors.dark.wallpaper);
      expect(MgColors.light.lerp(null, 0.5), same(MgColors.light));
    });

    test('copyWith replaces only the given tokens', () {
      const raspberry = Color(0xFFD6336C);
      final c = MgColors.light.copyWith(accent: raspberry);
      expect(c.accent, raspberry);
      expect(c.fg, MgColors.light.fg);
    });

    test('the theme carries the tokens', () {
      final theme = buildMgTheme(MgColors.dark);
      expect(theme.extension<MgColors>(), same(MgColors.dark));
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, MgColors.dark.accent);
    });
  });

  group('monogramOf', () {
    test('takes the first letters of two words', () {
      expect(monogramOf('Anna Petrova'), 'AP');
      expect(monogramOf('  design   team chat '), 'DT');
      expect(monogramOf('Mollygram'), 'M');
      expect(monogramOf('алина'), 'А');
      expect(monogramOf(''), '');
      expect(monogramOf('   '), '');
    });

    test('keeps grapheme clusters whole', () {
      expect(monogramOf('👩‍💻 Team'), '👩‍💻T');
    });
  });

  test('UnreadBadge.label compacts large counts', () {
    expect(UnreadBadge.label(7), '7');
    expect(UnreadBadge.label(999), '999');
    expect(UnreadBadge.label(1000), '1K');
    expect(UnreadBadge.label(1234), '1.2K');
    expect(UnreadBadge.label(15600), '15K');
  });
}
