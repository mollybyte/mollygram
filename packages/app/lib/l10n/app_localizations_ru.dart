// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Mollygram';

  @override
  String get back => 'Назад';

  @override
  String get qrTitle => 'Вход в Mollygram по QR-коду';

  @override
  String get qrStep1 => 'Откройте Telegram на телефоне';

  @override
  String get qrStep2 =>
      'Перейдите в Настройки > Устройства > Подключить устройство';

  @override
  String get qrStep3 =>
      'Наведите телефон на этот экран, чтобы подтвердить вход';

  @override
  String get qrLoading => 'Загружаем код…';

  @override
  String get logInByPhone => 'Вход по номеру телефона';

  @override
  String get logInByQr => 'Вход по QR-коду';

  @override
  String get phoneTitle => 'Ваш номер телефона';

  @override
  String get phoneHint => 'Проверьте код страны и введите номер телефона.';

  @override
  String get phoneNumberHint => 'Номер телефона';

  @override
  String get country => 'Страна';

  @override
  String get next => 'Далее';

  @override
  String get codeHint => 'Код';

  @override
  String get codeSentApp =>
      'Мы отправили код в приложение Telegram на другом устройстве.';

  @override
  String get codeSentSms => 'Мы отправили код в SMS.';

  @override
  String get codeSentCall => 'Мы звоним вам, чтобы продиктовать код.';

  @override
  String get codeSentOther => 'Введите полученный код.';

  @override
  String get passwordTitle => 'Двухэтапная проверка';

  @override
  String get passwordHint => 'Аккаунт защищён дополнительным паролем.';

  @override
  String passwordHintWithHint(String hint) {
    return 'Аккаунт защищён дополнительным паролем. Подсказка: $hint';
  }

  @override
  String get passwordFieldHint => 'Пароль';

  @override
  String get starting => 'Запускаем Telegram…';

  @override
  String get unsupportedTitle =>
      'Завершите регистрацию в официальном приложении';

  @override
  String get unsupportedStep =>
      'Этот шаг входа пока не поддерживается. Завершите регистрацию в официальном приложении Telegram и попробуйте снова.';

  @override
  String get errorInvalidPhone => 'Неверный номер телефона';

  @override
  String get errorInvalidCode => 'Неверный код';

  @override
  String get errorCodeExpired => 'Срок действия кода истёк, запросите новый';

  @override
  String get errorInvalidPassword => 'Неверный пароль';

  @override
  String get errorTooManyAttempts => 'Слишком много попыток, попробуйте позже';

  @override
  String errorGeneric(String message) {
    return 'Что-то пошло не так: $message';
  }

  @override
  String get missingKeysTitle => 'Нет ключей Telegram API';

  @override
  String get missingKeysHint =>
      'Соберите приложение с --dart-define-from-file=config/telegram.json. Шаблон лежит в config/telegram.example.json.';

  @override
  String get startFailedTitle => 'Не удалось запустить Telegram';

  @override
  String get searchHint => 'Поиск';

  @override
  String get folderAll => 'Все';

  @override
  String get noChats => 'Чатов пока нет';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get selectChat => 'Выберите чат, чтобы начать общение';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get attach => 'Прикрепить';

  @override
  String get emoji => 'Эмодзи и стикеры';

  @override
  String get record => 'Записать голосовое или видеосообщение';

  @override
  String get send => 'Отправить';

  @override
  String previewYou(String text) {
    return 'Вы: $text';
  }

  @override
  String get previewPhoto => 'Фото';

  @override
  String get previewVideo => 'Видео';

  @override
  String get previewVideoNote => 'Видеосообщение';

  @override
  String get previewVoiceNote => 'Голосовое сообщение';

  @override
  String get previewAudio => 'Аудио';

  @override
  String get previewDocument => 'Файл';

  @override
  String get previewSticker => 'Стикер';

  @override
  String get previewAnimation => 'GIF';

  @override
  String get previewOther => 'Сообщение';

  @override
  String get noTextMessages => 'Текстовых сообщений пока нет';
}
