// A thin wrapper around quickjs-ng for plugin_host.
//
// Only JSON strings cross the boundary: Dart never sees a JSValue, and the
// plugin never sees anything except what the host handed over via __mg_host.
// Limits: memory (our own allocator, see mg_malloc), stack
// (JS_SetMaxStackSize) and time (a deadline checked by the interrupt
// handler).

#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(_WIN32)
#include <windows.h>
#define MG_EXPORT __declspec(dllexport)
#else
#define MG_EXPORT __attribute__((visibility("default")))
#endif

#include "cutils.h"
#include "quickjs.h"

enum {
  MG_OK = 0,
  MG_EXCEPTION = 1,
  MG_TIMEOUT = 2,
  MG_OUT_OF_MEMORY = 3,
  MG_BAD_ARGUMENT = 4,
};

// The host receives the method name and JSON arguments and must
// synchronously call mg_vm_set_host_result (or nothing, in which case the
// plugin gets null).
typedef void (*MgHostFn)(int64_t vm_id, const char *method,
                         const char *args_json);

typedef struct MgVm {
  JSRuntime *rt;
  JSContext *ctx;
  int64_t id;
  MgHostFn host;
  int64_t memory_limit;
  int64_t heap_used;    // bytes handed out by mg_malloc and friends
  int out_of_memory;    // an allocation was refused since the last entry
  int64_t deadline_ns;  // 0 = no limit
  int interrupted;
  char *host_result;
} MgVm;

// The budget is measured in thread CPU time, not wall-clock time: a
// well-behaved plugin must not be rejected just because the system is busy.
static int64_t mg_now_ns(void) {
#if defined(_WIN32)
  FILETIME creation, exit, kernel, user;
  GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernel, &user);
  ULARGE_INTEGER k, u;
  k.LowPart = kernel.dwLowDateTime;
  k.HighPart = kernel.dwHighDateTime;
  u.LowPart = user.dwLowDateTime;
  u.HighPart = user.dwHighDateTime;
  return (int64_t)(k.QuadPart + u.QuadPart) * 100;
#else
  struct timespec ts;
  clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);
  return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
#endif
}

// The heap limit is enforced here rather than with JS_SetMemoryLimit so we
// know for sure when it was hit. QuickJS reports a refused allocation as an
// exception, but when the heap is full even that can fail, and inside a
// promise job the failure is swallowed into a rejected promise nobody
// listens to. Which of these happens depends on the platform's malloc
// rounding, so heap-usage heuristics are not reliable (they missed it on
// Windows). A refused allocation sets a flag that the next return to the
// host turns into MG_OUT_OF_MEMORY.
static size_t mg_usable(const void *p) {
  return p == NULL ? 0 : js__malloc_usable_size(p);
}

static int mg_admit(MgVm *vm, size_t freed, size_t size) {
  if (vm->heap_used - (int64_t)freed + (int64_t)size > vm->memory_limit) {
    vm->out_of_memory = 1;
    return 0;
  }
  return 1;
}

static void *mg_malloc(void *opaque, size_t size) {
  MgVm *vm = opaque;
  if (!mg_admit(vm, 0, size)) return NULL;
  void *p = malloc(size);
  vm->heap_used += (int64_t)mg_usable(p);
  return p;
}

static void *mg_calloc(void *opaque, size_t count, size_t size) {
  MgVm *vm = opaque;
  if (size != 0 && count > SIZE_MAX / size) return NULL;
  if (!mg_admit(vm, 0, count * size)) return NULL;
  void *p = calloc(count, size);
  vm->heap_used += (int64_t)mg_usable(p);
  return p;
}

static void mg_free_block(void *opaque, void *ptr) {
  MgVm *vm = opaque;
  vm->heap_used -= (int64_t)mg_usable(ptr);
  free(ptr);
}

static void *mg_realloc(void *opaque, void *ptr, size_t size) {
  MgVm *vm = opaque;
  size_t old = mg_usable(ptr);
  if (size > old && !mg_admit(vm, old, size)) return NULL;
  void *p = realloc(ptr, size);
  // realloc(p, 0) may free p and return NULL.
  if (p != NULL || size == 0) vm->heap_used += (int64_t)mg_usable(p) - (int64_t)old;
  return p;
}

static const JSMallocFunctions mg_malloc_funcs = {
    mg_calloc, mg_malloc, mg_free_block, mg_realloc, js__malloc_usable_size,
};

static int mg_interrupt(JSRuntime *rt, void *opaque) {
  (void)rt;
  MgVm *vm = opaque;
  if (vm->deadline_ns != 0 && mg_now_ns() > vm->deadline_ns) {
    vm->interrupted = 1;
    return 1;
  }
  return 0;
}

static char *mg_strdup(const char *s, size_t len) {
  char *out = malloc(len + 1);
  if (out == NULL) return NULL;
  memcpy(out, s, len);
  out[len] = 0;
  return out;
}

// __mg_host(method: string, argsJson: string): string | null
static JSValue mg_host_call(JSContext *ctx, JSValueConst this_val, int argc,
                            JSValueConst *argv) {
  (void)this_val;
  MgVm *vm = JS_GetContextOpaque(ctx);
  if (argc < 2 || !JS_IsString(argv[0]) || !JS_IsString(argv[1]))
    return JS_ThrowTypeError(ctx, "__mg_host(method, json)");
  const char *method = JS_ToCString(ctx, argv[0]);
  const char *args = JS_ToCString(ctx, argv[1]);
  if (method == NULL || args == NULL) {
    JS_FreeCString(ctx, method);
    JS_FreeCString(ctx, args);
    return JS_EXCEPTION;
  }
  free(vm->host_result);
  vm->host_result = NULL;
  // Time spent in the host must not eat into the plugin's budget
  // unpredictably, but it does not extend it either: the deadline stays.
  vm->host(vm->id, method, args);
  JS_FreeCString(ctx, method);
  JS_FreeCString(ctx, args);
  if (vm->host_result == NULL) return JS_NULL;
  JSValue res = JS_NewString(ctx, vm->host_result);
  free(vm->host_result);
  vm->host_result = NULL;
  return res;
}

MG_EXPORT MgVm *mg_vm_new(int64_t id, int64_t memory_limit,
                          int64_t stack_limit, MgHostFn host) {
  MgVm *vm = calloc(1, sizeof(MgVm));
  if (vm == NULL) return NULL;
  vm->id = id;
  vm->host = host;
  vm->memory_limit = memory_limit;
  vm->rt = JS_NewRuntime2(&mg_malloc_funcs, vm);
  if (vm->rt == NULL) {
    free(vm);
    return NULL;
  }
  JS_SetMaxStackSize(vm->rt, (size_t)stack_limit);
  JS_SetInterruptHandler(vm->rt, mg_interrupt, vm);
  vm->ctx = JS_NewContext(vm->rt);
  if (vm->ctx == NULL) {
    JS_FreeRuntime(vm->rt);
    free(vm);
    return NULL;
  }
  JS_SetContextOpaque(vm->ctx, vm);
  JSValue global = JS_GetGlobalObject(vm->ctx);
  JS_SetPropertyStr(vm->ctx, global, "__mg_host",
                    JS_NewCFunction(vm->ctx, mg_host_call, "__mg_host", 2));
  JS_FreeValue(vm->ctx, global);
  return vm;
}

MG_EXPORT void mg_vm_free(MgVm *vm) {
  if (vm == NULL) return;
  free(vm->host_result);
  JS_FreeContext(vm->ctx);
  JS_FreeRuntime(vm->rt);
  free(vm);
}

MG_EXPORT void mg_vm_set_host_result(MgVm *vm, const char *json) {
  free(vm->host_result);
  vm->host_result = json == NULL ? NULL : mg_strdup(json, strlen(json));
}

// Sets the time budget for subsequent calls; 0 removes the limit.
MG_EXPORT void mg_vm_set_budget_ms(MgVm *vm, int64_t ms) {
  vm->deadline_ns = ms <= 0 ? 0 : mg_now_ns() + ms * 1000000LL;
  vm->interrupted = 0;
}

MG_EXPORT int64_t mg_vm_memory_used(MgVm *vm) {
  return vm->heap_used;
}

// Whether an allocation was refused since the VM was last entered. Lets a
// host callback tell a plugin's own error from running out of memory.
MG_EXPORT int mg_vm_out_of_memory(MgVm *vm) { return vm->out_of_memory; }

MG_EXPORT void mg_free(void *p) { free(p); }

// Converts the pending exception into a string and a status code.
static int mg_take_exception(MgVm *vm, char **out) {
  JSContext *ctx = vm->ctx;
  JSValue exc = JS_GetException(ctx);
  int status = MG_EXCEPTION;
  if (vm->interrupted) status = MG_TIMEOUT;
  const char *msg = JS_ToCString(ctx, exc);
  if (vm->out_of_memory) status = MG_OUT_OF_MEMORY;
  size_t len = 0;
  char *text = NULL;
  if (JS_IsError(exc)) {
    JSValue stack = JS_GetPropertyStr(ctx, exc, "stack");
    const char *st = JS_IsString(stack) ? JS_ToCString(ctx, stack) : NULL;
    if (msg != NULL) {
      size_t a = strlen(msg), b = st ? strlen(st) : 0;
      text = malloc(a + b + 2);
      if (text != NULL) {
        memcpy(text, msg, a);
        text[a] = '\n';
        if (b) memcpy(text + a + 1, st, b);
        text[a + 1 + b] = 0;
      }
    }
    JS_FreeCString(ctx, st);
    JS_FreeValue(ctx, stack);
  }
  if (text == NULL) {
    if (msg != NULL) {
      len = strlen(msg);
      text = mg_strdup(msg, len);
    } else {
      text = mg_strdup("", 0);
    }
  }
  JS_FreeCString(ctx, msg);
  JS_FreeValue(ctx, exc);
  *out = text;
  return status;
}

// A Dart isolate may move to another OS thread between events, so update
// the stack top for the recursion check before every entry into JS.
static void mg_enter(MgVm *vm) {
  JS_UpdateStackTop(vm->rt);
  vm->out_of_memory = 0;
}

// Reports a refused allocation even when the plugin code caught it or it
// was swallowed by a promise: the plugin is over its memory limit either
// way. Replaces any result already stored in *out.
static int mg_leave(MgVm *vm, int status, char **out) {
  if (!vm->out_of_memory || status == MG_OUT_OF_MEMORY) return status;
  free(*out);
  *out = mg_strdup("", 0);
  return MG_OUT_OF_MEMORY;
}

static int mg_stringify(MgVm *vm, JSValue val, char **out) {
  JSContext *ctx = vm->ctx;
  if (JS_IsUndefined(val)) {
    *out = mg_strdup("null", 4);
    return MG_OK;
  }
  JSValue json = JS_JSONStringify(ctx, val, JS_UNDEFINED, JS_UNDEFINED);
  if (JS_IsException(json)) return mg_take_exception(vm, out);
  if (JS_IsUndefined(json)) {
    *out = mg_strdup("null", 4);
    return MG_OK;
  }
  size_t len;
  const char *s = JS_ToCStringLen(ctx, &len, json);
  JS_FreeValue(ctx, json);
  if (s == NULL) return mg_take_exception(vm, out);
  *out = mg_strdup(s, len);
  JS_FreeCString(ctx, s);
  return MG_OK;
}

// Evaluates a script. Stores the result JSON or error text in *out; the
// caller frees the string with mg_free.
MG_EXPORT int mg_vm_eval(MgVm *vm, const char *code, int64_t len,
                         const char *filename, char **out) {
  mg_enter(vm);
  JSValue val = JS_Eval(vm->ctx, code, (size_t)len, filename,
                        JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_STRICT);
  if (JS_IsException(val)) return mg_take_exception(vm, out);
  int status = mg_stringify(vm, val, out);
  JS_FreeValue(vm->ctx, val);
  return mg_leave(vm, status, out);
}

// Calls the global function fn with one argument parsed from JSON.
MG_EXPORT int mg_vm_call(MgVm *vm, const char *fn, const char *arg_json,
                         char **out) {
  JSContext *ctx = vm->ctx;
  mg_enter(vm);
  JSValue global = JS_GetGlobalObject(ctx);
  JSValue func = JS_GetPropertyStr(ctx, global, fn);
  JS_FreeValue(ctx, global);
  if (!JS_IsFunction(ctx, func)) {
    JS_FreeValue(ctx, func);
    *out = mg_strdup("not a function", 14);
    return MG_BAD_ARGUMENT;
  }
  JSValue arg = JS_ParseJSON(ctx, arg_json, strlen(arg_json), "<host>");
  if (JS_IsException(arg)) {
    JS_FreeValue(ctx, func);
    return mg_take_exception(vm, out);
  }
  JSValue val = JS_Call(ctx, func, JS_UNDEFINED, 1, (JSValueConst *)&arg);
  JS_FreeValue(ctx, arg);
  JS_FreeValue(ctx, func);
  if (JS_IsException(val)) return mg_take_exception(vm, out);
  int status = mg_stringify(vm, val, out);
  JS_FreeValue(ctx, val);
  return mg_leave(vm, status, out);
}

// Runs the promise job queue. Returns MG_OK when the queue is empty.
MG_EXPORT int mg_vm_run_jobs(MgVm *vm, char **out) {
  JSContext *job_ctx;
  mg_enter(vm);
  for (;;) {
    int r = JS_ExecutePendingJob(vm->rt, &job_ctx);
    if (r == 0) break;
    if (r < 0) return mg_take_exception(vm, out);
  }
  *out = NULL;
  return mg_leave(vm, MG_OK, out);
}
