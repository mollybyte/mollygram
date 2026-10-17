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
  String sidebarSearchHint(String shortcut) {
    return 'Поиск или $shortcut';
  }

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
  String get draftLabel => 'Черновик:';

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
  String get videoSwitchCamera => 'Сменить камеру';

  @override
  String get senderYou => 'Вы';

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
  String get transcribe => 'Расшифровать';

  @override
  String get hideTranscript => 'Скрыть расшифровку';

  @override
  String get transcribing => 'Расшифровка…';

  @override
  String get transcriptionFailed => 'Не удалось расшифровать сообщение';

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
  String get deletedMark => 'удалено';

  @override
  String deletedAt(String time) {
    return 'Удалено $time';
  }

  @override
  String get menuEditHistory => 'История изменений';

  @override
  String get editHistoryTitle => 'История изменений';

  @override
  String get editHistoryCurrent => 'Текущая версия';

  @override
  String get editHistoryEmpty => 'Прежние версии не сохранены';

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
  String get moreReactions => 'Ещё реакции';

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
  String get menuChooseChat => 'Выбрать чат…';

  @override
  String get menuSaveAs => 'Сохранить как…';

  @override
  String get menuSaveToDownloads => 'Сохранить в загрузки';

  @override
  String get menuShowInFinder => 'Показать в Finder';

  @override
  String get menuShowInFolder => 'Показать в папке';

  @override
  String get menuQuickLook => 'Быстрый просмотр';

  @override
  String get sendWithoutSound => 'Отправить без звука';

  @override
  String get scheduleMessage => 'Запланировать сообщение…';

  @override
  String get sendWhenOnline => 'Отправить, когда появится в сети';

  @override
  String get scheduledWhenOnline =>
      'Отправится, когда собеседник появится в сети';

  @override
  String get scheduleTitle => 'Запланировать сообщение';

  @override
  String get scheduleHint => 'Выберите день и время отправки.';

  @override
  String get scheduleTimeHint => 'ЧЧ:ММ';

  @override
  String get scheduleAction => 'Запланировать';

  @override
  String get scheduledList => 'Запланированные сообщения';

  @override
  String scheduledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count запланированных сообщений',
      few: '$count запланированных сообщения',
      one: '$count запланированное сообщение',
    );
    return '$_temp0';
  }

  @override
  String get menuSendNow => 'Отправить сейчас';

  @override
  String get menuReschedule => 'Перенести…';

  @override
  String scheduledFor(String date) {
    return 'Запланировано на $date';
  }

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
  String get linkPreviewAboveText => 'Показать превью над текстом';

  @override
  String get linkPreviewBelowText => 'Показать превью под текстом';

  @override
  String get removeLinkPreview => 'Убрать превью ссылки';

  @override
  String get forwardTitle => 'Переслать в чат';

  @override
  String get forwardSearch => 'Поиск чатов';

  @override
  String get forwardHideSender => 'Скрыть имена отправителей';

  @override
  String get forwardHideCaptions => 'Скрыть подписи';

  @override
  String get forwardComment => 'Добавить комментарий…';

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
  String get menuHideArchive => 'Скрыть архив';

  @override
  String get menuShowArchive => 'Показать архив';

  @override
  String get showArchiveRow => 'Архив в списке чатов';

  @override
  String get showArchiveRowHint =>
      'Пока строка скрыта, архив доступен на боковой панели и в поиске.';

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
  String get leave => 'Выйти';

  @override
  String deleteAndLeaveTitle(String name) {
    return 'Удалить «$name» и выйти?';
  }

  @override
  String get chatActionFailed => 'Не получилось, попробуйте ещё раз';

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
  String get attachAddMore => 'Добавить ещё';

  @override
  String get groupAlbum => 'Сгруппировать в альбом';

  @override
  String get removeFromSend => 'Убрать';

  @override
  String get cancelUpload => 'Отменить отправку';

  @override
  String get retryUpload => 'Повторить';

  @override
  String get discardUpload => 'Удалить';

  @override
  String get sendAsFiles => 'Отправить как файлы';

  @override
  String get hideWithSpoiler => 'Скрыть спойлером';

  @override
  String get viewOnce => 'Один раз';

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
  String muteForHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'На $count часов',
      few: 'На $count часа',
      one: 'На $count час',
    );
    return '$_temp0';
  }

  @override
  String muteForDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'На $count дней',
      few: 'На $count дня',
      one: 'На $count день',
    );
    return '$_temp0';
  }

  @override
  String get muteUntilEnabled => 'Пока не включу обратно';

  @override
  String get autoDeleteTitle => 'Автоудаление сообщений';

  @override
  String get blockUser => 'Заблокировать';

  @override
  String get infoShareContact => 'Поделиться контактом';

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
  String get liveLocationEnded => 'Трансляция завершена';

  @override
  String liveMinutesLeft(int minutes) {
    return 'осталось $minutes мин';
  }

  @override
  String liveHoursLeft(int hours) {
    return 'осталось $hours ч';
  }

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
  String get pollAnonymous => 'Анонимный опрос';

  @override
  String get pollAnonymousQuiz => 'Анонимная викторина';

  @override
  String get pollFinalResults => 'Окончательные результаты';

  @override
  String get pollVote => 'Голосовать';

  @override
  String get pollRetractVote => 'Отозвать голос';

  @override
  String quizAnswers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ответов',
      few: '$count ответа',
      one: '$count ответ',
      zero: 'Пока никто не ответил',
    );
    return '$_temp0';
  }

  @override
  String get menuStopPoll => 'Остановить опрос';

  @override
  String get stopPollTitle => 'Остановить опрос?';

  @override
  String get stopPollMessage => 'Больше никто не сможет в нём проголосовать.';

  @override
  String get botMenu => 'Меню';

  @override
  String get webAppUnavailable => 'Не удалось открыть приложение бота';

  @override
  String get sendAs => 'Отправлять как';

  @override
  String get sendAsPersonal => 'Личный аккаунт';

  @override
  String get sendAsChannel => 'Канал';

  @override
  String get sendAsPremium => 'Telegram Premium';

  @override
  String get botKeyboard => 'Клавиатура бота';

  @override
  String get botNoAnswer => 'Бот не ответил';

  @override
  String get sharePhoneTitle => 'Поделиться номером телефона?';

  @override
  String sharePhoneMessage(String bot) {
    return '$bot получит номер телефона вашего аккаунта.';
  }

  @override
  String get share => 'Поделиться';

  @override
  String get attachFile => 'Файл…';

  @override
  String get attachPoll => 'Опрос…';

  @override
  String get attachContact => 'Контакт…';

  @override
  String get sendContactTitle => 'Отправить контакт';

  @override
  String get attachLocation => 'Геопозиция…';

  @override
  String get sendLocationTitle => 'Отправить геопозицию';

  @override
  String get locationSearchHint => 'Место, адрес или координаты';

  @override
  String get locationStartHint =>
      'Введите координаты или вставьте ссылку на карту, чтобы выбрать точку, затем ищите места рядом';

  @override
  String get sendThisLocation => 'Отправить эту точку';

  @override
  String get mapZoomIn => 'Приблизить';

  @override
  String get mapZoomOut => 'Отдалить';

  @override
  String get newPollTitle => 'Новый опрос';

  @override
  String get newQuizTitle => 'Новая викторина';

  @override
  String get pollQuestionHint => 'Задайте вопрос';

  @override
  String get pollOptionsTitle => 'Варианты ответа';

  @override
  String get pollOptionHint => 'Добавить вариант';

  @override
  String get pollRemoveOption => 'Убрать вариант';

  @override
  String get pollCorrectAnswer => 'Правильный ответ';

  @override
  String get pollAnonymousVoting => 'Анонимное голосование';

  @override
  String get pollMultipleAnswers => 'Несколько ответов';

  @override
  String get pollQuizMode => 'Режим викторины';

  @override
  String get pollExplanationHint => 'Пояснение (необязательно)';

  @override
  String get pollQuizHint =>
      'Отметьте правильный ответ; участники увидят пояснение после ответа.';

  @override
  String get pollCreate => 'Создать';

  @override
  String get startBot => 'Запустить';

  @override
  String get contentGame => 'Игра';

  @override
  String get contentInvoice => 'Счёт';

  @override
  String get contentStory => 'История';

  @override
  String get contentChecklist => 'Список задач';

  @override
  String checklistProgress(int done, int total) {
    return '$done из $total выполнено';
  }

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
  String get accentViolet => 'Фиолетовый';

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
  String get gifsTab => 'GIF';

  @override
  String get customEmojiTab => 'Свои';

  @override
  String get emojiSearch => 'Поиск эмодзи';

  @override
  String get recentlyUsed => 'Недавние';

  @override
  String get noEmojiFound => 'Эмодзи не найдены';

  @override
  String get stickerSearch => 'Поиск стикеров';

  @override
  String get noStickersFound => 'Стикеры не найдены';

  @override
  String get stickerSearchResults => 'Найдено';

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
  String get noStickerSets => 'Наборов пока нет';

  @override
  String get noGifs => 'Сохранённых GIF пока нет';

  @override
  String get gifsFailed => 'Не удалось загрузить GIF';

  @override
  String get inlineSearching => 'Поиск…';

  @override
  String get inlineNoResults => 'Ничего не найдено';

  @override
  String get forwardedMessages => 'Пересланные сообщения';

  @override
  String get leaveComment => 'Оставить комментарий';

  @override
  String get comments => 'Комментарии';

  @override
  String get commentHint => 'Комментарий';

  @override
  String get commentsUnavailable => 'Не удалось открыть комментарии';

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
  String get replies => 'Ответы';

  @override
  String get replyHint => 'Ответить';

  @override
  String replyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ответов',
      few: '$count ответа',
      one: '$count ответ',
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
  String get mediaRotate => 'Повернуть';

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
  String get linkCannotSend => 'Не удалось отправить команду.';

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
  String get searchByDate => 'Перейти к дате';

  @override
  String get searchBySender => 'Поиск по отправителю';

  @override
  String get searchFilter => 'Фильтр результатов';

  @override
  String get searchAllKinds => 'Все сообщения';

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
  String get hashtagThisChat => 'Этот чат';

  @override
  String get hashtagMyMessages => 'Мои сообщения';

  @override
  String get hashtagPublicPosts => 'Публичные посты';

  @override
  String hashtagEmpty(String tag) {
    return 'Нет сообщений с $tag';
  }

  @override
  String get hashtagFailed => 'Не удалось выполнить поиск';

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
  String get sharedGifsTab => 'GIF';

  @override
  String get sharedGroupsTab => 'Группы';

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
  String get sharedGifsEmpty => 'Здесь пока нет GIF';

  @override
  String get sharedGroupsEmpty => 'Нет общих групп';

  @override
  String get sharedLoadFailed => 'Не удалось загрузить список';

  @override
  String get showInChat => 'Показать в чате';

  @override
  String get playlist => 'Плейлист';

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
  String get textNotAllowed => 'Текстовые сообщения в этой группе запрещены';

  @override
  String restrictedUntil(String date) {
    return 'Вы не можете писать здесь до $date';
  }

  @override
  String slowModeWait(String time) {
    return 'Медленный режим, следующее сообщение через $time';
  }

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
  String get backToTopics => 'Назад к темам';

  @override
  String get savedShowAsChats => 'Показать как чаты';

  @override
  String get savedShowAsMessages => 'Показать как сообщения';

  @override
  String get savedMyNotes => 'Мои заметки';

  @override
  String get savedHiddenAuthor => 'Скрытый автор';

  @override
  String get savedTagName => 'Назвать тег';

  @override
  String get savedTagClearName => 'Убрать название';

  @override
  String get savedTagFailed => 'Не удалось загрузить эти сообщения';

  @override
  String get savedAllMessages => 'Все сохранённые сообщения';

  @override
  String deleteSavedTopicConfirm(String name) {
    return 'Удалить всё сохранённое из «$name»?';
  }

  @override
  String get noTopics => 'Тем пока нет';

  @override
  String get topicClosed => 'Тема закрыта';

  @override
  String get topicUnavailable => 'Не удалось открыть тему';

  @override
  String get newTopic => 'Новая тема';

  @override
  String get topicName => 'Название темы';

  @override
  String get topicNameRequired => 'Дайте теме название';

  @override
  String get editTopic => 'Изменить тему';

  @override
  String get closeTopic => 'Закрыть тему';

  @override
  String get reopenTopic => 'Открыть тему снова';

  @override
  String get pinTopic => 'Закрепить';

  @override
  String get unpinTopic => 'Открепить';

  @override
  String get deleteTopic => 'Удалить тему';

  @override
  String deleteTopicConfirm(String name) {
    return 'Удалить «$name» со всеми сообщениями?';
  }

  @override
  String get topicActionFailed => 'Не удалось изменить тему';

  @override
  String get sponsored => 'Реклама';

  @override
  String get recommended => 'Рекомендация';

  @override
  String get sponsoredOpen => 'Открыть';

  @override
  String get sponsoredAbout =>
      'Это сообщение Telegram показывает от имени рекламодателя. Оно подобрано по теме канала, а не по вашим данным.';

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
  String get privacyTitle => 'Конфиденциальность';

  @override
  String get privacyLoadFailed =>
      'Не удалось загрузить настройки конфиденциальности.';

  @override
  String get privacyPhoneNumber => 'Номер телефона';

  @override
  String get privacyFindByPhone => 'Поиск по номеру';

  @override
  String get privacyLastSeen => 'Время захода и онлайн';

  @override
  String get privacyProfilePhotos => 'Фотографии профиля';

  @override
  String get privacyForwards => 'Пересылка сообщений';

  @override
  String get privacyCalls => 'Звонки';

  @override
  String get privacyVoiceMessages => 'Голосовые сообщения';

  @override
  String get privacyInvites => 'Группы и каналы';

  @override
  String get privacyBio => 'О себе';

  @override
  String get privacyBirthday => 'Дата рождения';

  @override
  String get privacyPhoneNumberQuestion => 'Кто видит мой номер телефона?';

  @override
  String get privacyFindByPhoneQuestion => 'Кто может найти меня по номеру?';

  @override
  String get privacyLastSeenQuestion =>
      'Кто видит время моего последнего захода?';

  @override
  String get privacyProfilePhotosQuestion =>
      'Кто видит фотографии моего профиля?';

  @override
  String get privacyForwardsQuestion =>
      'Кто может ссылаться на мой аккаунт при пересылке моих сообщений?';

  @override
  String get privacyCallsQuestion => 'Кто может мне звонить?';

  @override
  String get privacyVoiceMessagesQuestion =>
      'Кто может присылать мне голосовые и видеосообщения?';

  @override
  String get privacyInvitesQuestion =>
      'Кто может добавлять меня в группы и каналы?';

  @override
  String get privacyBioQuestion => 'Кто видит информацию обо мне?';

  @override
  String get privacyBirthdayQuestion => 'Кто видит мою дату рождения?';

  @override
  String get privacyPhoneNumberAbout =>
      'Те, у кого ваш номер сохранён в контактах, тоже увидят его в Telegram.';

  @override
  String get privacyFindByPhoneAbout =>
      'Добавив ваш номер в контакты, человек увидит ваш аккаунт в Telegram, только если он входит в этот круг.';

  @override
  String get privacyLastSeenAbout =>
      'Вы не увидите время захода тех, кому не показываете своё. Вместо него будет примерное время, например недавно или на этой неделе.';

  @override
  String get privacyForwardsAbout =>
      'Пересланные людьми вне этого круга сообщения не будут ссылаться на ваш аккаунт.';

  @override
  String get privacyVoiceMessagesAbout =>
      'Ограничить голосовые и видеосообщения могут только подписчики Telegram Premium.';

  @override
  String get privacyEverybody => 'Все';

  @override
  String get privacyMyContacts => 'Мои контакты';

  @override
  String get privacyNobody => 'Никто';

  @override
  String get privacyExceptions => 'Исключения';

  @override
  String get privacyExceptionsAbout => 'Исключения важнее выбора выше.';

  @override
  String get privacyAlwaysAllow => 'Всегда разрешать';

  @override
  String get privacyNeverAllow => 'Никогда не разрешать';

  @override
  String get privacyAlwaysAbout =>
      'Этим людям разрешено при любом выборе выше.';

  @override
  String get privacyNeverAbout =>
      'Этим людям не разрешено при любом выборе выше.';

  @override
  String get privacyAddPeople => 'Добавить людей';

  @override
  String get privacyGroupMembers => 'Участники группы';

  @override
  String privacyPeopleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count человека',
      many: '$count человек',
      few: '$count человека',
      one: '$count человек',
    );
    return '$_temp0';
  }

  @override
  String get blockedUsers => 'Заблокированные пользователи';

  @override
  String get blockedUsersAbout =>
      'Заблокированные не могут писать и звонить вам или добавлять вас в группы, а также не видят ваши фотографии, статус в сети и время захода.';

  @override
  String get blockedUsersEmpty => 'Никто не заблокирован.';

  @override
  String get blockSomeone => 'Заблокировать пользователя';

  @override
  String get privacyNotLoaded => 'Не загружено';

  @override
  String get unblock => 'Разблокировать';

  @override
  String get blockedShowMore => 'Показать ещё';

  @override
  String get keepDeletedMessages => 'Сохранять удалённые сообщения';

  @override
  String get keepDeletedMessagesHint =>
      'Сохранять сообщения, которые другие удалили для всех';

  @override
  String get keepEditHistory => 'Сохранять историю правок';

  @override
  String get keepEditHistoryHint =>
      'Сохранять прежние версии изменённых сообщений';

  @override
  String get storedMessagesAbout =>
      'Хранится в зашифрованном виде только на этом компьютере, для сообщений, которые Mollygram видел, пока был открыт. Никуда не отправляется. Показ в чатах появится позже.';

  @override
  String get clearStoredData => 'Сохранённые данные';

  @override
  String get clearStoredDataTitle =>
      'Удалить удалённые сообщения и историю правок, сохранённые на этом компьютере?';

  @override
  String get storedDataUnreadable => 'Сохранённые данные не читаются';

  @override
  String get storedDataUnreadableHint =>
      'Ключа нет в связке ключей. Сбросьте, чтобы начать заново.';

  @override
  String get resetStoredData => 'Сбросить';

  @override
  String get resetStoredDataTitle =>
      'Удалить нечитаемые сохранённые данные и начать заново?';

  @override
  String get edit => 'Изменить';

  @override
  String get create => 'Создать';

  @override
  String get remove => 'Удалить';

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

  @override
  String get passcodeLock => 'Код-пароль';

  @override
  String get passcodeAbout =>
      'Код-пароль блокирует Mollygram на этом Mac. Он не отправляется в Telegram и действует только здесь.';

  @override
  String get passcodeTurnOn => 'Включить код-пароль';

  @override
  String get passcodeTurnOff => 'Выключить код-пароль';

  @override
  String get passcodeTurnOffAction => 'Выключить';

  @override
  String get passcodeChange => 'Сменить код-пароль';

  @override
  String get passcodeCurrent => 'Текущий код-пароль';

  @override
  String get passcodeNew => 'Новый код-пароль';

  @override
  String get passcodeRepeat => 'Повторите код-пароль';

  @override
  String get passcodeTooShort => 'Нужно хотя бы 4 символа.';

  @override
  String get passcodesDontMatch => 'Код-пароли не совпадают.';

  @override
  String get passcodeWrong => 'Неверный код-пароль';

  @override
  String get passcodeAutoLock => 'Автоблокировка';

  @override
  String get passcodeAwayHour => 'Через 1 час';

  @override
  String passcodeAwayFor(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Через $minutes минуты',
      many: 'Через $minutes минут',
      few: 'Через $minutes минуты',
      one: 'Через $minutes минуту',
    );
    return '$_temp0';
  }

  @override
  String get passcodeLockNowHint => 'Нажмите ⌘L, чтобы заблокировать сразу.';

  @override
  String get passcodeLocked => 'Mollygram заблокирован';

  @override
  String get passcodeEnter => 'Введите код-пароль, чтобы продолжить.';

  @override
  String get passcodeHint => 'Код-пароль';

  @override
  String get passcodeForgot => 'Забыли код-пароль?';

  @override
  String get passcodeLogOutTitle => 'Выйти, чтобы убрать код-пароль?';

  @override
  String get passcodeLogOutMessage =>
      'Код-пароль нельзя восстановить. Выход убирает его, а чаты вернутся, когда вы снова войдёте.';

  @override
  String get twoStep => 'Двухэтапная аутентификация';

  @override
  String get twoStepOn => 'Вкл.';

  @override
  String get twoStepOff => 'Выкл.';

  @override
  String get twoStepOffAbout =>
      'Задайте пароль, который Telegram спросит после кода при входе на новом устройстве.';

  @override
  String get twoStepOnAbout =>
      'Telegram спрашивает этот пароль после кода при входе на новом устройстве.';

  @override
  String get twoStepLoadFailed =>
      'Не удалось загрузить двухэтапную аутентификацию.';

  @override
  String get twoStepSetPassword => 'Задать пароль';

  @override
  String get twoStepSetPasswordAbout =>
      'Резервная почта поможет сбросить пароль, если вы его забудете.';

  @override
  String get twoStepChangePassword => 'Сменить пароль';

  @override
  String get twoStepCurrentPassword => 'Текущий пароль';

  @override
  String get twoStepNewPassword => 'Новый пароль';

  @override
  String get twoStepRepeatPassword => 'Повторите пароль';

  @override
  String get twoStepHint => 'Подсказка (необязательно)';

  @override
  String twoStepHintIs(String hint) {
    return 'Подсказка: $hint';
  }

  @override
  String get twoStepHintIsPassword => 'Подсказка не может совпадать с паролем.';

  @override
  String get twoStepRecoveryEmail => 'Резервная почта';

  @override
  String get twoStepRecoveryEmailAbout =>
      'На этот адрес Telegram пришлёт код, чтобы сбросить забытый пароль.';

  @override
  String get twoStepSetEmail => 'Указать резервную почту';

  @override
  String get twoStepChangeEmail => 'Сменить резервную почту';

  @override
  String get twoStepEmailInvalid => 'Неверный адрес почты.';

  @override
  String get twoStepPasswordRejected =>
      'Telegram не принял этот пароль. Попробуйте другой.';

  @override
  String get twoStepConfirmEmail => 'Подтвердите резервную почту';

  @override
  String twoStepCodeSent(String email) {
    return 'Telegram отправил код на $email.';
  }

  @override
  String get twoStepEnterCode => 'Ввести код';

  @override
  String get twoStepCode => 'Код';

  @override
  String get twoStepCheckCode => 'Подтвердить';

  @override
  String get twoStepResendCode => 'Отправить код ещё раз';

  @override
  String get twoStepCancelEmail => 'Не использовать эту почту';

  @override
  String get twoStepEmailConfirmed => 'Резервная почта подтверждена.';

  @override
  String get twoStepPasswordSet => 'Двухэтапная аутентификация включена.';

  @override
  String get twoStepPasswordChanged => 'Пароль изменён.';

  @override
  String get twoStepTurnOff => 'Выключить двухэтапную аутентификацию';

  @override
  String get twoStepTurnOffAbout =>
      'Для входа на новом устройстве будет нужен только код.';

  @override
  String get twoStepTurnOffAction => 'Выключить';

  @override
  String get twoStepTurnedOff => 'Двухэтапная аутентификация выключена.';

  @override
  String get passwordsDontMatch => 'Пароли не совпадают.';

  @override
  String get accountTtlTitle => 'Удаление аккаунта';

  @override
  String get accountTtlRow => 'Если не заходить';

  @override
  String get accountTtlQuestion => 'Удалить аккаунт, если я не захожу';

  @override
  String get accountTtlAbout =>
      'Если вы ни разу не зайдёте за это время, аккаунт удалится вместе со всеми сообщениями и контактами.';

  @override
  String ttlMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count месяца',
      many: '$count месяцев',
      few: '$count месяца',
      one: '$count месяц',
    );
    return '$_temp0';
  }

  @override
  String ttlDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String get accounts => 'Аккаунты';

  @override
  String accountsAbout(int count) {
    return 'До $count аккаунтов, у каждого свои чаты и вкладки.';
  }

  @override
  String get addAccount => 'Добавить аккаунт';

  @override
  String accountNumber(int number) {
    return 'Аккаунт $number';
  }

  @override
  String switchToAccount(String name) {
    return 'Переключиться на $name';
  }

  @override
  String get notSignedIn => 'Вход не выполнен';

  @override
  String logOutAccountTitle(String name) {
    return 'Выйти из аккаунта $name?';
  }

  @override
  String backToAccount(String name) {
    return 'Вернуться к $name';
  }

  @override
  String get loggingOut => 'Выход…';

  @override
  String accountsFull(int count) {
    return 'Это предел: $count аккаунта. Выйдите из одного, чтобы добавить другой.';
  }

  @override
  String get accountsLegacy =>
      'Не удалось перенести папку данных прежней версии, поэтому доступен только этот аккаунт. Перезапустите Mollygram, чтобы попробовать снова.';

  @override
  String duplicateAccountTitle(String name) {
    return 'В $name уже выполнен вход';
  }

  @override
  String get duplicateAccountMessage =>
      'Переключиться на него и выйти из этой копии?';

  @override
  String get switchAccount => 'Переключиться';

  @override
  String get proxy => 'Прокси';

  @override
  String get useProxy => 'Использовать прокси';

  @override
  String get proxyHint =>
      'Telegram подключается через выбранный прокси. Пинг показывает время отклика в миллисекундах.';

  @override
  String get savedProxies => 'Сохранённые прокси';

  @override
  String get addProxy => 'Добавить прокси';

  @override
  String get editProxy => 'Изменить прокси';

  @override
  String get proxyServer => 'Сервер';

  @override
  String get proxyPort => 'Порт';

  @override
  String get proxyUsername => 'Имя пользователя';

  @override
  String get proxyPassword => 'Пароль';

  @override
  String get proxySecret => 'Ключ';

  @override
  String get proxyCheck => 'Проверить';

  @override
  String get proxyChecking => 'Проверка…';

  @override
  String proxyPing(int ms) {
    return '$ms мс';
  }

  @override
  String get proxyUnavailable => 'Недоступен';

  @override
  String get proxyRemove => 'Удалить прокси';

  @override
  String proxyRemoveTitle(String address) {
    return 'Удалить $address?';
  }

  @override
  String get proxyConnect => 'Подключиться';

  @override
  String get proxyFromLink => 'Добавить этот прокси и подключиться через него?';

  @override
  String get proxyNone => 'Прокси пока нет';

  @override
  String get language => 'Язык';

  @override
  String get languageSystem => 'Как в системе';

  @override
  String get languageHint =>
      'Меняет язык приложения. Чаты и сообщения остаются как есть.';

  @override
  String get proxyEditButton => 'Изменить';

  @override
  String get proxyInvalidSecret => 'Неверный ключ';

  @override
  String get proxyRemoveAction => 'Удалить';

  @override
  String get proxyLoadFailed => 'Не удалось загрузить прокси.';

  @override
  String get proxyShowSecret => 'Показать ключ';

  @override
  String get proxyHideSecret => 'Скрыть ключ';

  @override
  String get pluginShowMessage => 'Показать';

  @override
  String get pluginFilteredMessage => 'Скрыто плагином';

  @override
  String passcodeWaitSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Слишком много попыток. Попробуйте через $count секунды.',
      many: 'Слишком много попыток. Попробуйте через $count секунд.',
      few: 'Слишком много попыток. Попробуйте через $count секунды.',
      one: 'Слишком много попыток. Попробуйте через $count секунду.',
    );
    return '$_temp0';
  }

  @override
  String passcodeWaitMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Слишком много попыток. Попробуйте через $count минуты.',
      many: 'Слишком много попыток. Попробуйте через $count минут.',
      few: 'Слишком много попыток. Попробуйте через $count минуты.',
      one: 'Слишком много попыток. Попробуйте через $count минуту.',
    );
    return '$_temp0';
  }

  @override
  String get passcodeForgotNoSession =>
      'Telegram не запустился, поэтому выйти пока не из чего. Попробуйте, когда он подключится.';

  @override
  String get passcodeLogOutFailed =>
      'Не удалось выйти. Код-пароль останется, пока выход не получится.';

  @override
  String get passcodeUnreadable =>
      'Не удалось прочитать код-пароль из связки ключей. Окно останется заблокированным, пока это не получится.';

  @override
  String get passcodeReadAgain => 'Прочитать снова';

  @override
  String get twoStepPendingAbout =>
      'Двухэтапная проверка включится, когда вы введёте код из письма на резервную почту.';

  @override
  String get twoStepConfirmToFinish =>
      'Введите код из письма, чтобы включить двухэтапную проверку.';

  @override
  String get twoStepPasswordTooFresh =>
      'Пароль недавно меняли. Попробуйте позже.';

  @override
  String get twoStepSessionTooFresh =>
      'Это устройство вошло недавно. Попробуйте позже.';

  @override
  String get twoStepForgotPassword => 'Забыли пароль?';

  @override
  String get twoStepRecoverTitle => 'Сброс пароля';

  @override
  String twoStepRecoverAbout(String pattern) {
    return 'Введите код, отправленный на $pattern, и новый пароль.';
  }

  @override
  String get twoStepResetTitle => 'Сбросить пароль?';

  @override
  String get twoStepResetMessage =>
      'Без резервной почты Telegram удалит пароль через 7 дней. Вход с паролем отменит сброс.';

  @override
  String get twoStepResetAction => 'Сбросить';

  @override
  String twoStepResetPending(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Пароль будет удалён $dateString.';
  }

  @override
  String twoStepResetDeclined(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Telegram пока не может сбросить пароль. Попробуйте после $dateString.';
  }

  @override
  String get twoStepCancelReset => 'Отменить сброс';

  @override
  String ttlYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count года',
      many: '$count лет',
      few: '$count года',
      one: '$count год',
    );
    return '$_temp0';
  }

  @override
  String get accountTtlFooter =>
      'Аккаунт удалится, если вы не зайдёте за это время.';

  @override
  String get secretChat => 'Секретный чат';

  @override
  String get newSecretChat => 'Новый секретный чат';

  @override
  String get startSecretChat => 'Начать секретный чат';

  @override
  String get secretChatFailed =>
      'Не удалось начать секретный чат. Попробуйте ещё раз.';

  @override
  String secretChatWaiting(String name) {
    return 'Ожидание, пока $name появится в сети';
  }

  @override
  String get secretChatExchangingKeys => 'Обмен ключами шифрования';

  @override
  String get secretChatClosed => 'Секретный чат закрыт';

  @override
  String get closeSecretChat => 'Закрыть секретный чат';

  @override
  String get deleteChat => 'Удалить чат';

  @override
  String get deleteSecretChatTitle =>
      'Удалить этот секретный чат? Он закроется для вас обоих, а его сообщения будут удалены здесь.';

  @override
  String get encryptionKey => 'Ключ шифрования';

  @override
  String encryptionKeyHint(String name) {
    return 'Если на устройстве $name картинка и числа такие же, ваш чат защищён сквозным шифрованием.';
  }

  @override
  String get encryptionKeyPending =>
      'Ключ появится, когда приложение собеседника примет чат.';

  @override
  String get selfDestructTitle => 'Таймер самоуничтожения';

  @override
  String get selfDestructOff => 'Выключен';

  @override
  String selfDestructSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count секунды',
      many: '$count секунд',
      few: '$count секунды',
      one: '$count секунда',
    );
    return '$_temp0';
  }

  @override
  String selfDestructMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count минуты',
      many: '$count минут',
      few: '$count минуты',
      one: '$count минута',
    );
    return '$_temp0';
  }

  @override
  String selfDestructHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count часа',
      many: '$count часов',
      few: '$count часа',
      one: '$count час',
    );
    return '$_temp0';
  }

  @override
  String selfDestructDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count дня',
      many: '$count дней',
      few: '$count дня',
      one: '$count день',
    );
    return '$_temp0';
  }

  @override
  String selfDestructWeeks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count недели',
      many: '$count недель',
      few: '$count недели',
      one: '$count неделя',
    );
    return '$_temp0';
  }

  @override
  String get allowSecretScreenshots =>
      'Разрешить снимки экрана в секретных чатах';

  @override
  String get allowSecretScreenshotsHint =>
      'Рискованно: собеседник ожидает, что секретный чат не попадёт в снимки и запись экрана';

  @override
  String get secretScreenshotsOff =>
      'По умолчанию секретные чаты не попадают в снимки экрана; на macOS 15 и новее — по возможности';

  @override
  String get selfDestructFailed =>
      'Не удалось изменить таймер самоуничтожения. Секретный чат ещё не готов или нет соединения.';

  @override
  String get stickersAndEmoji => 'Стикеры и эмодзи';

  @override
  String get largeEmoji => 'Большие эмодзи';

  @override
  String get largeEmojiHint =>
      'Сообщение из одного–трёх эмодзи показывается крупно.';

  @override
  String get loopStickers => 'Повторять анимацию стикеров';

  @override
  String get animatedEmoji => 'Анимированные эмодзи';

  @override
  String get myStickers => 'Мои стикеры';

  @override
  String get myEmoji => 'Мои эмодзи';

  @override
  String get customEmoji => 'Пользовательские эмодзи';

  @override
  String get trendingStickers => 'Популярные стикеры';

  @override
  String get trendingEmoji => 'Популярные эмодзи';

  @override
  String get archivedStickers => 'Архивные стикеры';

  @override
  String get archivedEmoji => 'Архивные эмодзи';

  @override
  String get stickerSetsHint =>
      'Перетащите, чтобы изменить порядок. Правый клик по набору — архивировать или удалить.';

  @override
  String get archiveSet => 'Архивировать';

  @override
  String get restoreSet => 'Восстановить';

  @override
  String get addSet => 'Добавить';

  @override
  String get addByLink => 'Добавить по ссылке';

  @override
  String get openSetLink => 'Открыть';

  @override
  String get stickerSetNotFound => 'По этой ссылке набора нет.';

  @override
  String get noArchivedSets => 'В архиве пусто';

  @override
  String get stickerSetLoadFailed => 'Не удалось загрузить наборы.';

  @override
  String stickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стикеров',
      few: '$count стикера',
      one: '$count стикер',
    );
    return '$_temp0';
  }

  @override
  String emojiCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count эмодзи',
    );
    return '$_temp0';
  }

  @override
  String get removeStickerSetTitle => 'Удалить набор стикеров?';

  @override
  String get removeEmojiSetTitle => 'Удалить набор эмодзи?';

  @override
  String get stickerSetLookupFailed =>
      'Не удалось открыть набор. Проверьте подключение и попробуйте ещё раз.';

  @override
  String get keyboardShortcuts => 'Сочетания клавиш';

  @override
  String get shortcutsSearch => 'Поиск сочетаний';

  @override
  String get shortcutsHint =>
      'Нажмите на сочетание, затем новые клавиши. Esc отменяет, Delete убирает сочетание.';

  @override
  String get shortcutsGroupApp => 'Приложение';

  @override
  String get shortcutsGroupChat => 'Чат';

  @override
  String get shortcutsGroupNavigation => 'Навигация';

  @override
  String get shortcutsGroupAccounts => 'Аккаунты';

  @override
  String get shortcutsGroupPlugins => 'Плагины';

  @override
  String get shortcutNone => 'Нет';

  @override
  String get shortcutRecording => 'Нажмите сочетание';

  @override
  String get shortcutChange => 'Изменить сочетание';

  @override
  String get shortcutNeedsModifier => 'Добавьте к клавише Ctrl или Alt';

  @override
  String get shortcutNeedsModifierMac => 'Добавьте к клавише ⌘, ⌃ или ⌥';

  @override
  String get shortcutReserved => 'Используется системой';

  @override
  String get shortcutReservedMac => 'Используется macOS';

  @override
  String shortcutUsedBy(String title) {
    return 'Уже используется: «$title»';
  }

  @override
  String get shortcutReplace => 'Заменить';

  @override
  String get shortcutRestore => 'Вернуть по умолчанию';

  @override
  String get shortcutsRestoreAll => 'Сбросить все';

  @override
  String get shortcutsRestoreAllTitle => 'Вернуть все сочетания по умолчанию?';

  @override
  String get shortcutsRestoreAllMessage =>
      'Все изменённые сочетания вернутся к исходным.';

  @override
  String get shortcutsRestoreConfirm => 'Вернуть';

  @override
  String get adminTitleHint => 'Должность (необязательно)';

  @override
  String get adminTitleNote => 'Показывается участникам вместо «админ».';

  @override
  String get permCreateTopics => 'Создавать темы';

  @override
  String get permissions => 'Разрешения';

  @override
  String get permissionsEveryone => 'Что могут участники';

  @override
  String get slowMode => 'Медленный режим';

  @override
  String get slowModeOffNote => 'Участники могут писать сколько угодно часто.';

  @override
  String slowModeNote(String interval) {
    return 'Участники могут отправлять одно сообщение раз в $interval.';
  }

  @override
  String get off => 'Выкл.';

  @override
  String secondsShort(int count) {
    return '$count с';
  }

  @override
  String minutesShort(int count) {
    return '$count мин';
  }

  @override
  String hoursShort(int count) {
    return '$count ч';
  }

  @override
  String get removedUsers => 'Удалённые пользователи';

  @override
  String get noRemovedUsers => 'Никто не заблокирован и не ограничен.';

  @override
  String get unban => 'Разблокировать';

  @override
  String get banned => 'Заблокирован';

  @override
  String bannedUntil(String until) {
    return 'Заблокирован $until';
  }

  @override
  String get restricted => 'Ограничен';

  @override
  String cannot(String what) {
    return 'Не может: $what';
  }

  @override
  String untilDate(String date) {
    return 'до $date';
  }

  @override
  String get joinRequests => 'Заявки на вступление';

  @override
  String get noJoinRequests => 'Никто не ждёт одобрения.';

  @override
  String requestedOn(String date) {
    return 'Подал заявку $date';
  }

  @override
  String get approve => 'Принять';

  @override
  String get dismiss => 'Отклонить';

  @override
  String get recentActions => 'Недавние действия';

  @override
  String get recentActionsFailed => 'Не удалось загрузить недавние действия.';

  @override
  String get noRecentActions => 'Недавних действий нет.';

  @override
  String get recentActionsNote => 'Действия за последние 48 часов.';

  @override
  String get allAdmins => 'Все админы';

  @override
  String get logMedia => 'медиа';

  @override
  String logEditedMessage(String text) {
    return 'изменил(а) сообщение: $text';
  }

  @override
  String logDeletedMessage(String text) {
    return 'удалил(а) сообщение: $text';
  }

  @override
  String logPinnedMessage(String text) {
    return 'закрепил(а) сообщение: $text';
  }

  @override
  String get logUnpinnedMessage => 'открепил(а) сообщение';

  @override
  String get logStoppedPoll => 'остановил(а) опрос';

  @override
  String get logJoined => 'вступил(а)';

  @override
  String logJoinedByLink(String link) {
    return 'вступил(а) по ссылке $link';
  }

  @override
  String logJoinedByRequest(String name) {
    return 'вступил(а), одобрил(а) $name';
  }

  @override
  String logInvited(String name) {
    return 'добавил(а) $name';
  }

  @override
  String get logLeft => 'вышел (вышла)';

  @override
  String logPromoted(String name) {
    return 'назначил(а) $name админом или изменил(а) права';
  }

  @override
  String logDemoted(String name) {
    return 'снял(а) $name с админов';
  }

  @override
  String logBanned(String name) {
    return 'заблокировал(а) $name';
  }

  @override
  String logRestricted(String name) {
    return 'ограничил(а) $name';
  }

  @override
  String logUnrestricted(String name) {
    return 'снял(а) ограничения с $name';
  }

  @override
  String logTitleChanged(String name, String title) {
    return 'дал(а) $name должность $title';
  }

  @override
  String logTitleSet(String title) {
    return 'переименовал(а) чат в $title';
  }

  @override
  String get logDescriptionChanged => 'изменил(а) описание';

  @override
  String get logPhotoChanged => 'изменил(а) фото';

  @override
  String get logPhotoRemoved => 'удалил(а) фото';

  @override
  String get logMadePrivate => 'сделал(а) чат частным';

  @override
  String logMadePublic(String username) {
    return 'сделал(а) чат публичным: t.me/$username';
  }

  @override
  String get logUsernamesChanged => 'изменил(а) ссылки';

  @override
  String get logPermissionsChanged => 'изменил(а) разрешения';

  @override
  String get logSlowModeOff => 'выключил(а) медленный режим';

  @override
  String logSlowModeOn(String interval) {
    return 'установил(а) медленный режим: $interval';
  }

  @override
  String get logLinked => 'привязал(а) чат';

  @override
  String get logUnlinked => 'отвязал(а) чат';

  @override
  String get logReactionsChanged => 'изменил(а) доступные реакции';

  @override
  String get logHistoryShown => 'открыл(а) историю новым участникам';

  @override
  String get logHistoryHidden => 'скрыл(а) историю от новых участников';

  @override
  String get logInvitesOn => 'разрешил(а) участникам приглашать других';

  @override
  String get logInvitesOff => 'запретил(а) участникам приглашать других';

  @override
  String get logSignaturesOn => 'включил(а) подписи';

  @override
  String get logSignaturesOff => 'выключил(а) подписи';

  @override
  String get logProtectedOn => 'запретил(а) пересылку';

  @override
  String get logProtectedOff => 'разрешил(а) пересылку';

  @override
  String logLinkEdited(String link) {
    return 'изменил(а) ссылку $link';
  }

  @override
  String logLinkRevoked(String link) {
    return 'отозвал(а) ссылку $link';
  }

  @override
  String logLinkDeleted(String link) {
    return 'удалил(а) ссылку $link';
  }

  @override
  String get logVideoChatStarted => 'начал(а) видеочат';

  @override
  String get logVideoChatEnded => 'завершил(а) видеочат';

  @override
  String get logTopicsOn => 'включил(а) темы';

  @override
  String get logTopicsOff => 'выключил(а) темы';

  @override
  String logTopicCreated(String name) {
    return 'создал(а) тему $name';
  }

  @override
  String logTopicEdited(String name) {
    return 'изменил(а) тему $name';
  }

  @override
  String logTopicDeleted(String name) {
    return 'удалил(а) тему $name';
  }

  @override
  String logTopicToggled(String name) {
    return 'закрыл(а) или открыл(а) тему $name';
  }

  @override
  String get logTopicPinned => 'закрепил(а) или открепил(а) тему';

  @override
  String get logStickerSetChanged => 'изменил(а) набор стикеров';

  @override
  String get logAutoDeleteChanged => 'изменил(а) таймер автоудаления';

  @override
  String get logOther => 'изменил(а) настройку';

  @override
  String get groupType => 'Тип группы';

  @override
  String get channelType => 'Тип канала';

  @override
  String get privateChat => 'Частный';

  @override
  String get publicChat => 'Публичный';

  @override
  String get privateGroupNote =>
      'Вступить могут только те, у кого есть ссылка-приглашение.';

  @override
  String get publicGroupNote =>
      'Группу можно найти в поиске, и вступить может любой.';

  @override
  String get privateChannelNote =>
      'Подписаться могут только те, у кого есть ссылка-приглашение.';

  @override
  String get publicChannelNote =>
      'Канал можно найти в поиске, и подписаться может любой.';

  @override
  String get usernameTaken => 'Ссылка уже занята.';

  @override
  String get usernameInvalid =>
      'От 5 до 32 латинских букв, цифр и подчёркиваний, начиная с буквы.';

  @override
  String get usernameTooMany =>
      'У вас слишком много публичных чатов. Сделайте один частным.';

  @override
  String usernameNotSet(String username) {
    return 'Канал создан, но t.me/$username занята. Выберите другую ссылку в его профиле.';
  }

  @override
  String get publicLinkOptional => 'публичная ссылка (необязательно)';

  @override
  String get reactions => 'Реакции';

  @override
  String get reactionsAll => 'Все';

  @override
  String get reactionsSome => 'Некоторые';

  @override
  String get reactionsNone => 'Нет';

  @override
  String get reactionsAllNote => 'Участники могут ставить любые эмодзи.';

  @override
  String get reactionsSomeNote =>
      'Участники могут ставить только выбранные здесь эмодзи.';

  @override
  String get reactionsNoneNote => 'Реакции на сообщения отключены.';

  @override
  String get discussionGroup => 'Группа обсуждения';

  @override
  String get linkedChannel => 'Привязанный канал';

  @override
  String get discussionGroupNote => 'Комментарии к постам идут в эту группу.';

  @override
  String get linkedChannelNote => 'В этой группе хранятся комментарии канала.';

  @override
  String get pickDiscussionGroup =>
      'Выберите свою группу для комментариев к постам.';

  @override
  String get noSuitableGroups =>
      'Нет группы для привязки. Сначала создайте её.';

  @override
  String get unlink => 'Отвязать';

  @override
  String get unlinkTitle => 'Отвязать?';

  @override
  String get unlinkGroupMessage =>
      'У постов не будет комментариев, пока не привязана другая группа.';

  @override
  String get unlinkChannelMessage =>
      'Группа больше не будет хранить комментарии канала.';

  @override
  String get addMembers => 'Добавить участников';

  @override
  String get addSubscribers => 'Добавить подписчиков';

  @override
  String get add => 'Добавить';

  @override
  String get editLink => 'Изменить ссылку';

  @override
  String get manage => 'Управление';

  @override
  String get historyForNewMembers => 'Показывать историю новым участникам';

  @override
  String get topics => 'Темы';

  @override
  String get approveNewMembers => 'Одобрять новых участников';

  @override
  String get none => 'Нет';

  @override
  String ofCount(int count, int total) {
    return '$count из $total';
  }

  @override
  String get chatLinkHint => 'ссылка';

  @override
  String get chatLinkAvailable => 'Ссылка свободна.';

  @override
  String get chatBackground => 'Фон чатов';

  @override
  String get chatBackgroundHint =>
      'Градиенты следуют теме. Своя картинка в тёмной теме слегка затемняется.';

  @override
  String get wallpaperMist => 'Туман';

  @override
  String get wallpaperSage => 'Шалфей';

  @override
  String get wallpaperLinen => 'Лён';

  @override
  String get wallpaperClassic => 'Классика';

  @override
  String get wallpaperOcean => 'Океан';

  @override
  String get wallpaperLavender => 'Лаванда';

  @override
  String get wallpaperSand => 'Песок';

  @override
  String get wallpaperGraphite => 'Графит';

  @override
  String get wallpaperPlain => 'Однотонный';

  @override
  String get wallpaperPicture => 'Картинка';

  @override
  String get choosePicture => 'Выбрать картинку…';

  @override
  String get changePicture => 'Сменить картинку…';

  @override
  String get blurPicture => 'Размыть картинку';

  @override
  String get nightSchedule => 'Тёмная тема по расписанию';

  @override
  String get nightScheduleHint =>
      'В эти часы включается тёмная тема, что бы ни было выбрано выше.';

  @override
  String get nightFrom => 'С';

  @override
  String get nightTo => 'До';

  @override
  String get blurTheme => 'Vesper Blur';

  @override
  String get blurThemeHint =>
      'Тёмное матовое окно, размывающее рабочий стол под ним. Пока включено, заменяет тему выше.';

  @override
  String get blurOpacity => 'Непрозрачность окна';

  @override
  String get layout => 'Вид';

  @override
  String get mediaCorners => 'Скругление медиа';

  @override
  String get cornerSmall => 'Малое';

  @override
  String get cornerMedium => 'Среднее';

  @override
  String get cornerLarge => 'Большое';

  @override
  String get compactLayout => 'Компактный вид';

  @override
  String get compactLayoutHint =>
      'Плотнее строки в списке чатов и меньше воздуха между сообщениями.';

  @override
  String get appIcon => 'Значок приложения';

  @override
  String get appIconHint =>
      'Значок в Dock, пока Mollygram запущен. В Finder остаётся тот, с которым приложение поставляется.';

  @override
  String get appIconCrimson => 'Малиновый';

  @override
  String get appIconBlue => 'Синий';

  @override
  String get appIconGraphite => 'Графит';

  @override
  String get downloads => 'Загрузки';

  @override
  String get downloadsEmpty => 'Загрузок нет';

  @override
  String get downloadsEmptyHint =>
      'Здесь появятся файлы, которые вы сохраняете из чатов.';

  @override
  String get pauseAll => 'Приостановить все';

  @override
  String get resumeAll => 'Продолжить все';

  @override
  String get resume => 'Продолжить';

  @override
  String get clearFinished => 'Убрать завершённые';

  @override
  String get removeFromList => 'Убрать из списка';

  @override
  String get downloadPaused => 'Приостановлено';

  @override
  String downloadProgress(String done, String total) {
    return '$done из $total';
  }

  @override
  String downloadsActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Загружается $count файла',
      many: 'Загружается $count файлов',
      few: 'Загружается $count файла',
      one: 'Загружается $count файл',
    );
    return '$_temp0';
  }

  @override
  String downloadsAllPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Приостановлены $count загрузки',
      many: 'Приостановлено $count загрузок',
      few: 'Приостановлены $count загрузки',
      one: 'Приостановлена $count загрузка',
    );
    return '$_temp0';
  }

  @override
  String downloadsFinished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Загружено $count файла',
      many: 'Загружено $count файлов',
      few: 'Загружено $count файла',
      one: 'Загружен $count файл',
    );
    return '$_temp0';
  }

  @override
  String translateTo(String language) {
    return 'Перевести на $language';
  }

  @override
  String translatedFrom(String language) {
    return 'Переведено с $language';
  }

  @override
  String get translated => 'Переведено';

  @override
  String get translating => 'Перевожу…';

  @override
  String get translateShowOriginal => 'Показать оригинал';

  @override
  String get translateOptions => 'Параметры перевода';

  @override
  String get translateChooseLanguage => 'Перевести на…';

  @override
  String translateSkipLanguage(String language) {
    return 'Не переводить $language';
  }

  @override
  String get translateHideBar => 'Скрыть';

  @override
  String get translateFailed => 'Не удалось перевести часть сообщений';
}
