import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/theme.dart';

/// One folder of [FolderSegments].
@immutable
class FolderSegment {
  const FolderSegment({required this.label, this.count = 0, this.onTap});

  final String label;

  /// Unread chats in the folder; hidden when zero.
  final int count;
  final VoidCallback? onTap;
}

/// The chat folders as a segmented control: a soft track with the selected
/// folder on a raised card-coloured thumb that slides to the folder picked.
/// The track scrolls sideways when the folders don't fit, keeping the
/// selected one in view.
class FolderSegments extends StatefulWidget {
  const FolderSegments({
    super.key,
    required this.segments,
    required this.selected,
  });

  final List<FolderSegment> segments;

  /// The index of the selected segment; -1 for none.
  final int selected;

  static const double height = 30;

  @override
  State<FolderSegments> createState() => _FolderSegmentsState();
}

class _FolderSegmentsState extends State<FolderSegments> {
  static const _pad = 3.0;
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
    return Container(
      height: FolderSegments.height,
      decoration: BoxDecoration(
        color: c.field,
        borderRadius: BorderRadius.circular(FolderSegments.height / 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FolderSegments.height / 2),
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
                      borderRadius: BorderRadius.circular(thumb.height / 2),
                      boxShadow: [_thumbShadow(c)],
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, segment) in widget.segments.indexed)
                    FolderTab(
                      key: _keys[i],
                      label: segment.label,
                      count: segment.count,
                      selected: i == widget.selected,
                      // Until the thumb is placed, the selected folder
                      // draws its own, so the first frame has one too.
                      raised: thumb == null && i == widget.selected,
                      onTap: segment.onTap,
                    ),
                ],
              ),
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
    this.count = 0,
    this.selected = false,
    this.raised = false,
    this.onTap,
  });

  final String label;

  /// Unread chats in the folder; hidden when zero.
  final int count;
  final bool selected;

  /// Draws the raised thumb itself instead of leaving it to the track.
  final bool raised;
  final VoidCallback? onTap;

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
            height: FolderSegments.height - 6,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: widget.raised
                ? BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [_thumbShadow(c)],
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: mgTextStyle(
                    c,
                    size: MgType.tab,
                    weight: MgWeight.medium,
                    color: on || _hover ? c.fg : c.fg2,
                    height: 1.2,
                  ),
                  child: Text(widget.label),
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
            ),
          ),
        ),
      ),
    );
  }
}

/// The soft shadow that lifts the selected folder off the track.
BoxShadow _thumbShadow(MgColors c) => BoxShadow(
  color: c.isDark ? const Color(0x40000000) : const Color(0x1A000000),
  blurRadius: 3,
  offset: const Offset(0, 1),
);
