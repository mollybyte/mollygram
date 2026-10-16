import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

void main() {
  pressableTests();
  testWidgets('compact layout makes chat list rows shorter', (tester) async {
    late double regular;
    late double compact;
    for (final dense in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildMgTheme(
            MgColors.light,
            metrics: MgMetrics(compact: dense),
          ),
          home: Builder(
            builder: (context) {
              final extent = ChatListTile.extentOf(context);
              dense ? compact = extent : regular = extent;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }
    expect(regular, ChatListTile.extent);
    expect(compact, lessThan(regular));
  });

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

  test('copyWith can clear the bubble shadow', () {
    expect(MgColors.light.copyWith(bubbleShadow: null).bubbleShadow, isNull);
    expect(
      MgColors.light.copyWith(fg: const Color(0xFF000000)).bubbleShadow,
      MgColors.light.bubbleShadow,
    );
  });

  test('a theme change away from a selection colour keeps the accent', () {
    final from = MgColors.dark.copyWith(selection: const Color(0xFF6E57D6));
    final to = MgColors.dark.copyWith(accent: const Color(0xFF3FB8C6));
    expect(from.lerp(to, 1).selected, to.accent);
    expect(from.lerp(to, 0.5).selected.a, 1);
  });
}

void pressableTests() {
  testWidgets(
    'MgSpringCurve starts at 0, ends at 1, critical never overshoots',
    (tester) async {
      expect(MgMotion.settle.transform(0), 0);
      expect(MgMotion.settle.transform(1), closeTo(1, 0.02));
      for (var i = 0; i <= 100; i++) {
        expect(MgMotion.settle.transform(i / 100), lessThanOrEqualTo(1.001));
      }
      var peak = 0.0;
      for (var i = 0; i <= 100; i++) {
        peak = peak > MgMotion.spring.transform(i / 100)
            ? peak
            : MgMotion.spring.transform(i / 100);
      }
      expect(peak, greaterThan(1));
    },
  );

  testWidgets('a primary button cross-fades its label into the spinner', (
    tester,
  ) async {
    Widget button(bool loading) => MaterialApp(
      theme: buildMgTheme(MgColors.light),
      home: Center(
        child: MgPrimaryButton(
          label: 'Next',
          loading: loading,
          onPressed: () {},
        ),
      ),
    );
    await tester.pumpWidget(button(false));
    await tester.pumpWidget(button(true));
    await tester.pump(const Duration(milliseconds: 40));
    // Mid-way both are on screen, the label fading out.
    expect(find.text('Next'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(MgMotion.fast * 2);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('MgPressable sinks on pointer down and fires on tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Center(
          child: MgIconButton(
            icon: MgIcons.search,
            tooltip: 'Search',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byType(MgIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, lessThan(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('MgPressable lets go when a drag cancels the tap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMgTheme(MgColors.light),
        home: Center(
          child: MgIconButton(
            icon: MgIcons.search,
            tooltip: 'Search',
            onPressed: () {},
          ),
        ),
      ),
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byType(MgIconButton)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveBy(const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await g.up();
  });
}
