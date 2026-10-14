import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The color of a sender's name for Telegram's accent color [id]: the seven
/// built-in colors, lighter on the dark theme. Ids above 6 are profile
/// colors from the server; they fall back to the built-in ones.
Color peerNameColor(MgColors c, int id) {
  const light = [
    Color(0xFFCC5049),
    Color(0xFFD67722),
    Color(0xFF955CDB),
    Color(0xFF40A920),
    Color(0xFF309EBA),
    Color(0xFF368AD1),
    Color(0xFFC7508B),
  ];
  const dark = [
    Color(0xFFFF7B72),
    Color(0xFFFFA357),
    Color(0xFFB794FF),
    Color(0xFF7BD15C),
    Color(0xFF5CC8E0),
    Color(0xFF6CB2F2),
    Color(0xFFF07AB3),
  ];
  final palette = c.brightness == Brightness.dark ? dark : light;
  return palette[id.abs() % palette.length];
}

/// The quote of the message a reply answers: an accent bar, the author and
/// one line of the text. Tapping it jumps to the original.
class ReplyHeader extends StatelessWidget {
  const ReplyHeader({
    super.key,
    required this.author,
    required this.text,
    this.thumbnail,
    this.onTap,
  });

  final String author;

  /// One line of the original, or "Photo", "Deleted message" and so on.
  final String text;

  /// A small preview of the original's media.
  final Widget? thumbnail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final header = Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (thumbnail != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox.square(dimension: 32, child: thumbnail),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(
                    c,
                    size: MgType.small,
                    weight: FontWeight.w600,
                    color: c.accent,
                    height: 1.3,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, size: MgType.small, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return header;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: header),
    );
  }
}

/// "Forwarded from …" over a forwarded message.
class ForwardHeader extends StatelessWidget {
  const ForwardHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: mgTextStyle(
        c,
        size: MgType.small,
        weight: FontWeight.w500,
        color: c.accent,
        height: 1.3,
      ),
    );
  }
}

/// A reaction under a message: the emoji and how many people chose it.
/// Filled with the accent when the user is among them.
class ReactionChip extends StatelessWidget {
  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.chosen,
    this.onTap,
  });

  /// The emoji; custom emoji are drawn by their fallback emoji for now.
  final String emoji;
  final int count;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = chosen ? c.onAccent : c.fg;
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: chosen ? c.accent : c.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: mgTextStyle(c, size: 13, height: 1.2)),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: mgTextStyle(
                    c,
                    size: MgType.small,
                    weight: FontWeight.w500,
                    color: fg,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A chat event ("Anna joined the group") centered over the wallpaper.
class ServiceMessage extends StatelessWidget {
  const ServiceMessage(this.text, {super.key, this.child});

  final String text;

  /// Something shown under the text, such as a new group photo.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: c.datePill,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: mgTextStyle(
                    c,
                    size: MgType.small,
                    weight: FontWeight.w500,
                    color: const Color(0xFFFFFFFF),
                    height: 1.35,
                  ),
                ),
              ),
              if (child != null) ...[const SizedBox(height: 6), child!],
            ],
          ),
        ),
      ),
    );
  }
}

/// The waveform of a voice message, with the played part in full color.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.samples,
    required this.progress,
    required this.color,
    this.height = 20,
  });

  /// Bar heights from 0 to 31, as Telegram encodes them.
  final List<int> samples;

  /// 0 to 1: how much has been played.
  final double progress;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: CustomPaint(
      painter: _WaveformPainter(samples, progress, color),
      size: Size.infinite,
    ),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.samples, this.progress, this.color);

  final List<int> samples;
  final double progress;
  final Color color;

  static const double _bar = 2.5;
  static const double _gap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final count = ((size.width + _gap) / (_bar + _gap)).floor();
    if (count <= 0) return;
    final played = Paint()..color = color;
    final rest = Paint()..color = color.withValues(alpha: 0.35);
    for (var i = 0; i < count; i++) {
      // Resample the bars to the width available.
      final value = samples.isEmpty
          ? 0
          : samples[(i * samples.length / count).floor().clamp(
              0,
              samples.length - 1,
            )];
      final h = math.max(2.0, size.height * value / 31);
      final x = i * (_bar + _gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, _bar, h),
          const Radius.circular(1.25),
        ),
        (i + 0.5) / count <= progress ? played : rest,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.color != color ||
      !identical(old.samples, samples);
}

/// The round button of files and voice messages: download, cancel, play
/// or pause, with the download progress as a ring around it.
class MediaActionButton extends StatelessWidget {
  const MediaActionButton({
    super.key,
    required this.icon,
    required this.size,
    this.progress,
    this.onTap,
    this.semanticLabel,
    this.background,
  });

  final MgIconData icon;
  final double size;

  /// 0 to 1 while downloading, otherwise null.
  final double? progress;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Defaults to the accent.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final progress = this.progress;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: background ?? c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.expand(),
                ),
                MgIcon(icon, size: size * 0.45, color: c.onAccent),
                if (progress != null)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: CustomPaint(
                        painter: _RingPainter(progress, c.onAccent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color);

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Offset.zero & size,
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.02, 1),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// A link preview inside a text bubble: site name, title, description and
/// an optional picture, with an accent bar on the left.
class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    super.key,
    this.siteName = '',
    this.title = '',
    this.description = '',
    this.image,
    this.largeImage = false,
    this.onTap,
  });

  final String siteName;
  final String title;
  final String description;
  final Widget? image;

  /// Draws [image] full width under the text instead of as a thumbnail.
  final bool largeImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final texts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (siteName.isNotEmpty)
          Text(
            siteName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mgTextStyle(
              c,
              size: MgType.small,
              weight: FontWeight.w600,
              color: c.accent,
              height: 1.3,
            ),
          ),
        if (title.isNotEmpty)
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: mgTextStyle(
              c,
              size: MgType.small,
              weight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        if (description.isNotEmpty)
          Text(
            description,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: mgTextStyle(c, size: MgType.small, height: 1.3),
          ),
      ],
    );
    final card = Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: c.accent, width: 3)),
      ),
      child: image == null
          ? texts
          : largeImage
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                texts,
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: texts),
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(dimension: 52, child: image),
                ),
              ],
            ),
    );
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
