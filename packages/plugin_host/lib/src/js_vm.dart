import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'native/bindings.dart';

/// Чем закончился вызов в песочнице.
enum JsStatus { ok, exception, timeout, outOfMemory, badArgument }

final class JsResult {
  const JsResult(this.status, this.raw);

  final JsStatus status;

  /// JSON результата при [JsStatus.ok], иначе текст ошибки со стеком.
  final String raw;

  bool get isOk => status == JsStatus.ok;

  Object? get value => isOk ? jsonDecode(raw) : null;

  @override
  String toString() => '$status: $raw';
}

/// Обработчик вызовов `__mg_host(method, json)` из JS. Вызывается синхронно
/// посреди исполнения JS и должен вернуть JSON-строку или null.
typedef JsHostHandler = String? Function(String method, String argsJson);

/// Лимиты одной виртуальной машины.
final class JsLimits {
  const JsLimits({
    this.memoryBytes = 32 << 20,
    this.stackBytes = 512 << 10,
    this.loadBudget = const Duration(milliseconds: 500),
    this.callBudget = const Duration(milliseconds: 100),
  });

  /// Потолок кучи QuickJS. При превышении плагин получает исключение,
  /// а хост выключает плагин.
  final int memoryBytes;
  final int stackBytes;

  /// Сколько процессорного времени может занять загрузка плагина.
  final Duration loadBudget;

  /// Сколько может занять один синхронный заход в JS: обработчик события,
  /// команда или прогон очереди промисов.
  final Duration callBudget;
}

/// Один изолированный JSRuntime quickjs-ng. Без файлов, сети, таймеров и
/// модулей: всё, что плагин может сделать снаружи, идёт через [JsHostHandler].
///
/// Не потокобезопасен: живёт в том изоляте, где создан.
final class JsVm {
  JsVm({required JsHostHandler host, this.limits = const JsLimits()})
    : _host = host,
      _id = _nextId++ {
    _callback ??= NativeCallable<MgHostFnNative>.isolateLocal(_dispatchHost);
    final ptr = mg_vm_new(
      _id,
      limits.memoryBytes,
      limits.stackBytes,
      _callback!.nativeFunction,
    );
    if (ptr == nullptr) {
      throw StateError('quickjs: не удалось создать runtime');
    }
    _ptr = ptr;
    _live[_id] = this;
  }

  static int _nextId = 1;
  static final _live = <int, JsVm>{};
  static NativeCallable<MgHostFnNative>? _callback;

  final int _id;
  final JsHostHandler _host;
  final JsLimits limits;
  late Pointer<MgVm> _ptr;
  bool _disposed = false;

  static void _dispatchHost(
    int vmId,
    Pointer<Utf8> method,
    Pointer<Utf8> args,
  ) {
    final vm = _live[vmId];
    if (vm == null) return;
    String? result;
    try {
      result = vm._host(method.toDartString(), args.toDartString());
    } catch (e) {
      // Ошибка в коде хоста не должна пролетать сквозь C-стек QuickJS.
      result = jsonEncode({
        'error': {'code': 'host_failure', 'message': '$e'},
      });
    }
    if (result == null) return;
    final native = result.toNativeUtf8();
    mg_vm_set_host_result(vm._ptr, native);
    malloc.free(native);
  }

  int get memoryUsed {
    _checkAlive();
    return mg_vm_memory_used(_ptr);
  }

  JsResult eval(String code, {String filename = '<eval>', Duration? budget}) {
    _checkAlive();
    return using((arena) {
      final src = code.toNativeUtf8(allocator: arena);
      final name = filename.toNativeUtf8(allocator: arena);
      final out = arena<Pointer<Utf8>>();
      mg_vm_set_budget_ms(_ptr, (budget ?? limits.loadBudget).inMilliseconds);
      final status = mg_vm_eval(_ptr, src, src.length, name, out);
      return _result(status, out.value);
    });
  }

  /// Вызывает глобальную функцию [function] с одним JSON-аргументом.
  JsResult call(String function, Object? arg, {Duration? budget}) {
    _checkAlive();
    return using((arena) {
      final fn = function.toNativeUtf8(allocator: arena);
      final json = jsonEncode(arg).toNativeUtf8(allocator: arena);
      final out = arena<Pointer<Utf8>>();
      mg_vm_set_budget_ms(_ptr, (budget ?? limits.callBudget).inMilliseconds);
      final status = mg_vm_call(_ptr, fn, json, out);
      return _result(status, out.value);
    });
  }

  /// Прогоняет микрозадачи (продолжения промисов) до опустошения очереди.
  JsResult runJobs({Duration? budget}) {
    _checkAlive();
    return using((arena) {
      final out = arena<Pointer<Utf8>>();
      out.value = nullptr;
      mg_vm_set_budget_ms(_ptr, (budget ?? limits.callBudget).inMilliseconds);
      final status = mg_vm_run_jobs(_ptr, out);
      return _result(status, out.value);
    });
  }

  JsResult _result(int status, Pointer<Utf8> out) {
    var text = 'null';
    if (out != nullptr) {
      text = out.toDartString();
      mg_free(out.cast());
    }
    return JsResult(JsStatus.values[status], text);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _live.remove(_id);
    mg_vm_free(_ptr);
  }

  bool get isDisposed => _disposed;

  void _checkAlive() {
    if (_disposed) throw StateError('JsVm уже освобождена');
  }
}
