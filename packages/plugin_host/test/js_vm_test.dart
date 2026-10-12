import 'package:plugin_host/src/js_vm.dart';
import 'package:test/test.dart';

void main() {
  late JsVm vm;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    vm = JsVm(
      host: (method, args) {
        calls.add('$method $args');
        return '{"ok":42}';
      },
    );
  });
  tearDown(() => vm.dispose());

  test('evaluates and returns JSON', () {
    final r = vm.eval('({a: 1 + 2, b: [true, "x"]})');
    expect(r.value, {
      'a': 3,
      'b': [true, 'x'],
    });
  });

  test('a plugin exception becomes a status, not a crash', () {
    final r = vm.eval('throw new TypeError("boom")');
    expect(r.status, JsStatus.exception);
    expect(r.raw, contains('boom'));
    // The VM is still alive after the error.
    expect(vm.eval('1').value, 1);
  });

  test('an infinite loop is interrupted by the budget', () {
    final sw = Stopwatch()..start();
    final r = vm.eval('for (;;) {}', budget: const Duration(milliseconds: 50));
    expect(r.status, JsStatus.timeout);
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(vm.eval('2').value, 2);
  });

  test('running out of memory is caught by the limit', () {
    final small = JsVm(
      host: (_, _) => null,
      limits: const JsLimits(memoryBytes: 4 << 20),
    );
    addTearDown(small.dispose);
    final r = small.eval('const a = []; for (;;) a.push("x".repeat(1024));');
    expect(r.status, JsStatus.outOfMemory);
  });

  test('deep recursion does not crash the process', () {
    final r = vm.eval('function f(n) { return f(n + 1) + 1 } f(0)');
    expect(r.status, JsStatus.exception);
    expect(r.raw, contains('stack'));
  });

  test('no access to files, network or modules', () {
    final r = vm.eval(
      '[typeof require, typeof fetch, typeof std, typeof os, '
      'typeof XMLHttpRequest, typeof setTimeout]',
    );
    expect(r.value, everyElement('undefined'));
  });

  test('host calls go through __mg_host', () {
    final r = vm.eval('__mg_host("ping", JSON.stringify({x: 1}))');
    expect(r.value, '{"ok":42}');
    expect(calls, ['ping {"x":1}']);
  });

  test('call passes the argument as data, not code', () {
    vm.eval('globalThis.echo = (x) => x');
    final r = vm.call('echo', {'s': '"); throw 1; ("'});
    expect(r.value, {'s': '"); throw 1; ("'});
  });

  test('promises settle after runJobs', () {
    vm.eval('globalThis.out = 0; Promise.resolve(5).then((v) => out = v)');
    expect(vm.runJobs().isOk, isTrue);
    expect(vm.eval('out').value, 5);
  });
}
