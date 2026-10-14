import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'bench.dart';

/// With MG_AUTOBENCH=1 in the environment (or
/// --dart-define=MG_AUTOBENCH=true), runs the suite right away, prints the
/// report to stdout and exits.
final autobench =
    const bool.fromEnvironment('MG_AUTOBENCH') ||
    Platform.environment['MG_AUTOBENCH'] == '1';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MollygramMedia.ensureInitialized();
  runApp(const BenchApp());
}

const _fg = Color(0xFF1D1D1F);
const _muted = Color(0xFF86868B);
const _accent = Color(0xFF0071E3);

class BenchApp extends StatefulWidget {
  const BenchApp({super.key});

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  late final Bench _bench = Bench(
    refreshHz: () => WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .display
        .refreshRate,
  );

  @override
  void initState() {
    super.initState();
    if (autobench) unawaited(_autobench());
  }

  Future<void> _autobench() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    await _bench.runSuite();
    stdout.writeln('MG_BENCH_REPORT_BEGIN');
    stdout.writeln(_bench.report());
    stdout.writeln('MG_BENCH_REPORT_END');
    await stdout.flush();
    exit(0);
  }

  @override
  void dispose() {
    _bench.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: _accent,
      title: 'Video message benchmark',
      textStyle: const TextStyle(fontSize: 13, color: _fg, height: 1.35),
      builder: (context, _) => ColoredBox(
        color: const Color(0xFFF5F5F7),
        child: ListenableBuilder(
          listenable: _bench,
          builder: (context, _) => _BenchView(bench: _bench),
        ),
      ),
    );
  }
}

class _BenchView extends StatelessWidget {
  const _BenchView({required this.bench});

  final Bench bench;

  @override
  Widget build(BuildContext context) {
    final run = bench.current;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Button(
                label: bench.running ? 'Running' : 'Run',
                onTap: bench.running ? null : bench.runSuite,
              ),
              const SizedBox(width: 12),
              Text(
                run == null
                    ? 'Keep the window visible during the run.'
                    : '${run.label} '
                          '(${bench.results.length + 1} of ${bench.suite.length})',
                style: const TextStyle(color: _muted),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 260,
            child: Wrap(
              spacing: 16,
              children: [
                for (final p in bench.slots)
                  _Circle(player: p, elapsed: bench.elapsed),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (bench.results.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  bench.report(),
                  style: const TextStyle(fontFamily: 'Menlo', fontSize: 11),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.player, required this.elapsed});

  final CirclePlayer? player;
  final Duration elapsed;

  static const size = 240.0;

  @override
  Widget build(BuildContext context) {
    // The ring follows the ticker, not the video position, so the benchmark
    // repaints every vsync.
    final progress = (elapsed.inMicroseconds / runDuration.inMicroseconds)
        .clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleVideo(player: player, size: size),
          Positioned.fill(child: CustomPaint(painter: _RingPainter(progress))),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = const Color(0xE6FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: onTap == null ? _muted : _accent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFFFFFFF))),
      ),
    );
  }
}
