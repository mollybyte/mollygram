import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../../l10n/app_localizations.dart';
import '../../chat/media_content.dart';
import '../../folders/folder_sheet.dart';
import '../../session/providers.dart';

/// Looks up the set named [name], as `t.me/addstickers/<name>` or
/// `tg://addstickers?set=<name>` give it, and shows it in a sheet with Add
/// or Remove. Returns false when there is no such set.
Future<bool> showStickerSetSheet(BuildContext context, String name) async {
  final td.StickerSet set;
  try {
    final session = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(telegramSessionProvider).requireValue;
    set = await session.stickerSets.byName(name);
  } on Object {
    return false;
  }
  if (!context.mounted) return true;
  await showFolderSheet<void>(context, StickerSetSheet(set: set));
  return true;
}

/// A set's stickers in a grid, animated under the pointer, and the button
/// that adds or removes the set.
class StickerSetSheet extends ConsumerStatefulWidget {
  const StickerSetSheet({super.key, required this.set});

  final td.StickerSet set;

  @override
  ConsumerState<StickerSetSheet> createState() => _StickerSetSheetState();
}

class _StickerSetSheetState extends ConsumerState<StickerSetSheet> {
  late var _installed = widget.set.isInstalled;
  var _saving = false;
  var _failed = false;

  bool get _emoji => widget.set.stickerType is td.StickerTypeCustomEmoji;

  void _close() => Navigator.of(context).pop();

  Future<void> _toggle() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    final sets = ref.read(telegramSessionProvider).requireValue.stickerSets;
    final set = widget.set;
    final kind = StickerSetKind.of(set.stickerType);
    try {
      if (_installed) {
        await sets.remove(_infoOf(set));
      } else {
        await sets.install(set.id, kind);
      }
      if (!mounted) return;
      setState(() {
        _installed = !_installed;
        _saving = false;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final set = widget.set;
    final count = _emoji
        ? l10n.emojiCount(set.stickers.length)
        : l10n.stickerCount(set.stickers.length);
    final side = _emoji ? 40.0 : 72.0;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: SizedBox(
          width: 420,
          height: 520,
          child: Glass(
            radius: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              set.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: mgTextStyle(c, weight: FontWeight.w600),
                            ),
                            Text(
                              count,
                              style: mgTextStyle(
                                c,
                                size: MgType.caption,
                                color: c.fg2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MgIconButton(
                        icon: MgIcons.close,
                        tooltip: l10n.close,
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: side + 16,
                    ),
                    itemCount: set.stickers.length,
                    itemBuilder: (context, i) => _Cell(
                      key: ValueKey(set.stickers[i].id),
                      sticker: set.stickers[i],
                      side: side,
                    ),
                  ),
                ),
                Container(height: 0.5, color: c.separator),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_failed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            l10n.saveFailed,
                            textAlign: TextAlign.center,
                            style: mgTextStyle(
                              c,
                              size: MgType.caption,
                              color: MgDestructive.color,
                            ),
                          ),
                        ),
                      MgPrimaryButton(
                        key: const ValueKey('toggleSet'),
                        label: _installed ? l10n.remove : l10n.addSet,
                        loading: _saving,
                        expand: true,
                        onPressed: _saving ? null : () => unawaited(_toggle()),
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

/// The set as a list row of it would describe it, for removing.
td.StickerSetInfo _infoOf(td.StickerSet set) => td.StickerSetInfo(
  id: set.id,
  title: set.title,
  name: set.name,
  thumbnail: set.thumbnail,
  thumbnailOutline: set.thumbnailOutline,
  isOwned: set.isOwned,
  isInstalled: set.isInstalled,
  isArchived: set.isArchived,
  isOfficial: set.isOfficial,
  stickerType: set.stickerType,
  needsRepainting: set.needsRepainting,
  isAllowedAsChatEmojiStatus: set.isAllowedAsChatEmojiStatus,
  isViewed: set.isViewed,
  size: set.stickers.length,
  covers: const [],
);

/// A sticker that plays while the pointer is over it.
class _Cell extends StatefulWidget {
  const _Cell({super.key, required this.sticker, required this.side});

  final td.Sticker sticker;
  final double side;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: _hover ? c.hover : const Color(0x00000000),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: StickerContent(
          sticker: widget.sticker,
          side: widget.side,
          animate: _hover,
        ),
      ),
    );
  }
}
