import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A group member offered for an @mention.
final class MentionCandidate {
  const MentionCandidate({
    required this.userId,
    required this.name,
    this.username = '',
    this.photo,
  });

  final int userId;
  final String name;

  /// Without the @; empty when the user has none, and the mention then
  /// links the name to [userId].
  final String username;
  final td.File? photo;
}

/// Finds the members of a group who can be mentioned, the way the official
/// clients complete an @: TDLib's mention filter ranks recent speakers
/// first and matches names and usernames.
final class MentionSearch {
  MentionSearch(this._client);

  final td.TdClient _client;

  StreamSubscription<td.TdObject>? _subscription;

  /// The signed-in user, who is never offered.
  int? _myId;

  /// Listens for the signed-in user's id, which TDLib sends at start.
  Future<void> start() async {
    _subscription ??= _client.updates.listen((update) {
      if (update case td.UpdateOption(
        name: 'my_id',
        value: td.OptionValueInteger(:final value),
      )) {
        _myId = value;
      }
    });
  }

  Future<void> dispose() async => _subscription?.cancel();

  /// Up to [limit] members of [chatId] matching [query] (the text after
  /// the @). Deleted accounts are left out.
  Future<List<MentionCandidate>> search(
    int chatId,
    String query, {
    int limit = 20,
  }) async {
    final found = await _client.send(
      td.SearchChatMembers(
        chatId: chatId,
        query: query,
        limit: limit,
        filter: const td.ChatMembersFilterMention(),
      ),
    );
    final ids = [
      for (final member in found.members)
        if (member.memberId case td.MessageSenderUser(:final userId)
            when userId != _myId)
          userId,
    ];
    final users = await Future.wait(
      ids.map(
        (id) => _client
            .send(td.GetUser(userId: id))
            .then<td.User?>((user) => user, onError: (Object _) => null),
      ),
    );
    return [
      for (final user in users)
        if (user != null && user.type is! td.UserTypeDeleted)
          MentionCandidate(
            userId: user.id,
            name: [
              user.firstName,
              user.lastName,
            ].where((s) => s.isNotEmpty).join(' '),
            username: user.usernames?.editableUsername ?? '',
            photo: user.profilePhoto?.small,
          ),
    ];
  }
}
