import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_plugins_ui/mollygram_plugins_ui.dart';

/// Screenshots for visual review against design/Plugins.dc.html, not a
/// golden test: MG_SHOT_DIR=/path flutter test test/screenshot_test.dart.
/// Skipped when the variable is not set.
void main() {
  final dir = Platform.environment['MG_SHOT_DIR'];

  Future<void> loadFont(String family, Map<String, String> files) async {
    final loader = FontLoader(family);
    for (final path in files.values) {
      final f = File(path);
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  Future<void> fonts() async {
    const inter = '/usr/share/fonts/opentype/inter/Inter';
    await loadFont('Inter', {
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        w: '$inter-$w.otf',
    });
    await loadFont('Menlo', {
      'Regular': '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf',
    });
  }

  final shots = [
    (
      name: 'light',
      dark: false,
      locale: 'en',
      sel: 'dev.mollygram.codehighlight',
      consent: false,
    ),
    (
      name: 'dark',
      dark: true,
      locale: 'en',
      sel: 'dev.tgplug.summary',
      consent: false,
    ),
    (
      name: 'ru_filters',
      dark: false,
      locale: 'ru',
      sel: 'dev.mollygram.filters',
      consent: false,
    ),
    (
      name: 'consent',
      dark: true,
      locale: 'en',
      sel: 'io.graphy.stats',
      consent: true,
    ),
  ];

  for (final s in shots) {
    testWidgets('screenshot ${s.name}', (tester) async {
      tester.view.physicalSize = const Size(2880, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(fonts);
      final builtins = await tester.runAsync(loadBuiltinPlugins);
      final controller = PluginsController([
        for (final b in builtins!) b.entry,
        ...mockPlugins(),
      ], selected: s.sel);
      if (s.consent) controller.requestInstall(s.sel);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(1440, 900)),
              child: DefaultTextStyle(
                style: const TextStyle(fontFamily: 'Inter'),
                child: PluginsScreen(
                  controller: controller,
                  locale: s.locale,
                  brightness: s.dark ? Brightness.dark : Brightness.light,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary = tester.renderObject(
          find.byKey(const Key('shot')),
        ) as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/plugins_${s.name}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }, skip: dir == null);
  }
}
