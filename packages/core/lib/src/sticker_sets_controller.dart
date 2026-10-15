import 'dart:async';

import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

/// Sticker sets or custom emoji sets: the two kinds the settings manage
/// the same way.
enum StickerSetKind {
  stickers(td.StickerTypeRegular()),
  emoji(td.StickerTypeCustomEmoji());

  const StickerSetKind(this.type);

  final td.StickerType type;

  static StickerSetKind of(td.StickerType type) =>
      type is td.StickerTypeCustomEmoji ? emoji : stickers;
}

/// The set name in a link to a sticker or emoji set: `t.me/addstickers/x`,
/// `t.me/addemoji/x`, `tg://addstickers?set=x`, `tg://addemoji?set=x`, or
/// a bare name. Null when [text] is none of these.
String? stickerSetNameOf(String text) {
  final s = text.trim();
  final bare = RegExp(r'^[A-Za-z0-9_]{1,64}$');
  if (bare.hasMatch(s)) return s;
  final uri = Uri.tryParse(s.contains('://') ? s : 'https://$s');
  if (uri == null) return null;
  final String? name;
  if (uri.scheme == 'tg') {
    name = uri.host == 'addstickers' || uri.host == 'addemoji'
        ? uri.queryParameters['set']
        : null;
  } else {
    final segments = [
      for (final segment in uri.pathSegments)
        if (segment.isNotEmpty) segment,
    ];
    final telegram = {'t.me', 'telegram.me', 'telegram.dog'}.contains(uri.host);
    name =
        telegram &&
            segments.length == 2 &&
            (segments[0] == 'addstickers' || segments[0] == 'addemoji')
        ? segments[1]
        : null;
  }
  return name != null && bare.hasMatch(name) ? name : null;
}

/// [ids] with the one at [from] moved to [to], as a list reorders: [to]
/// is the index in the list after the move.
List<int> movedId(List<int> ids, int from, int to) {
  final next = [...ids];
  next.insert(to, next.removeAt(from));
  return next;
}

/// Installed, archived and trending sticker and emoji sets, after
/// TelegramSwift's InstalledStickerPacksController: reorder, archive,
/// remove, add, and look up a set by its link.
///
/// The installed lists are kept in memory, follow
/// `updateInstalledStickerSets`, and change at once on a reorder or an
/// archive, loading again from TDLib if it refuses.
final class StickerSetsController {
  StickerSetsController(this._client);

  final td.TdClient _client;
  final _changes = StreamController<void>.broadcast(sync: true);
  StreamSubscription<td.TdObject>? _subscription;
  final _installed = <StickerSetKind, List<td.StickerSetInfo>>{};
  final _loading =
      <
        StickerSetKind,
        ({int generation, Future<List<td.StickerSetInfo>> sets})
      >{};

  /// Bumped whenever a kind's list goes stale, so a load that was already
  /// under way isn't kept.
  final _generations = <StickerSetKind, int>{};

  /// Fires after an installed list changes.
  Stream<void> get changes => _changes.stream;

  Future<void> start() async {
    _subscription ??= _client.updates.listen(_onUpdate);
  }

  void _onUpdate(td.TdObject update) {
    if (update case td.UpdateInstalledStickerSets(:final stickerType)) {
      // Loaded again with the new sets' details on the next look.
      _invalidate(StickerSetKind.of(stickerType));
    }
  }

  void _invalidate(StickerSetKind kind) {
    _generations[kind] = (_generations[kind] ?? 0) + 1;
    _installed.remove(kind);
    _loading.remove(kind);
    _changed();
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// The installed sets as last loaded, or null before [installed].
  List<td.StickerSetInfo>? installedOf(StickerSetKind kind) => _installed[kind];

  /// The installed sets in the user's order.
  Future<List<td.StickerSetInfo>> installed(StickerSetKind kind) {
    final known = _installed[kind];
    if (known != null) return Future.value(known);
    final generation = _generations[kind] ?? 0;
    final loading = _loading[kind];
    if (loading != null && loading.generation == generation) {
      return loading.sets;
    }
    final sets = () async {
      try {
        final sets = List<td.StickerSetInfo>.unmodifiable(
          (await _client.send(
            td.GetInstalledStickerSets(stickerType: kind.type),
          )).sets,
        );
        // Kept only when nothing changed while it loaded; otherwise the
        // change has already asked for another look.
        if ((_generations[kind] ?? 0) == generation) _installed[kind] = sets;
        return sets;
      } finally {
        if (_loading[kind]?.generation == generation) _loading.remove(kind);
      }
    }();
    _loading[kind] = (generation: generation, sets: sets);
    return sets;
  }

  /// Moves an installed set from [from] to [to].
  Future<void> reorder(StickerSetKind kind, int from, int to) async {
    final sets = _installed[kind];
    if (sets == null || from == to) return;
    final ids = movedId([for (final s in sets) s.id], from, to);
    await _optimistic(kind, ids, () async {
      await _client.send(
        td.ReorderInstalledStickerSets(
          stickerType: kind.type,
          stickerSetIds: ids,
        ),
      );
    });
  }

  /// Moves an installed set to the archived ones.
  Future<void> archive(td.StickerSetInfo set) =>
      _change(set, installed: false, archived: true);

  /// Removes an installed or archived set.
  Future<void> remove(td.StickerSetInfo set) =>
      _change(set, installed: false, archived: false);

  /// Installs a set, from the trending ones, a link, or the archive.
  Future<void> install(int setId, StickerSetKind kind) async {
    await _client.send(
      td.ChangeStickerSet(setId: setId, isInstalled: true, isArchived: false),
    );
    // TDLib adds it at the top; the next look loads the list again.
    _invalidate(kind);
  }

  Future<void> _change(
    td.StickerSetInfo set, {
    required bool installed,
    required bool archived,
  }) async {
    final kind = StickerSetKind.of(set.stickerType);
    final sets = _installed[kind];
    final ids = [
      for (final s in sets ?? const <td.StickerSetInfo>[])
        if (s.id != set.id) s.id,
    ];
    await _optimistic(kind, ids, () async {
      await _client.send(
        td.ChangeStickerSet(
          setId: set.id,
          isInstalled: installed,
          isArchived: archived,
        ),
      );
    });
  }

  /// Shows [ids] at once, in that order. If [request] fails the list is
  /// loaded again: putting back a snapshot could undo a later change that
  /// succeeded.
  Future<void> _optimistic(
    StickerSetKind kind,
    List<int> ids,
    Future<void> Function() request,
  ) async {
    final before = _installed[kind];
    if (before != null) {
      final byId = {for (final s in before) s.id: s};
      _installed[kind] = List.unmodifiable([for (final id in ids) ?byId[id]]);
      _changed();
    }
    try {
      await request();
    } on Object {
      _invalidate(kind);
      rethrow;
    }
  }

  /// Archived sets, newest first, a page at a time: pass the last id seen
  /// as [after] for the next page.
  Future<List<td.StickerSetInfo>> archived(
    StickerSetKind kind, {
    int after = 0,
    int limit = 50,
  }) async => (await _client.send(
    td.GetArchivedStickerSets(
      stickerType: kind.type,
      offsetStickerSetId: after,
      limit: limit,
    ),
  )).sets;

  /// Sets Telegram features now, a page at a time from [offset].
  Future<List<td.StickerSetInfo>> trending(
    StickerSetKind kind, {
    int offset = 0,
    int limit = 50,
  }) async => (await _client.send(
    td.GetTrendingStickerSets(
      stickerType: kind.type,
      offset: offset,
      limit: limit,
    ),
  )).sets;

  /// Marks trending sets as seen, so Telegram stops counting them as new.
  Future<void> viewTrending(List<int> setIds) async {
    if (setIds.isEmpty) return;
    await _client.send(td.ViewTrendingStickerSets(stickerSetIds: setIds));
  }

  /// The set named [name] with all its stickers, as a link names it.
  Future<td.StickerSet> byName(String name) =>
      _client.send(td.SearchStickerSet(name: name, ignoreCache: false));

  /// Whether single emoji play as animations, TDLib's
  /// `disable_animated_emoji` turned around.
  Future<bool> animatedEmoji() async {
    final value = await _client.send(
      const td.GetOption(name: 'disable_animated_emoji'),
    );
    return !(value is td.OptionValueBoolean && value.value);
  }

  Future<void> setAnimatedEmoji(bool on) => _client.send(
    td.SetOption(
      name: 'disable_animated_emoji',
      value: td.OptionValueBoolean(value: !on),
    ),
  );

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }
}
