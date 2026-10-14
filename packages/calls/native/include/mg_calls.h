// C API of libmgcalls, the call engine of Mollygram (tgcalls + WebRTC).
//
// Only symbols starting with mg_call are exported. Strings returned by the
// library are owned by it and stay valid for the lifetime of the process.

#ifndef MG_CALLS_H
#define MG_CALLS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(MGCALLS_BUILD)
#define MG_CALLS_API __attribute__((visibility("default")))
#else
#define MG_CALLS_API
#endif

// Version of this C API. Bumped on every incompatible change, so Dart can
// refuse a library it was not written for.
#define MG_CALLS_API_VERSION 1

MG_CALLS_API int32_t mg_calls_api_version(void);

// tgcalls versions this library can connect with, newest first, as a JSON
// array of strings. Goes into callProtocol.library_versions.
MG_CALLS_API const char *mg_calls_versions_json(void);

// Highest API layer the registered implementations support. Goes into
// callProtocol.max_layer.
MG_CALLS_API int32_t mg_calls_max_layer(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // MG_CALLS_H
