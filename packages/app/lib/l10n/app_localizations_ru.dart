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
  String get sendFailed => 'Сообщение не отправлено. Попробуйте ещё раз';

  @override
  String get noMessages => 'Здесь пока нет сообщений';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get edited => 'изменено';

  @override
  String forwardedFrom(String name) {
    return 'Переслано от $name';
  }

  @override
  String get deletedMessage => 'Удалённое сообщение';

  @override
  String get loadingMessage => 'Загрузка…';

  @override
  String get unknownSender => 'Неизвестный';

  @override
  String get hiddenAccount => 'Скрытый аккаунт';

  @override
  String get download => 'Скачать';

  @override
  String get cancelDownload => 'Отменить загрузку';

  @override
  String get openFile => 'Открыть';

  @override
  String get play => 'Воспроизвести';

  @override
  String get pause => 'Пауза';

  @override
  String get menuReply => 'Ответить';

  @override
  String get menuEdit => 'Изменить';

  @override
  String get menuCopyText => 'Копировать текст';

  @override
  String get menuCopyLink => 'Копировать ссылку';

  @override
  String get menuForward => 'Переслать';

  @override
  String get menuDelete => 'Удалить';

  @override
  String get cancel => 'Отмена';

  @override
  String get deleteMessageTitle => 'Удалить сообщение?';

  @override
  String deleteMessagesTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count сообщений?',
      few: 'Удалить $count сообщения?',
      one: 'Удалить $count сообщение?',
    );
    return '$_temp0';
  }

  @override
  String get deleteForEveryone => 'Удалить у всех';

  @override
  String deleteAlsoFor(String name) {
    return 'Также удалить для $name';
  }

  @override
  String get editingMessage => 'Редактирование';

  @override
  String get forwardTitle => 'Переслать в чат';

  @override
  String get forwardSearch => 'Поиск чатов';

  @override
  String get noChatsFound => 'Чаты не найдены';

  @override
  String get statusOnline => 'в сети';

  @override
  String get statusJustNow => 'был(а) только что';

  @override
  String statusMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'был(а) $count минут назад',
      few: 'был(а) $count минуты назад',
      one: 'был(а) $count минуту назад',
    );
    return '$_temp0';
  }

  @override
  String statusToday(String time) {
    return 'был(а) сегодня в $time';
  }

  @override
  String statusYesterday(String time) {
    return 'был(а) вчера в $time';
  }

  @override
  String statusOnDate(String date) {
    return 'был(а) $date';
  }

  @override
  String get statusRecently => 'был(а) недавно';

  @override
  String get statusLastWeek => 'был(а) на этой неделе';

  @override
  String get statusLastMonth => 'был(а) в этом месяце';

  @override
  String get statusLongAgo => 'был(а) давно';

  @override
  String get statusBot => 'бот';

  @override
  String get statusService => 'уведомления сервиса';

  @override
  String get statusGroup => 'группа';

  @override
  String get statusChannel => 'канал';

  @override
  String statusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '$count участник',
    );
    return '$_temp0';
  }

  @override
  String statusMembersOnline(String members, String online) {
    return '$members, $online в сети';
  }

  @override
  String statusSubscribers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
    );
    return '$_temp0';
  }

  @override
  String get activityTyping => 'печатает';

  @override
  String get activityRecordingVoice => 'записывает голосовое';

  @override
  String get activityRecordingVideoNote => 'записывает видеосообщение';

  @override
  String get activityRecordingVideo => 'записывает видео';

  @override
  String get activitySendingPhoto => 'отправляет фото';

  @override
  String get activitySendingVideo => 'отправляет видео';

  @override
  String get activitySendingVoice => 'отправляет голосовое';

  @override
  String get activitySendingVideoNote => 'отправляет видеосообщение';

  @override
  String get activitySendingFile => 'отправляет файл';

  @override
  String get activityChoosingSticker => 'выбирает стикер';

  @override
  String get activityChoosingLocation => 'выбирает место';

  @override
  String get activityChoosingContact => 'выбирает контакт';

  @override
  String get activityPlayingGame => 'играет';

  @override
  String get activityWatchingAnimations => 'смотрит анимацию';

  @override
  String activityByOne(String name, String activity) {
    return '$name $activity';
  }

  @override
  String activityByTwo(String first, String second) {
    return '$first и $second печатают';
  }

  @override
  String activityByMany(String name, int count) {
    return '$name и ещё $count печатают';
  }

  @override
  String get archivedChats => 'Архив';

  @override
  String get noArchivedChats => 'В архиве нет чатов';

  @override
  String get menuPin => 'Закрепить';

  @override
  String get menuUnpin => 'Открепить';

  @override
  String get menuMute => 'Отключить уведомления';

  @override
  String get menuUnmute => 'Включить уведомления';

  @override
  String get muteFor1Hour => 'На 1 час';

  @override
  String get muteFor8Hours => 'На 8 часов';

  @override
  String get muteFor3Days => 'На 3 дня';

  @override
  String get muteForever => 'Навсегда';

  @override
  String get menuArchive => 'Архивировать';

  @override
  String get menuUnarchive => 'Вернуть из архива';

  @override
  String get menuMarkRead => 'Пометить как прочитанное';

  @override
  String get menuMarkUnread => 'Пометить как непрочитанное';

  @override
  String get menuMarkAllRead => 'Прочитать все';

  @override
  String get menuClearHistory => 'Очистить историю';

  @override
  String get menuDeleteChat => 'Удалить чат';

  @override
  String get menuDeleteAndLeave => 'Удалить и выйти';

  @override
  String get menuLeaveGroup => 'Покинуть группу';

  @override
  String get menuLeaveChannel => 'Покинуть канал';

  @override
  String get clearHistoryTitle => 'Очистить историю?';

  @override
  String clearHistoryMessage(String name) {
    return 'Сообщения в чате «$name» будут удалены у вас.';
  }

  @override
  String clearAlsoFor(String name) {
    return 'Также очистить для $name';
  }

  @override
  String get clear => 'Очистить';

  @override
  String get deleteChatTitle => 'Удалить чат?';

  @override
  String deleteChatMessage(String name) {
    return 'Чат с $name будет удалён у вас.';
  }

  @override
  String leaveTitle(String name) {
    return 'Покинуть «$name»?';
  }

  @override
  String get leave => 'Покинуть';

  @override
  String deleteAndLeaveTitle(String name) {
    return 'Удалить «$name» и выйти?';
  }

  @override
  String get chatActionFailed => 'Не получилось. Попробуйте ещё раз.';

  @override
  String get editFailed => 'Не удалось сохранить изменения';

  @override
  String attachTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправить $count файлов',
      few: 'Отправить $count файла',
      one: 'Отправить $count файл',
    );
    return '$_temp0';
  }

  @override
  String attachPhotosTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Отправить $count фото',
      few: 'Отправить $count фото',
      one: 'Отправить $count фото',
    );
    return '$_temp0';
  }

  @override
  String get sendAsFiles => 'Отправить как файлы';

  @override
  String get captionHint => 'Добавить подпись';

  @override
  String get dropFiles => 'Перетащите файлы сюда, чтобы отправить';

  @override
  String get attachFailed => 'Не удалось отправить файлы';

  @override
  String get hiddenMedia => 'Скрытое медиа, нажмите, чтобы показать';

  @override
  String get spoilerMedia => 'Спойлер';

  @override
  String get secretMedia => 'Нажмите, чтобы посмотреть';

  @override
  String get sensitiveMedia => '18+';

  @override
  String get forwardFailed => 'Не удалось переслать сообщение';

  @override
  String get close => 'Закрыть';

  @override
  String fileSizeBytes(String size) {
    return '$size Б';
  }

  @override
  String fileSizeKb(String size) {
    return '$size КБ';
  }

  @override
  String fileSizeMb(String size) {
    return '$size МБ';
  }

  @override
  String fileSizeGb(String size) {
    return '$size ГБ';
  }

  @override
  String fileProgress(String done, String total) {
    return '$done из $total';
  }

  @override
  String get contentLocation => 'Геопозиция';

  @override
  String get contentLiveLocation => 'Трансляция геопозиции';

  @override
  String get contentContact => 'Контакт';

  @override
  String get contentPoll => 'Опрос';

  @override
  String get contentQuiz => 'Викторина';

  @override
  String pollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count голосов',
      few: '$count голоса',
      one: '$count голос',
      zero: 'Нет голосов',
    );
    return '$_temp0';
  }

  @override
  String get contentGame => 'Игра';

  @override
  String get contentInvoice => 'Счёт';

  @override
  String get contentStory => 'История';

  @override
  String get contentChecklist => 'Список задач';

  @override
  String get contentGiveaway => 'Розыгрыш';

  @override
  String get contentPaidMedia => 'Платный контент';

  @override
  String get contentExpiredPhoto => 'Фото больше недоступно';

  @override
  String get contentExpiredVideo => 'Видео больше недоступно';

  @override
  String get contentExpiredVideoNote => 'Видеосообщение больше недоступно';

  @override
  String get contentExpiredVoiceNote => 'Голосовое сообщение больше недоступно';

  @override
  String get contentUnsupported =>
      'Это сообщение пока не поддерживается в Mollygram';

  @override
  String get callOutgoing => 'Исходящий звонок';

  @override
  String get callIncoming => 'Входящий звонок';

  @override
  String get callVideoOutgoing => 'Исходящий видеозвонок';

  @override
  String get callVideoIncoming => 'Входящий видеозвонок';

  @override
  String get callMissed => 'Пропущенный звонок';

  @override
  String get callDeclined => 'Отклонённый звонок';

  @override
  String get callCancelled => 'Отменённый звонок';

  @override
  String durationMinutes(int count) {
    return '$count мин';
  }

  @override
  String durationSeconds(int count) {
    return '$count с';
  }

  @override
  String serviceGroupCreated(String name, String title) {
    return '$name создаёт группу «$title»';
  }

  @override
  String get serviceChannelCreated => 'Канал создан';

  @override
  String serviceTitleChanged(String name, String title) {
    return '$name меняет название группы на «$title»';
  }

  @override
  String serviceChannelTitleChanged(String title) {
    return 'Название канала изменено на «$title»';
  }

  @override
  String servicePhotoChanged(String name) {
    return '$name обновляет фото группы';
  }

  @override
  String get serviceChannelPhotoChanged => 'Фото канала обновлено';

  @override
  String servicePhotoRemoved(String name) {
    return '$name удаляет фото группы';
  }

  @override
  String get serviceChannelPhotoRemoved => 'Фото канала удалено';

  @override
  String serviceJoined(String name) {
    return '$name вступает в группу';
  }

  @override
  String serviceAdded(String name, String members) {
    return '$name добавляет $members';
  }

  @override
  String serviceJoinedByLink(String name) {
    return '$name вступает в группу по ссылке';
  }

  @override
  String serviceJoinedByRequest(String name) {
    return '$name принят(а) в группу';
  }

  @override
  String serviceLeft(String name) {
    return '$name выходит из группы';
  }

  @override
  String serviceRemoved(String name, String member) {
    return '$name удаляет $member';
  }

  @override
  String servicePinned(String name, String text) {
    return '$name закрепляет «$text»';
  }

  @override
  String servicePinnedMessage(String name) {
    return '$name закрепляет сообщение';
  }

  @override
  String serviceScreenshot(String name) {
    return '$name делает снимок экрана';
  }

  @override
  String serviceAutoDeleteOn(String name, String time) {
    return '$name включает автоудаление сообщений через $time';
  }

  @override
  String serviceAutoDeleteOff(String name) {
    return '$name отключает автоудаление сообщений';
  }

  @override
  String get serviceUpgraded => 'Группа преобразована в супергруппу';

  @override
  String serviceVideoChatStarted(String name) {
    return '$name начинает видеочат';
  }

  @override
  String serviceVideoChatEnded(String duration) {
    return 'Видеочат завершён ($duration)';
  }

  @override
  String get serviceVideoChatScheduled => 'Видеочат запланирован';

  @override
  String serviceVideoChatInvited(String name, String members) {
    return '$name приглашает $members в видеочат';
  }

  @override
  String serviceTopicCreated(String title) {
    return 'Тема «$title» создана';
  }

  @override
  String serviceTopicEdited(String name) {
    return '$name изменяет тему';
  }

  @override
  String serviceContactJoined(String name) {
    return '$name теперь в Telegram';
  }

  @override
  String serviceThemeChanged(String name) {
    return '$name меняет тему чата';
  }

  @override
  String serviceBackgroundChanged(String name) {
    return '$name меняет обои чата';
  }

  @override
  String serviceGift(String name) {
    return '$name отправляет подарок';
  }

  @override
  String get servicePayment => 'Платёж выполнен';

  @override
  String serviceBoost(String name) {
    return '$name бустит группу';
  }

  @override
  String serviceGameScore(String name, int score) {
    return '$name набирает $score';
  }

  @override
  String serviceOther(String name) {
    return '$name выполняет действие, которое Mollygram пока не умеет показывать';
  }

  @override
  String get listSeparator => ', ';

  @override
  String durationHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String durationDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String durationWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недель',
      few: '$count недели',
      one: '$count неделю',
    );
    return '$_temp0';
  }

  @override
  String durationMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String get plugins => 'Плагины';

  @override
  String get settings => 'Настройки';
}
