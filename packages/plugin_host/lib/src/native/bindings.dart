// Bindings to src/mg_qjs.c. The library is built by hook/build.dart.
// ignore_for_file: non_constant_identifier_names
@DefaultAsset('package:plugin_host/src/native/bindings.dart')
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

final class MgVm extends Opaque {}

typedef MgHostFnNative = Void Function(
  Int64 vmId,
  Pointer<Utf8> method,
  Pointer<Utf8> argsJson,
);

@Native<
  Pointer<MgVm> Function(
    Int64,
    Int64,
    Int64,
    Pointer<NativeFunction<MgHostFnNative>>,
  )
>()
external Pointer<MgVm> mg_vm_new(
  int id,
  int memoryLimit,
  int stackLimit,
  Pointer<NativeFunction<MgHostFnNative>> host,
);

@Native<Void Function(Pointer<MgVm>)>()
external void mg_vm_free(Pointer<MgVm> vm);

@Native<Void Function(Pointer<MgVm>, Pointer<Utf8>)>()
external void mg_vm_set_host_result(Pointer<MgVm> vm, Pointer<Utf8> json);

@Native<Void Function(Pointer<MgVm>, Int64)>()
external void mg_vm_set_budget_ms(Pointer<MgVm> vm, int ms);

@Native<Int64 Function(Pointer<MgVm>)>()
external int mg_vm_memory_used(Pointer<MgVm> vm);

@Native<Void Function(Pointer<Void>)>()
external void mg_free(Pointer<Void> p);

@Native<
  Int32 Function(
    Pointer<MgVm>,
    Pointer<Utf8>,
    Int64,
    Pointer<Utf8>,
    Pointer<Pointer<Utf8>>,
  )
>()
external int mg_vm_eval(
  Pointer<MgVm> vm,
  Pointer<Utf8> code,
  int len,
  Pointer<Utf8> filename,
  Pointer<Pointer<Utf8>> out,
);

@Native<
  Int32 Function(
    Pointer<MgVm>,
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<Pointer<Utf8>>,
  )
>()
external int mg_vm_call(
  Pointer<MgVm> vm,
  Pointer<Utf8> fn,
  Pointer<Utf8> argJson,
  Pointer<Pointer<Utf8>> out,
);

@Native<Int32 Function(Pointer<MgVm>, Pointer<Pointer<Utf8>>)>()
external int mg_vm_run_jobs(Pointer<MgVm> vm, Pointer<Pointer<Utf8>> out);
