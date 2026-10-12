import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../circle/circle_controller.dart';
import '../theme.dart';
import 'benchmark.dart';
import 'frame_stats.dart';

/// Служебная панель замера. Не часть дизайна, поэтому сплошная и мелкая.
class PerfOverlay extends StatefulWidget {
  const PerfOverlay({
    super.key,
    required this.stats,
    required this.bench,
    required this.circle,
    required this.app,
  });

  final FrameStats stats;
  final Benchmark bench;
  final CircleController circle;
  final AppState app;

  @override
  State<PerfOverlay> createState() => _PerfOverlayState();
}

class _PerfOverlayState extends State<PerfOverlay> {
  FrameSummary? _live;
  DateTime _last = DateTime(0);

  @override
  void initState() {
    super.initState();
    widget.stats.addListener(_onFrames);
  }

  @override
  void dispose() {
    widget.stats.removeListener(_onFrames);
    super.dispose();
  }

  void _onFrames() {
    // Обновляем цифры не чаще двух раз в секунду, чтобы не мерить себя.
    final now = DateTime.now();
    if (now.difference(_last) < const Duration(milliseconds: 500)) return;
    _last = now;
    if (!mounted) return;
    setState(() {
      _live = FrameSummary.of(
        widget.stats.recent,
        View.of(context).display.refreshRate,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final bench = widget.bench;
    final circle = widget.circle;
    final app = widget.app;
    final hz = View.of(context).display.refreshRate;
    final style = TextStyle(
      fontSize: 11,
      height: 1.45,
      color: c.fg,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String f(double v) => v.toStringAsFixed(1);
    final live = _live;

    return ListenableBuilder(
      listenable: Listenable.merge([bench, circle, app]),
      builder: (context, _) {
        return Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: c.dark ? const Color(0xF0202226) : const Color(0xF5FFFFFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.field),
          ),
          child: DefaultTextStyle.merge(
            style: style,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Кадры · ${hz > 0 ? '${hz.toStringAsFixed(0)} Гц' : 'частота ?'}'
                  '${kDebugMode ? ' · debug' : ''}',
                  style: style.copyWith(fontWeight: FontWeight.w600),
                ),
                if (kDebugMode)
                  Text(
                    'Цифры показательны только в --profile',
                    style: style.copyWith(color: c.fg2),
                  ),
                if (live != null && live.frames > 1) ...[
                  Text(
                    '${f(live.fps)} fps, vsync ${f(live.vsyncHz)} Гц, '
                    'бюджет ${f(live.budgetMs)} мс',
                  ),
                  Text(
                    'build ${f(live.buildP50)} / ${f(live.buildP95)} мс, '
                    'raster ${f(live.rasterP50)} / ${f(live.rasterP95)} мс',
                  ),
                  Text(
                    'дольше бюджета ${live.overBudget}, '
                    'пропущено vsync ${live.missedVsyncs}',
                    style: style.copyWith(color: c.fg2),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      bench.running ? 'Идёт замер' : 'Замер 1 мин',
                      onTap: bench.running ? null : () => bench.runSuite(),
                      primary: true,
                    ),
                    _Chip(
                      circle.playing ? 'Пауза' : 'Пуск кружка',
                      onTap: bench.running
                          ? null
                          : () => circle.setPlaying(!circle.playing),
                    ),
                    _Chip(
                      'Плеер: ${circle.backend.label}',
                      onTap: bench.running
                          ? null
                          : () => circle.setBackend(
                              circle.backend == CircleBackend.mediaKit
                                  ? CircleBackend.avFoundation
                                  : CircleBackend.mediaKit,
                            ),
                    ),
                    _Chip(
                      'Размытие: ${app.blur ? 'вкл' : 'выкл'}',
                      onTap: bench.running
                          ? null
                          : () => app.setBlur(!app.blur),
                    ),
                    _Chip(
                      'Тема: ${switch (app.themeMode) {
                        ThemeMode.system => 'система',
                        ThemeMode.light => 'светлая',
                        ThemeMode.dark => 'тёмная',
                      }}',
                      onTap: app.cycleTheme,
                    ),
                  ],
                ),
                if (bench.running) ...[
                  const SizedBox(height: 8),
                  Text(bench.progress, style: style.copyWith(color: c.accent)),
                ],
                if (circle.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Плеер: ${circle.error}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(color: const Color(0xFFD70015)),
                  ),
                ],
                if (bench.report != null) ...[
                  const SizedBox(height: 8),
                  _Results(bench: bench),
                  const SizedBox(height: 6),
                  _Chip(
                    'Скопировать отчёт',
                    onTap: () =>
                        Clipboard.setData(ClipboardData(text: bench.report!)),
                  ),
                ],
                const SizedBox(height: 6),
                Text('⌘⇧P скрыть панель', style: style.copyWith(color: c.fg2)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.bench});
  final Benchmark bench;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    String f(double v) => v.toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in bench.results) ...[
          Text(
            r.config.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          for (final e in r.phases.entries)
            Text(
              '${e.key.label}: ${f(e.value.fps)} fps, '
              'raster p95 ${f(e.value.rasterP95)} мс, '
              'дропов ${e.value.missedVsyncs} (${f(e.value.missedPct)}%)',
              style: TextStyle(color: c.fg2),
            ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.onTap, this.primary = false});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: primary && enabled ? c.accent : c.field,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: primary && enabled
                    ? Colors.white
                    : (enabled ? c.fg : c.fg2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
