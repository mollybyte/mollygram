import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import 'settings_style.dart';

/// The check mark at the end of the chosen row of a list, as in System
/// Settings. It fades and scales in, and keeps its room when hidden so
/// the rows line up.
class SelectionCheck extends StatelessWidget {
  const SelectionCheck({super.key, required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final duration = settingsMotionOf(context);
    return SizedBox.square(
      dimension: 18,
      child: AnimatedOpacity(
        opacity: checked ? 1 : 0,
        duration: duration,
        curve: settingsCurve,
        child: AnimatedScale(
          scale: checked ? 1 : 0.6,
          duration: duration,
          curve: settingsCurve,
          child: MgIcon(_check, size: 16, stroke: 2.4, color: c.accent),
        ),
      ),
    );
  }
}

const _check = MgIconData('check', '<path d="M5 12.5l4.5 4.5L19 7"/>');
