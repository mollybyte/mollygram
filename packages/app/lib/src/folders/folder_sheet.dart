import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// Shows [sheet] centered over the window the way the app's other sheets
/// appear: a short fade and scale, no dimming, closed by a click outside.
Future<T?> showFolderSheet<T>(BuildContext context, Widget sheet) =>
    showMgSheet<T>(context, sheet);
