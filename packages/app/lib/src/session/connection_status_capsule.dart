import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'providers.dart';

/// The session's connection status as a small capsule, shown in the
/// sidebar's title bar while the app is not connected and up to date.
class ConnectionStatusCapsule extends ConsumerWidget {
  const ConnectionStatusCapsule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConnectionStatusView(
    status: ref.watch(connectionStatusProvider).value ?? ConnectionStatus.ready,
  );
}

/// Shows "Connecting…", "Updating…" and the like while [status] is not
/// ready, the way the official macOS client puts them in place of the chat
/// list title.
///
/// A status only appears once it has lasted [delay], so a quick reconnect
/// doesn't flash; it fades out as soon as the connection is ready. The
/// capsule never takes clicks, so the title bar under it still drags the
/// window.
class ConnectionStatusView extends StatefulWidget {
  const ConnectionStatusView({
    super.key,
    required this.status,
    this.delay = const Duration(milliseconds: 800),
  });

  final ConnectionStatus status;
  final Duration delay;

  @override
  State<ConnectionStatusView> createState() => _ConnectionStatusViewState();
}

class _ConnectionStatusViewState extends State<ConnectionStatusView> {
  static const _duration = Duration(milliseconds: 220);

  Timer? _delay;
  var _visible = false;

  /// Whether the capsule has appeared and not yet finished fading out.
  var _onScreen = false;

  /// The status the capsule shows; it stays while the capsule fades out.
  ConnectionStatus? _shown;

  @override
  void initState() {
    super.initState();
    _apply(widget.status);
  }

  @override
  void didUpdateWidget(ConnectionStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) _apply(widget.status);
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _apply(ConnectionStatus status) {
    if (status.isReady) {
      _delay?.cancel();
      _delay = null;
      _visible = false;
      if (!_onScreen) _shown = null;
      return;
    }
    _shown = status;
    if (_visible || _delay != null) return;
    _delay = Timer(widget.delay, () {
      if (!mounted) return;
      setState(() {
        _delay = null;
        _visible = true;
        _onScreen = true;
      });
    });
  }

  /// Drops the capsule once it has faded out, unless another status is
  /// already waiting out its delay.
  void _onFaded() {
    if (_visible) return;
    _onScreen = false;
    if (_delay != null || _shown == null) return;
    setState(() => _shown = null);
  }

  String _label(AppLocalizations l10n, ConnectionStatus status) =>
      switch (status) {
        ConnectionStatus.waitingForNetwork => l10n.connectionWaitingForNetwork,
        ConnectionStatus.connectingToProxy => l10n.connectionConnectingToProxy,
        ConnectionStatus.connecting => l10n.connectionConnecting,
        ConnectionStatus.updating => l10n.connectionUpdating,
        ConnectionStatus.ready => '',
      };

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    if (shown == null) return const SizedBox.shrink();
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    final label = _label(l10n, shown);

    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: duration,
          curve: Curves.easeOut,
          onEnd: _onFaded,
          child: AnimatedSlide(
            offset: _visible ? Offset.zero : const Offset(0, -0.25),
            duration: duration,
            curve: Curves.easeOutCubic,
            child: Semantics(
              liveRegion: true,
              label: _visible ? label : null,
              child: ExcludeSemantics(
                // The spinner stops while the capsule is hidden.
                child: TickerMode(
                  enabled: _visible,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.field,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CupertinoActivityIndicator(radius: 5.5, color: c.fg2),
                        const SizedBox(width: 6),
                        AnimatedSize(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          child: AnimatedSwitcher(
                            duration: duration,
                            layoutBuilder: (current, previous) => Stack(
                              alignment: Alignment.centerLeft,
                              children: [...previous, ?current],
                            ),
                            child: Text(
                              label,
                              key: ValueKey(shown),
                              maxLines: 1,
                              style: mgTextStyle(
                                c,
                                size: MgType.small,
                                color: c.fg2,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
