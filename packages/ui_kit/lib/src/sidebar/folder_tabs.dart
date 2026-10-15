import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// One folder of [FolderSegments].
@immutable
class FolderSegment {
  const FolderSegment({
    required this.label,
    this.icon,
    this.count = 0,
    this.onTap,
  });

  final String label;

  /// Drawn over the label, as on a macOS toolbar.
  final MgIconData? icon;

  /// Unread chats in the folder; hidden when zero.
  final int count;
  final VoidCallback? onTap;
}

/// The chat folders as a segmented control: a soft track with the selected
/// folder on a raised card-coloured thumb that slides to the folder picked.
/// When the folders fit they share the track's width evenly; otherwise the
/// track scrolls sideways, keeping the selected one in view.
class FolderSegments extends StatefulWidget {
  const FolderSegments({
    super.key,
    required this.segments,
    required this.selected,
  });

  final List<FolderSegment> segments;

  /// The index of the selected segment; -1 for none.
  final int selected;

  static const double height = 34;

  /// The height with icons over the labels.
  static const double iconHeight = 46;

  static double heightOf(List<FolderSegment> segments) =>
      segments.any((s) => s.icon != null) ? iconHeight : height;

  @override
  State<FolderSegments> createState() => _FolderSegmentsState();
}

class _FolderSegmentsState extends State<FolderSegments> {
  static const _pad = 4.0;
  static const _slide = Duration(milliseconds: 260);

  final _scroll = ScrollController();
  final _rowKey = GlobalKey();
  var _keys = <GlobalKey>[];

  /// The thumb's place in the row; null until the row is laid out.
  Rect? _thumb;

  /// The first placement doesn't slide in from nowhere.
  var _placed = false;

  @override
  void initState() {
    super.initState();
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(FolderSegments old) {
    super.didUpdateWidget(old);
    _syncKeys();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _syncKeys() {
    final n = widget.segments.length;
    if (_keys.length != n) {
      _keys = [
        for (var i = 0; i < n; i++) i < _keys.length ? _keys[i] : GlobalKey(),
      ];
    }
  }

  void _measure() {
    if (!mounted) return;
    final i = widget.selected;
    final row = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    final box = i >= 0 && i < _keys.length
        ? _keys[i].currentContext?.findRenderObject() as RenderBox?
        : null;
    if (row == null || box == null || !row.hasSize || !box.hasSize) {
      if (_thumb != null) setState(() => _thumb = null);
      return;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: row);
    final rect = origin & box.size;
    if (rect != _thumb) {
      setState(() => _thumb = rect);
      _reveal(rect);
    }
    if (!_placed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _placed = true);
      });
    }
  }

  /// Scrolls the track so the selected folder is fully shown.
  void _reveal(Rect rect) {
    if (!_scroll.hasClients) return;
    final view = _scroll.position.viewportDimension;
    final at = _scroll.offset;
    double? to;
    if (rect.left - _pad < at) {
      to = rect.left - _pad;
    } else if (rect.right + _pad > at + view) {
      to = rect.right + _pad - view;
    }
    if (to == null) return;
    to = to.clamp(0.0, _scroll.position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(to, duration: _slide, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final thumb = _thumb;
    final still = !_placed || MediaQuery.disableAnimationsOf(context);
    final height = FolderSegments.heightOf(widget.segments);
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - 2 * _pad;
        final natural = [
          for (final segment in widget.segments)
            FolderTab.naturalWidth(context, segment),
        ];
        final fits =
            room.isFinite && natural.fold(0.0, (a, b) => a + b) <= room;
        return _track(c, height, thumb, still, fits ? room : null);
      },
    );
  }

  /// The track; [fill] is the width the folders share evenly when they
  /// fit, null when they scroll.
  Widget _track(
    MgColors c,
    double height,
    Rect? thumb,
    bool still,
    double? fill,
  ) {
    final tabs = [
      for (final (i, segment) in widget.segments.indexed)
        FolderTab(
          key: _keys[i],
          label: segment.label,
          icon: segment.icon,
          count: segment.count,
          height: height - 2 * _pad,
          selected: i == widget.selected,
          // Until the thumb is placed, the selected folder
          // draws its own, so the first frame has one too.
          raised: thumb == null && i == widget.selected,
          onTap: segment.onTap,
        ),
    ];
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(height / 2 > 15 ? 14 : 15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2 > 15 ? 14 : 15),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(_pad),
          child: Stack(
            key: _rowKey,
            children: [
              if (thumb != null)
                AnimatedPositioned(
                  duration: still ? Duration.zero : _slide,
                  curve: Curves.easeOutCubic,
                  left: thumb.left,
                  top: 0,
                  width: thumb.width,
                  height: thumb.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(
                        height == FolderSegments.height ? thumb.height / 2 : 10,
                      ),
                      boxShadow: [_thumbShadow(c)],
                    ),
                  ),
                ),
              if (fill != null)
                SizedBox(
                  width: fill,
                  child: Row(
                    children: [for (final tab in tabs) Expanded(child: tab)],
                  ),
                )
              else
                Row(mainAxisSize: MainAxisSize.min, children: tabs),
            ],
          ),
        ),
      ),
    );
  }
}

/// One folder in [FolderSegments]: its label and an optional unread count.
/// It draws no fill when selected, unless [raised]; the sliding thumb under
/// it does.
class FolderTab extends StatefulWidget {
  const FolderTab({
    super.key,
    required this.label,
    this.icon,
    this.height = FolderSegments.height - 8,
    this.count = 0,
    this.selected = false,
    this.raised = false,
    this.onTap,
  });

  final String label;
  final MgIconData? icon;
  final double height;

  /// Unread chats in the folder; hidden when zero.
  final int count;
  final bool selected;

  /// Draws the raised thumb itself instead of leaving it to the track.
  final bool raised;
  final VoidCallback? onTap;

  static const double _padding = 10;

  static TextStyle _labelStyle(MgColors c, {required bool stacked}) =>
      mgTextStyle(
        c,
        size: stacked ? MgType.meta : MgType.small,
        weight: MgWeight.medium,
        height: 1.2,
      );

  /// How wide [segment] is when it doesn't have to share the track.
  static double naturalWidth(BuildContext context, FolderSegment segment) {
    final c = MgColors.of(context);
    final stacked = segment.icon != null;
    final text = TextPainter(
      text: TextSpan(
        text: segment.label,
        style: _labelStyle(c, stacked: stacked),
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final count = segment.count > 0 ? 5 + 7.0 * '${segment.count}'.length : 0;
    final width = text.width + (stacked ? 0 : count);
    text.dispose();
    return (stacked && width < 18 ? 18 : width) + 2 * _padding;
  }

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final on = widget.selected;
    return Semantics(
      button: true,
      selected: on,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: widget.height,
            padding: const EdgeInsets.symmetric(horizontal: FolderTab._padding),
            alignment: Alignment.center,
            decoration: widget.raised
                ? BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(
                      widget.icon == null ? 13 : 10,
                    ),
                    boxShadow: [_thumbShadow(c)],
                  )
                : null,
            child: widget.icon == null ? _inline(c, on) : _stacked(c, on),
          ),
        ),
      ),
    );
  }

  /// An icon over the label; an unread count is an accent dot.
  Widget _stacked(MgColors c, bool on) {
    final tone = on ? c.accent : (_hover ? c.fg : c.icon);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: tone),
              duration: const Duration(milliseconds: 160),
              builder: (context, color, _) =>
                  MgIcon(widget.icon!, size: 17, color: color ?? tone),
            ),
            if (widget.count > 0)
              Positioned(
                right: -4,
                top: -1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: FolderTab._labelStyle(
            c,
            stacked: true,
          ).copyWith(color: on || _hover ? c.fg : c.fg2),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _inline(MgColors c, bool on) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: FolderTab._labelStyle(
            c,
            stacked: false,
          ).copyWith(color: on || _hover ? c.fg : c.fg2),
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (widget.count > 0) ...[
        const SizedBox(width: 5),
        Text(
          '${widget.count}',
          style: mgTextStyle(
            c,
            size: MgType.caption,
            weight: MgWeight.medium,
            color: c.accent,
            height: 1.2,
          ),
        ),
      ],
    ],
  );
}

/// The soft shadow that lifts the selected folder off the track.
BoxShadow _thumbShadow(MgColors c) => BoxShadow(
  color: c.isDark ? const Color(0x40000000) : const Color(0x14000000),
  blurRadius: 2,
  offset: const Offset(0, 1),
);
