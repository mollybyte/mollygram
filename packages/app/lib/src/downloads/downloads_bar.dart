import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';

import '../../l10n/app_localizations.dart';
import '../session/providers.dart';
import '../settings/storage_page.dart' show formatBytes;
import 'downloads_providers.dart';
import 'downloads_sheet.dart';

/// A slim row above the chat list while something downloads, or is
/// paused: a progress ring, how many files and how far along. A click
/// opens the downloads. Slides away once everything is finished, as the
/// official client's bar does.
class DownloadsBar extends ConsumerWidget {
  const DownloadsBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(telegramSessionProvider).hasValue;
    final counts = ready
        ? ref.watch(downloadCountsProvider).value ?? const DownloadCounts()
        : const DownloadCounts();
    final unfinished = counts.active + counts.paused;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: unfinished == 0
          ? const SizedBox(width: double.infinity, height: 0)
          : _Bar(counts: counts),
    );
  }
}

class _Bar extends ConsumerStatefulWidget {
  const _Bar({required this.counts});

  final DownloadCounts counts;

  @override
  ConsumerState<_Bar> createState() => _BarState();
}

class _BarState extends ConsumerState<_Bar> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final totals =
        ref.watch(downloadTotalsProvider).value ?? const DownloadTotals();
    final counts = widget.counts;
    final paused = counts.active == 0;
    final title = paused
        ? l10n.downloadsAllPaused(counts.paused)
        : l10n.downloadsActive(counts.active);
    final detail = totals.totalSize > 0
        ? l10n.downloadProgress(
            formatBytes(totals.downloadedSize, l10n, locale),
            formatBytes(totals.totalSize, l10n, locale),
          )
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Semantics(
        button: true,
        label: title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            key: const ValueKey('downloadsBar'),
            onTap: () => showDownloadsSheet(context),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
              decoration: BoxDecoration(
                color: _hover ? c.hover : c.field,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 22,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(end: totals.progress),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          builder: (_, value, _) => CustomPaint(
                            size: const Size.square(22),
                            painter: _Ring(
                              progress: value,
                              color: paused ? c.fg2 : c.accent,
                              track: c.separator,
                            ),
                          ),
                        ),
                        MgIcon(
                          paused ? MgIcons.pause : MgIcons.arrowDown,
                          size: 10,
                          color: paused ? c.fg2 : c.accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: mgTextStyle(
                            c,
                            size: MgType.small,
                            weight: FontWeight.w500,
                          ),
                        ),
                        if (detail != null)
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mgTextStyle(
                              c,
                              size: MgType.meta,
                              color: c.fg2,
                            ),
                          ),
                      ],
                    ),
                  ),
                  MgIcon(MgIcons.chevron, size: 12, color: c.fg2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    canvas.drawOval(
      rect,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      rect,
      -1.5708,
      6.2832 * progress.clamp(0.02, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.progress != progress || old.color != color || old.track != track;
}
