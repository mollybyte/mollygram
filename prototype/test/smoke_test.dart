import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_prototype/app_state.dart';
import 'package:mollygram_prototype/chat/fake_data.dart';
import 'package:mollygram_prototype/circle/circle_controller.dart';
import 'package:mollygram_prototype/main.dart';
import 'package:mollygram_prototype/perf/frame_stats.dart';

void main() {
  testWidgets('окно строится, лента прокручивается, переключатели работают', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = AppState();
    await tester.pumpWidget(
      PrototypeApp(app: app, circle: CircleController(enabled: false)),
    );
    await tester.pump();

    expect(find.text('Аня Морозова'), findsWidgets);
    expect(find.text('Сообщение'), findsOneWidget);
    expect(find.textContaining('640 · media_kit'), findsOneWidget);

    await tester.fling(find.byType(ListView).last, const Offset(0, 3000), 4000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    app.setBlur(false);
    app.cycleTheme();
    app.cycleTheme();
    await tester.pump();
    expect(tester.takeException(), isNull);

    app.toggleOverlay();
    await tester.pump();
    expect(find.text('Замер 1 мин'), findsNothing);
  });

  test('лента детерминирована и содержит живой кружок', () {
    final a = buildMessages(5000);
    final b = buildMessages(5000);
    expect(a.length, 5000);
    expect(a[2].kind, MsgKind.liveCircle);
    expect([for (final m in a) m.text], [for (final m in b) m.text]);
  });

  test('сводка считает пропущенные vsync', () {
    // 120 Гц: шаг 8333 мкс, один кадр пропущен (двойной интервал).
    final samples = <FrameSample>[];
    var t = 0;
    for (var i = 0; i < 100; i++) {
      t += i == 50 ? 16666 : 8333;
      samples.add(
        FrameSample(
          vsyncUs: t,
          buildMs: 1,
          rasterMs: i == 50 ? 12 : 2,
          totalMs: 4,
        ),
      );
    }
    final s = FrameSummary.of(samples, 120);
    expect(s.frames, 100);
    expect(s.missedVsyncs, 1);
    expect(s.overBudget, 1);
    expect(s.vsyncHz, closeTo(120, 0.5));
  });
}
