import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// A folder as the folder list shows it, from `updateChatFolders`.
final class ChatFolderSummary {
  const ChatFolderSummary({
    required this.id,
    required this.title,
    required this.iconName,
    this.isShareable = false,
    this.hasMyInviteLinks = false,
  });

  final int id;
  final String title;

  /// One of TDLib's folder icon names, such as "Work"; see [chatFolderIconNames].
  final String iconName;
  final bool isShareable;
  final bool hasMyInviteLinks;
}

/// The icon names TDLib accepts in `chatFolderIcon`, in the order the
/// picker shows them.
const chatFolderIconNames = [
  'Custom',
  'All',
  'Unread',
  'Unmuted',
  'Private',
  'Groups',
  'Channels',
  'Bots',
  'Favorite',
  'Love',
  'Home',
  'Work',
  'Study',
  'Trade',
  'Money',
  'Travel',
  'Airplane',
  'Book',
  'Note',
  'Light',
  'Like',
  'Palette',
  'Game',
  'Sport',
  'Party',
  'Flower',
  'Cat',
  'Crown',
  'Mask',
  'Setup',
];

/// The rules of one folder while it is edited: which chats it takes in by
/// type or by name, which it leaves out, and its name and icon.
final class ChatFolderDraft {
  const ChatFolderDraft({
    this.title = '',
    this.iconName = '',
    this.colorId = -1,
    this.isShareable = false,
    this.pinnedChatIds = const [],
    this.includedChatIds = const [],
    this.excludedChatIds = const [],
    this.includeContacts = false,
    this.includeNonContacts = false,
    this.includeGroups = false,
    this.includeChannels = false,
    this.includeBots = false,
    this.excludeMuted = false,
    this.excludeRead = false,
    this.excludeArchived = false,
  });

  factory ChatFolderDraft.fromTd(td.ChatFolder folder) => ChatFolderDraft(
    title: folder.name.text.text,
    iconName: folder.icon?.name ?? '',
    colorId: folder.colorId,
    isShareable: folder.isShareable,
    pinnedChatIds: folder.pinnedChatIds,
    includedChatIds: folder.includedChatIds,
    excludedChatIds: folder.excludedChatIds,
    includeContacts: folder.includeContacts,
    includeNonContacts: folder.includeNonContacts,
    includeGroups: folder.includeGroups,
    includeChannels: folder.includeChannels,
    includeBots: folder.includeBots,
    excludeMuted: folder.excludeMuted,
    excludeRead: folder.excludeRead,
    excludeArchived: folder.excludeArchived,
  );

  /// The name; TDLib allows up to [maxTitleLength] characters.
  final String title;

  /// Empty lets TDLib choose the icon from the rules.
  final String iconName;
  final int colorId;
  final bool isShareable;
  final List<int> pinnedChatIds;
  final List<int> includedChatIds;
  final List<int> excludedChatIds;
  final bool includeContacts;
  final bool includeNonContacts;
  final bool includeGroups;
  final bool includeChannels;
  final bool includeBots;
  final bool excludeMuted;
  final bool excludeRead;
  final bool excludeArchived;

  static const maxTitleLength = 12;

  /// Whether any chat type is taken in.
  bool get includesTypes =>
      includeContacts ||
      includeNonContacts ||
      includeGroups ||
      includeChannels ||
      includeBots;

  /// The chats picked by name, pinned ones first, as TDLib counts them
  /// against the limit.
  List<int> get chosenChatIds => [
    ...pinnedChatIds,
    for (final id in includedChatIds)
      if (!pinnedChatIds.contains(id)) id,
  ];

  /// TDLib rejects a folder without a name or without any chat.
  bool get canSave =>
      title.trim().isNotEmpty &&
      (includesTypes || pinnedChatIds.isNotEmpty || includedChatIds.isNotEmpty);

  ChatFolderDraft copyWith({
    String? title,
    String? iconName,
    List<int>? pinnedChatIds,
    List<int>? includedChatIds,
    List<int>? excludedChatIds,
    bool? includeContacts,
    bool? includeNonContacts,
    bool? includeGroups,
    bool? includeChannels,
    bool? includeBots,
    bool? excludeMuted,
    bool? excludeRead,
    bool? excludeArchived,
  }) => ChatFolderDraft(
    title: title ?? this.title,
    iconName: iconName ?? this.iconName,
    colorId: colorId,
    isShareable: isShareable,
    pinnedChatIds: pinnedChatIds ?? this.pinnedChatIds,
    includedChatIds: includedChatIds ?? this.includedChatIds,
    excludedChatIds: excludedChatIds ?? this.excludedChatIds,
    includeContacts: includeContacts ?? this.includeContacts,
    includeNonContacts: includeNonContacts ?? this.includeNonContacts,
    includeGroups: includeGroups ?? this.includeGroups,
    includeChannels: includeChannels ?? this.includeChannels,
    includeBots: includeBots ?? this.includeBots,
    excludeMuted: excludeMuted ?? this.excludeMuted,
    excludeRead: excludeRead ?? this.excludeRead,
    excludeArchived: excludeArchived ?? this.excludeArchived,
  );

  td.ChatFolder toTd() => td.ChatFolder(
    name: td.ChatFolderName(
      text: td.FormattedText(text: title.trim(), entities: const []),
      animateCustomEmoji: false,
    ),
    icon: iconName.isEmpty ? null : td.ChatFolderIcon(name: iconName),
    colorId: colorId,
    isShareable: isShareable,
    pinnedChatIds: pinnedChatIds,
    // A chat is either pinned or included, never both.
    includedChatIds: [
      for (final id in includedChatIds)
        if (!pinnedChatIds.contains(id)) id,
    ],
    excludedChatIds: excludedChatIds,
    excludeMuted: excludeMuted,
    excludeRead: excludeRead,
    excludeArchived: excludeArchived,
    includeContacts: includeContacts,
    includeNonContacts: includeNonContacts,
    includeBots: includeBots,
    includeGroups: includeGroups,
    includeChannels: includeChannels,
  );
}

/// A folder Telegram suggests, such as "Unread" or "Personal".
final class RecommendedChatFolder {
  const RecommendedChatFolder({
    required this.folder,
    required this.description,
  });

  final ChatFolderDraft folder;
  final String description;
}

/// What kind of chat a row of the chat picker is.
enum FolderChatKind { user, bot, group, channel }

/// A chat as the folder editor and its picker show it.
final class FolderChat {
  const FolderChat({
    required this.id,
    required this.title,
    required this.kind,
    this.photo,
    this.isSelf = false,
  });

  final int id;
  final String title;
  final FolderChatKind kind;
  final td.File? photo;

  /// Saved Messages.
  final bool isSelf;
}

/// The account's chat folders: the list TDLib keeps up to date, and
/// creating, editing, reordering and deleting them.
///
/// The limits come from TDLib's options and grow with Premium: 10 folders
/// and 100 chosen chats per folder without it, 20 and 200 with it.
final class ChatFoldersController {
  ChatFoldersController(this._client);

  final td.TdClient _client;
  final _changes = StreamController<void>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  var _folders = const <ChatFolderSummary>[];
  var _mainPosition = 0;
  var _maxFolders = 10;
  var _maxChosenChats = 100;
  int? _myId;

  /// The folders in the order the sidebar shows them.
  List<ChatFolderSummary> get folders => _folders;

  /// Where "All chats" sits among the folders; 0 is first.
  int get mainChatListPosition => _mainPosition;

  /// How many folders the account can have.
  int get maxFolders => _maxFolders;

  /// How many chats a folder can take in by name.
  int get maxChosenChats => _maxChosenChats;

  bool get canCreate => _folders.length < _maxFolders;

  /// Fires after the folders or the limits change.
  Stream<void> get changes => _changes.stream;

  /// Subscribes to updates. Call it before sign-in, so the first
  /// `updateChatFolders` is not missed.
  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  void _onUpdate(td.TdObject update) {
    switch (update) {
      case td.UpdateChatFolders(
        :final chatFolders,
        :final mainChatListPosition,
      ):
        _folders = List.unmodifiable([
          for (final folder in chatFolders)
            ChatFolderSummary(
              id: folder.id,
              title: folder.name.text.text,
              iconName: folder.icon.name,
              isShareable: folder.isShareable,
              hasMyInviteLinks: folder.hasMyInviteLinks,
            ),
        ]);
        _mainPosition = mainChatListPosition;
      case td.UpdateOption(
        name: 'chat_folder_count_max',
        value: td.OptionValueInteger(:final value),
      ):
        _maxFolders = value;
      case td.UpdateOption(
        name: 'chat_folder_chosen_chat_count_max',
        value: td.OptionValueInteger(:final value),
      ):
        _maxChosenChats = value;
      case td.UpdateOption(
        name: 'my_id',
        value: td.OptionValueInteger(:final value),
      ):
        _myId = value;
        return;
      default:
        return;
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The rules of folder [id].
  Future<ChatFolderDraft> folder(int id) async => ChatFolderDraft.fromTd(
    await _client.send(td.GetChatFolder(chatFolderId: id)),
  );

  /// Creates a folder and returns its id.
  Future<int> create(ChatFolderDraft folder) async {
    final info = await _client.send(td.CreateChatFolder(folder: folder.toTd()));
    return info.id;
  }

  Future<void> edit(int id, ChatFolderDraft folder) =>
      _client.send(td.EditChatFolder(chatFolderId: id, folder: folder.toTd()));

  /// The chats the user can leave together with folder [id]: those it
  /// was shared with them through.
  Future<List<FolderChat>> chatsToLeave(int id) async {
    final chats = await _client.send(
      td.GetChatFolderChatsToLeave(chatFolderId: id),
    );
    return describe(chats.chatIds);
  }

  /// Deletes folder [id], leaving [leaveChatIds] with it.
  Future<void> delete(int id, {List<int> leaveChatIds = const []}) async {
    await _client.send(
      td.DeleteChatFolder(chatFolderId: id, leaveChatIds: leaveChatIds),
    );
    _folders = List.unmodifiable([
      for (final f in _folders)
        if (f.id != id) f,
    ]);
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Puts the folders in the order of [ids] at once, and asks TDLib to;
  /// when it refuses, the order it last reported comes back.
  Future<void> reorder(List<int> ids) async {
    final before = _folders;
    final byId = {for (final f in before) f.id: f};
    _folders = List.unmodifiable([for (final id in ids) ?byId[id]]);
    if (!_changes.isClosed) _changes.add(null);
    try {
      await _client.send(
        td.ReorderChatFolders(
          chatFolderIds: ids,
          mainChatListPosition: _mainPosition,
        ),
      );
    } on Object {
      _folders = before;
      if (!_changes.isClosed) _changes.add(null);
      rethrow;
    }
  }

  /// The folders Telegram suggests for this account.
  Future<List<RecommendedChatFolder>> recommended() async {
    final found = await _client.send(const td.GetRecommendedChatFolders());
    return [
      for (final r in found.chatFolders)
        RecommendedChatFolder(
          folder: ChatFolderDraft.fromTd(r.folder),
          description: r.description,
        ),
    ];
  }

  /// The title, kind and photo of each of [ids], in order; chats TDLib
  /// doesn't know are left out.
  Future<List<FolderChat>> describe(List<int> ids) async {
    final chats = await Future.wait([
      for (final id in ids) _describe(id).catchError((Object _) => null),
    ]);
    return [for (final chat in chats) ?chat];
  }

  /// Chats to pick from: the main list in its order, or the chats that
  /// match [query].
  Future<List<FolderChat>> candidates({
    String query = '',
    int limit = 100,
  }) async {
    final q = query.trim();
    final chats = await _client.send(
      q.isEmpty
          ? td.GetChats(chatList: const td.ChatListMain(), limit: limit)
          : td.SearchChats(query: q, limit: limit),
    );
    return describe(chats.chatIds);
  }

  Future<FolderChat?> _describe(int id) async {
    final chat = await _client.send(td.GetChat(chatId: id));
    final kind = switch (chat.type) {
      td.ChatTypeBasicGroup() => FolderChatKind.group,
      td.ChatTypeSupergroup(:final isChannel) =>
        isChannel ? FolderChatKind.channel : FolderChatKind.group,
      td.ChatTypePrivate(:final userId) ||
      td.ChatTypeSecret(:final userId) => await _userKind(userId),
    };
    final userId = switch (chat.type) {
      td.ChatTypePrivate(:final userId) => userId,
      _ => null,
    };
    return FolderChat(
      id: chat.id,
      title: chat.title,
      kind: kind,
      photo: chat.photo?.small,
      isSelf: userId != null && userId == _myId,
    );
  }

  Future<FolderChatKind> _userKind(int userId) async {
    try {
      final user = await _client.send(td.GetUser(userId: userId));
      return user.type is td.UserTypeBot
          ? FolderChatKind.bot
          : FolderChatKind.user;
    } on Object {
      return FolderChatKind.user;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
