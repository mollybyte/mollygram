import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The blurred, dimmed window behind an editor: dark in the dark theme, a
/// calm light gray in the light one, like Photos.
class EditorBackdrop extends StatelessWidget {
  const EditorBackdrop({super.key, required this.colors});

  final MgColors colors;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: ColoredBox(
        color: colors.isDark
            ? const Color(0xEE141416)
            : const Color(0xEEEDEDF0),
      ),
    ),
  );
}
