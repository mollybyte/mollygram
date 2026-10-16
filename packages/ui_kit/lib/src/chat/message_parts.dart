import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// The color of a sender's name for Telegram's accent color [id]: the seven
/// built-in colors, lighter on the dark theme. Ids above 6 are profile
/// colors from the server; they fall back to the built-in ones.
Color peerNameColor(MgColors c, int id) {
  const light = [
    Color(0xFFD9443B),
    Color(0xFFDE7012),
    Color(0xFF8E4FE0),
    Color(0xFF35A512),
    Color(0xFF1F9BBF),
    Color(0xFF2B84D6),
    Color(0xFFD13F86),
  ];
  const dark = [
    Color(0xFFFF6B61),
    Color(0xFFFF9A40),
    Color(0xFFAA85FF),
    Color(0xFF66CF45),
    Color(0xFF3FC3E2),
    Color(0xFF55A9F7),
    Color(0xFFF7649F),
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

/// A forwarded message: a rounded bar in the source's colour down its
/// left side, with the source's name and the original date at the top,
/// as in Telegram for macOS.
class ForwardedBlock extends StatelessWidget {
  const ForwardedBlock({
    super.key,
    required this.source,
    required this.child,
    this.date,
    this.color,
    this.onSourceTap,
  });

  final String source;

  /// When the original was posted, already formatted.
  final String? date;

  /// The source's name colour; the accent when unknown.
  final Color? color;
  final VoidCallback? onSourceTap;
  final Widget child;

  static const double barWidth = 2.5;
  static const double indent = 10;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final tint = color ?? c.accent;
    final nameStyle = mgTextStyle(c, weight: FontWeight.w500, color: tint);
    final dateStyle = mgTextStyle(c, size: MgType.small, color: c.fg2);
    final title = onSourceTap == null
        ? Text.rich(
            TextSpan(
              children: [
                TextSpan(text: source, style: nameStyle),
                if (date case final date?)
                  TextSpan(text: '  $date', style: dateStyle),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        // A name that opens its source: the date stays plain beside it.
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: _SourceName(
                  text: source,
                  style: nameStyle,
                  onTap: onSourceTap!,
                ),
              ),
              if (date case final date?)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(date, style: dateStyle, maxLines: 1),
                ),
            ],
          );
    return CustomPaint(
      painter: _BarPainter(tint),
      child: Padding(
        padding: const EdgeInsets.only(left: indent, top: 1, bottom: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(bottom: 2), child: title),
            child,
          ],
        ),
      ),
    );
  }
}

/// The forward's source name as a link: a hand cursor, and a thin
/// underline that fades in under the pointer.
class _SourceName extends StatefulWidget {
  const _SourceName({
    required this.text,
    required this.style,
    required this.onTap,
  });

  final String text;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  State<_SourceName> createState() => _SourceNameState();
}

class _SourceNameState extends State<_SourceName> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.style.color ?? const Color(0xFF000000);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Text(
          widget.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(
            decoration: _hover ? TextDecoration.underline : TextDecoration.none,
            decorationColor: color.withValues(alpha: 0.55),
            decorationThickness: 1,
          ),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromLTRBR(
        0,
        0,
        ForwardedBlock.barWidth,
        size.height,
        const Radius.circular(ForwardedBlock.barWidth / 2),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.color != color;
}

/// The comments row under a channel post: the latest commenters' avatars
/// and how many comments there are, or an invitation to leave the first.
class CommentsRow extends StatefulWidget {
  const CommentsRow({
    super.key,
    required this.label,
    this.avatars = const [],
    this.unread = false,
    this.onTap,
  });

  final String label;

  /// Up to three small avatars, newest last.
  final List<Widget> avatars;

  /// Comments the user has not read yet: an accent dot after the label.
  final bool unread;
  final VoidCallback? onTap;

  @override
  State<CommentsRow> createState() => _CommentsRowState();
}

class _CommentsRowState extends State<CommentsRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final avatars = widget.avatars.take(3).toList();
    const side = 22.0;
    final row = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.only(top: 7, bottom: 2),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatars.isEmpty)
            MgIcon(MgIcons.comment, size: 18, color: c.accent)
          else
            SizedBox(
              width: side + (avatars.length - 1) * (side - 7),
              height: side,
              child: Stack(
                children: [
                  for (final (i, avatar) in avatars.indexed)
                    Positioned(
                      left: i * (side - 7),
                      child: Container(
                        width: side,
                        height: side,
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.windowBackground,
                        ),
                        child: ClipOval(child: avatar),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: mgTextStyle(
              c,
              weight: FontWeight.w500,
              color: c.accent.withValues(alpha: _hover ? 0.75 : 1),
            ),
          ),
          if (widget.unread)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Container(
                key: const ValueKey('unreadComments'),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent,
                ),
              ),
            ),
        ],
      ),
    );
    final onTap = widget.onTap;
    if (onTap == null) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

/// A reaction under a message: the emoji and how many people chose it.
/// Filled with the accent when the user is among them. Choosing it pops
/// the emoji and fills the chip, and the count rolls up or down.
class ReactionChip extends StatefulWidget {
  const ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.chosen,
    this.onTap,
    this.icon,
  });

  /// The emoji, or the semantics of [icon].
  final String emoji;

  /// Drawn in place of the [emoji], [iconSize] wide: a custom emoji's
  /// sticker.
  final Widget? icon;

  static const double iconSize = 16;
  final int count;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  State<ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: MgMotion.pop,
  );

  /// Whether the count last went up, which decides the way it rolls.
  var _up = true;

  static final _emojiScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.32,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.32,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 60,
    ),
  ]);

  @override
  void didUpdateWidget(ReactionChip old) {
    super.didUpdateWidget(old);
    if (widget.count != old.count) _up = widget.count > old.count;
    if (widget.chosen && !old.chosen && !_reduced) {
      unawaited(_pop.forward(from: 0));
    }
  }

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  Widget _count(MgColors c, Color fg, Duration duration) {
    Widget text(int n) => Text(
      '$n',
      key: ValueKey(n),
      style: mgTextStyle(
        c,
        size: MgType.small,
        weight: FontWeight.w500,
        color: fg,
        height: 1.2,
      ),
    );
    return ClipRect(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: MgMotion.enter,
        switchOutCurve: MgMotion.exitCurve,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerLeft,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final entering = child.key == ValueKey(widget.count);
          // The new number comes in from the side it grew from; the old
          // one leaves the other way.
          final from = _up ? 0.7 : -0.7;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: Offset(0, entering ? from : -from),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: text(widget.count),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = widget.chosen ? c.onAccent : c.fg;
    final duration = _reduced ? Duration.zero : MgMotion.standard;
    final emoji =
        widget.icon ??
        Text(widget.emoji, style: mgTextStyle(c, size: 13, height: 1.2));
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: duration,
          curve: MgMotion.standardCurve,
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.chosen ? c.accent : c.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(scale: _pop.drive(_emojiScale), child: emoji),
              if (widget.count > 0) ...[
                const SizedBox(width: 4),
                if (duration == Duration.zero)
                  _count(c, fg, duration)
                else
                  AnimatedSize(
                    duration: duration,
                    curve: MgMotion.enter,
                    alignment: Alignment.centerLeft,
                    child: _count(c, fg, duration),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The reactions under a message. A reaction that appears after the row is
/// on screen, because someone just chose it, pops in; the ones that were
/// there from the start do not move.
class ReactionRow extends StatefulWidget {
  const ReactionRow({super.key, required this.chips});

  /// The chips by a key that names the reaction, in order.
  final List<(String, ReactionChip)> chips;

  @override
  State<ReactionRow> createState() => _ReactionRowState();
}

class _ReactionRowState extends State<ReactionRow> {
  final _animate = <String, bool>{};
  var _built = false;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final shown = {for (final (key, _) in widget.chips) key};
    _animate.removeWhere((key, _) => !shown.contains(key));
    for (final (key, _) in widget.chips) {
      _animate.putIfAbsent(key, () => _built && !reduced);
    }
    _built = true;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final (key, chip) in widget.chips)
          _PopIn(
            key: ValueKey(key),
            animate: _animate[key]! && !reduced,
            child: chip,
          ),
      ],
    );
  }
}

/// Scales and fades [child] in once, from its left edge.
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MgMotion.pop,
      curve: MgMotion.popCurve,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.6 + 0.4 * t,
          alignment: Alignment.centerLeft,
          child: child,
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
