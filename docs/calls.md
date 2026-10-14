# Calls on macOS

Research for stage 8 ("Calls and macOS release"): how to get Telegram voice and video calls into Mollygram on macOS through `dart:ffi`. No app code yet. Sources were checked on 2026-10-13 against these commits:

| Source | Commit | Notes |
|--------|--------|-------|
| [TDLib](https://github.com/tdlib/td) | 1.8.68, `c15d3f5` (our pin, `packages/tdlib/tdlib.json`) | Call API in `packages/tdlib/schema/td_api.tl` |
| [tgcalls](https://github.com/TelegramMessenger/tgcalls) | `8d6dd4c` (master, 2026-10-12) | Telegram's call engine, used by every official client |
| [tg_owt](https://github.com/desktop-app/tg_owt) | `d1cf250` (2026-10-07) | Telegram's WebRTC fork with a CMake build |
| [tdesktop](https://github.com/telegramdesktop/tdesktop) | `3f406f0` (2026-10-13) | Reference integration; pins tgcalls `1c236c0`, tg_owt `d1cf250`, lib_webrtc `52636e8` |
| [lib_webrtc](https://github.com/desktop-app/lib_webrtc) | `52636e8` | tdesktop's audio device module, device lists, video track sink |

## Summary

- TDLib does all of the call signaling (creating, accepting, key exchange, emoji fingerprint, server list) but carries no audio or video. The media engine is **tgcalls** on top of **WebRTC**, and we have to ship it ourselves. This is how every TDLib client with calls works (Telegram X, Unigram).
- Recommended: one native library, `libmgcalls.dylib`, built in CI the same way `libtdjson.dylib` is. Inside: tgcalls + tg_owt + their codecs, statically linked, with a small C API on top (`mg_call_*`). Dart talks to it through `dart:ffi`; only video frames need a few lines of Swift for Flutter's texture registry.
- Licensing is fine for a GPL-3.0 app: tgcalls is LGPL-3.0, WebRTC and its parts are BSD-style, OpenSSL 3 is Apache-2.0. The one real concern is H.264 patents (see [Licensing](#licensing)).
- Effort: about 6–9 weeks for one-to-one voice and video calls of release quality, plus 4–6 weeks for group calls and video chats. The native build is the riskiest part and should start first.

## How a call works with TDLib

TDLib exposes one-to-one calls through a handful of methods and updates (all present in our 1.8.68 schema):

| Step | TDLib | tgcalls |
|------|-------|---------|
| Outgoing call | `createCall(user_id, protocol, is_video)` → `callId` | — |
| Incoming call | `updateCall` with `callStatePending(is_received)` | — |
| Accept | `acceptCall(call_id, protocol)` | — |
| Key exchange | `updateCall` → `callStateExchangingKeys` | — |
| Connect | `updateCall` → `callStateReady(protocol, servers, config, encryption_key, emojis, allow_p2p, is_group_call_supported, custom_parameters)` | `Meta::Create(version, Descriptor)` |
| Signaling, both ways | `updateNewCallSignalingData(call_id, data)` / `sendCallSignalingData(call_id, data)` | `receiveSignalingData(bytes)` / `signalingDataEmitted(bytes)` |
| Hang up | `discardCall(call_id, is_disconnected, invite_link, duration, is_video, connection_id)` | `stop(completion)` → `FinalState` (debug log, persistent state) |
| After the call | `callStateDiscarded(need_rating, need_debug_information, need_log)` → `sendCallRating`, `sendCallDebugInformation`, `sendCallLog` | `FinalState.debugLog` |

`callProtocol` carries `udp_p2p`, `udp_reflector`, `min_layer`, `max_layer` and `library_versions`. We fill it from tgcalls itself, exactly as tdesktop does (`calls_call.cpp`): `min_layer = 65`, `max_layer = tgcalls::Meta::MaxLayer()`, `library_versions = tgcalls::Meta::Versions()` newest first. In `callStateReady`, the first entry of `protocol.library_versions` is the version both sides agreed on, and it selects the tgcalls implementation.

Mapping `callStateReady` to `tgcalls::Descriptor`:

- `encryption_key` (256 bytes) → `EncryptionKey{value, isOutgoing}`; `isOutgoing` comes from `call.is_outgoing`.
- `servers` → `callServerTypeTelegramReflector(peer_tag, is_tcp)` becomes an `Endpoint` (`UdpRelay`/`TcpRelay`, 16-byte `peerTag`); `callServerTypeWebrtc(username, password, supports_turn, supports_stun)` becomes one or two `RtcServer` entries (STUN and/or TURN).
- `allow_p2p` → `Config.enableP2P`; `max_layer` → `Config.maxApiLayer`; `custom_parameters` → `Config.customParameters`.
- `config` is a JSON string from the server; tgcalls reads it for its own parameters. Timeouts (`initializationTimeout`, `receiveTimeout`) come from TDLib options (`call_connect_timeout_ms`, `call_packet_timeout_ms`).
- tdesktop uses `enableAEC = false, enableNS = true, enableAGC = true` on desktop; we copy that.
- `emojis` is the four-emoji key fingerprint shown in the call window.

Versions registered by tgcalls today: `InstanceImpl` 2.7.7 and 5.0.0, `InstanceV2Impl` 7.0.0–13.0.0 (13.0.0 is the production engine per tgcalls' July 2026 engine audit), `InstanceV2ReferenceImpl` 10.0.0 and 11.0.0, `InstanceV2CompatImpl` 14.0.0. tdesktop registers `InstanceImpl`, `InstanceV2Impl` and `InstanceV2ReferenceImpl`, and we should register exactly the same set; anything else risks connecting with an engine nobody on desktop has tested. The legacy libtgvoip engine (2.4.4) is not needed.

Group calls and video chats use a different path: `joinGroupCall` / `joinVideoChat` take a `groupCallJoinParameters.payload` produced by tgcalls (`GroupInstanceInterface::emitJoinPayload`) and return the server's answer, which goes back into `setJoinResponsePayload`. Conference calls (end-to-end encrypted group calls) also route media keys through TDLib: tgcalls' `e2eEncryptDecrypt` callback calls `encryptGroupCallData` / `decryptGroupCallData`, and `updateGroupCallVerificationState` provides the emoji. Upgrading a one-to-one call to a conference is `callDiscardReasonUpgradeToGroupCall(invite_link)`.

## Architecture

```
Flutter UI (call window, incoming call banner)
   │  Riverpod state
packages/calls (Dart)
   ├─ CallController: TDLib updates ⇄ native instance
   ├─ dart:ffi → libmgcalls.dylib (C API)
   └─ CallVideoView → Flutter Texture (Swift, ~150 lines)
libmgcalls.dylib
   ├─ mg_calls C API (our code, C++ → extern "C")
   ├─ tgcalls (LGPL-3.0), platform/darwin + desktop_capturer
   ├─ lib_webrtc parts: audio device module, device lists (optional, see below)
   └─ tg_owt (WebRTC) + opus, libvpx, openh264, dav1d, ffmpeg (subset), openssl, rnnoise, libyuv, abseil
```

The C API should be small and own every thread crossing. A first sketch:

```c
typedef struct mg_call mg_call;

// Versions and max layer for callProtocol.
const char *mg_calls_versions_json(void);
int32_t     mg_calls_max_layer(void);

// Created on callStateReady. `ready_json` is the TDLib object as JSON;
// the library does the Descriptor mapping itself, so Dart never touches C++ types.
mg_call *mg_call_create(const char *ready_json, int32_t is_outgoing,
                        const mg_call_callbacks *callbacks, void *user_data);
void     mg_call_receive_signaling(mg_call *, const uint8_t *data, size_t size);
void     mg_call_set_muted(mg_call *, int32_t muted);
void     mg_call_set_video(mg_call *, int32_t source /* off, camera, screen */, const char *device_id);
void     mg_call_set_devices(mg_call *, const char *input_id, const char *output_id);
void     mg_call_set_video_sink(mg_call *, int32_t remote, mg_frame_sink sink, void *sink_data);
void     mg_call_stop(mg_call *, mg_call_stopped_fn done, void *user_data);
```

Callbacks (`state`, `signal_bars`, `audio_level`, `remote_media_state`, `signaling_data`) arrive on WebRTC threads. On the Dart side they use `NativeCallable.listener`, which posts to the isolate that created it, so native code never blocks on Dart. Signaling bytes are copied before the callback returns.

### Video frames

`dart:ffi` alone cannot show video: Flutter on macOS takes external frames through `FlutterTextureRegistry`, which is an Objective-C/Swift API. The plan:

- A tiny Swift class implements `FlutterTexture.copyPixelBuffer()` and holds the latest `CVPixelBuffer`.
- `libmgcalls` delivers decoded frames as `CVPixelBuffer` (tgcalls' darwin code already decodes H.264/H.265 through VideoToolbox into pixel buffers; VP8/VP9/AV1 frames are converted with libyuv into an IOSurface-backed BGRA buffer from a pool).
- The Swift side calls `textureFrameAvailable`; Flutter composites without copying through Dart.

This also serves the 120 fps priority: frames never cross into Dart, the same way media_kit renders today.

The Swift code lives in the app's macOS runner or in a small plugin inside `packages/calls`. Both work; a plugin keeps it reusable for Windows later.

### Audio

tdesktop builds tg_owt with `TG_OWT_BUILD_AUDIO_BACKENDS=OFF` and supplies its own OpenAL-based audio device module from lib_webrtc. On macOS we have two options:

1. Build tg_owt with WebRTC's own CoreAudio module (`TG_OWT_BUILD_AUDIO_BACKENDS=ON`). Least code, but tdesktop does not exercise it, so device switching and AirPods edge cases are untested by anyone on desktop.
2. Reuse lib_webrtc's audio module and device resolver. Same path as tdesktop, but pulls in OpenAL (Apple's is deprecated; tdesktop builds its own fork of openal-soft) and part of the Desktop App Toolkit.

Recommendation: start with option 1 for the first working call, then evaluate on real hardware (built-in mic, AirPods, USB headset, device switch mid-call) before release.

### Camera and screen sharing

tgcalls already has the macOS pieces: `VideoCameraCapturerMac` (AVFoundation), `TGCMIOCapturer` (virtual cameras), `DesktopSharingCapturer` and `desktop_capturer/*` (screen and window capture). The app needs:

- `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` in Info.plist.
- Sandbox entitlements `com.apple.security.device.camera`, `com.apple.security.device.audio-input`, `com.apple.security.network.client` (already needed for TDLib). P2P mode also listens for UDP, so `com.apple.security.network.server` is likely needed; to verify.
- Screen Recording permission (TCC) for screen sharing. tg_owt's macOS capturer still uses `CGDisplayStream` and `CGWindowListCreateImage`, both deprecated in favor of ScreenCaptureKit, and macOS 15 shows a recurring permission prompt for apps on those APIs. Plan a ScreenCaptureKit capturer feeding tgcalls' custom video source; it is a contained piece of Swift or Objective-C.
- There is no CallKit on macOS. Incoming calls are our own window plus a `UNUserNotification`; a ringtone needs to play while the app is in the background.

## Build

tdesktop's `Telegram/build/prepare/prepare.py` and `Telegram/cmake/lib_tgcalls.cmake` are a working recipe for exactly this target: tgcalls with its darwin platform code against tg_owt, universal arm64 + x86_64. We follow it instead of Telegram iOS's Bazel build, which needs the whole iOS tree.

Dependencies and the versions tdesktop pins:

| Library | Version | Used for |
|---------|---------|----------|
| tg_owt | `d1cf250` (submodules: abseil, libyuv, libsrtp, crc32c, pffft, rnnoise) | WebRTC |
| tgcalls | `1c236c0` (tdesktop's pin) | Call engine |
| OpenSSL | 3.5.9 (same as our TDLib build) | Signaling encryption, SRTP |
| Opus | 1.5.2 | Audio codec |
| libvpx | 1.14.1 + tdesktop patches | VP8/VP9 |
| openh264 | 2.6.0 | H.264 software path (VideoToolbox is used where it can be) |
| dav1d | 1.5.4 | AV1 decoding |
| FFmpeg | 8.1.3, a small subset | tgcalls' video helpers |
| mozjpeg | 4.1.5 | tg_owt's libjpeg dependency |

The CI job mirrors `.github/workflows/tdlib.yml`:

1. Pin all commits in `packages/calls/calls.json`.
2. Build each dependency per architecture on `macos-15` (arm64) and `macos-15-intel` (x86_64), static libraries only, with `MACOSX_DEPLOYMENT_TARGET=11.0` like TDLib.
3. Build tg_owt with CMake (`-DTG_OWT_*_INCLUDE_PATH=...`), then tgcalls and our C API with a CMake file adapted from `lib_tgcalls.cmake`.
4. Link `libmgcalls.dylib` with an exported symbols list (`mg_call*` only) so its OpenSSL, abseil and WebRTC symbols cannot clash with the OpenSSL already inside `libtdjson.dylib`.
5. `lipo` the two architectures together, publish to a `calls-<short commit>` release on `main`, cache the dependency builds by their pins.

Estimated sizes and times (not measured yet): the dylib around 15–25 MB per architecture after stripping; a cold build of one architecture around 40–60 minutes on a GitHub runner (tg_owt alone is ~59 MB of sources), a few minutes with the dependency cache warm.

Linux CI cannot build this, so the PR-time CI stays as it is; the calls workflow runs only when its pins or files change, like the TDLib one.

## Licensing

Mollygram is GPL-3.0.

| Component | License | Compatible | Note |
|-----------|---------|------------|------|
| tgcalls | LGPL-3.0 | Yes | Ship its source with ours (it is public on GitHub, link it in NOTICE) |
| tg_owt / WebRTC, abseil, libyuv, libsrtp, crc32c, pffft, rnnoise | BSD-3/BSD-style, Apache-2.0 | Yes | Keep their license texts in the app bundle |
| OpenSSL 3 | Apache-2.0 | Yes with GPL-3.0 | Same as TDLib |
| Opus, libvpx, dav1d, openh264 (source) | BSD | Yes | |
| FFmpeg | LGPL-2.1+ if built without `--enable-gpl` | Yes | Our configure flags stay LGPL, as in tdesktop |
| lib_webrtc, `lib_tgcalls.cmake` (Desktop App Toolkit / tdesktop) | GPL-3.0 with OpenSSL exception | Yes | Only if we reuse them; otherwise inspiration only |

Two non-copyright points:

- **H.264 patents.** Cisco covers the MPEG LA royalties only for its own prebuilt openh264 binaries. Building openh264 from source, as tdesktop does, does not get that coverage. On macOS we can avoid most of the exposure by using VideoToolbox for H.264 (it is the system's licensed codec) and keeping openh264 only where tg_owt requires it. Worth a deliberate decision, not a silent default.
- **Telegram terms.** Calls go through Telegram's reflectors with our own `api_id`, like any third-party client. We found nothing in the Telegram API terms that restricts calls in third-party clients, and Telegram X and Unigram ship them.

The app bundle needs an "Open source licenses" screen listing all of the above; that is part of release work anyway.

## Effort

Effort as in `forks-research.md`: S up to a week, M 1–3 weeks, L more.

| # | Work | Effort | Notes |
|---|------|--------|-------|
| 1 | CI build of `libmgcalls.dylib` (deps, tg_owt, tgcalls, universal binary, release) | M–L | Highest risk, start first; most of the time is build debugging |
| 2 | C API and the `callStateReady` → `Descriptor` mapping, threading, logs | M | Includes a native test that runs two instances in one process (tgcalls' CLI tool does this) |
| 3 | `packages/calls`: controller, TDLib wiring, ringing and timeouts, rating and debug log upload | M | |
| 4 | Audio devices: list, select, switch mid-call, mute, levels | S–M | |
| 5 | Video: texture bridge, camera, local preview, remote video, aspect ratio | M | |
| 6 | Screen sharing with source picker | S–M | |
| 7 | UI: call window, incoming banner, emoji fingerprint, call history entries | M | Design first |
| 8 | Entitlements, permissions, background ringing, notarization with the new dylib | S | |
| 9 | Group calls and video chats (join payload, participants, video grid, raise hand, speaking) | L | Can ship after the first release |
| 10 | Conference calls (E2E, `encryptGroupCallData`, verification emoji, upgrade from 1:1) | M | After 9 |

Items 1–8: about 6–9 weeks for one-to-one calls. Items 9–10: another 4–6 weeks.

## Risks

1. **Build fragility.** tg_owt follows upstream WebRTC with Telegram patches and is only tested inside tdesktop's prepare script. Mitigation: pin the exact commits tdesktop pins, move them only together with tdesktop.
2. **Version drift.** Telegram adds call versions (14.0.0 exists, tdesktop does not register it yet). An old engine still connects because both sides negotiate, but we fall behind on quality fixes. Mitigation: bump tgcalls whenever tdesktop does.
3. **Two OpenSSL copies** (TDLib and calls) in one process. Safe with two-level namespaces and a strict export list; unsafe if either dylib exports OpenSSL symbols. CI should check `nm -gU` for anything outside `mg_call*`.
4. **Threading at the FFI boundary.** Callbacks from WebRTC threads into Dart must be asynchronous only (`NativeCallable.listener`), and `mg_call_stop` must wait for tgcalls' completion before freeing anything Dart can still call into.
5. **Audio device module** choice (see [Audio](#audio)): the WebRTC CoreAudio module is not what tdesktop uses, so we may hit bugs nobody else on desktop sees.
6. **macOS permissions.** Camera, microphone and screen recording prompts, and the macOS 15 recurring screen recording prompt, are easy to get wrong and only show up on signed builds.
7. **Testing.** Calls need two accounts and real networks. The tgcalls CLI tool runs calls in-process (P2P and through a real reflector), which gives us an automated smoke test for the native library; end-to-end tests stay manual.
8. **App size.** Adds roughly 30–50 MB to the universal app (estimate). Acceptable for a desktop client; tdesktop carries the same.
9. **The 26 ms spike after player recreation** noted in the prototype is a media_kit issue, but remote video in calls uses its own texture path, so it does not carry over.

## Decisions

Agreed on 2026-10-14:

1. **Audio module:** WebRTC CoreAudio first. tdesktop's OpenAL module stays the fallback if real-hardware testing shows problems.
2. **H.264:** VideoToolbox for encoding and decoding; openh264 only where tg_owt requires it.
3. **Scope of the first release:** one-to-one voice and video plus screen sharing. Group calls come right after.
