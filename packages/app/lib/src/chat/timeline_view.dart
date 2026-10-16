import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../plugins/message_hooks.dart';
import '../settings/appearance.dart';
import 'message_tile.dart';
import 'timeline.dart';
import 'timeline_scroll.dart';

/// The timeline, newest at the bottom: rows of messages and albums with a
/// date pill above the first message of each day.
///
/// It grows both ways from [anchor]: older rows above it, the anchor and
/// newer rows below. Rows that load above or below never move what is on
/// screen, and a jump lands without a visible scroll. Without an anchor
/// every row is above the bottom edge, as in a plain reversed list.
class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.messages,
    required this.store,
    required this.chatId,
    required this.isGroup,
    required this.controller,
    required this.onShown,
    required this.onNearTop,
    required this.onNearBottom,
    required this.actions,
    this.anchor,
    this.unreadFrom,
    this.flashId,
    this.flash = 0,
    this.topInset = TimelineView.headerInset,
    this.bottomInset = TimelineView.composerInset,
    this.selection,
    this.onDateTap,
  });

  /// Newest first.
  final List<ConversationMessage> messages;
  final ConversationStore store;
  final int chatId;
  final bool isGroup;
  final TimelineScrollController controller;

  /// Called as a message is built, which is when it is on screen or about
  /// to be.
  final void Function(ConversationMessage message) onShown;

  /// Called when the oldest loaded messages come into view.
  final VoidCallback onNearTop;

  /// Called when the newest loaded messages come into view.
  final VoidCallback onNearBottom;
  final MessageRowActions actions;

  /// The space under the newest message, for the composer and whatever
  /// floats above it, such as a bot's keyboard.
  final double bottomInset;

  /// The message the timeline grows from.
  final int? anchor;

  /// The first message that was unread when the chat opened; the unread
  /// band sits above it.
  final int? unreadFrom;

  /// The message a jump landed on, lit up for a moment each time [flash]
  /// grows.
  final int? flashId;
  final int flash;

  /// The space above the oldest message: the header, and the pinned bar
  /// when it shows.
  final double topInset;

  /// The ids of the selected messages while messages are being selected;
  /// null otherwise.
  final Set<int>? selection;

  /// A click on a date pill, at [position] in global coordinates, which
  /// opens the calendar to jump to a date.
  final void Function(DateTime day, Offset position)? onDateTap;

  static const double headerInset = 72;
  static const double composerInset = 64;

  static bool _holds(TimelineItem item, int? id) =>
      id != null &&
      item is TimelineRow &&
      item.row.messages.any((message) => message.id == id);

  /// The row under the point [dy] from the top of the timeline at [key],
  /// if a row is there. The rows are found in the render tree rather than
  /// hit-tested, since a scroll in progress ignores pointers.
  static TimelineRowHit? rowAt(GlobalKey key, double dy) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final markers = <_RenderRowMarker>[];
    _collect(box, markers);
    for (final marker in markers) {
      if (!marker.hasSize) continue;
      final top = marker.localToGlobal(Offset.zero, ancestor: box).dy;
      if (dy >= top && dy < top + marker.size.height) return marker.hit;
    }
    return null;
  }

  // Markers sit near the top of the tree, one per row, with the whole
  // message under each; the walk stops at them.
  static void _collect(RenderObject node, List<_RenderRowMarker> into) {
    if (node is _RenderRowMarker) {
      into.add(node);
      return;
    }
    node.visitChildren((child) => _collect(child, into));
  }

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

/// A message row found under a point of the timeline.
@immutable
final class TimelineRowHit {
  const TimelineRowHit({required this.messageId, required this.day});

  /// The row's first message.
  final int messageId;
  final DateTime day;
}

class _TimelineViewState extends State<TimelineView> {
  final _key = GlobalKey();
  DateTime? _floatingDay;
  var _scrolling = false;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(TimelineView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    _settle?.cancel();
    super.dispose();
  }

  /// The date of the topmost row floats while the user scrolls, as in
  /// the official app, and goes once the list has stood still a moment.
  void _onScroll() {
    final controller = widget.controller;
    if (!controller.hasClients ||
        !controller.position.isScrollingNotifier.value) {
      return;
    }
    final hit = TimelineView.rowAt(_key, widget.topInset + 4);
    if (hit == null) return;
    if (hit.day != _floatingDay || !_scrolling) {
      setState(() {
        _floatingDay = hit.day;
        _scrolling = true;
      });
    }
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _scrolling = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day = _floatingDay;
    return Stack(
      key: _key,
      children: [
        Positioned.fill(child: PluginVerdicts(child: _TimelineList(widget))),
        if (day != null)
          Positioned(
            top: widget.topInset - 34,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _scrolling ? 1 : 0,
                duration: Duration(milliseconds: _scrolling ? 120 : 300),
                curve: Curves.easeOut,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MgSpace.xxl),
                  child: DatePill(
                    formatDay(l10n, day, locale),
                    key: const ValueKey('floatingDate'),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Marks a row in the render tree with its first message and day, so a
/// hit test can tell which row is under a point.
class _RowMarker extends SingleChildRenderObjectWidget {
  const _RowMarker({required this.hit, required super.child});

  final TimelineRowHit hit;

  @override
  _RenderRowMarker createRenderObject(BuildContext context) =>
      _RenderRowMarker(hit);

  @override
  void updateRenderObject(BuildContext context, _RenderRowMarker render) {
    render.hit = hit;
  }
}

class _RenderRowMarker extends RenderProxyBox {
  _RenderRowMarker(this.hit);

  TimelineRowHit hit;
}

class _TimelineList extends StatelessWidget {
  const _TimelineList(this.view);

  final TimelineView view;

  @override
  Widget build(BuildContext context) {
    final messages = PluginVerdicts.visible(context, view.messages);
    final store = view.store;
    final chatId = view.chatId;
    final isGroup = view.isGroup;
    final controller = view.controller;
    final onShown = view.onShown;
    final onNearTop = view.onNearTop;
    final onNearBottom = view.onNearBottom;
    final actions = view.actions;
    final anchor = view.anchor;
    final unreadFrom = view.unreadFrom;
    final flashId = view.flashId;
    final flash = view.flash;
    final topInset = view.topInset;
    final selection = view.selection;
    final onDateTap = view.onDateTap;
    final bottomInset = view.bottomInset;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isChannel = store.isChannel(chatId);
    final items = timelineItems(
      messages,
      reachedStart: store.reachedStart(chatId),
      isChannel: isChannel,
    );
    final lastReadOutbox = store.lastReadOutbox(chatId);
    final reachedEnd = store.reachedEnd(chatId);

    // Items are newest first. The anchor's row and the newer ones go
    // below the center, nearest first, so the anchor's row touches it.
    final split = anchor == null
        ? -1
        : items.indexWhere((item) => TimelineView._holds(item, anchor));
    final below = split < 0 ? <TimelineItem>[] : items.sublist(0, split + 1);
    final newer = below.reversed.toList();
    final older = split < 0 ? items : items.sublist(split + 1);

    Widget build(TimelineItem item) {
      final Widget child = switch (item) {
        TimelineDate(:final day) => SelectionContainer.disabled(
          child: onDateTap == null
              ? DatePill(formatDay(l10n, day, locale))
              : MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTapUp: (details) =>
                        onDateTap(day, details.globalPosition),
                    child: DatePill(formatDay(l10n, day, locale)),
                  ),
                ),
        ),
        TimelineRow(
          :final row,
          :final startsRun,
          :final endsRun,
          :final startsForwards,
        ) =>
          () {
            row.messages.forEach(onShown);
            return _RowMarker(
              hit: TimelineRowHit(
                messageId: row.messages.first.id,
                day: dayOf(row.messages.first),
              ),
              child: Padding(
                padding: EdgeInsets.only(top: startsRun ? 6 : 2),
                child: MessageFlash(
                  flash: TimelineView._holds(item, flashId) ? flash : 0,
                  child: MessageTile(
                    row: row,
                    store: store,
                    context: MessageRowContext(
                      isGroup: isGroup,
                      isChannel: isChannel,
                      startsRun: startsRun,
                      endsRun: endsRun,
                      startsForwards: startsForwards,
                      lastReadOutbox: lastReadOutbox,
                      selecting: selection != null,
                      selected:
                          selection != null &&
                          row.messages.any((m) => selection.contains(m.id)),
                    ),
                    actions: actions,
                  ),
                ),
              ),
            );
          }(),
      };
      // Only the newest message, just sent or received, slides in; rows
      // that load or scroll into view later never move.
      final age = item is TimelineRow
          ? DateTime.now().millisecondsSinceEpoch - item.row.primary.date * 1000
          : -1;
      final fresh =
          item is TimelineRow &&
          identical(item, items.first) &&
          age >= 0 &&
          age < _Appear.window.inMilliseconds;
      final padded = _Appear(
        animate: fresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MgSpace.xxl),
          // The text size chosen in Settings, Appearance.
          child: MessageTextSize(child: child),
        ),
      );
      return KeyedSubtree(
        key: ValueKey<Object>(item.key),
        child: TimelineView._holds(item, unreadFrom)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SelectionContainer.disabled(
                    child: UnreadDivider(l10n.unreadMessages),
                  ),
                  padded,
                ],
              )
            : padded,
      );
    }

    int? indexOf(List<TimelineItem> list, Key key) {
      final value = (key as ValueKey<Object>).value;
      final index = list.indexWhere((item) => item.key == value);
      return index < 0 ? null : index;
    }

    const center = ValueKey('center');
    // Text can be selected across messages with the mouse and copied with
    // the shortcut; the row's own menu stands in for the selection menu.
    return SelectionArea(
      contextMenuBuilder: (context, state) => const SizedBox.shrink(),
      child: CustomScrollView(
        controller: controller,
        reverse: true,
        center: center,
        // No off-screen cache: a message is built when it enters the
        // viewport, which is when onShown reports it to TDLib as viewed.
        scrollCacheExtent: const ScrollCacheExtent.pixels(0),
        slivers: [
          // The space under the newest message, below the anchor's rows, or
          // right under the center when there are none, so offset 0 is the
          // bottom from the first frame.
          if (newer.isNotEmpty)
            SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (!reachedEnd && i >= newer.length - 8) onNearBottom();
                return build(newer[i]);
              },
              childCount: newer.length,
              findChildIndexCallback: (key) => indexOf(newer, key),
            ),
          ),
          SliverPadding(
            key: center,
            padding: EdgeInsets.only(bottom: newer.isEmpty ? bottomInset : 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  if (i >= older.length - 8) onNearTop();
                  if (!reachedEnd && newer.isEmpty && i < 8) onNearBottom();
                  return build(older[i]);
                },
                childCount: older.length,
                findChildIndexCallback: (key) => indexOf(older, key),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: topInset)),
        ],
      ),
    );
  }
}

/// Fades a new message in while it rises a few pixels, as a quick settle:
/// no bounce, over before the eye waits for it. Decided once, when the
/// row is first built; with reduced motion the row simply appears.
class _Appear extends StatefulWidget {
  const _Appear({required this.animate, required this.child});

  final bool animate;
  final Widget child;

  /// How recent a message must be to count as new.
  static const window = Duration(seconds: 4);

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.23, 1, 0.32, 1),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_controller.forward());
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) {
      final t = _curve.value;
      if (t >= 1) return child!;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}
