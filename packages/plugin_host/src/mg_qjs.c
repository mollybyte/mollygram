// Тонкая обёртка над quickjs-ng для plugin_host.
//
// Наружу торчат только строки JSON: Dart никогда не видит JSValue, а плагин
// никогда не видит ничего, кроме того, что хост отдал через __mg_host.
// Лимиты: память (JS_SetMemoryLimit), стек (JS_SetMaxStackSize) и время
// (дедлайн, который проверяет обработчик прерываний).

#include <stdlib.h>
#include <string.h>
#include <time.h>

#if defined(_WIN32)
#include <windows.h>
#define MG_EXPORT __declspec(dllexport)
#else
#define MG_EXPORT __attribute__((visibility("default")))
#endif

#include "quickjs.h"

enum {
  MG_OK = 0,
  MG_EXCEPTION = 1,
  MG_TIMEOUT = 2,
  MG_OUT_OF_MEMORY = 3,
  MG_BAD_ARGUMENT = 4,
};

// Хост получает имя метода и аргументы в JSON и обязан синхронно вызвать
// mg_vm_set_host_result (или ничего, тогда плагин получит null).
typedef void (*MgHostFn)(int64_t vm_id, const char *method,
                         const char *args_json);

typedef struct MgVm {
  JSRuntime *rt;
  JSContext *ctx;
  int64_t id;
  MgHostFn host;
  int64_t memory_limit;
  int64_t deadline_ns;  // 0 = без ограничения
  int interrupted;
  char *host_result;
} MgVm;

// Бюджет считается по процессорному времени потока, а не по настенным
// часам: под нагрузкой системы честный плагин не должен получать отказ.
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
  // Время, проведённое в хосте, не должно съедать бюджет плагина
  // непредсказуемо, но и не продлевает его: дедлайн остаётся прежним.
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
  vm->rt = JS_NewRuntime();
  if (vm->rt == NULL) {
    free(vm);
    return NULL;
  }
  JS_SetMemoryLimit(vm->rt, (size_t)memory_limit);
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

// Задаёт бюджет времени на следующие вызовы; 0 снимает ограничение.
MG_EXPORT void mg_vm_set_budget_ms(MgVm *vm, int64_t ms) {
  vm->deadline_ns = ms <= 0 ? 0 : mg_now_ns() + ms * 1000000LL;
  vm->interrupted = 0;
}

MG_EXPORT int64_t mg_vm_memory_used(MgVm *vm) {
  JSMemoryUsage usage;
  JS_ComputeMemoryUsage(vm->rt, &usage);
  return usage.malloc_size;
}

MG_EXPORT void mg_free(void *p) { free(p); }

// Превращает текущее исключение в строку и код статуса.
static int mg_take_exception(MgVm *vm, char **out) {
  JSContext *ctx = vm->ctx;
  JSValue exc = JS_GetException(ctx);
  int status = MG_EXCEPTION;
  if (vm->interrupted) status = MG_TIMEOUT;
  const char *msg = JS_ToCString(ctx, exc);
  if (msg != NULL && strstr(msg, "out of memory") != NULL)
    status = MG_OUT_OF_MEMORY;
  // Если памяти не хватило даже на объект ошибки, QuickJS бросает null.
  // Отличаем это от `throw null` в плагине по заполненности кучи.
  if (status == MG_EXCEPTION && JS_IsNull(exc) &&
      mg_vm_memory_used(vm) > vm->memory_limit / 10 * 9)
    status = MG_OUT_OF_MEMORY;
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
      // Когда памяти нет даже на сообщение, отдаём статус без текста.
      if (status == MG_EXCEPTION && !vm->interrupted) status = MG_OUT_OF_MEMORY;
      text = mg_strdup("", 0);
    }
  }
  JS_FreeCString(ctx, msg);
  JS_FreeValue(ctx, exc);
  *out = text;
  return status;
}

// Изолят Dart может между событиями переехать на другой поток ОС, поэтому
// перед каждым входом в JS обновляем вершину стека для проверки рекурсии.
static void mg_enter(MgVm *vm) { JS_UpdateStackTop(vm->rt); }

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

// Выполняет скрипт. В *out кладёт JSON результата или текст ошибки;
// строку освобождает вызывающий через mg_free.
MG_EXPORT int mg_vm_eval(MgVm *vm, const char *code, int64_t len,
                         const char *filename, char **out) {
  mg_enter(vm);
  JSValue val = JS_Eval(vm->ctx, code, (size_t)len, filename,
                        JS_EVAL_TYPE_GLOBAL | JS_EVAL_FLAG_STRICT);
  if (JS_IsException(val)) return mg_take_exception(vm, out);
  int status = mg_stringify(vm, val, out);
  JS_FreeValue(vm->ctx, val);
  return status;
}

// Вызывает глобальную функцию fn с одним аргументом, разобранным из JSON.
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
  return status;
}

// Прогоняет очередь промисов. Возвращает MG_OK, когда очередь пуста.
MG_EXPORT int mg_vm_run_jobs(MgVm *vm, char **out) {
  JSContext *job_ctx;
  mg_enter(vm);
  for (;;) {
    int r = JS_ExecutePendingJob(vm->rt, &job_ctx);
    if (r == 0) break;
    if (r < 0) return mg_take_exception(vm, out);
  }
  *out = NULL;
  return MG_OK;
}
