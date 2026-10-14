import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/session/close_before_exit.dart';

void main() {
  Future<AppExitResponse> requestExit(WidgetTester tester) =>
      // ignore: invalid_use_of_protected_member
      tester.binding.handleRequestAppExit();

  testWidgets('quits only after close has finished', (tester) async {
    final closing = Completer<void>();
    var closed = false;
    await tester.pumpWidget(
      CloseBeforeExit(
        close: () async {
          await closing.future;
          closed = true;
        },
        child: const SizedBox(),
      ),
    );

    AppExitResponse? response;
    unawaited(requestExit(tester).then((r) => response = r));
    await tester.pump();
    expect(response, isNull);

    closing.complete();
    await tester.pump();
    expect(closed, isTrue);
    expect(response, AppExitResponse.exit);
  });

  testWidgets('quits even if close fails', (tester) async {
    await tester.pumpWidget(
      CloseBeforeExit(
        close: () => Future.error(StateError('close failed')),
        child: const SizedBox(),
      ),
    );
    expect(await requestExit(tester), AppExitResponse.exit);
  });

  testWidgets('quits when close hangs past the timeout', (tester) async {
    await tester.pumpWidget(
      CloseBeforeExit(
        close: () => Completer<void>().future,
        timeout: const Duration(seconds: 1),
        child: const SizedBox(),
      ),
    );
    AppExitResponse? response;
    unawaited(requestExit(tester).then((r) => response = r));
    await tester.pump(const Duration(seconds: 2));
    expect(response, AppExitResponse.exit);
  });
}
