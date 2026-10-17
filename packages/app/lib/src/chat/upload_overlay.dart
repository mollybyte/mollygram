import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import 'td_file.dart';

// Kept here, not in MgIcons, which every icon golden lists.
const _retryIcon = MgIconData(
  'retry',
  '<path d="M20 12a8 8 0 1 1-2.6-5.9L20 8.5M20 4v4.5h-4.5"/>',
);

/// The file a photo, video or GIF message uploads, or null for other
/// content.
td.File? uploadFileOf(td.MessageContent content) => switch (content) {
  td.MessagePhoto(:final photo) when photo.sizes.isNotEmpty =>
    photo.sizes.last.photo,
  td.MessageVideo(:final video) => video.video,
  td.MessageAnimation(:final animation) => animation.animation,
  _ => null,
};

/// How much of [file] has gone up, 0 to 1, or null before the upload has
/// started and its size is known.
double? uploadProgress(td.File file) {
  final total = file.size > 0 ? file.size : file.expectedSize;
  if (total <= 0) return null;
  final done = file.remote.uploadedSize;
  if (done <= 0 && !file.remote.isUploadingActive) return null;
  return (done / total).clamp(0.0, 1.0).toDouble();
}

/// [child], a photo, video or GIF, with its upload on top while the
/// message is still being sent: a progress ring that cancels the send, and
/// once it has failed, buttons to try again or delete it. Messages that
/// are sent show [child] alone.
Widget withUploadOverlay({
  required ConversationMessage message,
  required Widget child,
  void Function(ConversationMessage message)? onCancel,
  void Function(ConversationMessage message)? onRetry,
}) {
  if (message.sendState == MessageSendState.sent) return child;
  final file = uploadFileOf(message.content);
  if (file == null) return child;
  final failed = message.sendState == MessageSendState.failed;
  final state = message.message.sendingState;
  // TDLib resends only what it permits as is; the rest can only go.
  final canRetry =
      state is td.MessageSendingStateFailed &&
      state.canRetry &&
      state.retryAfter <= 0 &&
      !state.needAnotherSender &&
      !state.needAnotherReplyQuote &&
      !state.needDropReply &&
      state.requiredPaidMessageStarCount == 0;
  return Stack(
    fit: StackFit.passthrough,
    children: [
      child,
      Positioned.fill(
        child: TdFileBuilder(
          file: file,
          builder: (context, latest) => UploadBadge(
            progress: uploadProgress(latest),
            failed: failed,
            canRetry: canRetry,
            onCancel: onCancel == null ? null : () => onCancel(message),
            onRetry: onRetry == null ? null : () => onRetry(message),
          ),
        ),
      ),
    ],
  );
}

/// The upload layer of one tile: a soft scrim and, in the middle, a ring
/// that fills as the file goes up with a cross to stop it, or, after a
/// failure, a retry button and a delete button.
class UploadBadge extends StatefulWidget {
  const UploadBadge({
    super.key,
    required this.progress,
    required this.failed,
    this.canRetry = true,
    this.onCancel,
    this.onRetry,
  });

  /// 0 to 1, or null while the upload has not started.
  final double? progress;
  final bool failed;

  /// Whether the failed message can be sent again as it is.
  final bool canRetry;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  State<UploadBadge> createState() => _UploadBadgeState();
}

class _UploadBadgeState extends State<UploadBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _waiting => !widget.failed && widget.progress == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncSpin();
  }

  @override
  void didUpdateWidget(UploadBadge old) {
    super.didUpdateWidget(old);
    _syncSpin();
  }

  void _syncSpin() {
    if (_waiting && !MediaQuery.disableAnimationsOf(context)) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = widget.failed;
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: AnimatedContainer(
            duration: MgMotion.standard,
            curve: MgMotion.standardCurve,
            color: Color(failed ? 0x66000000 : 0x40000000),
          ),
        ),
        Center(
          // A narrow album cell shrinks the controls to fit.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: MgMotion.standard,
              switchInCurve: MgMotion.enter,
              switchOutCurve: MgMotion.exitCurve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: failed
                  ? Row(
                      key: const ValueKey('failed'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.canRetry) ...[
                          _RoundButton(
                            icon: _retryIcon,
                            label: l10n.retryUpload,
                            onTap: widget.onRetry,
                          ),
                          const SizedBox(width: 10),
                        ],
                        _RoundButton(
                          icon: MgIcons.trash,
                          label: l10n.discardUpload,
                          onTap: widget.onCancel,
                        ),
                      ],
                    )
                  : _RoundButton(
                      key: const ValueKey('sending'),
                      icon: MgIcons.close,
                      label: l10n.cancelUpload,
                      onTap: widget.onCancel,
                      ring: _spin,
                      progress: widget.progress,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A 40 px dark glass circle with an icon; with [progress] or [ring] a
/// ring runs around it. Brightens and grows a touch under the pointer.
class _RoundButton extends StatefulWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.ring,
    this.progress,
  });

  final MgIconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Spins the ring while the upload has not started.
  final Animation<double>? ring;
  final double? progress;

  @override
  State<_RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<_RoundButton> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    final ring = widget.ring;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hover ? 1.06 : 1,
            duration: MgMotion.fast,
            curve: MgMotion.standardCurve,
            child: AnimatedContainer(
              duration: MgMotion.fast,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(_hover ? 0x99000000 : 0x80000000),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.progress != null || ring != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(end: widget.progress ?? 0),
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => AnimatedBuilder(
                            animation: ring ?? const AlwaysStoppedAnimation(0),
                            builder: (context, _) => CustomPaint(
                              painter: _UploadRingPainter(
                                progress: widget.progress == null
                                    ? 0.22
                                    : math.max(value, 0.03),
                                turn: widget.progress == null
                                    ? (ring?.value ?? 0)
                                    : 0,
                                color: white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  MgIcon(
                    widget.icon,
                    size: 16,
                    color: white.withValues(alpha: _hover ? 1 : 0.88),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadRingPainter extends CustomPainter {
  _UploadRingPainter({
    required this.progress,
    required this.turn,
    required this.color,
  });

  final double progress;

  /// A full turn is 1; rotates the arc while waiting.
  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final arc = rect.deflate(paint.strokeWidth / 2);
    canvas.drawArc(
      arc,
      0,
      math.pi * 2,
      false,
      paint..color = color.withValues(alpha: 0.2),
    );
    canvas.drawArc(
      arc,
      -math.pi / 2 + turn * math.pi * 2,
      math.pi * 2 * progress,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_UploadRingPainter old) =>
      old.progress != progress || old.turn != turn || old.color != color;
}
