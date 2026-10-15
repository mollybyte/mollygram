import 'dart:async';

import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The small spinner a list shows while its first page loads.
class LoadSpinner extends StatefulWidget {
  const LoadSpinner({super.key});

  @override
  State<LoadSpinner> createState() => _LoadSpinnerState();
}

/// Shown only when loading takes long enough to notice.
class _LoadSpinnerState extends State<LoadSpinner> {
  var _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 160),
      child: SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 1.6, color: c.fg2),
      ),
    );
  }
}
