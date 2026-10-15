import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Roboto from the Flutter SDK so golden images show real text
/// instead of the Ahem test font's boxes. It is registered under the
/// app's system font family too (see `mgFontFamily`), because the test
/// engine draws a family it cannot find in the box font without trying
/// the fallbacks.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = '$root/bin/cache/artifacts/material_fonts';
    for (final family in ['Roboto', 'CupertinoSystemText']) {
      final loader = FontLoader(family);
      for (final name in ['Regular', 'Medium', 'Bold']) {
        final file = File('$dir/Roboto-$name.ttf');
        if (file.existsSync()) {
          final bytes = file.readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
      }
      await loader.load();
    }
  }
  await testMain();
}
