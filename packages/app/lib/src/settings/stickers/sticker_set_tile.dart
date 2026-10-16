import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/media_content.dart';
import '../../chat/td_file.dart';
import '../settings_style.dart';

/// "12 stickers" or "40 emoji".
String stickerSetCount(AppLocalizations l10n, td.StickerSetInfo set) =>
    set.stickerType is td.StickerTypeCustomEmoji
    ? l10n.emojiCount(set.size)
    : l10n.stickerCount(set.size);

/// Asks before removing [set] for good; true to go ahead.
Future<bool> confirmStickerSetRemoval(
  BuildContext context, {
  required String title,
  required bool emoji,
}) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showMgConfirm(
    context,
    title: emoji ? l10n.removeEmojiSetTitle : l10n.removeStickerSetTitle,
    message: title,
    confirmLabel: l10n.remove,
    cancelLabel: l10n.cancel,
    destructive: true,
  );
  return confirmed != null;
}

/// A set's picture: its thumbnail, still, or its first sticker, or the
/// first letter of its title on a grey tile when it has neither.
class StickerSetThumb extends StatelessWidget {
  const StickerSetThumb({super.key, required this.set, this.size = 32});

  final td.StickerSetInfo set;
  final double size;

  @override
  Widget build(BuildContext context) {
    final thumb = set.thumbnail;
    final Widget child = switch (thumb?.format) {
      td.ThumbnailFormatWebp() ||
      td.ThumbnailFormatPng() ||
      td.ThumbnailFormatJpeg() => TdImage(
        thumbnail: thumb!.file,
        fit: BoxFit.contain,
        background: const Color(0x00000000),
      ),
      td.ThumbnailFormatTgs() => TdFileBuilder(
        file: thumb!.file,
        download: true,
        priority: DownloadPriority.preview,
        builder: (context, file) {
          final path = downloadedPath(file);
          if (path == null) return const SizedBox.shrink();
          return Lottie.file(
            File(path),
            animate: false,
            decoder: LottieComposition.decodeGZip,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => _monogram(context),
          );
        },
      ),
      _ when set.covers.isNotEmpty => FittedBox(
        child: StickerContent(
          sticker: set.covers.first,
          side: size,
          animate: false,
        ),
      ),
      _ => _monogram(context),
    };
    return SizedBox.square(dimension: size, child: child);
  }

  Widget _monogram(BuildContext context) {
    final c = MgColors.of(context);
    final title = set.title.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.27),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.avatarTop, c.avatarBottom],
        ),
      ),
      child: Center(
        child: Text(
          title.isEmpty ? '' : title.characters.first.toUpperCase(),
          style: mgTextStyle(
            c,
            weight: FontWeight.w600,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// A set as a settings row: picture, title and count, opening the set.
class StickerSetRow extends StatelessWidget {
  const StickerSetRow({
    super.key,
    required this.set,
    this.trailing,
    this.onTap,
    this.onMenu,
  });

  final td.StickerSetInfo set;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// A right click, at that position.
  final void Function(Offset position)? onMenu;

  @override
  Widget build(BuildContext context) {
    final onMenu = this.onMenu;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: onMenu == null
          ? null
          : (details) => onMenu(details.globalPosition),
      child: SettingsRow(
        leading: StickerSetThumb(set: set),
        title: set.title,
        subtitle: stickerSetCount(AppLocalizations.of(context), set),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// Installed sets, reordered by dragging their handles: the rows part to
/// make room, and the dragged one lifts (without growing under reduced
/// motion).
class StickerSetReorderList extends StatelessWidget {
  const StickerSetReorderList({
    super.key,
    required this.sets,
    required this.onReorder,
    required this.onOpen,
    required this.onMenu,
  });

  final List<td.StickerSetInfo> sets;
  final void Function(int from, int to) onReorder;
  final ValueChanged<td.StickerSetInfo> onOpen;
  final void Function(td.StickerSetInfo set, Offset position) onMenu;

  /// Every row is this tall, so the hairlines can sit between the slots.
  static const rowHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final s = SettingsColors.of(context);
    // With reduced motion the dragged row only gains its shadow.
    final lift = MediaQuery.disableAnimationsOf(context) ? 0.0 : 0.02;
    final list = ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: onReorder,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(animation.value);
          return Transform.scale(
            scale: 1 + lift * t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: s.group,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.18 * t),
                    blurRadius: 16 * t,
                    offset: Offset(0, 4 * t),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: child,
      ),
      children: [
        for (var i = 0; i < sets.length; i++)
          SizedBox(
            key: ValueKey(sets[i].id),
            height: rowHeight,
            child: StickerSetRow(
              set: sets[i],
              onTap: () => onOpen(sets[i]),
              onMenu: (position) => onMenu(sets[i], position),
              trailing: ReorderableDragStartListener(
                index: i,
                child: const _Handle(),
              ),
            ),
          ),
      ],
    );
    // The hairlines belong to the slots, so none travels with a dragged
    // row; the group draws the one above the first.
    return Stack(
      children: [
        list,
        Positioned.fill(
          child: IgnorePointer(
            child: Column(
              children: [
                for (var i = 0; i < sets.length; i++)
                  SizedBox(
                    height: rowHeight,
                    child: i == 0
                        ? null
                        : Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: settingsInset + 32 + 10,
                                right: settingsInset,
                              ),
                              child: Container(height: 0.5, color: c.separator),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Three short lines that brighten under the pointer, with a grab cursor.
class _Handle extends StatefulWidget {
  const _Handle();

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  var _hover = false;

  static const _grip = MgIconData(
    'grip',
    '<path d="M6 8.5h12M6 12h12M6 15.5h12"/>',
  );

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: AnimatedOpacity(
          duration: settingsMotionOf(context),
          opacity: _hover ? 1 : 0.55,
          child: MgIcon(_grip, size: 18, color: c.fg2),
        ),
      ),
    );
  }
}
