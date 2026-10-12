import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_prototype/app_state.dart';
import 'package:mollygram_prototype/circle/circle_controller.dart';
import 'package:mollygram_prototype/main.dart';

/// A window screenshot for visual review, not a golden test:
/// MG_SHOT_DIR=/path flutter test test/screenshot_test.dart. Skipped when the
/// variable is not set.
void main() {
  final dir = Platform.environment['MG_SHOT_DIR'];

  Future<void> loadFonts() async {
    const files = {
      'Regular': FontWeight.w400,
      'Medium': FontWeight.w500,
      'SemiBold': FontWeight.w600,
      'Bold': FontWeight.w700,
    };
    final loader = FontLoader('Roboto');
    for (final name in files.keys) {
      final f = File('/usr/share/fonts/opentype/inter/Inter-$name.otf');
      if (f.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
      }
    }
    await loader.load();
  }

  for (final dark in [false, true]) {
    testWidgets('screenshot, ${dark ? 'dark' : 'light'}', (tester) async {
      tester.view.physicalSize = const Size(2880, 1800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.runAsync(loadFonts);

      final app = AppState();
      if (dark) {
        app.cycleTheme();
        app.cycleTheme();
      }
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('shot'),
          child: PrototypeApp(
            app: app,
            circle: CircleController(enabled: false),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        final boundary = tester.renderObject(
          find.byKey(const Key('shot')),
        ) as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        File('$dir/window_${dark ? 'dark' : 'light'}.png')
            .writeAsBytesSync(png!.buffer.asUint8List());
      });
    }, skip: dir == null);
  }
}
