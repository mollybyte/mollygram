import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'native/bindings.dart';

/// How a call into the sandbox ended.
enum JsStatus { ok, exception, timeout, outOfMemory, badArgument }

final class JsResult {
  const JsResult(this.status, this.raw);

  final JsStatus status;

  /// The result JSON for [JsStatus.ok], otherwise the error text with stack.
  final String raw;

  bool get isOk => status == JsStatus.ok;

  Object? get value => isOk ? jsonDecode(raw) : null;

  @override
  String toString() => '$status: $raw';
}

/// Handles `__mg_host(method, json)` calls from JS.
///
/// Called synchronously in the middle of JS execution; must return a JSON
/// string or null.
typedef JsHostHandler = String? Function(String method, String argsJson);

/// Limits for a single virtual machine.
final class JsLimits {
  const JsLimits({
    this.memoryBytes = 32 << 20,
    this.stackBytes = 512 << 10,
    this.loadBudget = const Duration(milliseconds: 500),
    this.callBudget = const Duration(milliseconds: 100),
  });

  /// The QuickJS heap ceiling.
  ///
  /// When it is exceeded, the plugin gets an exception and the host disables
  /// the plugin.
  final int memoryBytes;
  final int stackBytes;

  /// How much CPU time loading the plugin may take.
  final Duration loadBudget;

  /// How long a single synchronous entry into JS may take: an event
  /// handler, a command or a promise queue run.
  final Duration callBudget;
}

/// A single isolated quickjs-ng JSRuntime.
///
/// It has no files, network, timers or modules: everything a plugin can do
/// outside goes through [JsHostHandler].
///
/// Not thread-safe: it lives in the isolate where it was created.
final class JsVm {
  JsVm({required this._host, this.limits = const JsLimits()})
    : _id = _nextId++ {
    _callback ??= NativeCallable<MgHostFnNative>.isolateLocal(_dispatchHost);
    final ptr = mg_vm_new(
      _id,
      limits.memoryBytes,
      limits.stackBytes,
      _callback!.nativeFunction,
    );
    if (ptr == nullptr) {
      throw StateError('quickjs: failed to create runtime');
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
      // An error in host code must not propagate through the QuickJS C stack.
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

  /// Calls the global function [function] with a single JSON argument.
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

  /// Runs microtasks (promise continuations) until the queue is empty.
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
    if (_disposed) throw StateError('JsVm is already disposed');
  }
}
