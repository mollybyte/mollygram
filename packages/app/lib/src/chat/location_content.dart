import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import 'formatted_text.dart';
import 'td_file.dart';

/// A place in a message: a map around it with a pin, as Telegram for
/// macOS draws locations, and under it the venue's name and address or
/// how long a live location still runs. [avatar] stands in the pin for a
/// live location, as the official apps show who is sharing. A click
/// opens the place in Maps.
class LocationContent extends ConsumerStatefulWidget {
  const LocationContent({
    super.key,
    required this.location,
    this.venue,
    this.live,
    this.avatar,
    this.chatId = 0,
  });

  final td.Location location;
  final td.Venue? venue;

  /// Set for a live location: the message's content, for the time left.
  final td.MessageLiveLocation? live;
  final Widget? avatar;
  final int chatId;

  static const double width = 300;
  static const double height = 170;

  @override
  ConsumerState<LocationContent> createState() => _LocationContentState();
}

class _LocationContentState extends ConsumerState<LocationContent> {
  late Future<td.File?> _map = _load();

  Future<td.File?> _load() async {
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return null;
    try {
      return await session.files.mapThumbnail(
        widget.location,
        width: LocationContent.width.round(),
        height: LocationContent.height.round(),
        chatId: widget.chatId,
      );
    } on td.TdException {
      return null;
    }
  }

  @override
  void didUpdateWidget(LocationContent old) {
    super.didUpdateWidget(old);
    if (old.location.latitude != widget.location.latitude ||
        old.location.longitude != widget.location.longitude) {
      _map = _load();
    }
  }

  void _open() {
    final l = widget.location;
    openLink(
      'https://maps.apple.com/?ll=${l.latitude},${l.longitude}'
      '&q=${l.latitude},${l.longitude}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final venue = widget.venue;
    final live = widget.live;
    final (String? title, String? subtitle) = switch ((venue, live)) {
      (final td.Venue venue, _) => (venue.title, venue.address),
      (_, final td.MessageLiveLocation live) => (
        l10n.contentLiveLocation,
        _timeLeft(l10n, live.expiresIn),
      ),
      _ => (null, null),
    };
    final map = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: LocationContent.width,
        height: LocationContent.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<td.File?>(
              future: _map,
              builder: (context, snapshot) {
                final file = snapshot.data;
                final below = ColoredBox(color: c.datePill);
                if (file == null) return below;
                return TdImage(
                  file: file,
                  fit: BoxFit.cover,
                  background: c.datePill,
                );
              },
            ),
            // The pin's tip sits on the place, in the middle of the map.
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: const Offset(0, -_Pin.height / 2),
                child: _Pin(avatar: widget.avatar, accent: c.accent),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.fg.withValues(alpha: 0.08)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _open,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            map,
            if (title != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: LocationContent.width,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, weight: FontWeight.w600),
                ),
              ),
            ],
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 1),
              SizedBox(
                width: LocationContent.width,
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mgTextStyle(c, size: MgType.caption, color: c.fg2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _timeLeft(AppLocalizations l10n, int seconds) {
    if (seconds <= 0) return l10n.liveLocationEnded;
    if (seconds >= 3600) return l10n.liveHoursLeft(seconds ~/ 3600);
    return l10n.liveMinutesLeft((seconds / 60).ceil());
  }
}

/// A drop-shaped pin in the accent colour with a white dot, or with the
/// sharer's [avatar] for a live location.
class _Pin extends StatelessWidget {
  const _Pin({required this.avatar, required this.accent});

  final Widget? avatar;
  final Color accent;

  static const double height = 40;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(30, height),
    painter: _PinPainter(accent),
    child: SizedBox(
      width: 30,
      height: height,
      child: Align(
        alignment: const Alignment(0, -0.62),
        child: switch (avatar) {
          final avatar? => ClipOval(
            child: SizedBox(width: 22, height: 22, child: avatar),
          ),
          null => const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 10, height: 10),
          ),
        },
      ),
    ),
  );
}

class _PinPainter extends CustomPainter {
  const _PinPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final path = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r))
      ..moveTo(r - r * 0.62, r + r * 0.78)
      ..lineTo(r, size.height)
      ..lineTo(r + r * 0.62, r + r * 0.78)
      ..close();
    canvas.drawShadow(path, const Color(0x66000000), 3, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}
