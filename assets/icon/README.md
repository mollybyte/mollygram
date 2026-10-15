# App icon

`generate.py` builds every platform icon from the brand artwork in
[`docs/assets/icon.svg`](../../docs/assets/icon.svg) and copies them into the
Flutter projects:

```sh
pip install cairosvg pillow
python3 assets/icon/generate.py
```

| File | Use |
| --- | --- |
| `mollygram-1024.png` | macOS master: squircle on Apple's 1024 grid (824 px body, 100 px margin, drop shadow) |
| `mollygram-flat-1024.png` | Windows and Linux master, no system margin |
| `mollygram.icns` | macOS icon file, 16 to 1024 |
| `mollygram.ico` | Windows icon file, 16 to 256 |
| `linux/<size>.png` | Linux hicolor sizes, install as `dev.mollygram.app.png` |

The script also writes `macos/Runner/Assets.xcassets/AppIcon.appiconset` in
`packages/app`, `packages/app/windows/runner/resources/app_icon.ico`
and `packages/app/linux/runner/resources/app_icon.png`. Do not edit those by hand.

Application id on every platform: `dev.mollygram.app` (reverse of the
provisional domain mollygram.dev). It must be final before the first public
release, because macOS keys settings and keychain entries to it.
