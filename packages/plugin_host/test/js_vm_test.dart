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

  test('считает и возвращает JSON', () {
    final r = vm.eval('({a: 1 + 2, b: [true, "x"]})');
    expect(r.value, {
      'a': 3,
      'b': [true, 'x'],
    });
  });

  test('исключение плагина превращается в статус, а не падение', () {
    final r = vm.eval('throw new TypeError("boom")');
    expect(r.status, JsStatus.exception);
    expect(r.raw, contains('boom'));
    // VM жива после ошибки.
    expect(vm.eval('1').value, 1);
  });

  test('бесконечный цикл прерывается по бюджету', () {
    final sw = Stopwatch()..start();
    final r = vm.eval('for (;;) {}', budget: const Duration(milliseconds: 50));
    expect(r.status, JsStatus.timeout);
    expect(sw.elapsedMilliseconds, lessThan(1000));
    expect(vm.eval('2').value, 2);
  });

  test('переполнение памяти ловится лимитом', () {
    final small = JsVm(
      host: (_, _) => null,
      limits: const JsLimits(memoryBytes: 4 << 20),
    );
    addTearDown(small.dispose);
    final r = small.eval('const a = []; for (;;) a.push("x".repeat(1024));');
    expect(r.status, JsStatus.outOfMemory);
  });

  test('глубокая рекурсия не роняет процесс', () {
    final r = vm.eval('function f(n) { return f(n + 1) + 1 } f(0)');
    expect(r.status, JsStatus.exception);
    expect(r.raw, contains('stack'));
  });

  test('нет доступа к файлам, сети и модулям', () {
    final r = vm.eval(
      '[typeof require, typeof fetch, typeof std, typeof os, '
      'typeof XMLHttpRequest, typeof setTimeout]',
    );
    expect(r.value, everyElement('undefined'));
  });

  test('вызов хоста идёт через __mg_host', () {
    final r = vm.eval('__mg_host("ping", JSON.stringify({x: 1}))');
    expect(r.value, '{"ok":42}');
    expect(calls, ['ping {"x":1}']);
  });

  test('call передаёт аргумент как данные, а не как код', () {
    vm.eval('globalThis.echo = (x) => x');
    final r = vm.call('echo', {'s': '"); throw 1; ("'});
    expect(r.value, {'s': '"); throw 1; ("'});
  });

  test('промисы доезжают после runJobs', () {
    vm.eval('globalThis.out = 0; Promise.resolve(5).then((v) => out = v)');
    expect(vm.runJobs().isOk, isTrue);
    expect(vm.eval('out').value, 5);
  });
}
