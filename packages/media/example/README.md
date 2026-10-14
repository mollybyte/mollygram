# Video message benchmark

Measures frame timing while `mollygram_media` plays video messages
(circles) at 384, 512 and 640 px, H.264, 60 fps sources. Each size runs
four scenarios for 8 seconds:

- **1 circle playing** and **4 circles playing**: steady playback with a
  progress ring repainting every vsync.
- **switch, pooled player**: every 0.8 s the circle gets a new source on the
  same player and texture, as `CirclePlayerPool` does in the app.
- **switch, new player**: every 0.8 s the player is disposed and a new one
  is created, as the prototype did when it swapped backends.

The "after switch" column is the worst build and raster time and the number
of missed vsyncs within 500 ms after each switch.

## Run

Use a profile build on a real Mac; a CI virtual machine has no 120 Hz
display and a virtual GPU.

```sh
cd packages/media/example
fvm flutter run --profile -d macos
```

Press Run in the window, or run it unattended; the report goes to stdout:

```sh
fvm flutter build macos --profile
MG_AUTOBENCH=1 build/macos/Build/Products/Profile/mollygram_media_example.app/Contents/MacOS/mollygram_media_example
```

Keep the window visible and on one display during the run.
