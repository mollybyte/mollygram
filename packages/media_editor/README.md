# mollygram_media_editor

The editor for photos (and later videos) before they are sent.

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
- Strings are built in (English and Russian), picked by the ambient locale.

Keys: Escape leaves the tool or cancels, Enter confirms, ⌘Z / ⇧⌘Z undo and
redo, ⌘R rotates.
