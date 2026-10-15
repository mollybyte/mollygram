import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

/// The line under the composer while slowmode holds the next message
/// back: counts down to [until] every second and goes away by itself.
class SlowModeNotice extends StatefulWidget {
  const SlowModeNotice({super.key, required this.until, required this.label});

  final DateTime until;

  /// "Slowmode is on, next message in 0:27" for the time left.
  final String Function(String time) label;

  @override
  State<SlowModeNotice> createState() => _SlowModeNoticeState();
}

class _SlowModeNoticeState extends State<SlowModeNotice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.until.isAfter(DateTime.now())) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    final c = MgColors.of(context);
    return AnimatedOpacity(
      opacity: seconds == 0 ? 0 : 1,
      duration: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          widget.label(
            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
          ),
          textAlign: TextAlign.center,
          style: mgTextStyle(c, size: MgType.small, color: c.fg2),
        ),
      ),
    );
  }
}
