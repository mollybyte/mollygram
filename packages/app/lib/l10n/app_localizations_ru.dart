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
  String get signInTitle => 'Вход в Telegram';

  @override
  String get signInQrSteps =>
      'Откройте Telegram на телефоне, перейдите в Настройки > Устройства > Подключить устройство и отсканируйте этот код.';

  @override
  String get signInQrLoading => 'Загружаем код…';

  @override
  String get signInWithPhone => 'Войти по номеру телефона';

  @override
  String get signInWithQr => 'Войти по QR-коду';

  @override
  String get phoneTitle => 'Ваш номер телефона';

  @override
  String get phoneHint => 'Введите номер в международном формате, начиная с +.';

  @override
  String get phoneLabel => 'Номер телефона';

  @override
  String get continueAction => 'Продолжить';

  @override
  String get codeTitle => 'Введите код';

  @override
  String get codeHint =>
      'Telegram отправил код в приложение на другом устройстве или по SMS.';

  @override
  String get codeLabel => 'Код';

  @override
  String get wrongNumber => 'Другой номер?';

  @override
  String get passwordTitle => 'Двухэтапная проверка';

  @override
  String get passwordHint => 'Аккаунт защищён дополнительным паролем.';

  @override
  String passwordHintWithHint(String hint) {
    return 'Аккаунт защищён дополнительным паролем. Подсказка: $hint';
  }

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get starting => 'Запускаем Telegram…';

  @override
  String get unsupportedStep =>
      'Этот шаг входа пока не поддерживается. Завершите регистрацию в официальном приложении и попробуйте снова.';

  @override
  String get errorInvalidPhone => 'Неверный номер телефона.';

  @override
  String get errorInvalidCode => 'Неверный код.';

  @override
  String get errorCodeExpired => 'Срок действия кода истёк, запросите новый.';

  @override
  String get errorInvalidPassword => 'Неверный пароль.';

  @override
  String get errorTooManyAttempts => 'Слишком много попыток, попробуйте позже.';

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
  String get selectChat => 'Выберите чат, чтобы начать общение';

  @override
  String get messageHint => 'Сообщение';

  @override
  String get send => 'Отправить';

  @override
  String get newMessage => 'Новое сообщение';

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
