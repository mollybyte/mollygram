# Prototype: glass, long feed, video messages

A standalone Flutter project for testing three risky areas before main development:

- a floating glass layer (sidebar, two header capsules, composer) over Telegram wallpaper, with all panels in one `BackdropGroup` via `BackdropFilter.grouped`;
- a feed of 5000 messages of varying height scrolling under the glass;
- a 640x640, 60 fps, H.264 round video message in two players: `media_kit` (libmpv) and the system AVFoundation via `video_player`.

There is no TDLib here; all data is fake. The code is not moved into the app as is; only the findings are.

## Running on a Mac

Requires Xcode and [fvm](https://fvm.app). The Flutter version is pinned in `.fvmrc` (3.47.7).

```sh
brew tap leoafarias/fvm && brew install fvm   # once
cd prototype
fvm install          # installs the version from .fvmrc
fvm flutter pub get
fvm flutter run --profile -d macos
```

Measure only in `--profile` or `--release`: debug numbers are several times worse and mean nothing. Keep the window on the built-in display of a MacBook Pro with ProMotion (120 Hz), without an external monitor.

A ready-made profile build can be downloaded without Xcode from the `mollygram-prototype-macos-profile` artifact of a Prototype workflow run. The build is unsigned: on first launch, right-click the app and choose "Open".

## Taking measurements

The debug panel is at the top right (⌘⇧P hides it). It shows live fps, build and raster p50/p95, and dropped-frame counters.

1. Press "Benchmark 1 min" and do not touch the window. Three configurations run for 20 seconds each: media_kit with glass, AVFoundation with glass, media_kit without blur.
2. Each run: the video message plays for 6 seconds while idle, then for 14 seconds the feed scrolls up 9000 px and back. When the video message scrolls off screen, it keeps playing in a corner, as in Telegram.
3. Press "Copy report" and post the text in the thread.

The same in one command; the report is printed to the terminal and the app exits:

```sh
fvm flutter build macos --profile
MG_AUTOBENCH=1 build/macos/Build/Products/Profile/mollygram_prototype.app/Contents/MacOS/mollygram_prototype
```

## What the numbers mean

- **fps** and **vsync Hz**: how many frames per second actually reach the screen. The target on ProMotion is 120.
- **build / raster p50/p95/max**: UI thread and GPU thread time per frame. The budget at 120 Hz is 8.3 ms.
- **over budget**: frames whose build or raster did not fit into one vsync.
- **missed vsyncs**: real drops. During a benchmark the ticker requests a frame on every vsync, so every gap between frames is visible to the user.

Prototype pass criterion: 120 fps and less than 1% missed vsyncs while scrolling under glass with a video message playing. If the glass does not fit the budget, comparing with the "without blur" run shows how much the blur itself costs.

## Test clip

`assets/circle_640.mp4` was generated with ffmpeg: 640x640, 60 fps, 12 seconds, H.264 High, two squares moving at constant speed so that stutter is visible.

```sh
ffmpeg -f lavfi -i "gradients=s=640x640:r=60:d=12:speed=0.015:n=4:c0=0xDBDDBB:c1=0x6BA587:c2=0xD5D88D:c3=0x88B884" \
  -vf "drawbox=x='100+mod(t*220\,400)':y=300:w=40:h=40:color=white@0.95:t=fill,drawbox=x=300:y='100+mod(t*160\,400)':w=40:h=40:color=0x0071E3@0.95:t=fill" \
  -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 -preset slow -movflags +faststart -an assets/circle_640.mp4
```
