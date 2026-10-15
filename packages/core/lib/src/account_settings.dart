import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The signed-in user as the settings show it.
final class AccountProfile {
  const AccountProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.phoneNumber,
    required this.bio,
    required this.isPremium,
    this.photo,
    int? bioLimit,
  }) : bioLimit = bioLimit ?? (isPremium ? 140 : 70);

  final int userId;
  final String firstName;
  final String lastName;

  /// The editable username without the @; empty when none is set.
  final String username;

  /// Digits only, without the leading +.
  final String phoneNumber;
  final String bio;
  final bool isPremium;

  /// The small profile photo, when there is one.
  final td.File? photo;

  String get name => [firstName, lastName].where((s) => s.isNotEmpty).join(' ');

  /// Telegram's limit for [bio], in characters: the `bio_length_max`
  /// option, or the usual 70 (140 with Premium) when TDLib has none.
  final int bioLimit;
}

/// Why a username can't be used, found before asking Telegram.
enum UsernameIssue {
  tooShort,
  tooLong,
  invalidCharacter,
  startsWithLetter,
  endsWithUnderscore,
}

/// Telegram's answer about a username the user typed.
enum UsernameAvailability {
  available,
  invalid,
  occupied,
  purchasable,
  unavailable,
}

/// What Telegram allows in a username: 5 to 32 Latin letters, digits and
/// underscores, starting with a letter and not ending with an underscore.
/// An empty username is fine: it removes the username. Returns null when
/// the username can be sent to Telegram.
UsernameIssue? usernameIssue(String username) {
  if (username.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z0-9_]*$').hasMatch(username)) {
    return UsernameIssue.invalidCharacter;
  }
  if (!RegExp('^[A-Za-z]').hasMatch(username)) {
    return UsernameIssue.startsWithLetter;
  }
  if (username.length < 5) return UsernameIssue.tooShort;
  if (username.length > 32) return UsernameIssue.tooLong;
  if (username.endsWith('_')) return UsernameIssue.endsWithUnderscore;
  return null;
}

/// A business bot that can act for the account.
final class ConnectedBot {
  const ConnectedBot({
    required this.userId,
    required this.name,
    required this.username,
    this.photo,
  });

  final int userId;
  final String name;

  /// The bot's small profile photo, if it has one.
  final td.File? photo;

  /// Without the @; empty when the bot has none.
  final String username;
}

/// One device or app signed in to the account.
final class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.isCurrent,
    required this.application,
    required this.device,
    required this.location,
    required this.lastActiveDate,
    this.isUnconfirmed = false,
  });

  factory ActiveSession.from(td.Session session) {
    String join(Iterable<String> parts) =>
        parts.map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    return ActiveSession(
      id: session.id,
      isCurrent: session.isCurrent,
      application: join([session.applicationName, session.applicationVersion]),
      device: [
        session.deviceModel.trim(),
        join([session.platform, session.systemVersion]),
      ].where((s) => s.isNotEmpty).join(', '),
      location: session.location,
      lastActiveDate: session.lastActiveDate,
      isUnconfirmed: session.isUnconfirmed,
    );
  }

  final int id;
  final bool isCurrent;

  /// The app name and version, such as "Telegram iOS 11.2".
  final String application;

  /// The device model and system, such as "iPhone 15, iOS 18.1".
  final String device;

  /// Where the session was signed in from, by IP address.
  final String location;

  /// Unix seconds.
  final int lastActiveDate;

  /// A new sign-in that hasn't been confirmed from another session yet.
  final bool isUnconfirmed;
}

/// The account part of the settings: the user's own profile, the devices
/// signed in to the account and signing out.
final class AccountSettings {
  AccountSettings(this._client);

  final td.TdClient _client;

  Future<AccountProfile> profile() async {
    final me = await _client.send(const td.GetMe());
    final full = await _client.send(td.GetUserFullInfo(userId: me.id));
    int? bioLimit;
    try {
      final option = await _client.send(
        const td.GetOption(name: 'bio_length_max'),
      );
      if (option is td.OptionValueInteger && option.value > 0) {
        bioLimit = option.value;
      }
    } on td.TdException {
      // Missing option: the usual limit applies.
    }
    return AccountProfile(
      userId: me.id,
      firstName: me.firstName,
      lastName: me.lastName,
      username: me.usernames?.editableUsername ?? '',
      phoneNumber: me.phoneNumber,
      bio: full.bio?.text ?? '',
      isPremium: me.isPremium,
      photo: me.profilePhoto?.small,
      bioLimit: bioLimit,
    );
  }

  Future<void> setName(String firstName, String lastName) => _client.send(
    td.SetName(firstName: firstName.trim(), lastName: lastName.trim()),
  );

  Future<void> setBio(String bio) => _client.send(td.SetBio(bio: bio.trim()));

  /// Sets the editable username; an empty one removes it.
  Future<void> setUsername(String username) =>
      _client.send(td.SetUsername(username: username));

  /// Asks Telegram whether [username] is free for the user with [userId].
  /// The user's own private chat has the user's id.
  Future<UsernameAvailability> checkUsername(
    int userId,
    String username,
  ) async {
    final result = await _client.send(
      td.CheckChatUsername(chatId: userId, username: username),
    );
    return switch (result) {
      td.CheckChatUsernameResultOk() => UsernameAvailability.available,
      td.CheckChatUsernameResultUsernameInvalid() =>
        UsernameAvailability.invalid,
      td.CheckChatUsernameResultUsernameOccupied() =>
        UsernameAvailability.occupied,
      td.CheckChatUsernameResultUsernamePurchasable() =>
        UsernameAvailability.purchasable,
      _ => UsernameAvailability.unavailable,
    };
  }

  /// Every signed-in session in TDLib's order, which the apps are asked
  /// to keep; this session is moved to the top if it isn't there already.
  Future<List<ActiveSession>> activeSessions() async {
    final result = await _client.send(const td.GetActiveSessions());
    final sessions = [for (final s in result.sessions) ActiveSession.from(s)];
    return [
      ...sessions.where((s) => s.isCurrent),
      ...sessions.where((s) => !s.isCurrent),
    ];
  }

  /// The business bot connected to the account, or null when there is
  /// none. TDLib asks apps to show it with the active sessions.
  Future<ConnectedBot?> connectedBot() async {
    final td.BusinessConnectedBotInfo info;
    try {
      info = await _client.send(const td.GetBusinessConnectedBot());
    } on td.TdException catch (e) {
      // Only "not found" means no bot; anything else is a failure to load.
      if (e.code == 404) return null;
      rethrow;
    }
    final id = info.bot.botUserId;
    final user = await _client.send(td.GetUser(userId: id));
    return ConnectedBot(
      userId: id,
      name: [
        user.firstName,
        user.lastName,
      ].where((s) => s.isNotEmpty).join(' '),
      username: user.usernames?.activeUsernames.firstOrNull ?? '',
      photo: user.profilePhoto?.small,
    );
  }

  Future<void> disconnectBot(int botUserId) =>
      _client.send(td.DeleteBusinessConnectedBot(botUserId: botUserId));

  Future<void> terminateSession(int id) =>
      _client.send(td.TerminateSession(sessionId: id));

  Future<void> terminateOtherSessions() =>
      _client.send(const td.TerminateAllOtherSessions());
}
