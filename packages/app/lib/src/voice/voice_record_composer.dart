import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mollygram_media/mollygram_media.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import 'voice_record_controller.dart';

/// The recording dot and the cancel warning: the system red.
const _red = Color(0xFFFF3B30);

/// Gives a composer voice recording: a record button for its trailing slot
/// and, while recording, the bar that takes the place of the text field.
///
/// ```dart
/// VoiceRecordComposer(
///   onRecorded: send,
///   builder: (context, button, bar) =>
///       Composer(recordButton: button, replacement: bar, ...),
/// )
/// ```
class VoiceRecordComposer extends StatefulWidget {
  const VoiceRecordComposer({
    super.key,
    required this.onRecorded,
    required this.builder,
    this.recorder,
  });

  /// Sends a finished recording.
  final Future<void> Function(RecordedVoice voice) onRecorded;

  /// [bar] is null unless recording.
  final Widget Function(BuildContext context, Widget button, Widget? bar)
  builder;

  /// For tests; the app records through the platform channel.
  final VoiceRecorder? recorder;

  @override
  State<VoiceRecordComposer> createState() => _VoiceRecordComposerState();
}

class _VoiceRecordComposerState extends State<VoiceRecordComposer> {
  late final VoiceRecordController _controller;
  final _barFocus = FocusNode(debugLabel: 'voice recording');
  FocusNode? _focusBefore;
  bool _wasRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = VoiceRecordController(
      recorder:
          widget.recorder ??
          VoiceRecorder(
            directory: () async =>
                '${(await getTemporaryDirectory()).path}/Voice',
          ),
      onRecorded: (voice) => widget.onRecorded(voice),
    )..addListener(_changed);
  }

  /// Moves focus to the bar while recording, so Esc and Enter reach it
  /// and not the text field, and gives it back after.
  void _changed() {
    final recording = _controller.isRecording;
    if (recording != _wasRecording) {
      _wasRecording = recording;
      if (recording) {
        _focusBefore = FocusManager.instance.primaryFocus;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.isRecording) _barFocus.requestFocus();
        });
      } else {
        final before = _focusBefore;
        _focusBefore = null;
        if (_barFocus.hasFocus) {
          if (before != null && before.context != null) {
            before.requestFocus();
          } else {
            _barFocus.unfocus();
          }
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_changed)
      ..dispose();
    _barFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording =
        _controller.isRecording || _controller.phase == RecordPhase.sending;
    return widget.builder(
      context,
      _RecordButton(controller: _controller),
      recording
          ? _RecordingBar(
              key: const ValueKey('voice bar'),
              controller: _controller,
              focusNode: _barFocus,
            )
          : null,
    );
  }
}

/// The microphone in the composer. A press held past a moment records; the
/// big circle, the lock and notes are drawn above everything in an overlay.
class _RecordButton extends StatefulWidget {
  const _RecordButton({required this.controller});

  final VoiceRecordController controller;

  @override
  State<_RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<_RecordButton>
    with TickerProviderStateMixin {
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  /// The circle growing in and out.
  late final _appear = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 200),
  );

  /// The note above the button fading in and out.
  late final _hintFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );

  /// The press is held long enough to be a recording, not a click.
  static const _holdDelay = Duration(milliseconds: 160);

  Timer? _holdTimer;
  int? _pointer;
  Offset _origin = Offset.zero;
  bool _hover = false;

  VoiceRecordController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
    _appear.addStatusListener((_) => _syncPortal());
    _hintFade.addStatusListener((_) => _syncPortal());
  }

  void _changed() {
    final recording = _c.phase != RecordPhase.idle;
    if (recording) {
      if (_c.isRecording) unawaited(_appear.forward());
    } else {
      unawaited(_appear.reverse());
    }
    if (_c.hint != null) {
      unawaited(_hintFade.forward());
    } else {
      unawaited(_hintFade.reverse());
    }
    _syncPortal();
    setState(() {});
  }

  void _syncPortal() {
    final show = _c.isActive || !_appear.isDismissed || !_hintFade.isDismissed;
    if (show && !_portal.isShowing) {
      _portal.show();
    } else if (!show && _portal.isShowing) {
      _portal.hide();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _c.removeListener(_changed);
    _appear.dispose();
    _hintFade.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton || _pointer != null) return;
    if (_c.phase == RecordPhase.locked) return;
    _pointer = event.pointer;
    _origin = event.position;
    _holdTimer = Timer(_holdDelay, () => unawaited(_c.press()));
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _c.drag(event.position - _origin);
  }

  void _up(PointerUpEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (_holdTimer?.isActive ?? false) {
      _holdTimer!.cancel();
      return _c.tap();
    }
    unawaited(_c.release());
  }

  void _cancel(PointerCancelEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _holdTimer?.cancel();
    unawaited(_c.cancel());
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final active = _c.isActive;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => _RecordOverlay(
          link: _link,
          controller: _c,
          appear: _appear,
          hintFade: _hintFade,
        ),
        child: Semantics(
          button: true,
          label: l10n.voiceHoldToRecord,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Listener(
              onPointerDown: _down,
              onPointerMove: _move,
              onPointerUp: _up,
              onPointerCancel: _cancel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hover && !active ? c.hover : const Color(0x00000000),
                  shape: BoxShape.circle,
                ),
                child: MgIcon(
                  MgIcons.mic,
                  size: 18,
                  color: active ? c.accent : (_hover ? c.fg : c.fg2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything that floats over the composer while recording: the big
/// circle that follows the voice, the lock above it, and the notes.
class _RecordOverlay extends StatelessWidget {
  const _RecordOverlay({
    required this.link,
    required this.controller,
    required this.appear,
    required this.hintFade,
  });

  final LayerLink link;
  final VoiceRecordController controller;
  final Animation<double> appear;
  final Animation<double> hintFade;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.center,
          followerAnchor: Alignment.center,
          child: _BigCircle(controller: controller, appear: appear),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -30),
          child: _Lock(controller: controller),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.topRight,
          followerAnchor: Alignment.bottomRight,
          offset: const Offset(4, -14),
          child: FadeTransition(
            opacity: hintFade,
            child: _HintBubble(controller: controller),
          ),
        ),
      ],
    );
  }
}

/// The accent circle under the pointer, with a halo that breathes with the
/// voice. Locked, it is the send button.
class _BigCircle extends StatefulWidget {
  const _BigCircle({required this.controller, required this.appear});

  final VoiceRecordController controller;
  final Animation<double> appear;

  static const double size = 120;
  static const double radius = 30;

  @override
  State<_BigCircle> createState() => _BigCircleState();
}

class _BigCircleState extends State<_BigCircle>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _level = 0;
  final _levelNotifier = ValueNotifier(0.0);
  late final _scale = CurvedAnimation(
    parent: widget.appear,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration _) {
    final peaks = widget.controller.recorder.peaks;
    final recording = widget.controller.isRecording;
    // The loudest of the last 60 ms, eased so the halo does not jitter.
    var peak = 0.0;
    for (var i = math.max(0, peaks.length - 3); i < peaks.length; i++) {
      peak = math.max(peak, peaks[i]);
    }
    final target = recording ? meterLevel(peak) : 0.0;
    _level += (target - _level) * (target > _level ? 0.35 : 0.12);
    if ((_levelNotifier.value - _level).abs() > 0.002) {
      _levelNotifier.value = _level;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scale.dispose();
    _levelNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final locked = controller.phase == RecordPhase.locked;
        final armed = controller.cancelArmed;
        final color = armed ? c.fg2 : c.accent;
        final circle = SizedBox.square(
          dimension: _BigCircle.size,
          child: ScaleTransition(
            scale: _scale,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 180),
              builder: (context, color, _) => CustomPaint(
                painter: _CirclePainter(
                  level: _levelNotifier,
                  color: color ?? c.accent,
                  radius: _BigCircle.radius,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, a) => ScaleTransition(
                      scale: a,
                      child: FadeTransition(opacity: a, child: child),
                    ),
                    child: MgIcon(
                      locked ? MgIcons.send : MgIcons.mic,
                      key: ValueKey(locked),
                      size: locked ? 22 : 24,
                      stroke: locked ? 2.4 : 2,
                      color: c.onAccent,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (!locked) return IgnorePointer(child: circle);
        // Only the circle itself takes the click, not the halo around it.
        return SizedBox.square(
          dimension: _BigCircle.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              IgnorePointer(child: circle),
              SizedBox.square(
                dimension: _BigCircle.radius * 2,
                child: Semantics(
                  button: true,
                  label: l10n.send,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => unawaited(controller.send()),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CirclePainter extends CustomPainter {
  _CirclePainter({
    required this.level,
    required this.color,
    required this.radius,
  }) : super(repaint: level);

  final ValueListenable<double> level;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final l = level.value;
    canvas
      ..drawCircle(
        center,
        radius + 6 + l * 22,
        Paint()..color = color.withValues(alpha: 0.16),
      )
      ..drawCircle(
        center,
        radius + 2 + l * 10,
        Paint()..color = color.withValues(alpha: 0.22),
      )
      ..drawCircle(center, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_CirclePainter old) =>
      old.color != color || old.radius != radius || old.level != level;
}

/// The lock above the circle: an open shackle and a nudging chevron while
/// held, a closed lock for a moment once locked.
class _Lock extends StatefulWidget {
  const _Lock({required this.controller});

  final VoiceRecordController controller;

  @override
  State<_Lock> createState() => _LockState();
}

class _LockState extends State<_Lock> with SingleTickerProviderStateMixin {
  late final _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _justLocked = false;
  Timer? _lockedTimer;
  RecordPhase _phase = RecordPhase.idle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _changed();
  }

  void _changed() {
    final phase = widget.controller.phase;
    if (phase != _phase) {
      if (phase == RecordPhase.locked) {
        _justLocked = true;
        _lockedTimer?.cancel();
        _lockedTimer = Timer(const Duration(milliseconds: 650), () {
          if (mounted) setState(() => _justLocked = false);
        });
      } else if (phase != RecordPhase.sending) {
        _justLocked = false;
      }
      if (phase == RecordPhase.holding) {
        unawaited(_nudge.repeat(reverse: true));
      } else {
        _nudge.stop();
      }
      _phase = phase;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _lockedTimer?.cancel();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final controller = widget.controller;
    final holding = controller.phase == RecordPhase.holding;
    final visible = (holding && !controller.cancelArmed) || _justLocked;
    final progress = _justLocked ? 1.0 : controller.lockProgress;
    final closed = controller.phase == RecordPhase.locked;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: Duration(milliseconds: visible ? 220 : 260),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 0.25),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Transform.translate(
            offset: Offset(0, -14 * progress),
            child: Glass(
              radius: 16,
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: SizedBox(
                width: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, a) =>
                          ScaleTransition(scale: a, child: child),
                      child: MgIcon(
                        closed ? MgIcons.lock : MgIcons.lockOpen,
                        key: ValueKey(closed),
                        size: 16,
                        color: Color.lerp(c.fg2, c.accent, progress),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedBuilder(
                      animation: _nudge,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(
                          0,
                          -3 * Curves.easeInOut.transform(_nudge.value),
                        ),
                        child: child,
                      ),
                      child: Opacity(
                        opacity: (1 - progress * 1.5).clamp(0.0, 1.0),
                        child: MgIcon(
                          MgIcons.chevronUp,
                          size: 14,
                          color: c.fg2,
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
    );
  }
}

/// A note above the record button: how to record, or what went wrong.
class _HintBubble extends StatelessWidget {
  const _HintBubble({required this.controller});

  final VoiceRecordController controller;

  static final _privacySettings = Uri.parse(
    'x-apple.systempreferences:com.apple.preference.security'
    '?Privacy_Microphone',
  );

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hint = controller.hint;
        // Keeps the last text while fading out.
        if (hint == null) return const SizedBox.shrink();
        final text = switch (hint) {
          RecordHint.holdToRecord => l10n.voiceHoldToRecord,
          RecordHint.microphoneDenied => l10n.voiceMicrophoneDenied,
          RecordHint.failed => l10n.voiceRecordFailed,
        };
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Glass(
            radius: 12,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: mgTextStyle(c, size: MgType.small)),
                if (hint == RecordHint.microphoneDenied)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          controller.dismissHint();
                          unawaited(launchUrl(_privacySettings));
                        },
                        child: Text(
                          l10n.voiceOpenSettings,
                          style: mgTextStyle(
                            c,
                            size: MgType.small,
                            color: c.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Takes the place of the text field while recording: a blinking dot, the
/// time and the voice drawn as it comes in. Locked, a bin on the left
/// throws the recording away.
class _RecordingBar extends StatefulWidget {
  const _RecordingBar({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final VoiceRecordController controller;
  final FocusNode focusNode;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  final _elapsed = ValueNotifier(Duration.zero);
  late final _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  late final _dotOpacity = Tween(
    begin: 1.0,
    end: 0.25,
  ).chain(CurveTween(curve: Curves.easeInOut)).animate(_blink);

  @override
  void initState() {
    super.initState();
    // The bar appears when recording starts, so its ticker is the clock;
    // frame time keeps the timer and the waveform in step.
    _ticker = createTicker((elapsed) {
      if (widget.controller.isRecording) _elapsed.value = elapsed;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _blink.dispose();
    _elapsed.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = widget.controller;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      unawaited(controller.cancel());
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        controller.phase == RecordPhase.locked) {
      unawaited(controller.send());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final controller = widget.controller;
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: _onKey,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final locked = controller.phase == RecordPhase.locked;
          final armed = controller.cancelArmed;
          return SizedBox(
            height: 32,
            child: Row(
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: locked
                      ? MgIconButton(
                          icon: MgIcons.trash,
                          tooltip: l10n.voiceDelete,
                          iconSize: 18,
                          onPressed: () => unawaited(controller.cancel()),
                        )
                      : const SizedBox(width: 10, height: 32),
                ),
                const SizedBox(width: 6),
                FadeTransition(
                  opacity: _dotOpacity,
                  child: const SizedBox.square(
                    dimension: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder(
                  valueListenable: _elapsed,
                  builder: (context, elapsed, _) => Text(
                    formatRecordingTime(elapsed),
                    style: mgTextStyle(c, size: MgType.title).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: armed
                        ? Center(
                            key: const ValueKey('armed'),
                            child: Text(
                              l10n.voiceReleaseToCancel,
                              style: mgTextStyle(c, color: _red),
                            ),
                          )
                        : SizedBox.expand(
                            key: const ValueKey('wave'),
                            child: CustomPaint(
                              painter: _LiveWaveformPainter(
                                peaks: controller.recorder.peaks,
                                elapsed: _elapsed,
                                color: c.accent,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// `0:07,45`: minutes, seconds and hundredths, as the official apps show
/// a recording.
String formatRecordingTime(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  final hundredths = d.inMilliseconds % 1000 ~/ 10;
  return '$minutes:${seconds.toString().padLeft(2, '0')},'
      '${hundredths.toString().padLeft(2, '0')}';
}

/// The voice as it is recorded: one bar per 60 ms, entering on the right
/// and gliding left with the clock, fading out at the left edge.
class _LiveWaveformPainter extends CustomPainter {
  _LiveWaveformPainter({
    required this.peaks,
    required this.elapsed,
    required this.color,
  }) : super(repaint: elapsed);

  final List<double> peaks;
  final ValueListenable<Duration> elapsed;
  final Color color;

  static const _bar = 2.5;
  static const _gap = 2.0;
  static const _peaksPerBar = 3;
  static const _barMs = 20.0 * _peaksPerBar;
  static const _fade = 36.0;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = peaks.length ~/ _peaksPerBar;
    if (bars == 0) return;
    final now = elapsed.value.inMicroseconds / 1000;
    const step = _bar + _gap;
    final paint = Paint();
    for (var i = bars - 1; i >= 0; i--) {
      // Bars hold their place in time; the newest may lag the clock by a
      // batch, so it never runs ahead of the right edge.
      final age = math.max(0.0, now - (i + 1) * _barMs) / _barMs;
      final x = size.width - _bar - age * step;
      if (x < -_bar) break;
      var peak = 0.0;
      for (var j = i * _peaksPerBar; j < (i + 1) * _peaksPerBar; j++) {
        peak = math.max(peak, peaks[j]);
      }
      final h = math.max(2.0, size.height * 0.62 * meterLevel(peak));
      final fade = (x / _fade).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: color.a * fade);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, _bar, h),
          const Radius.circular(_bar / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter old) =>
      old.peaks != peaks || old.color != color || old.elapsed != elapsed;
}
