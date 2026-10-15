import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// The tags on the user's Saved Messages: the reactions put on saved
/// messages, each with the name the user gave it and how many messages
/// carry it, as `getSavedMessagesTags` lists them and
/// `updateSavedMessagesTags` keeps them.
///
/// Made by `ConversationController.openSavedTags`, which feeds it
/// updates until [dispose].
final class SavedTags {
  SavedTags(this._client, {required this._onDispose});

  final td.TdClient _client;
  final void Function(SavedTags) _onDispose;
  final _changes = StreamController<void>.broadcast(sync: true);
  var _tags = const <td.SavedMessagesTag>[];
  var _disposed = false;

  Stream<void> get changes => _changes.stream;

  /// Most used first, as TDLib orders them.
  List<td.SavedMessagesTag> get tags => _tags;

  /// Asks TDLib for the tags across all of Saved Messages.
  Future<void> load() async {
    final result = await _client.send(
      const td.GetSavedMessagesTags(savedMessagesTopicId: 0),
    );
    if (_disposed) return;
    _tags = result.tags;
    _notify();
  }

  /// Gives [tag] the name [label], or takes the name away when empty.
  Future<void> setLabel(td.ReactionType tag, String label) =>
      _client.send(td.SetSavedMessagesTagLabel(tag: tag, label: label));

  /// Applies a TDLib update to the tags.
  void handle(td.TdObject update) {
    if (update case td.UpdateSavedMessagesTags(
      savedMessagesTopicId: 0,
      :final tags,
    )) {
      _tags = tags.tags;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) _changes.add(null);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _onDispose(this);
    unawaited(_changes.close());
  }
}
