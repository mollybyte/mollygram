import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
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
class TimelineView extends StatelessWidget {
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

  /// The message the timeline grows from.
  final int? anchor;

  /// The first message that was unread when the chat opened; the unread
  /// band sits above it.
  final int? unreadFrom;

  /// The message a jump landed on, lit up for a moment each time [flash]
  /// grows.
  final int? flashId;
  final int flash;

  static const double topInset = 72;
  static const double bottomInset = 88;

  static bool _holds(TimelineItem item, int? id) =>
      id != null &&
      item is TimelineRow &&
      item.row.messages.any((message) => message.id == id);

  @override
  Widget build(BuildContext context) {
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
        : items.indexWhere((item) => _holds(item, anchor));
    final below = split < 0 ? <TimelineItem>[] : items.sublist(0, split + 1);
    final newer = below.reversed.toList();
    final older = split < 0 ? items : items.sublist(split + 1);

    Widget build(TimelineItem item) {
      final Widget child = switch (item) {
        TimelineDate(:final day) => DatePill(formatDay(l10n, day, locale)),
        TimelineRow(
          :final row,
          :final startsRun,
          :final endsRun,
          :final startsForwards,
        ) =>
          () {
            row.messages.forEach(onShown);
            return Padding(
              padding: EdgeInsets.only(top: startsRun ? 6 : 2),
              child: MessageFlash(
                flash: _holds(item, flashId) ? flash : 0,
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
                  ),
                  actions: actions,
                ),
              ),
            );
          }(),
      };
      final padded = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: child,
      );
      return KeyedSubtree(
        key: ValueKey<Object>(item.key),
        child: _holds(item, unreadFrom)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [UnreadDivider(l10n.unreadMessages), padded],
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
    return CustomScrollView(
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
          const SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
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
        const SliverToBoxAdapter(child: SizedBox(height: topInset)),
      ],
    );
  }
}
