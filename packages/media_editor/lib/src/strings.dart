import 'package:flutter/widgets.dart';

import 'model/adjustments.dart';

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
    required this.draw,
    required this.pen,
    required this.marker,
    required this.arrow,
    required this.eraser,
    required this.color,
    required this.thickness,
    required this.text,
    required this.textHint,
    required this.plain,
    required this.outline,
    required this.frame,
    required this.emoji,
    required this.shapes,
    required this.rectangle,
    required this.ellipse,
    required this.line,
    required this.filled,
    required this.delete,
    required this.size,
    required this.blur,
    required this.pixelate,
    required this.adjust,
    required this.presetNames,
    required this.adjustmentNames,
    required this.mute,
    required this.unmute,
    required this.setCover,
    required this.coverFrame,
    required this.secondsShort,
    required this.stickers,
    required this.addSticker,
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

  /// The drawing tool and its brushes.
  final String draw;
  final String pen;
  final String marker;
  final String arrow;
  final String eraser;
  final String color;
  final String thickness;

  /// Text, emoji and shape overlays.
  final String text;
  final String textHint;
  final String plain;
  final String outline;
  final String frame;
  final String emoji;
  final String shapes;
  final String rectangle;
  final String ellipse;
  final String line;
  final String filled;
  final String delete;
  final String size;
  final String blur;
  final String pixelate;

  /// The adjust tool, its looks and its adjustments.
  final String adjust;
  final List<String> presetNames;
  final List<String> adjustmentNames;

  /// The video editor.
  final String mute;
  final String unmute;
  final String setCover;

  /// The cover button when the shown frame is the cover.
  final String coverFrame;

  /// The unit after a length in seconds, as in "8.4 s".
  final String secondsShort;

  /// The sticker tool.
  final String stickers;
  final String addSticker;

  String preset(FilterPreset p) => presetNames[p.index];
  String adjustment(Adjustment a) => adjustmentNames[a.index];

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
    draw: 'Draw',
    pen: 'Pen',
    marker: 'Marker',
    arrow: 'Arrow',
    eraser: 'Eraser',
    color: 'Color',
    thickness: 'Thickness',
    text: 'Text',
    textHint: 'Type text',
    plain: 'Plain',
    outline: 'Outline',
    frame: 'Frame',
    emoji: 'Emoji',
    shapes: 'Shapes',
    rectangle: 'Rectangle',
    ellipse: 'Ellipse',
    line: 'Line',
    filled: 'Filled',
    delete: 'Delete',
    size: 'Size',
    blur: 'Blur',
    pixelate: 'Pixelate',
    adjust: 'Adjust',
    presetNames: [
      'Original',
      'Vivid',
      'Warm',
      'Cool',
      'Mono',
      'Faded',
      'Dramatic',
    ],
    adjustmentNames: [
      'Brightness',
      'Contrast',
      'Saturation',
      'Warmth',
      'Fade',
      'Vignette',
    ],
    mute: 'Mute',
    unmute: 'Unmute',
    setCover: 'Use as cover',
    coverFrame: 'Cover frame',
    secondsShort: 's',
    stickers: 'Stickers',
    addSticker: 'Add sticker',
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
    draw: 'Рисовать',
    pen: 'Ручка',
    marker: 'Маркер',
    arrow: 'Стрелка',
    eraser: 'Ластик',
    color: 'Цвет',
    thickness: 'Толщина',
    text: 'Текст',
    textHint: 'Введите текст',
    plain: 'Обычный',
    outline: 'Контур',
    frame: 'Плашка',
    emoji: 'Эмодзи',
    shapes: 'Фигуры',
    rectangle: 'Прямоугольник',
    ellipse: 'Эллипс',
    line: 'Линия',
    filled: 'Залитая',
    delete: 'Удалить',
    size: 'Размер',
    blur: 'Размытие',
    pixelate: 'Пикселизация',
    adjust: 'Коррекция',
    presetNames: [
      'Оригинал',
      'Яркий',
      'Тёплый',
      'Холодный',
      'Моно',
      'Выцветший',
      'Драма',
    ],
    adjustmentNames: [
      'Яркость',
      'Контраст',
      'Насыщенность',
      'Теплота',
      'Выцветание',
      'Виньетка',
    ],
    mute: 'Без звука',
    unmute: 'Включить звук',
    setCover: 'Сделать обложкой',
    coverFrame: 'Кадр обложки',
    secondsShort: 'с',
    stickers: 'Стикеры',
    addSticker: 'Добавить стикер',
  );

  /// The strings for the ambient locale: Russian for `ru`, English
  /// otherwise.
  static MediaEditorStrings of(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode == 'ru' ? ru : en;
  }
}
