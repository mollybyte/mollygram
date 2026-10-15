import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';

/// Runs [close] when the app is asked to quit and lets it quit afterwards.
///
/// TDLib keeps its own threads running. If the process exits while they are
/// still working, C++ static destructors free mutexes those threads still use
/// and the app aborts on the way out ("mutex lock failed" in libtdjson). Closing
/// the clients first stops those threads.
class CloseBeforeExit extends StatefulWidget {
  const CloseBeforeExit({
    super.key,
    required this.close,
    required this.child,
    this.timeout = const Duration(seconds: 30),
  });

  final Future<void> Function() close;
  final Widget child;

  /// How long to wait for [close] before quitting anyway. TDLib needs a few
  /// seconds to flush its database on a large account; quitting earlier is
  /// the abort this widget exists to prevent, so the wait is generous.
  final Duration timeout;

  @override
  State<CloseBeforeExit> createState() => _CloseBeforeExitState();
}

class _CloseBeforeExitState extends State<CloseBeforeExit> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onExitRequested: _onExit);
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _onExit() async {
    try {
      await widget.close().timeout(widget.timeout);
    } catch (_) {
      // Quitting must not depend on a clean close.
    }
    return AppExitResponse.exit;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
