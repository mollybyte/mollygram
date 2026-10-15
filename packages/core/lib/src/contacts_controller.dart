import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// When a user was last online, as precisely as their privacy settings
/// let Telegram say.
enum PresenceKind {
  online,

  /// Seen at [Presence.wasOnline].
  offline,
  recently,
  lastWeek,
  lastMonth,

  /// A long time ago, or never shown (bots, deleted accounts).
  unknown,
}

final class Presence {
  const Presence(this.kind, {this.wasOnline});

  static const unknown = Presence(PresenceKind.unknown);

  final PresenceKind kind;

  /// For [PresenceKind.offline]: when the user was last online.
  final DateTime? wasOnline;

  factory Presence.from(td.UserStatus status) => switch (status) {
    td.UserStatusOnline() => const Presence(PresenceKind.online),
    td.UserStatusOffline(:final wasOnline) => Presence(
      PresenceKind.offline,
      wasOnline: DateTime.fromMillisecondsSinceEpoch(wasOnline * 1000),
    ),
    td.UserStatusRecently() => const Presence(PresenceKind.recently),
    td.UserStatusLastWeek() => const Presence(PresenceKind.lastWeek),
    td.UserStatusLastMonth() => const Presence(PresenceKind.lastMonth),
    _ => unknown,
  };

  @override
  bool operator ==(Object other) =>
      other is Presence && other.kind == kind && other.wasOnline == wasOnline;

  @override
  int get hashCode => Object.hash(kind, wasOnline);
}

/// A Telegram user as the contacts list and the new message picker show
/// them. The user's private chat has the same id.
final class ContactUser {
  const ContactUser({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.username = '',
    this.phoneNumber = '',
    this.presence = Presence.unknown,
    this.isContact = false,
    this.isBot = false,
  });

  final int id;
  final String firstName;
  final String lastName;

  /// The first active username, without "@"; empty when there is none.
  final String username;

  /// Digits only, as TDLib gives them; empty when hidden.
  final String phoneNumber;
  final Presence presence;
  final bool isContact;
  final bool isBot;

  String get name => lastName.isEmpty ? firstName : '$firstName $lastName';

  factory ContactUser.from(td.User user) => ContactUser(
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    username: user.usernames?.activeUsernames.firstOrNull ?? '',
    phoneNumber: user.phoneNumber,
    presence: Presence.from(user.status),
    isContact: user.isContact,
    isBot: user.type is td.UserTypeBot,
  );

  ContactUser withPresence(Presence presence) => ContactUser(
    id: id,
    firstName: firstName,
    lastName: lastName,
    username: username,
    phoneNumber: phoneNumber,
    presence: presence,
    isContact: isContact,
    isBot: isBot,
  );
}

/// The result of adding a contact by phone number.
sealed class AddContactResult {
  const AddContactResult();
}

final class ContactAdded extends AddContactResult {
  const ContactAdded(this.userId);

  final int userId;
}

/// Nobody uses Telegram with that phone number.
final class NotOnTelegram extends AddContactResult {
  const NotOnTelegram();
}

/// The user's contacts and the users TDLib has told the app about, kept
/// current through `updateUser` and `updateUserStatus`.
final class ContactsController {
  ContactsController(this._client);

  final td.TdClient _client;
  final _users = <int, ContactUser>{};
  final _contacts = <int>{};
  final _changes = StreamController<void>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  Future<void>? _loading;

  /// Fires when a user or the contact list changes.
  Stream<void> get changes => _changes.stream;

  /// Whether [load] has completed once.
  bool get isLoaded => _loaded;
  var _loaded = false;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  /// A user TDLib has sent, or null when the app hasn't seen them.
  ContactUser? user(int id) => _users[id];

  /// The contacts, sorted by name.
  List<ContactUser> get contacts =>
      [for (final id in _contacts) ?_users[id]]
        ..sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));

  /// Asks TDLib for the contact list. Repeated calls share the request.
  Future<void> load() => _loading ??= _load().whenComplete(() {
    _loading = null;
  });

  Future<void> _load() async {
    final users = await _client.send(const td.GetContacts());
    await _ensureUsers(users.userIds);
    _contacts
      ..clear()
      ..addAll(users.userIds);
    _loaded = true;
    _emit();
  }

  /// Contacts whose name or username matches [query], as TDLib ranks them.
  Future<List<ContactUser>> search(String query, {int limit = 30}) async {
    final text = query.trim();
    if (text.isEmpty) return contacts;
    final users = await _client.send(
      td.SearchContacts(query: text, limit: limit),
    );
    await _ensureUsers(users.userIds);
    return [for (final id in users.userIds) ?_users[id]];
  }

  /// Public chats, channels and users whose username matches [query].
  /// Fails quietly offline.
  Future<List<int>> searchPublic(String query) async {
    final text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final chats = await _client.send(td.SearchPublicChats(query: text));
      return chats.chatIds;
    } on td.TdException {
      return const [];
    }
  }

  /// The id of the private chat with [userId], creating it if needed.
  Future<int> privateChat(int userId) async =>
      (await _client.send(td.CreatePrivateChat(userId: userId, force: false)))
          .id;

  /// Adds a contact by phone number.
  Future<AddContactResult> add({
    required String phoneNumber,
    required String firstName,
    String lastName = '',
  }) async {
    final imported = await _client.send(
      td.ImportContacts(
        contacts: [
          td.ImportedContact(
            phoneNumber: phoneNumber,
            firstName: firstName,
            lastName: lastName,
          ),
        ],
      ),
    );
    final userId = imported.userIds.firstOrNull ?? 0;
    if (userId == 0) return const NotOnTelegram();
    await _ensureUsers([userId]);
    if (_contacts.add(userId)) _emit();
    return ContactAdded(userId);
  }

  Future<void> remove(int userId) async {
    await _client.send(td.RemoveContacts(userIds: [userId]));
    if (_contacts.remove(userId)) _emit();
  }

  Future<void> _ensureUsers(List<int> ids) async {
    final missing = [
      for (final id in ids)
        if (!_users.containsKey(id)) id,
    ];
    final users = await Future.wait([
      for (final id in missing)
        _client
            .send(td.GetUser(userId: id))
            .then<td.User?>((user) => user)
            .catchError((Object _) => null, test: (e) => e is td.TdException),
    ]);
    for (final user in users) {
      if (user != null) _users[user.id] = ContactUser.from(user);
    }
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateUser(:final user):
        final contact = ContactUser.from(user);
        _users[user.id] = contact;
        // Adding and removing contacts elsewhere arrives here too.
        if (_loaded) {
          contact.isContact
              ? _contacts.add(user.id)
              : _contacts.remove(user.id);
        }
        _emit();
      case td.UpdateUserStatus(:final userId, :final status):
        final user = _users[userId];
        if (user == null) return;
        _users[userId] = user.withPresence(Presence.from(status));
        _emit();
      default:
    }
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}

String _sortKey(ContactUser user) => user.name.toLowerCase();
