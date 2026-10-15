import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../profile/manage_sheet.dart';
import '../session/providers.dart';
import 'td_file.dart';

/// What the location sheet picked: a point on the map or a venue.
sealed class LocationChoice {
  const LocationChoice();
}

final class PointChoice extends LocationChoice {
  const PointChoice(this.location);
  final td.Location location;
}

final class VenueChoice extends LocationChoice {
  const VenueChoice(this.venue);
  final td.Venue venue;
}

/// Asks which place to send, as Telegram for macOS offers under the
/// attach button: a map to pan and zoom with the pin in its middle, a
/// field that takes a place name for the venue search, coordinates or a
/// map link, and the venues found around the pin. Null when dismissed.
Future<LocationChoice?> pickLocation(
  BuildContext context, {
  required int chatId,
}) => showManageSheet<LocationChoice>(context, _LocationPicker(chatId: chatId));

/// Coordinates in [text]: "48.8566, 2.3522" or a maps link that carries
/// them; null when there are none. One of the two has a decimal point,
/// so a house number and a postcode don't pass as a place.
td.Location? parseCoordinates(String text) {
  for (final m in _coordinates.allMatches(text)) {
    final lat = double.tryParse(m[1]!);
    final lon = double.tryParse(m[2]!);
    if (lat == null || lon == null) continue;
    if (lat.abs() > 90 || lon.abs() > 180) continue;
    if (!m[1]!.contains('.') && !m[2]!.contains('.')) continue;
    return td.Location(latitude: lat, longitude: lon, horizontalAccuracy: 0);
  }
  return null;
}

final _coordinates = RegExp(
  r'(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)',
);

class _LocationPicker extends ConsumerStatefulWidget {
  const _LocationPicker({required this.chatId});

  final int chatId;

  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  /// Where the map was left last time, so the sheet opens there again.
  static td.Location? _lastCenter;
  static int _lastZoom = 15;

  final _search = TextEditingController();
  td.Location? _center = _lastCenter;
  int _zoom = _lastZoom;
  Future<td.File?>? _map;
  Size _mapSize = Size.zero;

  /// How far the map has been dragged since the last fetch.
  Offset _drag = Offset.zero;

  Timer? _debounce;
  var _venues = const <td.Venue>[];
  var _searched = false;
  var _searching = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (_center != null) _map = _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<td.File?> _load() async {
    final center = _center;
    if (center == null || _mapSize.isEmpty) return null;
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return null;
    try {
      return await session.files.mapThumbnail(
        center,
        width: _mapSize.width.round(),
        height: _mapSize.height.round(),
        zoom: _zoom,
        chatId: widget.chatId,
      );
    } on td.TdException {
      return null;
    }
  }

  void _moveTo(td.Location center, {int? zoom}) {
    setState(() {
      _center = _lastCenter = center;
      if (zoom != null) _zoom = _lastZoom = zoom;
      _drag = Offset.zero;
      _map = _load();
    });
  }

  void _zoomBy(int step) {
    final zoom = (_zoom + step).clamp(_minZoom, _maxZoom);
    if (zoom == _zoom || _center == null) return;
    _moveTo(_center!, zoom: zoom);
  }

  /// The map was dragged by [_drag]: the point under its middle moves
  /// the other way, by the Web Mercator metres a pixel covers at this
  /// zoom.
  void _dragEnd() {
    final center = _center;
    if (center == null || _drag == Offset.zero) return;
    final worldPx = 256 * math.pow(2, _zoom).toDouble();
    final x = (center.longitude + 180) / 360 * worldPx - _drag.dx;
    final latRad = center.latitude * math.pi / 180;
    final mercator = math.log(math.tan(math.pi / 4 + latRad / 2));
    final y = (0.5 - mercator / (2 * math.pi)) * worldPx - _drag.dy;
    final lon = x / worldPx * 360 - 180;
    final lat =
        (2 * math.atan(math.exp((0.5 - y / worldPx) * 2 * math.pi)) -
            math.pi / 2) *
        180 /
        math.pi;
    _moveTo(
      td.Location(
        latitude: lat.clamp(-85.0, 85.0),
        longitude: ((lon + 180) % 360) - 180,
        horizontalAccuracy: 0,
      ),
    );
    _searchVenues();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final place = parseCoordinates(text);
    if (place != null) {
      _moveTo(place);
      setState(() {
        _venues = const [];
        _searched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _searchVenues);
  }

  Future<void> _searchVenues() async {
    final center = _center;
    final query = _search.text.trim();
    if (center == null || parseCoordinates(query) != null) return;
    final session = ref.read(telegramSessionProvider).asData?.value;
    if (session == null) return;
    final request = ++_request;
    setState(() => _searching = true);
    List<td.Venue> venues;
    try {
      venues = await session.conversations.searchVenues(
        widget.chatId,
        query,
        center,
      );
    } on td.TdException {
      venues = const [];
    }
    if (!mounted || request != _request) return;
    setState(() {
      _venues = venues;
      _searched = true;
      _searching = false;
    });
  }

  static const _minZoom = 13;
  static const _maxZoom = 20;
  static const _mapHeight = 190.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    final center = _center;
    return ManageSheetFrame(
      title: l10n.sendLocationTitle,
      height: 520,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MgSearchField(
            controller: _search,
            hintText: l10n.locationSearchHint,
            onChanged: _onChanged,
            onSubmitted: (_) => _searchVenues(),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _mapHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, _mapHeight);
                if (size != _mapSize) {
                  _mapSize = size;
                  if (center != null) _map = _load();
                }
                return _buildMap(context, center);
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: center == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        l10n.locationStartHint,
                        textAlign: TextAlign.center,
                        style: mgTextStyle(c, color: c.fg2),
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      _PlaceRow(
                        key: const ValueKey('send-this-location'),
                        tile: _PinTile(color: c.accent),
                        title: l10n.sendThisLocation,
                        subtitle: _format(center),
                        onTap: () =>
                            Navigator.of(context).pop(PointChoice(center)),
                      ),
                      for (final venue in _venues)
                        _PlaceRow(
                          tile: _LetterTile(venue.title),
                          title: venue.title,
                          subtitle: venue.address,
                          onTap: () =>
                              Navigator.of(context).pop(VenueChoice(venue)),
                        ),
                      if (_searched && !_searching && _venues.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l10n.nothingFound,
                            textAlign: TextAlign.center,
                            style: mgTextStyle(c, color: c.fg2),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, td.Location? center) {
    final l10n = AppLocalizations.of(context);
    final c = MgColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: c.datePill),
          if (center != null) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) => setState(() => _drag += d.delta),
              onPanEnd: (_) => _dragEnd(),
              onPanCancel: _dragEnd,
              onDoubleTap: () => _zoomBy(1),
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Transform.translate(
                  offset: _drag,
                  child: FutureBuilder<td.File?>(
                    future: _map,
                    builder: (context, snapshot) {
                      final file = snapshot.data;
                      if (file == null) return const SizedBox.expand();
                      return TdImage(
                        file: file,
                        fit: BoxFit.cover,
                        background: c.datePill,
                      );
                    },
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  offset: const Offset(0, -_pinHeight / 2),
                  child: CustomPaint(
                    size: const Size(30, _pinHeight),
                    painter: _PinPainter(c.accent),
                    child: const SizedBox(
                      width: 30,
                      height: _pinHeight,
                      child: Align(
                        alignment: Alignment(0, -0.62),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color(0xFFFFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 10, height: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Glass(
                radius: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MgIconButton(
                      icon: MgIcons.plus,
                      tooltip: l10n.mapZoomIn,
                      onPressed: _zoom < _maxZoom ? () => _zoomBy(1) : null,
                    ),
                    MgIconButton(
                      icon: _minusIcon,
                      tooltip: l10n.mapZoomOut,
                      onPressed: _zoom > _minZoom ? () => _zoomBy(-1) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.fg.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _format(td.Location l) =>
      '${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}';
}

const _pinHeight = 40.0;

const _minusIcon = MgIconData('minus', '<path d="M6 12h12"/>');

/// A row in the list under the map: a 40 px tile, a title and a line
/// under it; brightens under the pointer, a tap picks it.
class _PlaceRow extends StatefulWidget {
  const _PlaceRow({
    super.key,
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_PlaceRow> createState() => _PlaceRowState();
}

class _PlaceRowState extends State<_PlaceRow> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          label: widget.title,
          button: true,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _hover ? c.fg.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(dimension: 40, child: widget.tile),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, weight: FontWeight.w500),
                      ),
                      if (widget.subtitle.isNotEmpty)
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.caption,
                            color: c.fg2,
                          ),
                        ),
                    ],
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

/// The tile of the "send this location" row: a small pin on the accent.
class _PinTile extends StatelessWidget {
  const _PinTile({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color),
    child: Center(
      child: CustomPaint(
        size: const Size(15, 20),
        painter: const _PinPainter(Color(0xFFFFFFFF), shadow: false),
      ),
    ),
  );
}

/// A venue's tile: its first letter on a tinted square.
class _LetterTile extends StatelessWidget {
  const _LetterTile(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14)),
      child: Center(
        child: Text(
          title.isEmpty ? '' : title[0].toUpperCase(),
          style: mgTextStyle(c, color: c.accent, weight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// The drop-shaped pin the location card draws, in [color].
class _PinPainter extends CustomPainter {
  const _PinPainter(this.color, {this.shadow = true});

  final Color color;
  final bool shadow;

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
    if (shadow) canvas.drawShadow(path, const Color(0x66000000), 3, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.color != color || old.shadow != shadow;
}
