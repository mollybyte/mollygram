# mollygram_media_editor

The editor for photos and videos before they are sent.

```dart
final result = await showMediaEditor(context, path: '/path/photo.jpg');
// result.path: the edited file (or the original when nothing changed)
// result.edit: what was done, pass it back as `initial` to keep editing
```

- `MediaEdit` holds the edit relative to the original: quarter turns,
  mirror, normalized crop and the locked aspect ratio. It never depends on
  the preview resolution, so reopening the editor on the original loses
  nothing.
- `exportEdit` applies a `MediaEdit` at full resolution. PNG stays PNG,
  everything else becomes JPEG (quality 93), capped at 8192 px a side.
- Pass a `stickerPicker` to get a sticker tool: the editor calls it and
  places the `StickerFilePick` (a still image file) or `EmojiPick` it
  returns as an overlay.
- Strings are built in (English and Russian), picked by the ambient locale.

Keys: Escape leaves the tool or cancels, Enter confirms, ⌘Z / ⇧⌘Z undo and
redo, ⌘R rotates.

## Video

```dart
final result = await showVideoEditor(context, path: '/path/clip.mov', engine: engine);
// result.path: the trimmed file (or the original when nothing changed)
// result.thumbnailPath, result.coverPath: JPEGs for the message
```

- `VideoEdit` holds the kept range, whether the sound goes and the cover
  frame, all as positions in the original file.
- `VideoEngine` is what reads and writes the file: probing, frames at a
  time, and the export. The app provides one (AVFoundation on macOS);
  tests use a fake.

Keys: Escape cancels, Enter confirms, M mutes, ← → step a second
(⇧ a tenth).
