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
  String get connectionWaitingForNetwork => 'Ожидание сети…';

  @override
  String get connectionConnectingToProxy => 'Подключение к прокси…';

  @override
  String get connectionConnecting => 'Соединение…';

  @override
  String get connectionUpdating => 'Обновление…';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get newMessage => 'Новое сообщение';

  @override
  String get contacts => 'Контакты';

  @override
  String get peopleSearchHint => 'Имя или имя пользователя';

  @override
  String get recentChats => 'Недавние';

  @override
  String get globalSearch => 'Глобальный поиск';

  @override
  String get noContacts => 'Контактов пока нет';

  @override
  String get presenceOnline => 'в сети';

  @override
  String get presenceJustNow => 'был(а) только что';

  @override
  String presenceMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'был(а) $count минуты назад',
      many: 'был(а) $count минут назад',
      few: 'был(а) $count минуты назад',
      one: 'был(а) $count минуту назад',
    );
    return '$_temp0';
  }

  @override
  String presenceToday(Object time) {
    return 'был(а) сегодня в $time';
  }

  @override
  String presenceYesterday(Object time) {
    return 'был(а) вчера в $time';
  }

  @override
  String presenceDate(Object date) {
    return 'был(а) $date';
  }

  @override
  String get presenceRecently => 'был(а) недавно';

  @override
  String get presenceLastWeek => 'был(а) на этой неделе';

  @override
  String get presenceLastMonth => 'был(а) в этом месяце';

  @override
  String get presenceLongAgo => 'был(а) давно';

  @override
  String get presenceBot => 'бот';

  @override
  String get addContact => 'Добавить контакт';

  @override
  String get contactFirstName => 'Имя';

  @override
  String get contactLastName => 'Фамилия (необязательно)';

  @override
  String get contactPhone => 'Номер телефона';

  @override
  String get contactAdd => 'Добавить';

  @override
  String get contactFirstNameRequired => 'Введите имя';

  @override
  String get contactPhoneRequired => 'Введите номер телефона';

  @override
  String get contactNotOnTelegram => 'Этого номера нет в Telegram';

  @override
  String get contactAddFailed =>
      'Не удалось добавить контакт. Проверьте соединение и попробуйте ещё раз.';

  @override
  String get deleteContact => 'Удалить контакт';

  @override
  String deleteContactTitle(Object name) {
    return 'Удалить $name из контактов?';
  }

  @override
  String get deleteContactFailed => 'Не удалось удалить контакт';

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
  String get voiceHoldToRecord => 'Удерживайте, чтобы записать голосовое';

  @override
  String get voiceReleaseToCancel => 'Отпустите для отмены';

  @override
  String get voiceDelete => 'Удалить запись';

  @override
  String get voiceMicrophoneDenied => 'У Mollygram нет доступа к микрофону.';

  @override
  String get voiceOpenSettings => 'Открыть Системные настройки';

  @override
  String get voiceRecordFailed => 'Не удалось начать запись';

  @override
  String get voiceSendFailed => 'Не удалось отправить голосовое';

  @override
  String get videoHoldToRecord => 'Удерживайте, чтобы записать видеосообщение';

  @override
  String get videoCameraDenied => 'У Mollygram нет доступа к камере.';

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
  String get notifications => 'Уведомления';

  @override
  String get notificationsSectionAlerts => 'Оповещения';

  @override
  String get notificationsSectionBadge => 'Значок в Dock';

  @override
  String get notificationsShow => 'Показывать уведомления';

  @override
  String get notificationsShowHint =>
      'Баннеры появляются, пока Mollygram в фоне. Чаты без звука не беспокоят.';

  @override
  String get notificationsPreview => 'Показывать текст сообщения';

  @override
  String get notificationsPreviewHint =>
      'Если выключено, в уведомлении видно только, кто написал.';

  @override
  String get notificationsSound => 'Звук';

  @override
  String get notificationsBadge => 'Показывать число непрочитанных';

  @override
  String get notificationsBadgeMuted => 'Учитывать чаты без звука';

  @override
  String get notificationsBadgeMessages => 'Считать сообщения, а не чаты';

  @override
  String get notificationsDenied =>
      'Уведомления для Mollygram выключены в Системных настройках.';

  @override
  String get notificationsOpenSystemSettings => 'Открыть Системные настройки';

  @override
  String get notificationHiddenText => 'Новое сообщение';

  @override
  String get notificationReply => 'Ответить';

  @override
  String get notificationSend => 'Отправить';

  @override
  String get notificationReplyPlaceholder => 'Сообщение';

  @override
  String get notificationMarkRead => 'Отметить прочитанным';

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
  String get menuQuote => 'Цитировать';

  @override
  String get menuReport => 'Пожаловаться';

  @override
  String get reportDetailsTitle => 'Добавить подробности';

  @override
  String get reportDetailsOptional =>
      'Можно добавить подробности или отправить жалобу как есть.';

  @override
  String get reportDetailsHint => 'Что не так с этим сообщением?';

  @override
  String get reportSent => 'Спасибо, жалоба отправлена.';

  @override
  String seenBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Просмотрели: $count',
      one: 'Просмотрели: $count',
    );
    return '$_temp0';
  }

  @override
  String reactedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count реакций',
      few: '$count реакции',
      one: '$count реакция',
    );
    return '$_temp0';
  }

  @override
  String readAt(String time) {
    return 'Прочитано $time';
  }

  @override
  String get notReadYet => 'Ещё не прочитано';

  @override
  String editedAt(String time) {
    return 'Изменено $time';
  }

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
  String get formatBold => 'Жирный';

  @override
  String get formatItalic => 'Курсив';

  @override
  String get formatUnderline => 'Подчёркнутый';

  @override
  String get formatStrikethrough => 'Зачёркнутый';

  @override
  String get formatMonospace => 'Моноширинный';

  @override
  String get formatSpoiler => 'Спойлер';

  @override
  String get formatQuote => 'Цитата';

  @override
  String get formatLink => 'Ссылка…';

  @override
  String get formatPlain => 'Обычный текст';

  @override
  String get linkTitle => 'Добавить ссылку';

  @override
  String get linkHint => 'Адрес';

  @override
  String get linkApply => 'Применить';

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
  String get forwardHideSender => 'Скрыть имена отправителей';

  @override
  String get forwardHideCaptions => 'Скрыть подписи';

  @override
  String get noChatsFound => 'Чаты не найдены';

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
  String get peerInfo => 'Информация';

  @override
  String get statusOnline => 'в сети';

  @override
  String get lastSeenJustNow => 'был(а) только что';

  @override
  String lastSeenMinutesAgo(int count) {
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
  String lastSeenToday(String time) {
    return 'был(а) сегодня в $time';
  }

  @override
  String lastSeenYesterday(String time) {
    return 'был(а) вчера в $time';
  }

  @override
  String lastSeenDate(String date) {
    return 'был(а) $date';
  }

  @override
  String get lastSeenRecently => 'был(а) недавно';

  @override
  String get lastSeenWeek => 'был(а) на этой неделе';

  @override
  String get lastSeenMonth => 'был(а) в этом месяце';

  @override
  String get lastSeenLongAgo => 'был(а) давно';

  @override
  String get statusBot => 'бот';

  @override
  String get deletedAccount => 'Удалённый аккаунт';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count участников',
      few: '$count участника',
      one: '$count участник',
      zero: 'нет участников',
    );
    return '$_temp0';
  }

  @override
  String subscribersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count подписчиков',
      few: '$count подписчика',
      one: '$count подписчик',
      zero: 'нет подписчиков',
    );
    return '$_temp0';
  }

  @override
  String get infoBio => 'О себе';

  @override
  String get infoUsername => 'Имя пользователя';

  @override
  String get infoPhone => 'Телефон';

  @override
  String get infoBirthday => 'День рождения';

  @override
  String get infoDescription => 'Описание';

  @override
  String get infoLink => 'Ссылка';

  @override
  String get copied => 'Скопировано';

  @override
  String get infoMessage => 'Написать';

  @override
  String get infoMute => 'Без звука';

  @override
  String get infoUnmute => 'Со звуком';

  @override
  String get blockUser => 'Заблокировать';

  @override
  String get unblockUser => 'Разблокировать';

  @override
  String blockConfirmTitle(String name) {
    return 'Заблокировать $name?';
  }

  @override
  String get blockConfirmMessage =>
      'Пользователь не сможет писать и звонить вам.';

  @override
  String get block => 'Заблокировать';

  @override
  String get memberOwner => 'владелец';

  @override
  String get memberAdmin => 'админ';

  @override
  String get infoFailed => 'Не удалось загрузить информацию';

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

  @override
  String get settingsSearch => 'Поиск';

  @override
  String get myProfile => 'Мой профиль';

  @override
  String get firstName => 'Имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get username => 'Имя пользователя';

  @override
  String get bio => 'О себе';

  @override
  String get phoneNumber => 'Номер телефона';

  @override
  String get bioHint =>
      'Любые подробности, например: возраст, род занятий или город.';

  @override
  String get usernameHint =>
      'По этому имени вас смогут найти и написать вам, не зная номера телефона. Можно использовать a–z, 0–9 и подчёркивания, не меньше 5 символов.';

  @override
  String get usernameTooShort =>
      'Имя пользователя должно содержать не меньше 5 символов.';

  @override
  String get usernameTooLong =>
      'Имя пользователя не может быть длиннее 32 символов.';

  @override
  String get usernameInvalidCharacter =>
      'Допустимы только a–z, 0–9 и подчёркивания.';

  @override
  String get usernameStartsWithLetter =>
      'Имя пользователя должно начинаться с буквы.';

  @override
  String get usernameEndsWithUnderscore =>
      'Имя пользователя не может заканчиваться подчёркиванием.';

  @override
  String get usernameChecking => 'Проверка…';

  @override
  String usernameAvailable(String name) {
    return '@$name свободно.';
  }

  @override
  String get usernameOccupied => 'Это имя пользователя уже занято.';

  @override
  String get usernamePurchasable =>
      'Это имя пользователя продаётся на Fragment.';

  @override
  String get usernameUnavailable => 'Это имя пользователя нельзя использовать.';

  @override
  String get firstNameRequired => 'Имя не может быть пустым.';

  @override
  String get saveFailed => 'Не удалось сохранить изменение.';

  @override
  String get profileFailed => 'Не удалось загрузить профиль.';

  @override
  String get tryAgain => 'Повторить';

  @override
  String get logOut => 'Выйти';

  @override
  String get logOutButton => 'Выйти…';

  @override
  String get logOutTitle => 'Выйти из Telegram?';

  @override
  String get logOutMessage =>
      'Чаты и медиа будут удалены с этого компьютера. В облаке Telegram они сохранятся.';

  @override
  String get privacyAndSecurity => 'Конфиденциальность и безопасность';

  @override
  String get activeSessions => 'Активные сеансы';

  @override
  String get activeSessionsHint =>
      'Устройства и приложения, в которых выполнен вход в ваш аккаунт.';

  @override
  String get thisDevice => 'Это устройство';

  @override
  String get otherSessions => 'Другие сеансы';

  @override
  String get noOtherSessions => 'Вход выполнен только на этом устройстве.';

  @override
  String get sessionsFailed => 'Не удалось загрузить сеансы.';

  @override
  String get sessionOnline => 'в сети';

  @override
  String get sessionUnconfirmed => 'Новый вход';

  @override
  String get terminate => 'Завершить';

  @override
  String get terminateSessionTitle => 'Завершить этот сеанс?';

  @override
  String get terminateOthers => 'Завершить все другие сеансы';

  @override
  String get terminateOthersHint => 'Выход на всех устройствах, кроме этого.';

  @override
  String get terminateOthersTitle => 'Завершить все другие сеансы?';

  @override
  String get logOutFailed =>
      'Не удалось выйти. Проверьте подключение и повторите попытку.';

  @override
  String get connectedBot => 'Подключённый бизнес-бот';

  @override
  String get connectedBotFailed => 'Не удалось загрузить подключённого бота';

  @override
  String get connectedBotHint =>
      'Этот бот может читать ваши бизнес-чаты и отвечать в них.';

  @override
  String get disconnect => 'Отключить';

  @override
  String disconnectBotTitle(String name) {
    return 'Отключить $name?';
  }

  @override
  String get appearance => 'Оформление';

  @override
  String get themeAuto => 'Авто';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get accentColor => 'Цвет акцента';

  @override
  String get accentBlue => 'Синий';

  @override
  String get accentIndigo => 'Индиго';

  @override
  String get accentTeal => 'Бирюзовый';

  @override
  String get accentGreen => 'Зелёный';

  @override
  String get accentOrange => 'Оранжевый';

  @override
  String get accentGraphite => 'Графит';

  @override
  String get chatWallpaper => 'Обои в чатах';

  @override
  String get chatWallpaperHint => 'Если выключено, у чатов будет простой фон.';

  @override
  String get messageTextSize => 'Размер текста сообщений';

  @override
  String textSizeValue(String size) {
    return '$size пт';
  }

  @override
  String get previewSender => 'Анна';

  @override
  String get previewMessage => 'Доброе утро! Новые настройки отлично выглядят.';

  @override
  String get reduceMotion => 'Уменьшить движение';

  @override
  String get reduceMotionHint =>
      'Отключает анимацию. Mollygram также учитывает одноимённую настройку универсального доступа macOS.';

  @override
  String get dataAndStorage => 'Данные и память';

  @override
  String get storageUsage => 'Хранилище';

  @override
  String get storageCalculating => 'Подсчёт…';

  @override
  String storageUsed(String size) {
    return 'Медиа и файлы: $size';
  }

  @override
  String get storageEmpty =>
      'На этом компьютере нет сохранённых медиа и файлов.';

  @override
  String get storagePhotos => 'Фото';

  @override
  String get storageVideos => 'Видео';

  @override
  String get storageFiles => 'Файлы';

  @override
  String get storageVoiceAndMusic => 'Голосовые и музыка';

  @override
  String get storageStickers => 'Стикеры';

  @override
  String get storageOther => 'Другое';

  @override
  String get storageDatabase => 'База сообщений';

  @override
  String get storageHint =>
      'Удалённые медиа остаются в облаке Telegram и загружаются снова, когда нужны. Сообщения сохраняются.';

  @override
  String get storageFailed => 'Не удалось подсчитать занятое место.';

  @override
  String get clearCache => 'Очистить кэш…';

  @override
  String clearCacheTitle(String size) {
    return 'Удалить $size с этого компьютера?';
  }

  @override
  String get clearCacheMessage =>
      'Медиа останутся в облаке Telegram и загрузятся снова, когда вы их откроете.';

  @override
  String get clear => 'Очистить';

  @override
  String get clearCacheFailed => 'Не удалось очистить кэш.';

  @override
  String get autoDownload => 'Автозагрузка медиа';

  @override
  String get autoDownloadWifi => 'По Wi-Fi и Ethernet';

  @override
  String get autoDownloadOther => 'В других сетях';

  @override
  String get autoDownloadHint =>
      'Другие сети — это режим модема и прочие лимитные подключения.';

  @override
  String get downloadFolder => 'Папка загрузок';

  @override
  String get downloadFolderDefault => 'Загрузки';

  @override
  String get chooseFolder => 'Выбрать…';

  @override
  String get downloadFolderHint => 'Сюда сохраняются файлы из чатов.';

  @override
  String sizeBytes(String size) {
    return '$size Б';
  }

  @override
  String sizeKilobytes(String size) {
    return '$size КБ';
  }

  @override
  String sizeMegabytes(String size) {
    return '$size МБ';
  }

  @override
  String sizeGigabytes(String size) {
    return '$size ГБ';
  }

  @override
  String get emojiTab => 'Эмодзи';

  @override
  String get stickersTab => 'Стикеры';

  @override
  String get emojiSearch => 'Поиск эмодзи';

  @override
  String get recentlyUsed => 'Недавние';

  @override
  String get noEmojiFound => 'Эмодзи не найдены';

  @override
  String get emojiSmileys => 'Смайлы';

  @override
  String get emojiPeople => 'Люди';

  @override
  String get emojiAnimals => 'Животные и природа';

  @override
  String get emojiFood => 'Еда и напитки';

  @override
  String get emojiTravel => 'Путешествия и места';

  @override
  String get emojiActivities => 'Занятия';

  @override
  String get emojiObjects => 'Предметы';

  @override
  String get emojiSymbols => 'Символы';

  @override
  String get emojiFlags => 'Флаги';

  @override
  String get favoriteStickers => 'Избранные';

  @override
  String get stickersFailed => 'Не удалось загрузить стикеры';

  @override
  String get noStickerSets => 'Пока нет стикеров';

  @override
  String get forwardedMessages => 'Пересланные сообщения';

  @override
  String get leaveComment => 'Оставить комментарий';

  @override
  String commentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count комментариев',
      few: '$count комментария',
      one: '$count комментарий',
    );
    return '$_temp0';
  }

  @override
  String get mediaSaved => 'Сохранено';

  @override
  String get mediaSaveFailed => 'Не удалось сохранить файл';

  @override
  String get mediaCopied => 'Скопировано';

  @override
  String mediaCounter(int index, int count) {
    return '$index из $count';
  }

  @override
  String get mediaCopy => 'Копировать';

  @override
  String get mediaSave => 'Сохранить';

  @override
  String get mediaPrevious => 'Назад';

  @override
  String get mediaNext => 'Вперёд';

  @override
  String get mediaPause => 'Пауза';

  @override
  String get mediaPlay => 'Воспроизвести';

  @override
  String get mediaSpeed => 'Скорость';

  @override
  String get mediaLoop => 'Повтор';

  @override
  String get mediaUnmute => 'Включить звук';

  @override
  String get mediaMute => 'Выключить звук';

  @override
  String get unreadMessages => 'Непрочитанные сообщения';

  @override
  String get scrollToBottom => 'К последнему сообщению';

  @override
  String get nextMention => 'Следующее упоминание';

  @override
  String get nextReaction => 'Следующая реакция';

  @override
  String get linkJoinChannel => 'Подписаться на канал';

  @override
  String get linkJoinGroup => 'Вступить в группу';

  @override
  String get linkRequestToJoin => 'Подать заявку';

  @override
  String get linkViewChannel => 'Открыть канал';

  @override
  String get linkViewGroup => 'Открыть группу';

  @override
  String linkSubscribers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString подписчиков',
      few: '$countString подписчика',
      one: '$countString подписчик',
      zero: 'Нет подписчиков',
    );
    return '$_temp0';
  }

  @override
  String linkMembers(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString участников',
      few: '$countString участника',
      one: '$countString участник',
      zero: 'Нет участников',
    );
    return '$_temp0';
  }

  @override
  String get linkApprovalHint => 'Заявку должен одобрить администратор.';

  @override
  String get linkRequestSent => 'Заявка отправлена';

  @override
  String get linkRequestSentHint =>
      'Вы вступите, когда администратор её одобрит.';

  @override
  String get linkJoinFailed => 'Не удалось вступить. Попробуйте позже.';

  @override
  String get linkMissing => 'Ссылка недействительна или устарела.';

  @override
  String get linkUnsupported =>
      'Mollygram пока не умеет открывать такие ссылки.';

  @override
  String get done => 'Готово';

  @override
  String get linkForbidden => 'Вы не можете просматривать этот чат.';

  @override
  String get menuPin => 'Закрепить';

  @override
  String get menuUnpin => 'Открепить';

  @override
  String get pinnedMessage => 'Закреплённое сообщение';

  @override
  String pinnedMessageNumber(int number) {
    return 'Закреплённое сообщение #$number';
  }

  @override
  String get hidePinned => 'Скрыть закреплённые';

  @override
  String get backToPrevious => 'Вернуться назад';

  @override
  String get searchInChat => 'Поиск в чате';

  @override
  String searchCounter(int index, int count) {
    return '$index из $count';
  }

  @override
  String get searchNoResults => 'Ничего не найдено';

  @override
  String get searchOlder => 'Предыдущий результат';

  @override
  String get searchNewer => 'Следующий результат';

  @override
  String get sharedMedia => 'Общие материалы';

  @override
  String get sharedMediaTab => 'Медиа';

  @override
  String get sharedFilesTab => 'Файлы';

  @override
  String get sharedLinksTab => 'Ссылки';

  @override
  String get sharedVoiceTab => 'Голосовые';

  @override
  String get sharedMusicTab => 'Музыка';

  @override
  String get sharedMediaEmpty => 'Здесь пока нет фото и видео';

  @override
  String get sharedFilesEmpty => 'Здесь пока нет файлов';

  @override
  String get sharedLinksEmpty => 'Здесь пока нет ссылок';

  @override
  String get sharedVoiceEmpty => 'Здесь пока нет голосовых сообщений';

  @override
  String get sharedMusicEmpty => 'Здесь пока нет музыки';

  @override
  String get sharedLoadFailed => 'Не удалось загрузить список';

  @override
  String get showInChat => 'Показать в чате';

  @override
  String get joinChannel => 'Подписаться';

  @override
  String get joinGroup => 'Вступить в группу';

  @override
  String get muteChat => 'Без звука';

  @override
  String get unmuteChat => 'Включить звук';

  @override
  String get chatUnavailable => 'Вы не можете участвовать в этом чате';

  @override
  String get chatActionFailed => 'Не получилось, попробуйте ещё раз';

  @override
  String get privacyExtras => 'Дополнительная приватность';

  @override
  String get privacyExtrasAbout =>
      'Эти переключатели определяют, что видят другие, пока вы пользуетесь Mollygram на этом Mac. Читать и отправлять сообщения можно как обычно.';

  @override
  String get privacyExtrasOnlineNote =>
      'Кое-что всё равно видно: отправка сообщения ненадолго показывает вас в сети и отмечает чат прочитанным, при отправке файлов видна загрузка, а реакция показывает, что вы видели сообщение.';

  @override
  String get ghostMode => 'Режим призрака';

  @override
  String get ghostModeHint => 'Включает всё, что ниже, разом';

  @override
  String get ghostModeIsOn => 'Режим призрака включён';

  @override
  String get privacyExtrasAreOn => 'Включена часть дополнительной приватности';

  @override
  String get hideReadReceipts => 'Не отправлять отметки о прочтении';

  @override
  String get hideReadReceiptsHint =>
      'Отправители не увидят, что вы прочитали их сообщения';

  @override
  String get hideTyping => 'Не показывать набор текста';

  @override
  String get hideTypingHint => 'И запись голосовых и видеосообщений тоже';

  @override
  String get stayOffline => 'Оставаться не в сети';

  @override
  String get stayOfflineHint =>
      'Пока приложение открыто, другие не увидят вас в сети';

  @override
  String get hideContentOpened =>
      'Не отмечать голосовые и видеосообщения прослушанными';

  @override
  String get hideContentOpenedHint =>
      'Отправители не увидят, что вы их прослушали';

  @override
  String get menuSelect => 'Выбрать';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Выбрано $count сообщений',
      few: 'Выбрано $count сообщения',
      one: 'Выбрано $count сообщение',
    );
    return '$_temp0';
  }

  @override
  String get clearSelection => 'Снять выделение';

  @override
  String get copy => 'Копировать';

  @override
  String get chatFolders => 'Папки с чатами';

  @override
  String get chatFoldersHint =>
      'Распределите чаты по папкам и переключайтесь между ними в боковой панели.';

  @override
  String get createFolder => 'Создать папку';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get editFolder => 'Изменить папку';

  @override
  String get folderName => 'Название папки';

  @override
  String get folderIcon => 'Значок папки';

  @override
  String get folderIncluded => 'Добавленные чаты';

  @override
  String get folderExcluded => 'Исключённые чаты';

  @override
  String get folderAddChats => 'Добавить чаты';

  @override
  String get folderExcludeChats => 'Исключить чаты';

  @override
  String get folderIncludedHint =>
      'Выберите чаты или типы чатов, которые будут в этой папке.';

  @override
  String get folderExcludedHint =>
      'Выберите чаты или типы чатов, которых никогда не будет в этой папке.';

  @override
  String get folderContacts => 'Контакты';

  @override
  String get folderNonContacts => 'Не контакты';

  @override
  String get folderGroups => 'Группы';

  @override
  String get folderChannels => 'Каналы';

  @override
  String get folderBots => 'Боты';

  @override
  String get folderMuted => 'Без уведомлений';

  @override
  String get folderRead => 'Прочитанные';

  @override
  String get folderArchived => 'Архивированные';

  @override
  String get folderChatTypes => 'Типы чатов';

  @override
  String get folderChats => 'Чаты';

  @override
  String get folderBot => 'бот';

  @override
  String get folderGroup => 'группа';

  @override
  String get folderChannel => 'канал';

  @override
  String get folderSavedMessages => 'Избранное';

  @override
  String get folderRemove => 'Убрать';

  @override
  String get folderAdd => 'Добавить';

  @override
  String get folderReorder => 'Перетащите, чтобы изменить порядок';

  @override
  String get folderReorderHint =>
      'Потяните за маркер, чтобы изменить порядок папок.';

  @override
  String get recommendedFolders => 'Рекомендуемые папки';

  @override
  String get deleteFolder => 'Удалить папку';

  @override
  String get deleteFolderMessage => 'Чаты из неё не будут удалены.';

  @override
  String get deleteFolderLeave =>
      'Чаты из неё не будут удалены. Можно также покинуть чаты, которыми с вами поделились через эту папку:';

  @override
  String get delete => 'Удалить';

  @override
  String get save => 'Сохранить';

  @override
  String deleteFolderTitle(String name) {
    return 'Удалить «$name»?';
  }

  @override
  String folderLimit(int count) {
    return 'Максимум папок: $count.';
  }

  @override
  String folderChatsLimit(int count) {
    return 'Максимум чатов в папке: $count.';
  }

  @override
  String folderChatsCounter(int count, int max) {
    return '$count из $max';
  }

  @override
  String get previousMonth => 'Предыдущий месяц';

  @override
  String get nextMonth => 'Следующий месяц';

  @override
  String get pinnedList => 'Закреплённые сообщения';

  @override
  String pinnedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count закреплённых сообщений',
      few: '$count закреплённых сообщения',
      one: '$count закреплённое сообщение',
    );
    return '$_temp0';
  }

  @override
  String get backToChat => 'Назад в чат';

  @override
  String get unpinAll => 'Открепить все';

  @override
  String unpinAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Открепить все $count сообщений?',
      few: 'Открепить все $count сообщения?',
      one: 'Открепить $count сообщение?',
    );
    return '$_temp0';
  }

  @override
  String get edit => 'Изменить';

  @override
  String get create => 'Создать';

  @override
  String get remove => 'Удалить';

  @override
  String get leave => 'Выйти';

  @override
  String get newGroup => 'Новая группа';

  @override
  String get newChannel => 'Новый канал';

  @override
  String get groupName => 'Название группы';

  @override
  String get channelName => 'Название канала';

  @override
  String get descriptionHint => 'Описание (необязательно)';

  @override
  String get descriptionNote => 'Показывается в профиле под названием.';

  @override
  String get chatTitleRequired => 'Введите название';

  @override
  String get addMembersHint => 'Добавить участников';

  @override
  String get createFailed => 'Не удалось создать. Попробуйте ещё раз.';

  @override
  String get editGroup => 'Изменить группу';

  @override
  String get editChannel => 'Изменить канал';

  @override
  String get setPhoto => 'Выбрать фото';

  @override
  String get changePhoto => 'Изменить фото';

  @override
  String get removePhoto => 'Удалить фото';

  @override
  String get inviteLinks => 'Пригласительные ссылки';

  @override
  String get primaryLink => 'Основная ссылка';

  @override
  String get createPrimaryLink => 'Создать ссылку';

  @override
  String get additionalLinks => 'Дополнительные ссылки';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String get revokeLink => 'Отозвать';

  @override
  String get revokeLinkTitle => 'Отозвать ссылку?';

  @override
  String get revokeLinkMessage => 'По ней больше никто не сможет вступить.';

  @override
  String get revokePrimaryMessage =>
      'По ней больше никто не сможет вступить. Её заменит новая основная ссылка.';

  @override
  String get createLink => 'Создать новую ссылку';

  @override
  String get newLink => 'Новая ссылка';

  @override
  String get linkNameHint => 'Название ссылки (видят только админы)';

  @override
  String get linkDuration => 'Срок действия';

  @override
  String get linkMemberLimit => 'Число вступлений';

  @override
  String get linkRequestApproval => 'Одобрять новых участников';

  @override
  String get noLimit => 'Без ограничений';

  @override
  String get oneDay => '1 день';

  @override
  String get oneWeek => '1 неделя';

  @override
  String get oneMonth => '1 месяц';

  @override
  String linkJoined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'вступили $count',
      many: 'вступили $count',
      few: 'вступили $count',
      one: 'вступил $count',
      zero: 'никто не вступил',
    );
    return '$_temp0';
  }

  @override
  String linkJoinedOf(int count, int limit) {
    return 'Вступили $count из $limit';
  }

  @override
  String get linkApproval => 'с одобрением';

  @override
  String get linkExpired => 'истекла';

  @override
  String linkExpires(String date) {
    return 'до $date';
  }

  @override
  String get searchMembers => 'Поиск участников';

  @override
  String get showMoreMembers => 'Показать ещё';

  @override
  String get promoteToAdmin => 'Назначить админом';

  @override
  String get editAdminRights => 'Изменить права админа';

  @override
  String get dismissAdmin => 'Снять с должности админа';

  @override
  String get restrictMember => 'Ограничить';

  @override
  String get removeFromGroup => 'Удалить из группы';

  @override
  String get removeFromChannel => 'Удалить из канала';

  @override
  String removeMemberTitle(String name) {
    return 'Удалить $name?';
  }

  @override
  String get addAdmin => 'Новый админ';

  @override
  String get adminRights => 'Права админа';

  @override
  String adminRightsOf(String name) {
    return 'Что может $name';
  }

  @override
  String restrictWhatCan(String name) {
    return 'Что $name ещё может';
  }

  @override
  String get rightChangeInfo => 'Изменять профиль группы';

  @override
  String get rightChangeChannelInfo => 'Изменять профиль канала';

  @override
  String get rightPostMessages => 'Публиковать сообщения';

  @override
  String get rightEditMessages => 'Изменять чужие сообщения';

  @override
  String get rightDeleteMessages => 'Удалять сообщения';

  @override
  String get rightBanUsers => 'Блокировать участников';

  @override
  String get rightInviteUsers => 'Добавлять участников';

  @override
  String get rightAddSubscribers => 'Добавлять подписчиков';

  @override
  String get rightPinMessages => 'Закреплять сообщения';

  @override
  String get rightManageVideoChats => 'Управлять видеочатами';

  @override
  String get rightAddAdmins => 'Назначать админов';

  @override
  String get rightAnonymous => 'Оставаться анонимным';

  @override
  String get permSendMessages => 'Отправлять сообщения';

  @override
  String get permSendMedia => 'Отправлять медиа';

  @override
  String get permSendStickers => 'Отправлять стикеры и GIF';

  @override
  String get permSendPolls => 'Отправлять опросы';

  @override
  String get permEmbedLinks => 'Предпросмотр ссылок';

  @override
  String get leaveGroup => 'Выйти из группы';

  @override
  String get leaveChannel => 'Покинуть канал';

  @override
  String get deleteGroup => 'Удалить группу';

  @override
  String get deleteChannel => 'Удалить канал';

  @override
  String get leaveGroupTitle => 'Выйти из группы?';

  @override
  String get leaveChannelTitle => 'Покинуть канал?';

  @override
  String get deleteGroupTitle => 'Удалить группу?';

  @override
  String get deleteChannelTitle => 'Удалить канал?';

  @override
  String get membersFailed => 'Не удалось загрузить участников.';

  @override
  String get memberChangeFailed =>
      'Не удалось внести изменение. Возможно, у вас нет на это прав.';

  @override
  String get removeRestrictions => 'Снять ограничения';

  @override
  String get rightManageTopics => 'Управлять темами';

  @override
  String notAddedMembers(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Группа создана, но $names нельзя добавить из-за их настроек приватности.',
      one:
          'Группа создана, но $names нельзя добавить из-за настроек приватности.',
    );
    return '$_temp0';
  }

  @override
  String get leaveOwnerNote =>
      'Вы останетесь владельцем и сможете вернуться по ссылке.';

  @override
  String get deleteGroupMessage =>
      'Группа и все её сообщения пропадут у всех участников. Это нельзя отменить.';

  @override
  String get deleteChannelMessage =>
      'Канал и все его публикации пропадут у всех подписчиков. Это нельзя отменить.';

  @override
  String get leaveFailed => 'Не удалось выйти. Попробуйте ещё раз.';

  @override
  String get deleteFailed => 'Не удалось удалить. Попробуйте ещё раз.';

  @override
  String get folderDeletedChat => 'Удалённый чат';
}
