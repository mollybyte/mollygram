import 'package:plugin_host/plugin_host.dart';

import 'controller.dart';

/// Texts of the plugins screen in English and Russian.
///
/// Third-party plugins show their manifest texts as is; our own plugins are
/// translated here by id.
final class PluginsStrings {
  const PluginsStrings._(this.locale);

  final String locale;

  static const en = PluginsStrings._('en');
  static const ru = PluginsStrings._('ru');

  static PluginsStrings forLocale(String code) => code == 'ru' ? ru : en;

  bool get _ru => locale == 'ru';
  String _t(String en, String ru) => _ru ? ru : en;

  String get pluginList => _t('Plugin list', 'Список плагинов');
  String get search => _t('Search', 'Поиск');
  String get searchPlugins => _t('Search plugins', 'Поиск плагинов');
  String get installFromFile =>
      _t('Install from file…', 'Установить из файла…');
  String get enablePlugin => _t('Enable plugin', 'Включить плагин');
  String get install => _t('Install', 'Установить');
  String get access => _t('Access', 'Доступ');
  String get options => _t('Options', 'Параметры');
  String get commands => _t('Commands', 'Команды');
  String get manifest => _t('Manifest', 'Манифест');
  String get log => _t('Log', 'Журнал');
  String get logEmpty => _t(
    'Nothing logged since the app started.',
    'С запуска приложения записей нет.',
  );
  String get copyLog => _t('Copy', 'Скопировать');
  String get uninstall => _t('Uninstall plugin…', 'Удалить плагин…');
  String get off => _t('off', 'выкл');
  String get installedGroup => _t('Installed', 'Установленные');
  String get availableGroup => _t('Available', 'Доступно');
  String get builtIn => _t('Built-in plugin', 'Встроенный плагин');
  String get noAccess =>
      _t('No access to your data', 'Нет доступа к вашим данным');
  String get noResults => _t('No plugins found', 'Плагины не найдены');
  String get cancel => _t('Cancel', 'Отменить');
  String get allow => _t('Allow', 'Разрешить');
  String get update => _t('Update', 'Обновить');
  String get review => _t('Review…', 'Посмотреть…');
  String get canAccess =>
      _t('It will be able to use:', 'Плагин получит доступ:');
  String get newAccess =>
      _t('New access in this version:', 'Новый доступ в этой версии:');

  String get uninstallConfirm => _t('Uninstall', 'Удалить');
  String get uninstallMessage => _t(
    'Its settings are removed with it.',
    'Его настройки будут удалены вместе с ним.',
  );
  String uninstallTitle(String name) =>
      _t('Uninstall “$name”?', 'Удалить «$name»?');

  /// Why a picked file was not offered for install.
  String installFailed(InstallFailure f) => switch (f.problem) {
    InstallProblem.invalid => _t(
      'This is not a valid plugin: ${f.details.join('; ')}',
      'Это не плагин или он повреждён: ${f.details.join('; ')}',
    ),
    InstallProblem.older => _t(
      'A newer version of this plugin is already installed.',
      'Уже установлена более новая версия этого плагина.',
    ),
    InstallProblem.sameVersion => _t(
      'This version is already installed.',
      'Эта версия уже установлена.',
    ),
    InstallProblem.notSaved => _t(
      'Could not install the plugin: ${f.details.join('; ')}',
      'Не удалось установить плагин: ${f.details.join('; ')}',
    ),
    InstallProblem.builtIn => _t(
      'This plugin uses the id of a built-in plugin.',
      'Этот плагин использует идентификатор встроенного плагина.',
    ),
  };

  String updated(String when) => _t('Updated $when', 'Обновлён $when');
  String installTitle(String name) =>
      _t('Install “$name”?', 'Установить «$name»?');
  String updateTitle(String name, String version) => _t(
    '“$name” $version asks for more access',
    '«$name» $version просит больше доступа',
  );
  String updateAvailable(String version) => _t(
    'Version $version asks for more access',
    'Версия $version просит больше доступа',
  );
  String allMessagesWarning(String author) => _t(
    'This plugin can read all your messages. Install it only if you trust '
        '$author.',
    'Плагин сможет читать все ваши сообщения. Устанавливайте, только если '
        'доверяете $author.',
  );
  String disabled(String reason) =>
      _t('Turned off after errors: $reason', 'Выключен из-за ошибок: $reason');

  /// "3 days ago", "вчера".
  String ago(DateTime then, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(then.year, then.month, then.day)).inDays;
    if (days <= 0) return _t('today', 'сегодня');
    if (days == 1) return _t('yesterday', 'вчера');
    if (days < 7) {
      return _t(
        '$days days ago',
        '$days ${_plural(days, 'день', 'дня', 'дней')} назад',
      );
    }
    if (days < 30) {
      final w = days ~/ 7;
      return _t(
        w == 1 ? 'a week ago' : '$w weeks ago',
        w == 1 ? 'неделю назад' : '$w нед. назад',
      );
    }
    final m = days ~/ 30;
    if (m < 12) {
      return _t(
        m == 1 ? 'a month ago' : '$m months ago',
        m == 1 ? 'месяц назад' : '$m мес. назад',
      );
    }
    final y = days ~/ 365;
    return _t(
      y <= 1 ? 'a year ago' : '$y years ago',
      y <= 1 ? 'год назад' : '$y ${_plural(y, 'год', 'года', 'лет')} назад',
    );
  }

  static String _plural(int n, String one, String few, String many) {
    final d10 = n % 10, d100 = n % 100;
    if (d10 == 1 && d100 != 11) return one;
    if (d10 >= 2 && d10 <= 4 && (d100 < 12 || d100 > 14)) return few;
    return many;
  }

  /// Rows of the "Access" section: what a plugin can reach.
  List<AccessRow> accessRows(PermissionSet p, {List<String> hooks = const []}) {
    return [
      if (p.messagesRead != MessagesScope.none)
        switch (p.messagesRead) {
          MessagesScope.onCommand => AccessRow(
            AccessIcon.messages,
            _t('Messages in the current chat', 'Сообщения текущего чата'),
            _t(
              'Only when you run a command',
              'Только когда вы вызываете команду',
            ),
          ),
          MessagesScope.chats => AccessRow(
            AccessIcon.messages,
            _t('Messages in selected chats', 'Сообщения выбранных чатов'),
            _t('You choose the chats', 'Список чатов задаёте вы'),
          ),
          _ => AccessRow(
            AccessIcon.messages,
            _t('All messages', 'Все сообщения'),
            _t('In all chats', 'Во всех чатах'),
            warning: true,
          ),
        },
      if (p.composerWrite)
        AccessRow(
          AccessIcon.composer,
          _t('Composer', 'Поле ввода'),
          _t(
            'Can insert text and change the draft before sending',
            'Может вставлять текст и менять черновик перед отправкой',
          ),
        ),
      if (p.net.isNotEmpty)
        AccessRow(
          AccessIcon.network,
          _t('Network', 'Сеть'),
          [
            for (final (i, h) in p.net.indexed)
              h != userEndpoint
                  ? h
                  : i == 0
                  ? _t('An address you provide', 'Адрес, который вы укажете')
                  : _t('an address you provide', 'адрес, который вы укажете'),
          ].join(', '),
        ),
      if (p.storageBytes > 0)
        AccessRow(
          AccessIcon.storage,
          _t('Storage', 'Хранилище'),
          _t('Up to ${_size(p.storageBytes)}', 'До ${_size(p.storageBytes)}'),
        ),
      if (p.notificationsManage)
        AccessRow(
          AccessIcon.notifications,
          _t('Notifications', 'Уведомления'),
          _t('Defer and group', 'Откладывать и группировать'),
        ),
      if (p.mediaRead.isNotEmpty)
        AccessRow(
          AccessIcon.media,
          _t('Media', 'Медиа'),
          _capitalize(
            [
              for (final k in MediaKind.values)
                if (p.mediaRead.contains(k)) _media(k),
            ].join(', '),
          ),
        ),
      if (hooks.contains(PluginEvent.messageRenderCode.id))
        AccessRow(
          AccessIcon.render,
          _t('Message rendering', 'Отображение сообщений'),
          _t('Code blocks only', 'Только блоки кода'),
        ),
    ];
  }

  String _media(MediaKind k) => switch (k) {
    MediaKind.voice => _t('voice messages', 'голосовые'),
    MediaKind.round => _t('round videos', 'кружки'),
    MediaKind.photo => _t('photos', 'фото'),
    MediaKind.video => _t('videos', 'видео'),
    MediaKind.document => _t('files', 'файлы'),
  };

  String _size(int bytes) => bytes >= 1 << 20
      ? '${bytes >> 20} ${_t('MB', 'МБ')}'
      : '${bytes >> 10} ${_t('KB', 'КБ')}';

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// The name, description and setting labels of one of our plugins in the
  /// current language, or null to show the manifest texts.
  PluginTexts? ownPlugin(String id) => _ru ? _ruPlugins[id] : null;
}

enum AccessIcon {
  messages,
  composer,
  network,
  storage,
  notifications,
  media,
  render,
}

final class AccessRow {
  const AccessRow(this.icon, this.title, this.detail, {this.warning = false});

  final AccessIcon icon;
  final String title;
  final String detail;

  /// Shown with a warning at install time: access to all messages.
  final bool warning;
}

/// Translated texts of a plugin: labels are keyed by setting key, options by
/// `key.value`.
final class PluginTexts {
  const PluginTexts({
    required this.name,
    required this.description,
    this.labels = const {},
  });

  final String name;
  final String description;
  final Map<String, String> labels;
}

const _ruPlugins = {
  'dev.mollygram.filters': PluginTexts(
    name: 'Фильтры',
    description:
        'Сворачивает или скрывает рекламу и сообщения с вашими ключевыми '
        'словами. Сообщения проверяются на устройстве и никуда не '
        'отправляются.',
    labels: {
      'ads': 'Фильтровать рекламу',
      'keywords': 'Ключевые слова через запятую',
      'mode': 'Отфильтрованные сообщения',
      'mode.collapse': 'Сворачивать',
      'mode.hide': 'Скрывать',
    },
  ),
  'dev.mollygram.codehighlight': PluginTexts(
    name: 'Подсветка кода',
    description:
        'Раскрашивает блоки кода в сообщениях по синтаксису. Работает на '
        'устройстве и не получает доступа к сообщениям, сети или хранилищу.',
  ),
  'dev.mollygram.transcribe': PluginTexts(
    name: 'Расшифровка',
    description:
        'Расшифровывает голосовые и кружки на устройстве, без сети и без '
        'Premium.',
    labels: {
      'auto': 'Расшифровывать автоматически',
      'language': 'Язык',
      'language.auto': 'Определять автоматически',
      'language.ru': 'Русский',
      'language.en': 'Английский',
    },
  ),
};
