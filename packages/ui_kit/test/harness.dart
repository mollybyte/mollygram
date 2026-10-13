import 'package:flutter/material.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Wraps [child] in a themed app for tests.
Widget themed(Widget child, {MgColors colors = MgColors.light}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildMgTheme(colors),
    home: Material(type: MaterialType.transparency, child: child),
  );
}
