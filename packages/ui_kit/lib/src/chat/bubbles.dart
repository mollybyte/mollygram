import 'package:flutter/widgets.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The largest width of a text bubble.
const double kMaxBubbleWidth = 420;

/// Corner radii of a bubble: 16, with a 5 px tail corner at the bottom on
/// the sender's side.
BorderRadius bubbleRadius({required bool outgoing}) => outgoing
    ? const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(5),
      )
    : const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(5),
        bottomRight: Radius.circular(16),
      );

/// The solid bubble decoration (`.bin` / `.bout`). Bubbles are never glass.
BoxDecoration bubbleDecoration(MgColors c, {required bool outgoing}) =>
    BoxDecoration(
      color: outgoing ? c.bubbleOut : c.bubbleIn,
      borderRadius: bubbleRadius(outgoing: outgoing),
      boxShadow: c.bubbleShadow == null
          ? null
          : [
              BoxShadow(
                color: c.bubbleShadow!,
                offset: const Offset(0, 1),
                blurRadius: 1,
              ),
            ],
    );

/// Delivery state of an outgoing message.
enum MessageStatus {
  /// Incoming messages, and outgoing ones with no ticks shown.
  none,
  sending,
  sent,
  read,

  /// The server rejected the message; drawn in red.
  failed,
}

/// The time of a message with its delivery ticks, and an optional label in
/// front of it ("edited", "deleted"; localized by the app).
class MessageMeta extends StatelessWidget {
  const MessageMeta({
    super.key,
    required this.time,
    this.status = MessageStatus.none,
    this.label,
    this.color,
  });

  final String time;
  final MessageStatus status;
  final String? label;

  /// Defaults to the secondary text color.
  final Color? color;

  static const double _tickSize = 14;
  static const double _tickGap = 2;
  static const double _labelGap = 12;

  static MgIconData? _tick(MessageStatus status) => switch (status) {
    MessageStatus.none => null,
    MessageStatus.sending => MgIcons.sending,
    MessageStatus.sent => MgIcons.sent,
    MessageStatus.read => MgIcons.readTicks,
    MessageStatus.failed => MgIcons.failed,
  };

  /// The red of a message that was not sent.
  static const Color failedColor = Color(0xFFFF3B30);

  static TextStyle styleOf(MgColors c, {Color? color}) =>
      mgTextStyle(c, size: MgType.meta, color: color ?? c.fg2, height: 1.35);

  /// The laid out width of a meta, used to leave room for it after text.
  static double widthOf(
    BuildContext context, {
    required String time,
    MessageStatus status = MessageStatus.none,
    String? label,
  }) {
    final style = styleOf(MgColors.of(context));
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(String s) {
      final p = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    var width = measure(time);
    if (_tick(status) != null) width += _tickGap + _tickSize;
    if (label != null) width += measure(label) + _labelGap;
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = styleOf(c, color: color);
    final tick = _tick(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(label!, style: style),
          const SizedBox(width: _labelGap),
        ],
        Text(time, style: style),
        if (tick != null) ...[
          const SizedBox(width: _tickGap),
          MgIcon(
            tick,
            size: _tickSize,
            color: status == MessageStatus.failed ? failedColor : style.color,
          ),
        ],
      ],
    );
  }
}

/// A solid bubble around [child], aligned to the sender's side.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.outgoing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(11, 7, 11, 5),
    this.width,
  });

  final bool outgoing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// A fixed width for media and files; text bubbles hug their content up
  /// to [kMaxBubbleWidth].
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: width,
      constraints: width == null
          ? const BoxConstraints(maxWidth: kMaxBubbleWidth)
          : null,
      padding: padding,
      decoration: bubbleDecoration(c, outgoing: outgoing),
      child: DefaultTextStyle.merge(style: mgTextStyle(c), child: child),
    );
  }
}

/// A text message. The time sits in the bottom-right corner and the text
/// flows around it, as in Telegram: an invisible spacer the width of the
/// meta is appended to the last line.
class TextMessageBubble extends StatelessWidget {
  const TextMessageBubble({
    super.key,
    required this.text,
    required this.time,
    required this.outgoing,
    this.status = MessageStatus.none,
    this.label,
    this.dimmed = false,
    this.sender,
  });

  final String text;

  /// The author's name over the text, for incoming messages in groups.
  final String? sender;
  final String time;
  final bool outgoing;
  final MessageStatus status;

  /// "edited" or "deleted", localized by the app.
  final String? label;

  /// Draws the bubble faded, for a message that was deleted but kept.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final metaWidth = MessageMeta.widthOf(
      context,
      time: time,
      status: status,
      label: label,
    );
    final body = Stack(
      children: [
        Text.rich(
          TextSpan(
            text: text,
            children: [
              WidgetSpan(child: SizedBox(width: metaWidth + 8, height: 14)),
            ],
          ),
        ),
        Positioned(
          right: 0,
          bottom: -1,
          child: MessageMeta(time: time, status: status, label: label),
        ),
      ],
    );
    final sender = this.sender;
    final bubble = MessageBubble(
      outgoing: outgoing,
      child: sender == null
          ? body
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(
                    MgColors.of(context),
                    weight: FontWeight.w600,
                    color: MgColors.of(context).accent,
                  ),
                ),
                const SizedBox(height: 1),
                body,
              ],
            ),
    );
    return dimmed ? Opacity(opacity: 0.55, child: bubble) : bubble;
  }
}

/// The date separator over the wallpaper.
class DatePill extends StatelessWidget {
  const DatePill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: c.datePill,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            text,
            style: mgTextStyle(
              c,
              size: MgType.small,
              weight: FontWeight.w500,
              color: const Color(0xFFFFFFFF),
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

/// The dark pill with the time over photos and video messages.
class MediaPill extends StatelessWidget {
  const MediaPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.mediaPill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: mgTextStyle(
          c,
          size: MgType.meta,
          color: const Color(0xFFFFFFFF),
          height: 1.35,
        ),
      ),
    );
  }
}
