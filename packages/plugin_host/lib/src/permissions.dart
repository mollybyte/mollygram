import 'package:yaml/yaml.dart';

/// Which messages a plugin can read.
enum MessagesScope {
  none,

  /// Only the current chat, and only during a command the user invoked.
  onCommand,

  /// Only the chats the user selected in the plugin settings.
  chats,

  /// All chats.
  ///
  /// The install screen shows a separate warning for this scope.
  all,
}

enum MediaKind { voice, round, photo, video, document }

/// A special `net` entry for an address the user enters themselves (for
/// example, their own model server). Until then, the network is closed.
const userEndpoint = 'user_endpoint';

/// The maximum storage a plugin can request.
const maxStorageBytes = 50 << 20;

/// Permissions from the manifest's `permissions` section.
///
/// An unknown permission makes the manifest invalid: it must never be
/// silently ignored.
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

  /// Exact host names, https only. Wildcards and IPs are not accepted.
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
      throw const FormatException('permissions must be an object');
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
            errors.add('messages.read: on_command, chats[] or all');
          } else {
            messages = scope;
          }
        case 'composer.write':
          if (value is! bool) errors.add('composer.write: true or false');
          composer = value == true;
        case 'notifications.manage':
          if (value is! bool) {
            errors.add('notifications.manage: true or false');
          }
          notifications = value == true;
        case 'net':
          if (value is! List) {
            errors.add('net must be a list of hosts');
            break;
          }
          for (final h in value) {
            if (h is String && (h == userEndpoint || _host.hasMatch(h))) {
              net.add(h);
            } else {
              errors.add('net: "$h" does not look like a host name');
            }
          }
        case 'storage':
          final m = value is String ? _size.firstMatch(value.trim()) : null;
          if (m == null) {
            errors.add('storage: a size like 512kb or 5mb');
            break;
          }
          final n = int.parse(m[1]!);
          storage = m[2]!.toLowerCase() == 'kb' ? n << 10 : n << 20;
          if (storage > maxStorageBytes) {
            errors.add('storage: at most ${maxStorageBytes >> 20}mb');
          }
        case 'media.read':
          if (value is! List) {
            errors.add('media.read must be a list of kinds');
            break;
          }
          for (final k in value) {
            final kind = MediaKind.values.asNameMap()[k];
            if (kind == null) {
              errors.add('media.read: unknown kind "$k"');
            } else {
              media.add(kind);
            }
          }
        default:
          errors.add('unknown permission "$key"');
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

  /// Returns the permissions that were not in [previous].
  ///
  /// If the list is not empty, the plugin update stays disabled until the
  /// user consents again.
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

  /// Returns the rows for the "Access" section of the plugin screen.
  List<({String title, String detail})> describe() => [
    if (messagesRead != MessagesScope.none)
      switch (messagesRead) {
        MessagesScope.onCommand => (
          title: 'Messages in the current chat',
          detail: 'Only when you run a command',
        ),
        MessagesScope.chats => (
          title: 'Messages in selected chats',
          detail: 'You choose the chats',
        ),
        _ => (title: 'All messages', detail: 'In all chats'),
      },
    if (composerWrite)
      (title: 'Composer', detail: 'Can insert and change the draft'),
    if (net.isNotEmpty)
      (
        title: 'Network',
        detail: net
            .map((h) => h == userEndpoint ? 'an address you provide' : h)
            .join(', '),
      ),
    if (storageBytes > 0)
      (title: 'Storage', detail: 'Up to ${_formatSize(storageBytes)}'),
    if (notificationsManage)
      (title: 'Notifications', detail: 'Defer and group'),
    if (mediaRead.isNotEmpty)
      (title: 'Media', detail: mediaRead.map((k) => _mediaNames[k]).join(', ')),
  ];

  static const _mediaNames = {
    MediaKind.voice: 'voice messages',
    MediaKind.round: 'round videos',
    MediaKind.photo: 'photos',
    MediaKind.video: 'videos',
    MediaKind.document: 'files',
  };

  static String _formatSize(int bytes) =>
      bytes >= 1 << 20 ? '${bytes >> 20} MB' : '${bytes >> 10} KB';
}

/// An event a plugin can subscribe to with `mg.on`.
enum PluginEvent {
  appReady('app.ready', EventKind.observe),
  chatOpened('chat.opened', EventKind.observe),
  messageIncoming('message.incoming', EventKind.observe),
  messageEdited('message.edited', EventKind.observe),
  messageDeleted('message.deleted', EventKind.observe),

  /// Intercepts sending: the plugin can change the text or cancel it.
  messageSending('message.sending', EventKind.intercept),

  /// Renders an extra block below a message.
  ///
  /// The plugin receives only its own fragment (a code block, a voice
  /// message) and returns declarative UI.
  messageRenderCode('message.render.code', EventKind.render),
  messageRenderVoice('message.render.voice', EventKind.render),
  messageRenderRound('message.render.round', EventKind.render),

  /// A tap on a button the plugin rendered itself.
  uiAction('ui.action', EventKind.render),
  notificationIncoming('notification.incoming', EventKind.intercept),
  settingsChanged('settings.changed', EventKind.observe);

  const PluginEvent(this.id, this.kind);

  final String id;
  final EventKind kind;

  static final byName = {for (final e in values) e.id: e};

  /// Returns the permission missing for a subscription, or null if none.
  String? requires(PermissionSet p) => switch (this) {
    chatOpened || messageIncoming || messageEdited || messageDeleted
        when p.messagesRead == MessagesScope.none ||
            p.messagesRead == MessagesScope.onCommand =>
      'messages.read: chats[] or all',
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
  /// Observation only; the result is ignored.
  observe,

  /// A `{cancel: true}` or `{modify: ...}` result changes the action.
  intercept,

  /// The result is a list of declarative UI nodes.
  render,
}
