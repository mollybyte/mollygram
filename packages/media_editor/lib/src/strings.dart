import 'package:flutter/widgets.dart';

/// The editor's own strings in English and Russian, picked by the ambient
/// locale. The editor ships them itself so it can be used without the
/// app's localizations.
///
/// Russian follows the app's rule: only the first word is capitalized.
final class MediaEditorStrings {
  const MediaEditorStrings._({
    required this.edit,
    required this.cancel,
    required this.done,
    required this.crop,
    required this.rotate,
    required this.flip,
    required this.reset,
    required this.undo,
    required this.redo,
    required this.free,
    required this.original,
    required this.square,
    required this.portrait,
    required this.landscape,
    required this.saving,
    required this.failed,
  });

  /// Opens the editor, on the attachment preview.
  final String edit;
  final String cancel;
  final String done;
  final String crop;
  final String rotate;
  final String flip;
  final String reset;
  final String undo;
  final String redo;

  /// Aspect ratio names.
  final String free;
  final String original;
  final String square;
  final String portrait;
  final String landscape;

  /// Shown while the edited file is written.
  final String saving;

  /// Shown when the file could not be read or written.
  final String failed;

  static const en = MediaEditorStrings._(
    edit: 'Edit',
    cancel: 'Cancel',
    done: 'Done',
    crop: 'Crop',
    rotate: 'Rotate',
    flip: 'Flip',
    reset: 'Reset',
    undo: 'Undo',
    redo: 'Redo',
    free: 'Free',
    original: 'Original',
    square: 'Square',
    portrait: 'Portrait',
    landscape: 'Landscape',
    saving: 'Saving…',
    failed: 'Couldn’t edit this file',
  );

  static const ru = MediaEditorStrings._(
    edit: 'Изменить',
    cancel: 'Отмена',
    done: 'Готово',
    crop: 'Обрезка',
    rotate: 'Повернуть',
    flip: 'Отразить',
    reset: 'Сбросить',
    undo: 'Отменить',
    redo: 'Повторить',
    free: 'Свободно',
    original: 'Исходный',
    square: 'Квадрат',
    portrait: 'Вертикально',
    landscape: 'Горизонтально',
    saving: 'Сохранение…',
    failed: 'Не удалось изменить файл',
  );

  /// The strings for the ambient locale: Russian for `ru`, English
  /// otherwise.
  static MediaEditorStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'ru' ? ru : en;
  }
}
