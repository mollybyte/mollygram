import 'package:yaml/yaml.dart';

/// Какие сообщения плагин может читать.
enum MessagesScope {
  none,

  /// Только текущий чат и только во время команды, которую вызвал
  /// пользователь.
  onCommand,

  /// Только чаты, которые пользователь выбрал в настройках плагина.
  chats,

  /// Все чаты. На экране установки показывается отдельным предупреждением.
  all,
}

enum MediaKind { voice, round, photo, video, document }

/// Особый адрес в `net`: адрес, который пользователь вписал сам (например,
/// свой сервер модели). До этого сеть закрыта.
const userEndpoint = 'user_endpoint';

/// Максимум хранилища, который может попросить плагин.
const maxStorageBytes = 50 << 20;

/// Права из секции `permissions` манифеста. Неизвестное право делает
/// манифест невалидным: молча игнорировать его нельзя.
final class PermissionSet {
  const PermissionSet({
    this.messagesRead = MessagesScope.none,
    this.composerWrite = false,
    this.net = const {},
    this.storageBytes = 0,
    this.notificationsManage = false,
    this.mediaRead = const {},
  });

  static const none = PermissionSet();

  final MessagesScope messagesRead;
  final bool composerWrite;

  /// Точные имена хостов, только https. Маски и IP не принимаются.
  final Set<String> net;
  final int storageBytes;
  final bool notificationsManage;
  final Set<MediaKind> mediaRead;

  static final _host = RegExp(
    r'^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$',
  );
  static final _size = RegExp(r'^(\d+)\s*(kb|mb)$', caseSensitive: false);

  factory PermissionSet.parse(Object? raw) {
    if (raw == null) return none;
    if (raw is! YamlMap && raw is! Map) {
      throw const FormatException('permissions должен быть объектом');
    }
    final map = raw as Map;
    final errors = <String>[];
    var messages = MessagesScope.none;
    var composer = false;
    final net = <String>{};
    var storage = 0;
    var notifications = false;
    final media = <MediaKind>{};

    for (final MapEntry(:key, :value) in map.entries) {
      switch (key) {
        case 'messages.read':
          final scope = switch (value) {
            'on_command' => MessagesScope.onCommand,
            'chats[]' => MessagesScope.chats,
            'all' => MessagesScope.all,
            _ => null,
          };
          if (scope == null) {
            errors.add('messages.read: on_command, chats[] или all');
          } else {
            messages = scope;
          }
        case 'composer.write':
          if (value is! bool) errors.add('composer.write: true или false');
          composer = value == true;
        case 'notifications.manage':
          if (value is! bool) {
            errors.add('notifications.manage: true или false');
          }
          notifications = value == true;
        case 'net':
          if (value is! List) {
            errors.add('net должен быть списком хостов');
            break;
          }
          for (final h in value) {
            if (h is String && (h == userEndpoint || _host.hasMatch(h))) {
              net.add(h);
            } else {
              errors.add('net: "$h" не похоже на имя хоста');
            }
          }
        case 'storage':
          final m = value is String ? _size.firstMatch(value.trim()) : null;
          if (m == null) {
            errors.add('storage: размер вида 512kb или 5mb');
            break;
          }
          final n = int.parse(m[1]!);
          storage = m[2]!.toLowerCase() == 'kb' ? n << 10 : n << 20;
          if (storage > maxStorageBytes) {
            errors.add('storage: не больше ${maxStorageBytes >> 20}mb');
          }
        case 'media.read':
          if (value is! List) {
            errors.add('media.read должен быть списком типов');
            break;
          }
          for (final k in value) {
            final kind = MediaKind.values.asNameMap()[k];
            if (kind == null) {
              errors.add('media.read: неизвестный тип "$k"');
            } else {
              media.add(kind);
            }
          }
        default:
          errors.add('неизвестное право "$key"');
      }
    }
    if (errors.isNotEmpty) throw FormatException(errors.join('; '));
    return PermissionSet(
      messagesRead: messages,
      composerWrite: composer,
      net: Set.unmodifiable(net),
      storageBytes: storage,
      notificationsManage: notifications,
      mediaRead: Set.unmodifiable(media),
    );
  }

  /// Права, которых не было в [previous]. Если список не пуст, обновление
  /// плагина не включается, пока пользователь не согласится заново.
  List<String> escalationsFrom(PermissionSet previous) => [
    if (messagesRead.index > previous.messagesRead.index)
      'messages.read: ${messagesRead.name}',
    if (composerWrite && !previous.composerWrite) 'composer.write',
    for (final h in net.difference(previous.net)) 'net: $h',
    if (storageBytes > previous.storageBytes) 'storage',
    if (notificationsManage && !previous.notificationsManage)
      'notifications.manage',
    for (final k in mediaRead.difference(previous.mediaRead))
      'media.read: ${k.name}',
  ];

  /// Строки для блока «Доступ» на экране плагина.
  List<({String title, String detail})> describe() => [
    if (messagesRead != MessagesScope.none)
      switch (messagesRead) {
        MessagesScope.onCommand => (
          title: 'Сообщения текущего чата',
          detail: 'Только когда вы вызываете команду',
        ),
        MessagesScope.chats => (
          title: 'Сообщения выбранных чатов',
          detail: 'Список чатов задаёте вы',
        ),
        _ => (title: 'Все сообщения', detail: 'Во всех чатах'),
      },
    if (composerWrite)
      (title: 'Поле ввода', detail: 'Может вставлять и менять черновик'),
    if (net.isNotEmpty)
      (
        title: 'Сеть',
        detail: net
            .map((h) => h == userEndpoint ? 'адрес, который вы укажете' : h)
            .join(', '),
      ),
    if (storageBytes > 0)
      (title: 'Хранилище', detail: 'До ${_formatSize(storageBytes)}'),
    if (notificationsManage)
      (title: 'Уведомления', detail: 'Откладывать и группировать'),
    if (mediaRead.isNotEmpty)
      (title: 'Медиа', detail: mediaRead.map((k) => _mediaNames[k]).join(', ')),
  ];

  static const _mediaNames = {
    MediaKind.voice: 'голосовые',
    MediaKind.round: 'кружки',
    MediaKind.photo: 'фото',
    MediaKind.video: 'видео',
    MediaKind.document: 'файлы',
  };

  static String _formatSize(int bytes) =>
      bytes >= 1 << 20 ? '${bytes >> 20} МБ' : '${bytes >> 10} КБ';
}

/// Событие, на которое плагин может подписаться через `mg.on`.
enum PluginEvent {
  appReady('app.ready', EventKind.observe),
  chatOpened('chat.opened', EventKind.observe),
  messageIncoming('message.incoming', EventKind.observe),
  messageEdited('message.edited', EventKind.observe),
  messageDeleted('message.deleted', EventKind.observe),

  /// Перехват отправки: можно изменить текст или отменить отправку.
  messageSending('message.sending', EventKind.intercept),

  /// Отрисовка дополнительного блока под сообщением. Плагин получает только
  /// свой фрагмент (блок кода, голосовое), а возвращает декларативный UI.
  messageRenderCode('message.render.code', EventKind.render),
  messageRenderVoice('message.render.voice', EventKind.render),
  messageRenderRound('message.render.round', EventKind.render),

  /// Нажатие на кнопку, которую нарисовал сам плагин.
  uiAction('ui.action', EventKind.render),
  notificationIncoming('notification.incoming', EventKind.intercept),
  settingsChanged('settings.changed', EventKind.observe);

  const PluginEvent(this.id, this.kind);

  final String id;
  final EventKind kind;

  static final byName = {for (final e in values) e.id: e};

  /// Какого права не хватает для подписки, или null, если хватает.
  String? requires(PermissionSet p) => switch (this) {
    chatOpened || messageIncoming || messageEdited || messageDeleted
        when p.messagesRead == MessagesScope.none ||
            p.messagesRead == MessagesScope.onCommand =>
      'messages.read: chats[] или all',
    messageSending when !p.composerWrite => 'composer.write',
    messageRenderVoice when !p.mediaRead.contains(MediaKind.voice) =>
      'media.read: [voice]',
    messageRenderRound when !p.mediaRead.contains(MediaKind.round) =>
      'media.read: [round]',
    notificationIncoming when !p.notificationsManage => 'notifications.manage',
    _ => null,
  };
}

enum EventKind {
  /// Только наблюдение, результат игнорируется.
  observe,

  /// Результат `{cancel: true}` или `{modify: ...}` меняет действие.
  intercept,

  /// Результат: список узлов декларативного UI.
  render,
}
