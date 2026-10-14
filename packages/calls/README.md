# mollygram_calls

Voice and video calls. A `dart:ffi` binding to `libmgcalls.dylib`, our build of Telegram's call engine: [tgcalls](https://github.com/TelegramMessenger/tgcalls) on top of [tg_owt](https://github.com/desktop-app/tg_owt) (WebRTC), with Opus, libvpx, openh264, an FFmpeg subset and OpenSSL linked statically. The library exports only the `mg_call*` C API from [`native/include/mg_calls.h`](native/include/mg_calls.h). The plan is in [docs/calls.md](../../docs/calls.md).

```dart
import 'package:mollygram_calls/mollygram_calls.dart';

final calls = MgCalls.open('libmgcalls.dylib');
calls.versions; // [13.0.0, 12.0.0, ...] for callProtocol.library_versions
calls.maxLayer; // 92
```

## Native library

All commits and versions are pinned in [`calls.json`](calls.json), the same ones tdesktop uses. The [`calls.yml`](../../.github/workflows/calls.yml) workflow builds the library on macOS runners per architecture, checks that it exports only `mg_call*` and links only system libraries, runs the FFI test against it and merges both slices into a universal dylib. On `main` it publishes a `calls-<sha>` release.

To build on a Mac (an hour or so the first time):

```sh
brew install cmake ninja meson nasm jq
packages/calls/native/deps.sh      # codecs, OpenSSL, tg_owt
packages/calls/native/build.sh     # tgcalls + C API -> .build/<arch>/out/libmgcalls.dylib
MGCALLS_PATH=$PWD/packages/calls/native/.build/$(uname -m)/out/libmgcalls.dylib \
  dart test packages/calls/test/native_test.dart
```

`deps.sh` follows tdesktop's `Telegram/build/prepare/prepare.py`; `native/CMakeLists.txt` follows its `Telegram/cmake/lib_tgcalls.cmake`. Differences from tdesktop: WebRTC's own CoreAudio device module instead of OpenAL, and a smaller FFmpeg (only the decoders tgcalls and WebRTC use).
